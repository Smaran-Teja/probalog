#!/usr/bin/env python3
"""probalog vs PSouffle.

PSouffle (Li, Xia, Adnan & Wang, FMCAD 2026) extends Souffle with exact
probabilistic inference: it instruments Souffle's evaluation to build a
derivation graph, compiles it with CUDD, and reports a probability per
output tuple. Artifact: https://doi.org/10.5281/zenodo.20091940

It is the closest comparison in this directory. Every other opponent
differs from probalog in some way that has to be corrected for:

  ProbLog, PITA   Prolog rather than Datalog, and goal-directed, so
                  they ground only what one query needs
  Scallop         bottom-up Datalog, but top-k approximate
  Praline         bottom-up Datalog, but computes bounds under unknown
                  correlations rather than exact marginals

PSouffle is bottom-up Datalog computing exact marginals, and its
`query(rel(_, _)).` form asks for the whole relation -- which is what
probalog computes whatever you ask it. So there is nothing to correct
for, and the answers are directly comparable.

The program families are imported from compare-souffle.py, so the two
scripts run byte-identical models and the results line up.

Usage:

    ./bench/compare-psouffle.sh --quick
    ./bench/compare-psouffle.sh ring pointsto
"""

import argparse
import importlib.util
import os
import re
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))


def _load_souffle_harness():
    """Reuse the program generators, so the two tables line up."""
    path = os.path.join(HERE, "compare-souffle.py")
    spec = importlib.util.spec_from_file_location("compare_souffle", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


CS = _load_souffle_harness()
SUITES = CS.SUITES
probalog_program = CS.probalog_program

PSOUFFLE = os.environ.get("PSOUFFLE", "psouffle")
RACKET = os.environ.get("RACKET", "racket")

# Every base fact gets this probability, matching compare-souffle.py's
# probalog@0.5 column so the two tables can be read together.
P = 0.5


# --------------------------------------------------------------------------
# Emitting a PSouffle program
# --------------------------------------------------------------------------

def psouffle_program(decls, facts, rules, output):
    """Same Datalog as Souffle, plus `.input` on the base relations and a
    wildcard `query` on the derived one.

    Probabilities do not appear in the program: they live in a `.prob`
    file beside each relation's `.facts`, aligned by line number.
    """
    base = {n for n, _ in facts}
    out = []
    for name, types in decls:
        args = ", ".join(f"a{i}:{t}" for i, t in enumerate(types))
        out.append(f".decl {name}({args})")
        if name in base:
            out.append(f".input {name}")
    out.append(f".output {output}")
    out += rules
    arity = next(len(ts) for n, ts in decls if n == output)
    out.append(f"query({output}({', '.join('_' * arity)})).")
    return "\n".join(out)


def write_facts(indir, facts):
    """One `<rel>.facts` of tab-separated tuples per relation, and one
    `<rel>.prob` of the same length giving each tuple's probability."""
    by_rel = {}
    for name, args in facts:
        by_rel.setdefault(name, []).append(args)
    for name, rows in by_rel.items():
        with open(os.path.join(indir, f"{name}.facts"), "w") as f:
            for args in rows:
                f.write("\t".join(str(a) for a in args) + "\n")
        with open(os.path.join(indir, f"{name}.prob"), "w") as f:
            f.write("".join(f"{P}\n" for _ in rows))


# --------------------------------------------------------------------------
# Running
# --------------------------------------------------------------------------

def timed(cmd, timeout, cwd=None):
    t0 = time.perf_counter()
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           timeout=timeout, cwd=cwd)
    except subprocess.TimeoutExpired:
        return None, "TIMEOUT"
    except FileNotFoundError:
        return None, "NOT FOUND"
    if r.returncode != 0:
        return None, f"ERROR\n{r.stdout}\n{r.stderr}"
    return time.perf_counter() - t0, r.stdout


# `rel("a", 15) : 0.435666`, with strings quoted and numbers bare.
ANSWER = re.compile(r"^(\w+)\((.*)\)\s*:\s*([0-9.eE+-]+)\s*$")


def psouffle_answers(outdir):
    """Output tuple -> probability, or None if the run produced nothing."""
    path = os.path.join(outdir, "facts.prob")
    if not os.path.exists(path):
        return None
    answers = {}
    with open(path) as f:
        for line in f:
            m = ANSWER.match(line.strip())
            if not m:
                continue
            args = tuple(a.strip().strip('"')
                         for a in m.group(2).split(",") if a.strip())
            answers[args] = float(m.group(3))
    return answers


