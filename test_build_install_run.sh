#!/bin/bash

# How to use:
# rm -rf ./dist && python setup.py sdist bdist_wheel && docker build -t bruvtab-buildinstallrun . && docker run -it bruvtab-buildinstallrun

# Fail on any error
set -e

pip install $(find . -name *.whl -type f)

python -c 'from bruvtab.tests.test_main import run_mocked_mediators as run; run(count=3, default_port_offset=0, delay=0)' &
sleep 3

function run() {
    echo "Running: $*"
    $*
}

run bruvtab list
run bruvtab windows
run bruvtab clients
run bruvtab active
run bruvtab words
run bruvtab text
run bruvtab html
