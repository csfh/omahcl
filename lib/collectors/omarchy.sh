#!/usr/bin/env bash
# Hardware check for Omarchy. It sends nothing unless you say yes.
#
#   On Omarchy:      asks, then sends a public hardware report.
#   Anywhere else:   checks locally whether this machine looks able to run Omarchy.
#                    It sends nothing.
#   Served as /delete: rebuilds this machine's hashes, then asks whether to delete
#                    any report the site holds for them.

set -euo pipefail

OMAHCL_URL=${OMAHCL_URL:-__OMAHCL_URL__}
# CollectsController fills this in for /collect and /delete. Anything but "delete"
# collects.
OMAHCL_ACTION=${OMAHCL_ACTION:-__OMAHCL_ACTION__}
OMAHCL_SYS_ROOT=${OMAHCL_SYS_ROOT:-}
OMAHCL_ARCH=${OMAHCL_ARCH:-}
OMAHCL_KERNEL=${OMAHCL_KERNEL:-}
OMAHCL_DRY_RUN=${OMAHCL_DRY_RUN:-}
OMAHCL_SUBMIT=${OMAHCL_SUBMIT:-}
OMAHCL_SKIP_CMDS=${OMAHCL_SKIP_CMDS:-}

SYS=${OMAHCL_SYS_ROOT:-/}
SYS=${SYS%/}
[[ -n $SYS ]] || SYS=/

