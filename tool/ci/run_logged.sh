#!/usr/bin/env bash
# Runs a command in CI. If it fails, the tail of its output is published as a
# GitHub annotation, so the cause is visible on the run summary page.
set -uo pipefail

log="$(mktemp)"
"$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

if [ "$status" -ne 0 ]; then
  body="$(tail -n 60 "$log" | sed -e 's/%/%25/g' -e 's/\r/%0D/g' | awk '{printf "%s%%0A", $0}')"
  echo "::error title=$* (exit $status)::$body"
fi
exit "$status"
