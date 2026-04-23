#!/usr/bin/env bash

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Package the Chrome extension as a CRX.

Options:
  --chrome-bin PATH   Chrome/Chromium binary to use for packaging
  --key-file PATH     PEM private key for stable CRX packaging
  --no-pem-output     Do not copy/write a PEM file into the output directory
  --output-dir PATH   Output directory for the CRX artifact
  --version VALUE     Version string used in filenames
  -h, --help          Show this help

Notes:
  A stable Chrome extension ID requires the private key matching the public
  key embedded in bruvtab/extension/chrome/manifest.json.

  If --key-file is omitted, this script removes the embedded manifest key,
  lets Chrome generate a temporary key, and writes both the CRX and PEM file
  into the output directory.
EOF
}

find_chrome_bin() {
  local candidate

  for candidate in \
    "${CHROME_BIN:-}" \
    google-chrome-stable \
    google-chrome \
    chromium \
    chromium-browser
  do
    if [[ -n "${candidate:-}" ]] && command -v "$candidate" >/dev/null 2>&1
    then
      command -v "$candidate"
      return 0
    fi
  done

  echo "Could not find a Chrome/Chromium binary" >&2
  return 2
}

main() {
  local chrome_bin
  local extension_source
  local key_file
  local output_dir
  local output_crx
  local output_pem
  local pem_output
  local repo_root
  local temp_dir
  local temp_extension_dir
  local version

  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Must be run from inside the bruvtab git repository" >&2
    return 2
  }

  chrome_bin=""
  extension_source="${repo_root}/bruvtab/extension/chrome"
  key_file=""
  output_dir="${repo_root}/dist/browser"
  pem_output=1
  version=""

  while [[ -n "${1:-}" ]]
  do
    case "$1" in
      --chrome-bin)
        chrome_bin="$2"
        shift 2
        ;;
      --key-file)
        key_file="$2"
        shift 2
        ;;
      --output-dir)
        output_dir="$2"
        shift 2
        ;;
      --no-pem-output)
        pem_output=""
        shift
        ;;
      --version)
        version="$2"
        shift 2
        ;;
      -h|--help)
        usage
        return 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage >&2
        return 2
        ;;
    esac
  done

  if [[ -z "${version:-}" ]]
  then
    version="$(
      python3 - <<'PY'
from bruvtab.__version__ import __version__
print(__version__)
PY
    )"
  fi

  if [[ ! -d "$extension_source" ]]
  then
    echo "Chrome extension source directory not found: $extension_source" >&2
    return 2
  fi

  if [[ -n "${key_file:-}" ]] && [[ ! -f "$key_file" ]]
  then
    echo "Chrome extension key file not found: $key_file" >&2
    return 2
  fi

  if [[ -n "${chrome_bin:-}" ]]
  then
    if ! command -v "$chrome_bin" >/dev/null 2>&1
    then
      echo "Chrome binary not found: $chrome_bin" >&2
      return 2
    fi
    chrome_bin="$(command -v "$chrome_bin")"
  else
    chrome_bin="$(find_chrome_bin)"
  fi

  mkdir -p "$output_dir"
  output_crx="${output_dir}/bruvtab-chrome-${version}.crx"
  output_pem="${output_dir}/bruvtab-chrome-${version}.pem"

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT
  temp_extension_dir="${temp_dir}/chrome"

  cp -R "$extension_source" "$temp_extension_dir"

  if [[ -z "${key_file:-}" ]]
  then
    python3 - <<'PY' "${temp_extension_dir}/manifest.json"
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
lines = path.read_text().splitlines()
filtered = []

for line in lines:
    stripped = line.lstrip()
    if stripped.startswith("// Extension ID:"):
        continue
    if stripped.startswith('"key":'):
        continue
    filtered.append(line)

path.write_text("\n".join(filtered) + "\n")
PY
  fi

  if [[ -n "${key_file:-}" ]]
  then
    "$chrome_bin" \
      --pack-extension="${temp_extension_dir}" \
      --pack-extension-key="${key_file}"
  else
    "$chrome_bin" \
      --pack-extension="${temp_extension_dir}"
  fi

  if [[ ! -f "${temp_extension_dir}.crx" ]]
  then
    echo "Chrome did not produce a CRX file" >&2
    return 1
  fi

  mv -f "${temp_extension_dir}.crx" "$output_crx"

  if [[ -n "${pem_output:-}" ]] && [[ -f "${temp_extension_dir}.pem" ]]
  then
    mv -f "${temp_extension_dir}.pem" "$output_pem"
  elif [[ -n "${pem_output:-}" ]] && [[ -n "${key_file:-}" ]]
  then
    cp -f "$key_file" "$output_pem"
  fi

  echo "Created $output_crx"

  if [[ -n "${pem_output:-}" ]] && [[ -f "$output_pem" ]]
  then
    echo "Created $output_pem"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  main "$@"
fi

# vim: set ft=sh ts=2 sw=2 et:
