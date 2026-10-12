#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tests/validate_project.py
if [[ -z "${THEOS:-}" || ! -f "${THEOS}/makefiles/common.mk" ]]; then
  echo "ERROR: THEOS does not point to an installed Theos SDK/toolchain." >&2
  echo "Install Theos + an iOS SDK and set THEOS, then rerun." >&2
  exit 2
fi
make clean
make package FINALPACKAGE=1
printf '\nCreated package(s):\n'
find packages -maxdepth 1 -name '*.deb' -print
