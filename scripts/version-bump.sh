#!/usr/bin/env bash

usage() {
  cat <<EOF
Usage: $(basename "$0") VERSION

Update the BruvTab version in:
  - bruvtab/__version__.py
  - bruvtab/extension/chrome/manifest.json
  - bruvtab/extension/firefox/manifest.json
EOF
}

main() {
  local repo_root
  local version

  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Must be run from inside the bruvtab git repository" >&2
    return 2
  }

  version="${1:-}"
  if [[ -z "${version:-}" ]]
  then
    usage >&2
    return 2
  fi

  python3 - <<'PY' "$repo_root" "$version"
import json
import pathlib
import re
import sys

repo_root = pathlib.Path(sys.argv[1])
version = sys.argv[2]

version_file = repo_root / "bruvtab" / "__version__.py"
chrome_manifest = repo_root / "bruvtab" / "extension" / "chrome" / "manifest.json"
firefox_manifest = repo_root / "bruvtab" / "extension" / "firefox" / "manifest.json"

version_text = version_file.read_text(encoding="utf-8")
updated_text, count = re.subn(
    r"^__version__ = ['\"][^'\"]+['\"]$",
    f"__version__ = '{version}'",
    version_text,
    count=1,
    flags=re.MULTILINE,
)
if count != 1:
    raise SystemExit(f"Could not update version in {version_file}")
version_file.write_text(updated_text, encoding="utf-8")

for manifest_path in (chrome_manifest, firefox_manifest):
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["version"] = version
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  main "$@"
fi

# vim: set ft=sh ts=2 sw=2 et:
