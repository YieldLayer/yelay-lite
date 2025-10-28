#!/usr/bin/env bash
set -euo pipefail

rm -f lcov.info
rm -rf coverage

forge coverage --report lcov

genhtml -o coverage lcov.info --branch-coverage --ignore-errors inconsistent

open coverage/index.html