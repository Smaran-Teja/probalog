#!/usr/bin/env bash
#
# Set up ProbLog in a local virtualenv, then run compare-problog.py.
#
# Everything here is idempotent and cached: the virtualenv is built
# once and reused, so only the first run pays the install. Any
# arguments are passed straight through to the Python script.
#
#   ./bench/compare-problog.sh --quick
#   ./bench/compare-problog.sh dag smokers --timeout 120
#   ./bench/compare-problog.sh chordring --backend ddnnf --verify
#   ./bench/compare-problog.sh --rebuild        # discard and reinstall
#
# The virtualenv lives in bench/.venv by default. Override with
# PROBALOG_BENCH_VENV=/some/path.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
venv="${PROBALOG_BENCH_VENV:-$here/.venv}"
script="$here/compare-problog.py"

note() { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# --rebuild is ours, not the Python script's, so pull it out of $@.
rebuild=0
args=()
for a in "$@"; do
  if [[ "$a" == "--rebuild" ]]; then rebuild=1; else args+=("$a"); fi
done

# --- prerequisites ---------------------------------------------------------

[[ -f "$script" ]] || die "cannot find $script"
command -v python3 >/dev/null || die "python3 not found"

# The Python script checks for racket too, but failing here is friendlier
# than failing after a multi-minute install.
racket_cmd="${RACKET:-racket}"
command -v "$racket_cmd" >/dev/null \
  || die "racket not found (set RACKET=... if it is installed elsewhere)

  probalog itself must be installed for the comparison to mean anything:
    raco pkg install --auto roulette/ roulette-lib/"

# --- virtualenv ------------------------------------------------------------

if [[ $rebuild -eq 1 && -d "$venv" ]]; then
  note "removing $venv"
  rm -rf "$venv"
fi

if [[ ! -x "$venv/bin/problog" ]]; then
  note "setting up ProbLog in $venv (first run only)"
  [[ -d "$venv" ]] || python3 -m venv "$venv"

  # Quiet unless something goes wrong, but keep the log to show on failure.
  log="$(mktemp)"
  trap 'rm -f "$log"' EXIT

  note "installing problog"
  if ! "$venv/bin/pip" install --quiet --upgrade pip problog >"$log" 2>&1; then
    cat "$log" >&2
    die "could not install problog"
  fi

  # pysdd is a Cython extension and does not build everywhere. It is not
  # strictly required, but ProbLog's fallback compiler is unsound on some
  # cyclic programs -- see the note in compare-problog.py -- so a failure
  # here is worth shouting about rather than silently tolerating.
  note "installing pysdd (ProbLog's SDD knowledge compiler)"
  if ! "$venv/bin/pip" install --quiet pysdd >"$log" 2>&1; then
    warn "pysdd failed to build; see the tail of the log below"
    tail -5 "$log" >&2
    warn "without it, ProbLog falls back to dsharp, which returns numbers
         that are not probabilities on some cyclic programs. Results from
         the chordring suite in particular should not be trusted. Re-run
         with --backend ddnnf to see that behaviour deliberately."
  fi
fi

# --- sanity check ----------------------------------------------------------

have_sdd=1
if ! "$venv/bin/python" -c "import pysdd" >/dev/null 2>&1; then
  have_sdd=0
fi

problog_version="$("$venv/bin/problog" --version 2>/dev/null || echo unknown)"
note "ProbLog $problog_version, SDD backend $([[ $have_sdd -eq 1 ]] && echo available || echo MISSING)"

# If SDD is unavailable and the caller has not chosen a backend, say so
# plainly rather than letting the Python script die on '-k sdd'.
if [[ $have_sdd -eq 0 ]] && [[ ! " ${args[*]:-} " =~ " --backend " ]]; then
  warn "no SDD backend; falling back to --backend ddnnf (answers may be wrong)"
  args+=(--backend ddnnf)
fi

# --- run -------------------------------------------------------------------

note "running compare-problog.py ${args[*]:-}"
echo
PROBLOG="$venv/bin/problog" RACKET="$racket_cmd" \
  exec "$venv/bin/python" "$script" ${args[@]+"${args[@]}"}
