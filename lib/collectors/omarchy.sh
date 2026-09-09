#!/usr/bin/env bash
# Collect Omarchy hardware facts and submit them to Market.

set -euo pipefail

MARKET_URL=${MARKET_URL:-__MARKET_URL__}
SYS=${MARKET_SYS_ROOT:-/}
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
    printf '%s' "${MARKET_ARCH:-unknown}"
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
  local machine_id product_serial board_serial material
  machine_id=$(read_strip "$(root etc/machine-id)")
  product_serial=$(read_strip "$(root sys/class/dmi/id/product_serial)")
  board_serial=$(read_strip "$(root sys/class/dmi/id/board_serial)")
  if [[ -n $product_serial || -n $board_serial ]]; then
    printf 'omarchy-market-instance-v1\0%s\0%s\0%s' "$machine_id" "$product_serial" "$board_serial" | sha256_hex
  else
    printf 'omarchy-market-instance-v1\0%s\0%s\0%s\0%s' "$machine_id" "$vendor" "$product" "$cpu_model" | sha256_hex
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

gpus_json() {
  if [[ -n ${MARKET_SKIP_CMDS:-} ]] || ! command -v lspci >/dev/null 2>&1; then
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

payload_json() {
  local id version channel vendor product family chassis cpu_model cpu_vendor arch cores mem uefi tpm digest
  id=$(os_field ID)
  if [[ $id != omarchy ]]; then
    echo "This collector only runs on Omarchy. ID in /etc/os-release must be omarchy." >&2
    exit 1
  fi
  version=$(clean "$(os_field VERSION_ID)" 80)
  [[ -n $version ]] || version=$(clean "$(os_field BUILD_ID)" 80)
  [[ -n $version ]] || version=unknown
  channel=$(clean "$(read_strip "$(root etc/omarchy/channel)")" 40)
  [[ -n $channel ]] || channel=stable

  vendor=$(dmi sys_vendor)
  product=$(dmi product_name)
  family=$(dmi product_family)
  chassis=$(dmi chassis_type)
  cpu_model=$(cpu_field "model name")
  cpu_vendor=$(cpu_field vendor_id)
  arch=$(clean "$(cpu_arch)" 40)
  cores=$(cpu_cores)
  mem=$(memory_bytes)
  [[ -n $cpu_model ]] || cpu_model="Unknown CPU"
  [[ -n $arch ]] || arch=unknown

  if [[ -z $vendor || -z $product ]]; then
    echo "Could not read machine vendor and product from DMI." >&2
    exit 1
  fi

  digest=$(instance_digest "$vendor" "$product" "$cpu_model")
  uefi=$(bool_dir "$(root sys/firmware/efi)")
  tpm=$(bool_dir "$(root sys/class/tpm)")

  printf '{"omarchy":{"version":"%s","channel":"%s"},"hardware":{"vendor":"%s","product":"%s","family":"%s","chassis":"%s","cpu":{"model":"%s","vendor":"%s","arch":"%s","cores":%s},"memory_bytes":%s,"gpus":%s,"uefi":%s,"tpm":{"present":%s},"secure_boot":{"enabled":%s}},"instance_digest":"%s"}' \
    "$(json_escape "$version")" \
    "$(json_escape "$channel")" \
    "$(json_escape "$vendor")" \
    "$(json_escape "$product")" \
    "$(json_escape "$family")" \
    "$(json_escape "$chassis")" \
    "$(json_escape "$cpu_model")" \
    "$(json_escape "$cpu_vendor")" \
    "$(json_escape "$arch")" \
    "$cores" \
    "$mem" \
    "$(gpus_json)" \
    "$uefi" \
    "$tpm" \
    "$(secure_boot_enabled)" \
    "$digest"
}

fetch_challenge() {
  local body
  body=$(curl -fsS -A "omarchy-market-collect/1" --max-time 30 "${MARKET_URL%/}/challenges") || {
    echo "Could not reach Market at $MARKET_URL" >&2
    exit 1
  }
  local nonce
  nonce=$(printf '%s' "$body" | sed -n 's/.*"nonce"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  if [[ -z $nonce ]]; then
    echo "Market did not return a challenge nonce." >&2
    exit 1
  fi
  printf '%s' "$nonce"
}

submit() {
  local body=$1
  local response
  if ! response=$(curl -fsS -A "omarchy-market-collect/1" --max-time 30 \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${MARKET_URL%/}/reports"); then
    echo "Market rejected the report." >&2
    exit 1
  fi
  printf '%s' "$response"
}

json_string_field() {
  printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

main() {
  if [[ $MARKET_URL == __* ]]; then
    echo "Set MARKET_URL, or download this script from Market so the URL is filled in." >&2
    exit 1
  fi
  local body
  body=$(payload_json)
  if printf '%s' "$body" | grep -Eqi '"[^"]*(serial|mac|hostname|username)[^"]*"[[:space:]]*:'; then
    echo "Refusing to submit identifier fields." >&2
    exit 1
  fi
  if [[ -n ${MARKET_DRY_RUN:-} ]]; then
    printf '%s\n' "$body"
    return
  fi
  local nonce
  nonce=$(fetch_challenge)
  body=$(printf '%s' "$body" | sed 's/}$//')
  body+=$(printf ',"nonce":"%s"}' "$(json_escape "$nonce")")
  local result
  result=$(submit "$body")
  echo "Submitted a hardware report."
  local model_url claim_url
  model_url=$(json_string_field "$result" model_url)
  claim_url=$(json_string_field "$result" claim_url)
  [[ -n $model_url ]] && echo "Compatibility page: $model_url"
  [[ -n $claim_url ]] && echo "Claim this report: $claim_url"
}

main
