#!/usr/bin/env bash
set -euo pipefail

mix deps.get
mix check

if [[ "${RUN_DIALYZER:-0}" == "1" ]]; then
  mix dialyzer
fi
