#!/usr/bin/env bash
set -euo pipefail

threshold="${1:-95}"

moon fmt --check
moon check --deny-warn
moon test
scripts/coverage_gate.sh --threshold "${threshold}"

