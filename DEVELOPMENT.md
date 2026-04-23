# Development

## Build, test and manual installation

1. Install docker: https://docs.docker.com/get-docker/
1. Install Python3
1. Clone repository and cd into it
1. Run:```just smoke-build && just smoke-test```
1. The build is in the dist folder and can be installed with ```pip install $(find ./dist -name *.whl -type f) ```

## Installation in development mode

cd bruvtab
pip install --user -e .
bruvtab install --tests

In firefox go to: about:debugging#/runtime/this-firefox -> Load temporary addon

In Chrome/Chromium go to: chrome://extensions/ -> Developer mode -> Load
unpacked

You should see the following output:

```txt
$ bruvtab clients
a.      localhost:4625  23744   firefox
b.      localhost:4626  28895   chrome/chromium
```

## Running tests

```bash
$ pytest bruvtab/tests
```

## Rest

This document serves the purpose of being a reminder to dev

Chrome extension IDs:

Debug:
    "chrome-extension://gcbobllgbdnjilcobohhdkaddibbjidl/"

  // Extension ID: gcbobllgbdnjilcobohhdkaddibbjidl
  "key": "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCgshokAudhB/hfn7hM0JgyvM9NVESvWAXoiSnyg89Zf+qzYl2q/fkfY4hnWaOF2qwZeSuBExkSOh2rDsbB4HK6QdeMeTI0WLnXmIWh6a7LM5Gk/RSm38M6ZdkEqBs5yYH7+8kqfsstyDpOEz7AdLsv+gWYh0qJf1XnJi+cA+pykwIDAQAB",

## TODO, things to implement

[_] provide zsh completion: ~/rc.arch/bz/.config/zsh/completion/_bt
[_] add config and allow setting debug level.  prod in release, debug in dev
[_] automake deployment of extensions and pypi packaging
[_] automate switching to environments (dev, prod)
[_] add regexp argument to bruvtab words command
    this will allow configuration on vim plugin side

- rofi: close multiple tabs (multiselect), should be opened with current tab
  selected for convenience

## Notes

Use this command to print current tabs in firefox:

echo -e 'repl.load("file:///home/ybochkarev/rc.arch/bz/.config/mozrepl/mozrepl.js"); hello(300);' | nc -q0 localhost 4242 | sed '/repl[0-9]*> .\+/!d' | sed 's/repl[0-9]*> //' | rev | cut -c2- | rev | cut -c2- J -C G '"title"' F --no-sort

fr (FiRefox) usage (or br - BRowser):

fr open     open a tab by title
fr close    mark and close multiple tabs

fc close
fo open
fs search

Getting data from PDF page:

Firefox:
var d = await window.PDFViewerApplication.pdfDocument.getData()
Uint8Array(100194) [ 37, 80, 68, 70, 45, 49, 46, 51, 10, 37, … ]

## CompleBox

Desired modes:

- insert
  - rt ticket number
  - rt ticket: title
  - ticket url
  - ? insert all: ticket: title (url)
- open rt ticket in a browser

- open sheet ticket in a browser

- activate browser tab
- close browser tab

## Multiple extensions/browsers/native apps

[+] differentiate browser instances, how? use prefixes ('a.', 'b.', ...)
[+] support gathering data from multiple mediators
    [+] native mediator should try binding to a free port [4625..4635]
    [+] bruvtab.py should try a range of ports
[+] build a unified interface for different browsers in background.js
[+] try putting window id into list response

## Roadmap

Install/devops
[_] put helpers (colors) into bruvtab.sh
[_] create helpers bruvtab-list, bruvtab-move, etc
[_] add integration with rofi
[_] zsh completion for commands
[+] add file with fzf integration: bruvtab-fzf.zsh
[+] add pyproject.toml, make sure bruvtab and bruvtab_mediator are available

Testing:
[_] how to setup integration testing? w chromium, firefox
    use docker

## Product features

[_] full-text search using extenal configured service (e.g. solr)
[_] all current operations should be supported on multiple browsers at a time
[_] move should work with multiple browsers and multiple windows
[_] ability to move within window of the same browser
[_] ability to move across windows of the same browser
[_] ability to move across windows of different browsers

## Bugs

[_] bruvtab move hangs after interacting with chromium
[_] bruvtab close, chromium timeout
[_] bruvtab active is broken with chromium extension
    [_] rofi, activate, close tabs: should select currently active tab
[_] rofi, close tabs: should be multi-selectable

## Release procedure

```bash
# Bump bersion in bruvtab/__version__.py

$ nvim CHANGELOG.md
$ git ci -m 'Bump version from 1.2.0 to 1.2.1\n<CHANGELOG HERE>'
$ git tag 1.2.1
$ git push origin master && git push --tags

# Push the tag. GitHub Actions will create the GitHub release and publish to PyPI.
```

Load env file as follows:
set -o allexport; source .env; set +o allexport

## Old steps of release procedure

$ just build
$ uv build # this one is faster
$ git push origin main && git push --tags

## Commands

chromium-browser --pack-extension=chrome

To make sure that extension works under selenium, copy bruvtab_mediator.json to:
/etc/opt/chrome/native-messaging-hosts

## Testing extension

To perform integration tests for the extension, chromium and firefox have
different approaches to load it upon the start.

### Chromium

chromium: google-chrome-stable --disable-gpu --load-extension=./firefox_extension

Chromium is a bit more demading. Several conditions are required before you can
run Chromium in Xvfb in integration tests:

1. Use extension from bruvtab/extension/chrome-tests. It contains the correct
   fake Key and extension ID (gcbobllgbdnjilcobohhdkaddibbjidl). The same
   extension ID is installed when you run `bruvtab install` command in Docker.
   This very extension ID is also present in
   bruvtab/mediator/chromium_mediator_tests.json, which is used in `bruvtab install`.

firefox: use web-ext run
https://developer.mozilla.org/en-US/Add-ons/WebExtensions/Getting_started_with_web-ext

## Signing Firefox extension

Mozilla requires stable Firefox add-ons to be signed, even for self-distribution.
Use an unlisted signing flow with AMO credentials:

```bash
export WEB_EXT_API_KEY='user:12345:67'
export WEB_EXT_API_SECRET='your-jwt-secret'
./scripts/sign-firefox-addon.sh
```

Signed artifacts are written to `dist/firefox-signed/`.
