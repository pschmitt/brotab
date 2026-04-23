#!/usr/bin/env bash

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Sign the Firefox BruvTab extension through AMO as an unlisted add-on.

Required environment:
  WEB_EXT_API_KEY       AMO JWT issuer key
  WEB_EXT_API_SECRET    AMO JWT secret

Options:
  --source-dir PATH     Extension source directory
  --artifacts-dir PATH  Output directory for signed artifacts
  --amo-metadata PATH   Metadata JSON for listed submissions
  --api-key KEY         Override WEB_EXT_API_KEY
  --api-secret SECRET   Override WEB_EXT_API_SECRET
  --channel CHANNEL     Signing channel (default: unlisted)
  -h, --help            Show this help
EOF
}

main() {
  local repo_root
  local source_dir
  local artifacts_dir
  local amo_metadata
  local api_key
  local api_secret
  local channel

  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Must be run from inside the bruvtab git repository" >&2
    return 2
  }

  source_dir="${repo_root}/bruvtab/extension/firefox"
  artifacts_dir="${repo_root}/dist/firefox-signed"
  amo_metadata="${repo_root}/assets/firefox/amo-metadata.json"
  api_key="${WEB_EXT_API_KEY:-}"
  api_secret="${WEB_EXT_API_SECRET:-}"
  channel="unlisted"

  while [[ -n "${1:-}" ]]
  do
    case "$1" in
      --source-dir)
        source_dir="$2"
        shift 2
        ;;
      --artifacts-dir)
        artifacts_dir="$2"
        shift 2
        ;;
      --amo-metadata)
        amo_metadata="$2"
        shift 2
        ;;
      --api-key)
        api_key="$2"
        shift 2
        ;;
      --api-secret)
        api_secret="$2"
        shift 2
        ;;
      --channel)
        channel="$2"
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

  if [[ -z "${api_key:-}" ]]
  then
    echo "WEB_EXT_API_KEY is required" >&2
    return 2
  fi

  if [[ -z "${api_secret:-}" ]]
  then
    echo "WEB_EXT_API_SECRET is required" >&2
    return 2
  fi

  if [[ ! -d "$source_dir" ]]
  then
    echo "Extension source directory not found: $source_dir" >&2
    return 2
  fi

  mkdir -p "$artifacts_dir"

  export WEB_EXT_API_KEY="$api_key"
  export WEB_EXT_API_SECRET="$api_secret"

  local -a web_ext_args
  web_ext_args=(
    sign
    --source-dir "$source_dir"
    --artifacts-dir "$artifacts_dir"
    --channel "$channel"
    --ignore-files 'readme.txt'
    --no-input
  )

  if [[ -n "${amo_metadata:-}" && -f "$amo_metadata" ]]
  then
    web_ext_args+=(--amo-metadata "$amo_metadata")
  fi

  web-ext "${web_ext_args[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  main "$@"
fi

# vim: set ft=sh ts=2 sw=2 et:
