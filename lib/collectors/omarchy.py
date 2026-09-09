#!/usr/bin/env python3
"""Collect Omarchy hardware facts and submit them to Market."""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

MARKET_URL = os.environ.get("MARKET_URL") or "__MARKET_URL__"
SYS = os.environ.get("MARKET_SYS_ROOT") or "/"


def root(*parts: str) -> str:
    return os.path.join(SYS, *[part.lstrip("/") for part in parts])


def read_text(path: str, limit: int = 8192) -> str:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return handle.read(limit)
    except OSError:
        return ""


def read_strip(path: str) -> str:
    return read_text(path).strip()


def clean(value: object, limit: int = 240) -> str:
    text = re.sub(r"[\r\n\t]+", " ", str(value or "")).strip()
    if not text:
        return ""
    lowered = text.lower()
    if lowered in {
        "not specified",
        "unknown",
        "none",
        "to be filled by o.e.m.",
        "default string",
        "system product name",
        "system manufacturer",
    }:
        return ""
    return text[:limit]


def parse_os_release(raw: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in raw.splitlines():
        if "=" not in line or line.startswith("#"):
            continue
        key, value = line.split("=", 1)
        fields[key] = value.strip().strip('"')
    return fields


def require_omarchy() -> dict[str, str]:
    fields = parse_os_release(read_text(root("etc/os-release")))
    if fields.get("ID") != "omarchy":
        raise SystemExit("This collector only runs on Omarchy. ID in /etc/os-release must be omarchy.")
    version = clean(fields.get("VERSION_ID") or fields.get("BUILD_ID") or "unknown", 80)
    channel_path = root("etc/omarchy/channel")
    channel = clean(read_strip(channel_path), 40) or "stable"
    return {"version": version, "channel": channel}


def dmi(name: str) -> str:
    if "serial" in name.lower() or name.lower() in {"product_uuid", "chassis_serial"}:
        return ""
    return clean(read_strip(root("sys/class/dmi/id", name)))


def instance_digest(vendor: str, product: str, cpu_model: str) -> str:
    machine_id = read_strip(root("etc/machine-id"))
    product_serial = read_strip(root("sys/class/dmi/id/product_serial"))
    board_serial = read_strip(root("sys/class/dmi/id/board_serial"))
    if product_serial or board_serial:
        material = f"{machine_id}\0{product_serial}\0{board_serial}"
    else:
        material = f"{machine_id}\0{vendor}\0{product}\0{cpu_model}"
    return hashlib.sha256(b"omarchy-market-instance-v1\0" + material.encode("utf-8", "replace")).hexdigest()


def cpuinfo() -> dict[str, object]:
    raw = read_text(root("proc/cpuinfo"), 65536)
    model = vendor = arch = ""
    cores = 0
    for line in raw.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = clean(value)
        if key == "model name" and not model:
            model = value
        elif key == "vendor_id" and not vendor:
            vendor = value
        elif key == "processor":
            cores += 1
    uname = os.uname().machine if SYS == "/" else ""
    arch = uname or clean(os.environ.get("MARKET_ARCH", ""))
    if not model:
        model = "Unknown CPU"
    if not arch:
        arch = "unknown"
    return {"model": model, "vendor": vendor, "arch": arch, "cores": cores or 1}


def memory_bytes() -> int:
    for line in read_text(root("proc/meminfo")).splitlines():
        if line.startswith("MemTotal:"):
            parts = line.split()
            try:
                return int(parts[1]) * 1024
            except (IndexError, ValueError):
                return 0
    return 0


def run(argv: list[str]) -> str:
    if os.environ.get("MARKET_SKIP_CMDS"):
        return ""
    try:
        return subprocess.check_output(argv, text=True, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.CalledProcessError):
        return ""


def secure_boot_enabled() -> bool:
    path = root("sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c")
    try:
        with open(path, "rb") as handle:
            data = handle.read(8)
    except OSError:
        return False
    return len(data) >= 5 and data[4] == 1


def gpus() -> list[dict[str, str]]:
    found: list[dict[str, str]] = []
    raw = run(["lspci", "-mm"])
    for line in raw.splitlines():
        if '"VGA compatible controller"' not in line and '"3D controller"' not in line:
            continue
        fields = re.findall(r'"([^"]*)"', line)
        if len(fields) >= 3:
            found.append({"vendor": clean(fields[1], 120), "name": clean(fields[2], 160)})
        if len(found) >= 8:
            break
    return found


def payload() -> dict[str, object]:
    omarchy = require_omarchy()
    hardware = {
        "vendor": dmi("sys_vendor"),
        "product": dmi("product_name"),
        "family": dmi("product_family"),
        "chassis": dmi("chassis_type"),
        "cpu": cpuinfo(),
        "memory_bytes": memory_bytes(),
        "gpus": gpus(),
        "uefi": os.path.isdir(root("sys/firmware/efi")),
        "tpm": {"present": os.path.isdir(root("sys/class/tpm"))},
        "secure_boot": {"enabled": secure_boot_enabled()},
    }
    if not hardware["vendor"] or not hardware["product"]:
        raise SystemExit("Could not read machine vendor and product from DMI.")
    digest = instance_digest(str(hardware["vendor"]), str(hardware["product"]), str(hardware["cpu"]["model"]))
    return {"omarchy": omarchy, "hardware": hardware, "instance_digest": digest}


def fetch_challenge() -> str:
    request = urllib.request.Request(
        MARKET_URL.rstrip("/") + "/challenges",
        headers={"User-Agent": "omarchy-market-collect/1"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")
        raise SystemExit(f"Market rejected the challenge ({error.code}): {detail}") from error
    except urllib.error.URLError as error:
        raise SystemExit(f"Could not reach Market at {MARKET_URL}: {error.reason}") from error
    nonce = payload.get("nonce")
    if not nonce:
        raise SystemExit("Market did not return a challenge nonce.")
    return str(nonce)


def submit(body: dict[str, object]) -> dict[str, object]:
    encoded = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        MARKET_URL.rstrip("/") + "/reports",
        data=encoded,
        headers={"Content-Type": "application/json", "User-Agent": "omarchy-market-collect/1"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")
        raise SystemExit(f"Market rejected the report ({error.code}): {detail}") from error
    except urllib.error.URLError as error:
        raise SystemExit(f"Could not reach Market at {MARKET_URL}: {error.reason}") from error


def assert_no_identifiers(body: dict[str, object]) -> None:
    names: list[str] = []

    def walk(value: object) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                names.append(str(key).lower())
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)

    walk(body)
    for fragment in ("serial", "mac", "hostname", "username"):
        if any(fragment in name for name in names):
            raise SystemExit(f"Refusing to submit identifier field containing {fragment}")


def main() -> None:
    if MARKET_URL.startswith("__"):
        raise SystemExit("Set MARKET_URL, or download this script from Market so the URL is filled in.")
    body = payload()
    assert_no_identifiers(body)
    if os.environ.get("MARKET_DRY_RUN"):
        json.dump(body, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return
    body["nonce"] = fetch_challenge()
    result = submit(body)
    print("Submitted a hardware report.")
    if result.get("model_url"):
        print(f"Compatibility page: {result['model_url']}")
    if result.get("claim_url"):
        print(f"Claim this report: {result['claim_url']}")


if __name__ == "__main__":
    main()
