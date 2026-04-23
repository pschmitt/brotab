#!/usr/bin/env bash

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Package the Chrome extension as a CRX.

Options:
  --chrome-bin PATH   Chrome/Chromium binary to use for packaging
  --key-file PATH     PEM private key for stable CRX packaging
  --no-pem-output     Do not write a PEM file into the output directory
  --output-dir PATH   Output directory for the CRX artifact
  --version VALUE     Version string used in filenames
  -h, --help          Show this help
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

strip_manifest_key() {
  local manifest_path="$1"

  python3 - <<'PY' "$manifest_path"
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data.pop("key", None)
path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

main() {
  local chrome_bin
  local extension_source
  local key_file
  local output_crx
  local output_dir
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
  chmod -R +w "$temp_extension_dir"
  strip_manifest_key "${temp_extension_dir}/manifest.json"

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

  if [[ -n "${pem_output:-}" ]]
  then
    if [[ -f "${temp_extension_dir}.pem" ]]
    then
      mv -f "${temp_extension_dir}.pem" "$output_pem"
    elif [[ -n "${key_file:-}" ]]
    then
      cp -f "$key_file" "$output_pem"
    fi
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
