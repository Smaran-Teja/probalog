#!/usr/bin/env python3
"""Turn a comparison script's output into GitHub annotations and a summary.

    ci-report.py TOOL OUTPUT_FILE

Annotations are printed as workflow commands on stdout, so they appear on
the run page and in the job list: a `notice` when every checked size
agreed, a `warning` when some sizes failed to run, and an `error` when
probalog and TOOL gave different answers. The full tables go to
$GITHUB_STEP_SUMMARY when it is set.

All five compare-*.py scripts print the same shape -- `=== suite: ... ===`
headings, then rows that start with a size tuple, with `yes`, `NO` or `-`
in the agree column and `ERROR`, `TIMEOUT` or `COMPILE FAIL` when a run did
not complete -- so one reader serves them all.
"""

import os
import re
import sys

FAILED = ("COMPILE FAIL", "TIMEOUT", "ERROR")
HEADING = re.compile(r"^=== ([\w-]+)")


def classify(row):
    """'agree', 'disagree', 'failed' or 'unchecked' for one data row."""
    tokens = row.split()
    if "NO" in tokens:
        return "disagree"
    if any(f in row for f in FAILED):
        return "failed"
    if "yes" in tokens:
        return "agree"
    return "unchecked"


def parse(text):
    """Ordered {suite: [row status, ...]}, and the report body."""
    suites, current, body = {}, None, []
    started = False
    for line in text.splitlines():
        m = HEADING.match(line)
        if m:
            current = m.group(1)
            suites.setdefault(current, [])
            started = True
        if started:
            body.append(line)
        if current and line.lstrip().startswith("("):
            suites[current].append(classify(line))
    return suites, "\n".join(body).rstrip()


def escape_data(s):
    return s.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def escape_property(s):
    return escape_data(s).replace(":", "%3A").replace(",", "%2C")


def main():
    tool, path = sys.argv[1], sys.argv[2]
    try:
        text = open(path).read()
    except OSError:
        text = ""
    suites, body = parse(text)

    counts = {k: 0 for k in ("agree", "disagree", "failed", "unchecked")}
    for rows in suites.values():
        for r in rows:
            counts[r] += 1
    checked = counts["agree"] + counts["disagree"]
    total = sum(counts.values())

    if total == 0:
        level, headline = "warning", f"probalog vs {tool}: no results produced"
    elif counts["disagree"]:
        level = "error"
        headline = (f"probalog vs {tool}: {counts['disagree']} of {checked} "
                    "checked sizes DISAGREE")
    elif counts["failed"]:
        level = "warning"
        headline = (f"probalog vs {tool}: {counts['agree']} agree, "
                    f"{counts['failed']} of {total} did not run")
    else:
        level = "notice"
        headline = f"probalog vs {tool}: all {counts['agree']} checked sizes agree"
        if counts["unchecked"]:
            headline += f" ({counts['unchecked']} not comparable)"

    # One line per suite, so a problem can be traced without opening the log.
    per_suite = []
    for name, rows in suites.items():
        a = rows.count("agree")
        extra = [f"{rows.count(k)} {k}" for k in ("disagree", "failed", "unchecked")
                 if rows.count(k)]
        per_suite.append(f"{name}: {a}/{len(rows)} agree"
                         + (f" ({', '.join(extra)})" if extra else ""))

    message = "\n".join(per_suite) + ("\n\n" + body if body else "")
    print(f"::{level} title={escape_property(headline)}::{escape_data(message)}")

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write(f"### {headline}\n\n")
            for line in per_suite:
                f.write(f"- {line}\n")
            f.write("\n```\n" + (body or "(no output)") + "\n```\n")


if __name__ == "__main__":
    main()
