#!/usr/bin/env bash
# Run the pure-Dart test harness. You need a Dart 3.5+ SDK on PATH; no
# Flutter install is required. The tests cover ranking/normalisation,
# HTML cleanup, FTS escaping, and the deterministic WOD seed.
set -euo pipefail
cd "$(dirname "$0")"
dart pub get
exec dart test --reporter expanded "$@"