root() {
  local part=${1#/}
  if [[ $SYS == / ]]; then
    printf '/%s\n' "$part"
  else
    printf '%s/%s\n' "$SYS" "$part"
  fi
}

read_strip() {
  local path=$1
  [[ -r $path ]] || { printf ''; return; }
  tr -d '\r' <"$path" | tr '\n\t' '  ' | head -c 8192 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

clean() {
  local text=$1
  local limit=${2:-240}
  text=${text//$'\r'/ }
  text=${text//$'\n'/ }
  text=${text//$'\t'/ }
  text=$(printf '%s' "$text" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  local lowered
  lowered=$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')
  case $lowered in
    "not specified" | unknown | none | "to be filled by o.e.m." | "default string" | "system product name" | "system manufacturer")
      printf ''
      return
      ;;
  esac
  printf '%s' "${text:0:limit}"
}

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/ }
  s=${s//$'\r'/ }
  s=${s//$'\t'/ }
  printf '%s' "$s"
}

os_field() {
  local key=$1
  local file
  file=$(root etc/os-release)
  [[ -r $file ]] || { printf ''; return; }
  local line
  line=$(grep -E "^${key}=" "$file" | head -n 1 || true)
  [[ -n $line ]] || { printf ''; return; }
  line=${line#*=}
  line=${line#\"}
  line=${line%\"}
  printf '%s' "$line"
}

dmi() {
  local name=$1
  local lower=${name,,}
  if [[ $lower == *serial* || $lower == product_uuid || $lower == chassis_serial ]]; then
    printf ''
    return
  fi
  clean "$(read_strip "$(root "sys/class/dmi/id/$name")")"
}

cpu_field() {
  local key=$1
  local file
  file=$(root proc/cpuinfo)
  [[ -r $file ]] || { printf ''; return; }
  local line
  line=$(grep -E "^${key}[[:space:]]*:" "$file" | head -n 1 || true)
  [[ -n $line ]] || { printf ''; return; }
  clean "${line#*:}"
}

cpu_cores() {
  local file
  file=$(root proc/cpuinfo)
  [[ -r $file ]] || { printf '1'; return; }
  local count
  count=$(grep -c '^processor' "$file" || true)
  [[ ${count:-0} -gt 0 ]] || count=1
  printf '%s' "$count"
}

cpu_arch() {
  if [[ $SYS == / ]]; then
    uname -m
  else
    printf '%s' "${OMAHCL_ARCH:-unknown}"
  fi
}

memory_bytes() {
  local file
  file=$(root proc/meminfo)
  [[ -r $file ]] || { printf '0'; return; }
  local kb
  kb=$(awk '/^MemTotal:/ { print $2; exit }' "$file")
  if [[ -z ${kb:-} ]]; then
    printf '0'
    return
  fi
  printf '%s' $((kb * 1024))
}

sha256_hex() {
  sha256sum | awk '{ print $1 }'
}

instance_digest() {
  local vendor=$1 product=$2 cpu_model=$3
  # This domain string predates the current name. Never rename it: that would
  # give every machine a new instance_digest and split its history.
  local domain=omarchy-market-instance-v1
  local machine_id
  machine_id=$(read_strip "$(root etc/machine-id)")
  printf '%s\0%s\0%s\0%s\0%s' "$domain" "$machine_id" "$vendor" "$product" "$cpu_model" | sha256_hex
}

host_kernel() {
  if [[ $SYS == / ]]; then
    uname -s
  else
    printf '%s' "${OMAHCL_KERNEL:-Linux}"
  fi
}

bool_dir() {
  if [[ -d $1 ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

secure_boot_enabled() {
  local path
  path=$(root sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c)
  if [[ ! -r $path ]]; then
    printf 'false'
    return
  fi
  local byte
  byte=$(dd if="$path" bs=1 skip=4 count=1 2>/dev/null | od -An -tu1 | tr -d ' \n')
  if [[ ${byte:-0} == 1 ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

# on, off, or unknown (the variable is missing or unreadable).
secure_boot_state() {
  local path
  path=$(root sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c)
  if [[ ! -r $path ]]; then
    printf 'unknown'
    return
  fi
  local byte
  byte=$(dd if="$path" bs=1 skip=4 count=1 2>/dev/null | od -An -tu1 | tr -d ' \n')
  if [[ ${byte:-0} == 1 ]]; then
    printf 'on'
  else
    printf 'off'
  fi
}

gpus_json() {
  if [[ -n ${OMAHCL_SKIP_CMDS:-} ]] || ! command -v lspci >/dev/null 2>&1; then
    printf '[]'
    return
  fi
  local json='[' n=0 line class vendor name
  while IFS= read -r line; do
    case $line in
      *'"VGA compatible controller"'* | *'"3D controller"'*) ;;
      *) continue ;;
    esac
    class=$(printf '%s' "$line" | grep -o '"[^"]*"' | sed -n '1s/"//gp')
    vendor=$(printf '%s' "$line" | grep -o '"[^"]*"' | sed -n '2s/"//gp')
    name=$(printf '%s' "$line" | grep -o '"[^"]*"' | sed -n '3s/"//gp')
    vendor=$(clean "$vendor" 120)
    name=$(clean "$name" 160)
    if [[ $n -gt 0 ]]; then
      json+=','
    fi
    json+=$(printf '{"vendor":"%s","name":"%s"}' "$(json_escape "$vendor")" "$(json_escape "$name")")
    n=$((n + 1))
    [[ $n -ge 8 ]] && break
  done < <(lspci -mm 2>/dev/null || true)
  json+=']'
  printf '%s' "$json"
}

# Omarchy's release channel is the path segment of its package repository.
omarchy_channel() {
  local file channel
  file=$(root etc/pacman.conf)
  [[ -r $file ]] || { printf 'stable'; return; }
  channel=$(sed -n 's#^[[:space:]]*Server[[:space:]]*=[[:space:]]*https\{0,1\}://pkgs\.omarchy\.org/\([^/]*\)/.*#\1#p' "$file" | head -n 1)
  channel=$(clean "$channel" 40)
  [[ -n $channel ]] || channel=stable
  printf '%s' "$channel"
}

# Fills the F_* globals from /proc, /sys and /etc. Never reads serial numbers.
gather_facts() {
  F_vendor=$(dmi sys_vendor)
  F_product=$(dmi product_name)
  F_family=$(dmi product_family)
  F_chassis=$(dmi chassis_type)
  F_cpu_model=$(cpu_field "model name")
  F_cpu_vendor=$(cpu_field vendor_id)
  F_arch=$(clean "$(cpu_arch)" 40)
  F_cores=$(cpu_cores)
  F_mem=$(memory_bytes)
  F_uefi=$(bool_dir "$(root sys/firmware/efi)")
  F_tpm=$(bool_dir "$(root sys/class/tpm)")
  F_sb=$(secure_boot_state)
  F_gpus=$(gpus_json)
  [[ -n $F_cpu_model ]] || F_cpu_model="Unknown CPU"
  [[ -n $F_arch ]] || F_arch=unknown
}

hardware_json() {
  local sb=false
  [[ $F_sb == on ]] && sb=true
  printf '{"vendor":"%s","product":"%s","family":"%s","chassis":"%s","cpu":{"model":"%s","vendor":"%s","arch":"%s","cores":%s},"memory_bytes":%s,"gpus":%s,"uefi":%s,"tpm":{"present":%s},"secure_boot":{"enabled":%s}}' \
    "$(json_escape "$F_vendor")" \
    "$(json_escape "$F_product")" \
    "$(json_escape "$F_family")" \
    "$(json_escape "$F_chassis")" \
    "$(json_escape "$F_cpu_model")" \
    "$(json_escape "$F_cpu_vendor")" \
    "$(json_escape "$F_arch")" \
    "$F_cores" \
    "$F_mem" \
    "$F_gpus" \
    "$F_uefi" \
    "$F_tpm" \
    "$sb"
}

omarchy_payload() {
  local version channel digest
  version=$(clean "$(os_field VERSION_ID)" 80)
  [[ -n $version ]] || version=$(clean "$(os_field BUILD_ID)" 80)
  [[ -n $version ]] || version=unknown
  channel=$(omarchy_channel)
  digest=$(instance_digest "$F_vendor" "$F_product" "$F_cpu_model")
  printf '{"omarchy":{"version":"%s","channel":"%s"},"hardware":%s,"instance_digest":"%s"}' \
    "$(json_escape "$version")" "$(json_escape "$channel")" "$(hardware_json)" "$digest"
}

delete_payload() {
  printf '{"instance_digest":"%s"}' "$(instance_digest "$F_vendor" "$F_product" "$F_cpu_model")"
}

# Each rule cites where it comes from. Anything the Omarchy manual does not
# settle is labelled "to verify" instead of being stated as fact.
evaluate() {
  GOOD=() BLOCKERS=() FIXES=() UNSURE=()
  local lower_vendor=${F_vendor,,}

  case $F_arch in
    x86_64)
      GOOD+=("x86_64 CPU. The manual names no architecture requirement, so this is not a guarantee.")
      ;;
    aarch64 | arm64)
      if [[ $lower_vendor == apple* ]]; then
        BLOCKERS+=("Apple silicon Mac. The manual says installing on an M-series Mac is not supported.")
      else
        UNSURE+=("ARM CPU ($F_arch). The manual does not say whether Omarchy installs on ARM (to verify).")
      fi
      ;;
    *)
      UNSURE+=("CPU architecture $F_arch. The manual does not say whether it is supported (to verify).")
      ;;
  esac

  if [[ $lower_vendor == apple* && $F_arch == x86_64 ]]; then
    UNSURE+=("Intel Mac. Supported since Omarchy 3, but the manual says sound and the Touch Bar do not work. It does not mention T2 Macs (to verify).")
  fi

  if [[ $F_uefi == true ]]; then
    case $F_sb in
      on) FIXES+=("Secure Boot is on. Turn it off in the BIOS before installing; the manual says the installer needs it off.") ;;
      unknown) UNSURE+=("Could not read the Secure Boot state. The manual says it must be off to install.") ;;
      off) GOOD+=("Secure Boot is off, as the installer needs.") ;;
    esac
  else
    UNSURE+=("Booted in legacy BIOS mode. The manual does not say whether Omarchy supports it (to verify).")
  fi

  if [[ $F_tpm == true ]]; then
    FIXES+=("A TPM is visible. The manual says to turn off Secure Boot and/or TPM in the BIOS before installing, so check that setting.")
  fi

  if [[ $F_mem -gt 0 && $F_mem -lt 1610612736 ]]; then
    UNSURE+=("Under 2 GB of memory. The Omarchy site shows a 2 GB ThinkPad X220 running it; less is untested (to verify).")
  fi

  if printf '%s' "$F_gpus" | grep -qi nvidia; then
    UNSURE+=("NVIDIA GPU. The manual lists no supported generations or drivers (to verify).")
  fi

  if [[ ${#BLOCKERS[@]} -gt 0 ]]; then
    VERDICT=unlikely
  elif [[ ${#UNSURE[@]} -gt 0 ]]; then
    VERDICT=unclear
  else
    VERDICT=likely
  fi
}

print_list() {
  local heading=$1 marker=$2
  shift 2
  [[ $# -gt 0 ]] || return 0
  echo
  echo "$heading"
  local item
  for item in "$@"; do
    echo "  $marker $item"
  done
}

print_machine() {
  echo
  echo "${F_vendor:-Unknown vendor} ${F_product:-unknown model}"
  echo "$F_cpu_model, $(((F_mem + 536870912) / 1073741824)) GB memory, $F_arch"
}

print_verdict() {
  print_machine
  echo
  case $VERDICT in
    likely)
      if [[ ${#FIXES[@]} -gt 0 ]]; then
        echo "Verdict: likely, once you change the BIOS settings below."
      else
        echo "Verdict: likely. Nothing here stands in the way of installing Omarchy."
      fi
      ;;
    unclear) echo "Verdict: unclear. Some things below are not covered by the Omarchy manual." ;;
    unlikely) echo "Verdict: unlikely. See what blocks it below." ;;
  esac
  print_list "Blocks it:" "x" "${BLOCKERS[@]+"${BLOCKERS[@]}"}"
  print_list "Change before installing:" "!" "${FIXES[@]+"${FIXES[@]}"}"
  print_list "Not settled by the manual:" "?" "${UNSURE[@]+"${UNSURE[@]}"}"
  print_list "Looks fine:" "+" "${GOOD[@]+"${GOOD[@]}"}"
  echo
  echo "Not checked: Wi-Fi, Bluetooth, audio, suspend, fingerprint reader. The manual has no hardware list."
}

# Shows what a send shares and the privacy policy, then asks. Every send needs an
# explicit yes, from the prompt or OMAHCL_SUBMIT; no terminal means no.
confirm_submit() {
  echo
  echo "Nothing has been sent yet. If you answer yes, this sends:"
  echo "  - vendor, model, product family, chassis type, CPU, memory size and GPU names"
  echo "  - whether the machine uses UEFI, has a TPM and has Secure Boot on"
  echo "  - the Omarchy version and release channel"
  echo "  - a one-way hash of the machine-id, model and CPU, so running this again"
  echo "    updates one entry instead of adding another"
  echo "It never sends serial numbers, MAC addresses, your hostname or username."
  echo "The report is public."
  echo "The server stores no IP address with the report. It keeps per-IP request"
  echo "counts for about an hour to limit abuse. Database backups keep those"
  echo "counts for up to a day after that."
  echo "Privacy policy: ${OMAHCL_URL%/}/privacy"
  ask_yes "Send it? [y/N] " "share it"
}

# The only way anything gets sent: an explicit yes at a terminal, or
# OMAHCL_SUBMIT=yes. No terminal means no.
ask_yes() {
  local prompt=$1 what=$2
  case ${OMAHCL_SUBMIT:-} in
    yes | y | 1) return 0 ;;
    no | n | 0) return 1 ;;
  esac
  if ! ( : </dev/tty ) 2>/dev/null; then
    echo "Run this in a terminal to choose whether to $what, or set OMAHCL_SUBMIT=yes." >&2
    return 1
  fi
  local answer=
  echo
  read -r -p "$prompt" answer </dev/tty || true
  case $answer in
    y | Y | yes | YES | Yes) return 0 ;;
    *) return 1 ;;
  esac
}

confirm_delete() {
  echo
  echo "Nothing has been sent yet. If you answer yes, this sends:"
  echo "  - a one-way hash of this machine's machine-id, model and CPU"
  echo "It sends nothing else. The server deletes any report that matches them right away."
  echo "Database backups keep a deleted report for up to a day after that."
  echo "Privacy policy: ${OMAHCL_URL%/}/privacy"
  ask_yes "Delete it? [y/N] " "delete it"
}

fetch_challenge() {
  local body
  body=$(curl -fsS -A "omahcl-collect/2" --max-time 30 "${OMAHCL_URL%/}/challenges") || {
    echo "Could not reach Omarchy HCL at $OMAHCL_URL" >&2
    exit 1
  }
  local nonce
  nonce=$(printf '%s' "$body" | sed -n 's/.*"nonce"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  if [[ -z $nonce ]]; then
    echo "Omarchy HCL did not return a challenge nonce." >&2
    exit 1
  fi
  printf '%s' "$nonce"
}

submit() {
  local body=$1 path=$2 what=$3
  local response
  if ! response=$(curl -fsS -A "omahcl-collect/2" --max-time 30 \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${OMAHCL_URL%/}/$path"); then
    echo "Omarchy HCL rejected the $what." >&2
    exit 1
  fi
  printf '%s' "$response"
}

json_string_field() {
  printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

json_number_field() {
  printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" | head -n 1
}

refuse_identifiers() {
  if printf '%s' "$1" | grep -Eqi '"[^"]*(serial|mac|hostname|username)[^"]*"[[:space:]]*:'; then
    echo "Refusing to submit identifier fields." >&2
    exit 1
  fi
}

# Prints the payload for a dry run and returns 0, or returns 1 for a real send.
# Callers use it as a condition, so it must never be the place that fails.
dry_run_print() {
  [[ -n ${OMAHCL_DRY_RUN:-} ]] || return 1
  printf '%s\n' "$1"
}

# Plain statement, never inside a condition, so set -e and the explicit exits apply.
post_payload() {
  local body=$1 path=${2:-reports} what=${3:-report} nonce
  nonce=$(fetch_challenge) || exit 1
  body=$(printf '%s' "$body" | sed 's/}$//')
  body+=$(printf ',"nonce":"%s"}' "$(json_escape "$nonce")")
  RESULT=$(submit "$body" "$path" "$what") || exit 1
}

run_omarchy() {
  gather_facts
  if [[ -z $F_vendor || -z $F_product ]]; then
    echo "Could not read machine vendor and product from DMI." >&2
    exit 1
  fi
  local payload
  payload=$(omarchy_payload)
  refuse_identifiers "$payload"
  if dry_run_print "$payload"; then
    return 0
  fi
  print_machine
  if ! confirm_submit; then
    echo "Nothing was sent."
    return 0
  fi
  post_payload "$payload"
  echo
  echo "Submitted a hardware report."
  local model_url
  model_url=$(json_string_field "$RESULT" model_url)
  if [[ -n $model_url ]]; then
    echo "Compatibility page: $model_url"
  fi
}

run_check() {
  gather_facts
  evaluate
  print_verdict
  echo
  echo "Nothing was sent. This check ran on your machine only."
}

run_delete() {
  gather_facts
  if [[ -z $F_vendor || -z $F_product ]]; then
    echo "Could not read machine vendor and product from DMI, so this machine's report cannot be found." >&2
    exit 1
  fi
  local payload
  payload=$(delete_payload)
  if dry_run_print "$payload"; then
    return 0
  fi
  print_machine
  if ! confirm_delete; then
    echo "Nothing was sent."
    return 0
  fi
  post_payload "$payload" deletions "deletion request"
  echo
  local deleted
  deleted=$(json_number_field "$RESULT" deleted)
  if [[ ${deleted:-0} -gt 0 ]]; then
    echo "Deleted ${deleted} report(s) for this machine."
  else
    echo "No report matched this machine. Reports are matched on the machine-id, vendor,"
    echo "model and CPU, so a reinstall or a changed model or CPU string, or a report"
    echo "sent before the hash dropped DMI serials, will not match."
  fi
}

# macOS has no /proc or /sys, so say what the manual says about Macs and stop.
run_macos() {
  local arch
  arch=$(cpu_arch)
  echo "This is macOS, so nothing here can read your hardware."
  echo
  case $arch in
    arm64 | aarch64)
      echo "Verdict: unlikely. This is an Apple silicon Mac, and the Omarchy manual says"
      echo "installing on an M-series Mac is not supported."
      ;;
    *)
      echo "This is an Intel Mac. Omarchy 3 added support for Intel Macs, but installing wipes"
      echo "the drive, and the manual says sound and the Touch Bar do not work."
      echo "It does not mention T2 Macs (to verify)."
      ;;
  esac
  echo
  echo "For a real check, boot a Linux live USB on the machine and run this again."
}

main() {
  if [[ $OMAHCL_URL == __* ]]; then
    echo "Set OMAHCL_URL, or download this script from Omarchy HCL so the URL is filled in." >&2
    exit 1
  fi

  local kernel
  kernel=$(host_kernel)
  case $kernel in
    Darwin)
      if [[ $OMAHCL_ACTION == delete ]]; then
        echo "This is macOS, where this script cannot read your hardware, so it never sent a report to delete."
        return 0
      fi
      run_macos
      return 0
      ;;
    Linux) ;;
    *)
      echo "This script reads /proc and /sys, so it only runs on Linux ($kernel found)." >&2
      exit 2
      ;;
  esac

  if [[ ! -r $(root proc/cpuinfo) || ! -d $(root sys) ]]; then
    echo "Could not read /proc and /sys. Run this on the machine itself, not inside a restricted container." >&2
    exit 2
  fi

  if grep -qi microsoft "$(root proc/version)" 2>/dev/null; then
    echo "This is Windows Subsystem for Linux. It does not show your real hardware." >&2
    echo "Boot a Linux live USB on the machine and run this again." >&2
    exit 2
  fi

  if [[ $OMAHCL_ACTION == delete ]]; then
    run_delete
  elif [[ $(os_field ID) == omarchy ]]; then
    run_omarchy
  else
    run_check
  fi
}

main
