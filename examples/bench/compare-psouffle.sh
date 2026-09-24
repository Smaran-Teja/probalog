#!/usr/bin/env bash
# Builds PSouffle on first run, then compares it against probalog.
#
# PSouffle is the FMCAD 2026 artifact (Li, Xia, Adnan & Wang), published
# at https://doi.org/10.5281/zenodo.20091940 under CC-BY-4.0. It is a
# fork of Souffle, so it is built from source rather than installed from
# a package manager. It needs CUDD 3.0.0, which no package manager here
# carries, so that is built from source too.
#
# CUDD is built with autotools, and libtool cannot handle whitespace in a
# path -- it splits the install target at the space and the build dies
# with "No such file or directory". This repository normally lives under
# a path containing spaces, so the build tree goes outside it. Override
# with PROBALOG_PSOUFFLE_HOME if you want it elsewhere; it is reused on
# later runs, and --rebuild starts over.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROBALOG_PSOUFFLE_HOME:-$HOME/.cache/probalog-psouffle}"
case "$ROOT" in
  *\ *) echo "build path must not contain spaces (libtool cannot cope): $ROOT" >&2
        echo "set PROBALOG_PSOUFFLE_HOME to a path without spaces" >&2
        exit 1 ;;
esac
CUDD="$ROOT/cudd-install"
SRC="$ROOT/psouffle/souffle-full-artifact-ae"
BIN="$SRC/build/src/souffle"

ZENODO=https://zenodo.org/records/20091940/files/psouffle.zip
CUDD_SRC=https://github.com/ivmai/cudd/archive/refs/tags/cudd-3.0.0.tar.gz

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }

if [ "${1:-}" = "--rebuild" ]; then rm -rf "$ROOT"; shift; fi

# Bison 3.2+ is required; macOS ships 2.3, so prefer Homebrew's if present.
if [ -d /opt/homebrew/opt/bison/bin ]; then
  PATH="/opt/homebrew/opt/bison/bin:$PATH"
fi
for tool in cmake bison; do
  command -v "$tool" >/dev/null || {
    echo "$tool not found; on macOS: brew install cmake bison" >&2; exit 1; }
done

if [ ! -f "$CUDD/lib/libcudd.dylib" ] && [ ! -f "$CUDD/lib/libcudd.so" ]; then
  say "building CUDD 3.0.0 (required for exact inference)"
  mkdir -p "$ROOT"
  curl -sL "$CUDD_SRC" -o "$ROOT/cudd.tgz"
  tar xzf "$ROOT/cudd.tgz" -C "$ROOT"
  ( cd "$ROOT/cudd-cudd-3.0.0" \
    && ./configure --prefix="$CUDD" --enable-shared --enable-obj >/dev/null \
    && make -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)" >/dev/null \
    && make install >/dev/null )
fi

if [ ! -x "$BIN" ]; then
  say "fetching and building PSouffle (this takes a few minutes)"
  mkdir -p "$ROOT/psouffle"
  curl -sL "$ZENODO" -o "$ROOT/psouffle.zip"
  unzip -oq "$ROOT/psouffle.zip" -d "$ROOT/psouffle"
  cmake -S "$SRC" -B "$SRC/build" -DCMAKE_BUILD_TYPE=Release \
        -DSOUFFLE_ENABLE_TESTING=OFF \
        -DCUDD_INCLUDE_DIR="$CUDD/include" \
        -DCUDD_LIBRARY="$CUDD/lib/libcudd.dylib" >/dev/null
  cmake --build "$SRC/build" -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)" >/dev/null
fi

say "$("$BIN" --version 2>&1 | head -1)"
say "running compare-psouffle.py $*"
echo
PSOUFFLE="$BIN" exec python3 "$HERE/compare-psouffle.py" "$@"
