set shell := ["bash", "-cu"]

default:
  @just --list

unit-test:
  pytest -v

build:
  rm -rf ./dist
  python -m build

smoke-build: build
  docker build -t bruvtab-smoke -f smoke.Dockerfile .

smoke-test:
  docker run -it bruvtab-smoke

integration-build:
  docker build -t bruvtab-integration -f jess.Dockerfile .

integration-run-container:
  docker run -v "$(pwd):/bruvtab" -p 19222:9222 -p 14625:4625 -it --rm --cpuset-cpus 0 --memory 512mb -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY="unix${DISPLAY}" -v /dev/shm:/dev/shm bruvtab-integration

integration-test:
  xhost +local:docker
  INTEGRATION_TEST=1 pytest -v -k test_integration -s

test-all: unit-test smoke-build smoke-test integration-build integration-test
  @echo "Testing all"

sign-firefox-addon:
  ./scripts/sign-firefox-addon.sh

package-browser-artifacts:
  ./scripts/package-browser-artifacts.sh

reset:
  pkill python3 || true
  pkill xvfb-run || true
  pkill node || true
  pkill Xvfb || true
  pkill firefox || true
