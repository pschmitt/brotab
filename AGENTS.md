# BruvTab Agent Guide

## Overview
BruvTab is a CLI tool for managing browser tabs (Firefox, Chrome/Chromium). It consists of a Python CLI, a native messaging mediator, and browser extensions.

## Core Architecture
- **CLI (`bruvtab/`)**: Primary user interface. `bruvtab/main.py` is the entry point.
- **Mediator (`bruvtab/mediator/`)**: A native messaging host that bridges the CLI and browser extensions.
- **Extensions (`bruvtab/extension/`)**: Browser-side code (JS) that interacts with the `tabs` API.

## Development
- **Task Runner**: Use `just`. Run `just` to list available commands.
- **Python Environment**: Managed via `pyproject.toml`. Dependencies and optional extras (test, dev) are defined there.
- **Testing**:
  - Unit tests: `pytest bruvtab/tests` (or `just unit-test`).
  - Smoke tests: `just smoke-test` (runs locally with mocked mediators).
  - Integration tests: `just integration-test` (requires a browser and mediator installed).

## Standards & Conventions
- **Python**: Follow `.pylintrc`. Use `uv` or `pip` for dependency management.
- **Version Management**: Version is defined in `bruvtab/__version__.py`.
- **Commits**: Follow existing style (concise, focus on "why").
- **Browser IDs**:
  - Chrome: `gcbobllgbdnjilcobohhdkaddibbjidl` (debug/test ID).

## Critical Files
- `justfile`: Defines all major dev workflows.
- `pyproject.toml`: Project metadata and entry points.
- `bruvtab/mediator/bruvtab_mediator.py`: Core logic for browser communication.
- `bruvtab/tests/test_integration.py`: End-to-end validation logic.