def probalog_answer(out):
    if not out or not out.strip():
        return None
    last = out.strip().splitlines()[-1]
    m = re.search(r"#t ([0-9.eE+-]+)", last)
    if m:
        return float(m.group(1))
    if last.endswith(": #t"):
        return 1.0
    if last.endswith(": #f"):
        return 0.0
    return None


def run_suite(name, spec, args, tmpdir):
    sizes = spec["quick"] if args.quick else spec["sizes"]
    print(f"\n=== {name}: {spec['blurb']} ===")
    print(f"{'size':<12}{'PSouffle':>10}{'(compile)':>11}{'probalog':>10}"
          f"{'ratio':>8}  {'agree':<7}{'|rel|':>8}")
    for params in sizes:
        decls, facts, sf_rules, rk_rules, output, query, tup = spec["fam"](*params)
        case = os.path.join(tmpdir, f"{name}-{'-'.join(map(str, params))}")
        indir, outdir = os.path.join(case, "input"), os.path.join(case, "output")
        os.makedirs(indir, exist_ok=True)
        os.makedirs(outdir, exist_ok=True)
        prog = os.path.join(case, "compute.dl")
        with open(prog, "w") as f:
            f.write(psouffle_program(decls, facts, sf_rules, output))
        write_facts(indir, facts)

        # Compilation is a separate phase and is reported separately:
        # PSouffle emits C++ and builds a binary, which probalog has no
        # counterpart for. The headline number is the run.
        exe = os.path.join(case, "compute")
        tc, _ = timed([PSOUFFLE, "-F", indir, "-D", outdir, prog, "-o", exe],
                      args.compile_timeout, cwd=case)
        if tc is None:
            print(f"{str(params):<12}{'-':>10}{'COMPILE FAIL':>11}")
            continue
        tp, po = timed([exe, "-F", indir, "-D", outdir, "--det-opt",
                        "--rewrite", "--logfile", "run"], args.timeout)
        answers = psouffle_answers(outdir) if tp is not None else None

        rk = os.path.join(case, "prog.rkt")
        with open(rk, "w") as f:
            f.write(probalog_program(facts, rk_rules, query, P))
        tr, ro = timed([RACKET, rk], args.timeout)
        vr = probalog_answer(ro) if tr is not None else None

        vp = answers.get(tup) if answers else None
        agree = ("yes" if vp is not None and vr is not None
                 and abs(vp - vr) < 1e-6 else
                 "-" if vp is None or vr is None else "NO")
        ratio = f"{tr / tp:.1f}x" if tp and tr else "-"
        print(f"{str(params):<12}"
              f"{('TIMEOUT' if tp is None else f'{tp:.2f}s'):>10}"
              f"{f'{tc:.1f}s':>11}"
              f"{('TIMEOUT' if tr is None else f'{tr:.2f}s'):>10}"
              f"{ratio:>8}  {agree:<7}{len(answers) if answers else 0:>8}")
        if agree == "NO":
            print(f"    PSouffle {vp}  probalog {vr}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("suites", nargs="*", choices=list(SUITES) + [], default=[])
    ap.add_argument("--quick", action="store_true", help="small sizes only")
    ap.add_argument("--timeout", type=float, default=10,
                    help="per-run timeout in seconds (default 10)")
    ap.add_argument("--compile-timeout", type=float, default=180,
                    help="per-case PSouffle compile timeout (default 180)")
    args = ap.parse_args()

    if subprocess.run(["which", PSOUFFLE], capture_output=True).returncode != 0:
        sys.exit(f"psouffle not found (set PSOUFFLE=...): {PSOUFFLE}\n"
                 "  see the setup notes in compare-psouffle.sh")

    print("probalog vs PSouffle   every base fact :: 0.5")
    print("  Both compute the whole derived relation, so there is no")
    print("  goal-direction difference to correct for.")
    print("  PSouffle compiles each program to a binary first; that phase")
    print("  is timed separately and excluded from the comparison.")

    with tempfile.TemporaryDirectory() as tmpdir:
        for name in (args.suites or list(SUITES)):
            run_suite(name, SUITES[name], args, tmpdir)


if __name__ == "__main__":
    main()
