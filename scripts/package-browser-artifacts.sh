#!/usr/bin/env bash

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Package browser extension artifacts for release uploads.

Options:
  --output-dir PATH  Output directory for packaged artifacts
  --version VALUE    Version string used in filenames
  -h, --help         Show this help
EOF
}

package_zip() {
  local source_dir="$1"
  local output_file="$2"

  rm -f "$output_file"
  (
    cd "$source_dir" || return 1
    zip -qr "$output_file" .
  )
}

main() {
  local repo_root
  local output_dir
  local version

  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Must be run from inside the bruvtab git repository" >&2
    return 2
  }

  output_dir="${repo_root}/dist/browser"
  version=""

  while [[ -n "${1:-}" ]]
  do
    case "$1" in
      --output-dir)
        output_dir="$2"
        shift 2
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

  mkdir -p "$output_dir"

  package_zip \
    "${repo_root}/bruvtab/extension/chrome" \
    "${output_dir}/bruvtab-chrome-${version}.zip"

  package_zip \
    "${repo_root}/bruvtab/extension/firefox" \
    "${output_dir}/bruvtab-firefox-source-${version}.zip"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  main "$@"
fi

# vim: set ft=sh ts=2 sw=2 et:
