set shell := ["bash", "-cu"]

default:
  @just --list

unit-test:
  pytest -v

build:
  rm -rf ./dist
  python -m build

smoke-test: build
  pip install --force-reinstall dist/*.whl
  python -c 'from bruvtab.tests.test_main import run_mocked_mediators as run; run(count=3, default_port_offset=0, delay=0)' & \
  sleep 3 && \
  bruvtab list && \
  bruvtab windows && \
  bruvtab clients && \
  bruvtab active && \
  bruvtab words && \
  bruvtab text && \
  bruvtab html

integration-build:
  docker build -t bruvtab-integration -f jess.Dockerfile .

integration-test:
  INTEGRATION_TEST=1 pytest -v -k test_integration -s

test-all: unit-test smoke-test integration-test
  @echo "Testing all"

sign-firefox-addon:
  ./scripts/sign-firefox-addon.sh

package-browser-artifacts:
  ./scripts/package-browser-artifacts.sh

package-chrome-crx:
  ./scripts/package-chrome-crx.sh

reset:
  pkill python3 || true
  pkill xvfb-run || true
  pkill node || true
  pkill Xvfb || true
  pkill firefox || true
