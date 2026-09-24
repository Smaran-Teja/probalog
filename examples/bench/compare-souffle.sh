#!/usr/bin/env bash
#
# Check that Souffle is available, then run compare-souffle.py.
#
# Unlike the ProbLog comparison there is nothing to install into a
# virtualenv -- Souffle is a native binary -- so this is mostly a
# presence check with a useful message when it is missing. Any
# arguments are passed straight through.
#
#   ./bench/compare-souffle.sh --quick
#   ./bench/compare-souffle.sh sg pointsto --timeout 120

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/compare-souffle.py"

note() { printf '\033[1m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ -f "$script" ]] || die "cannot find $script"
command -v python3 >/dev/null || die "python3 not found"

souffle_cmd="${SOUFFLE:-souffle}"
if ! command -v "$souffle_cmd" >/dev/null; then
  hint="see https://souffle-lang.github.io/install"
  command -v brew >/dev/null && hint="brew install souffle"
  die "souffle not found (set SOUFFLE=... if it is installed elsewhere)

  $hint"
fi

racket_cmd="${RACKET:-racket}"
command -v "$racket_cmd" >/dev/null \
  || die "racket not found (set RACKET=... if it is installed elsewhere)

  probalog itself must be installed for the comparison to mean anything:
    raco pkg install --auto roulette/ roulette-lib/"

note "$("$souffle_cmd" --version 2>&1 | grep -i '^version' | head -1 || echo 'Souffle (version unknown)')"
note "running compare-souffle.py $*"
echo

SOUFFLE="$souffle_cmd" RACKET="$racket_cmd" \
  exec python3 "$script" "$@"
