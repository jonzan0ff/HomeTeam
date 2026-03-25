#!/usr/bin/env python3
import argparse
import datetime as dt
import fnmatch
import json
from pathlib import Path


DEFAULT_POLICY = {
    "retirement": {
        "min_runs_no_failure": 10000,
        "min_runs_for_demotion": 1000,
        "min_runs_for_flaky": 200,
    },
    "protected_test_patterns": [],
}


def load_policy(policy_path: Path) -> dict:
    policy = DEFAULT_POLICY.copy()
    policy["retirement"] = DEFAULT_POLICY["retirement"].copy()
    policy["protected_test_patterns"] = list(DEFAULT_POLICY["protected_test_patterns"])

    if not policy_path.exists():
        return policy

    with policy_path.open("r", encoding="utf-8") as fh:
        custom = json.load(fh)

    policy["retirement"].update(custom.get("retirement", {}))
    policy["protected_test_patterns"] = custom.get(
        "protected_test_patterns", policy["protected_test_patterns"]
    )
    return policy


def matches_any(value: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(value, pattern) for pattern in patterns)


def read_case_history(history_path: Path) -> dict:
    stats: dict[str, dict] = {}
    total_rows = 0

    if not history_path.exists():
        return {"stats": stats, "total_rows": total_rows}

    with history_path.open("r", encoding="utf-8") as fh:
        for raw_line in fh:
            line = raw_line.strip()
            if not line:
                continue

            total_rows += 1
            row = json.loads(line)
            test_id = row.get("test_identifier") or row.get("test_name") or "unknown"
            result = (row.get("result") or "Unknown").lower()

            entry = stats.setdefault(
                test_id,
                {
                    "test_identifier": test_id,
                    "test_name": row.get("test_name", ""),
                    "test_suite": row.get("test_suite", ""),
                    "runs": 0,
                    "passed": 0,
                    "failed": 0,
                    "skipped": 0,
                    "unknown": 0,
                    "total_duration_seconds": 0.0,
                    "first_seen_utc": row.get("collected_at_utc"),
                    "last_seen_utc": row.get("collected_at_utc"),
                },
            )

            entry["runs"] += 1
            entry["total_duration_seconds"] += float(row.get("duration_seconds", 0.0) or 0.0)
            entry["last_seen_utc"] = row.get("collected_at_utc", entry["last_seen_utc"])

            if result.startswith("pass"):
                entry["passed"] += 1
            elif result.startswith("fail") or result.startswith("error"):
                entry["failed"] += 1
            elif result.startswith("skip"):
                entry["skipped"] += 1
            else:
                entry["unknown"] += 1

    return {"stats": stats, "total_rows": total_rows}


def top_sorted(rows: list[dict], key: str, limit: int = 25) -> list[dict]:
    return sorted(rows, key=lambda item: item.get(key, 0), reverse=True)[:limit]


def build_report(stats: dict, policy: dict) -> dict:
    retirement_cfg = policy["retirement"]
    min_runs_no_failure = int(retirement_cfg["min_runs_no_failure"])
    min_runs_for_demotion = int(retirement_cfg["min_runs_for_demotion"])
    min_runs_for_flaky = int(retirement_cfg["min_runs_for_flaky"])
    protected_patterns = policy.get("protected_test_patterns", [])

    rows = list(stats.values())
    for row in rows:
        row["avg_duration_seconds"] = (
            row["total_duration_seconds"] / row["runs"] if row["runs"] else 0.0
        )
        row["failure_rate"] = (row["failed"] / row["runs"]) if row["runs"] else 0.0
        row["is_protected"] = matches_any(row["test_identifier"], protected_patterns)

    retire_candidates = [
        row
        for row in rows
        if (not row["is_protected"])
        and row["runs"] >= min_runs_no_failure
        and row["failed"] == 0
    ]

    demote_candidates = [
        row
        for row in rows
        if (not row["is_protected"])
        and row["runs"] >= min_runs_for_demotion
        and row["failed"] == 0
        and row["runs"] < min_runs_no_failure
    ]

    flaky_candidates = [
        row
        for row in rows
        if row["runs"] >= min_runs_for_flaky and row["passed"] > 0 and row["failed"] > 0
    ]

    return {
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "policy": policy,
        "totals": {
            "unique_tests": len(rows),
        },
        "retire_candidates": top_sorted(retire_candidates, "runs"),
        "demote_candidates": top_sorted(demote_candidates, "runs"),
        "flaky_candidates": top_sorted(flaky_candidates, "failure_rate"),
        "slowest_tests": top_sorted(rows, "avg_duration_seconds"),
    }


def format_table(rows: list[dict], include_failure_rate: bool = False) -> list[str]:
    if not rows:
        return ["(none)"]

    lines = [
        "| Test Identifier | Runs | Failed | Avg Duration (s) | Failure Rate |",
        "|---|---:|---:|---:|---:|",
    ]
    for row in rows:
        failure_rate = f"{row['failure_rate']:.4f}" if include_failure_rate else "0.0000"
        lines.append(
            f"| `{row['test_identifier']}` | {row['runs']} | {row['failed']} | {row['avg_duration_seconds']:.3f} | {failure_rate} |"
        )
    return lines


def write_markdown(summary: dict, markdown_path: Path) -> None:
    md: list[str] = []
    md.append("# HomeTeam Regression Candidates")
    md.append("")
    md.append(f"Generated at: `{summary['generated_at_utc']}`")
    md.append(f"Unique tests tracked: `{summary['totals']['unique_tests']}`")
    md.append("")
    md.append("## Retire Candidates")
    md.append("Tests with no failures across the configured long-run threshold.")
    md.extend(format_table(summary["retire_candidates"]))
    md.append("")
    md.append("## Demote Candidates")
    md.append("Tests with no failures across medium-run threshold; move from per-PR to nightly first.")
    md.extend(format_table(summary["demote_candidates"]))
    md.append("")
    md.append("## Flaky Candidates")
    md.append("Tests that both pass and fail across history; prioritize stabilization.")
    md.extend(format_table(summary["flaky_candidates"], include_failure_rate=True))
    md.append("")
    md.append("## Slowest Tests")
    md.extend(format_table(summary["slowest_tests"]))
    md.append("")

    markdown_path.parent.mkdir(parents=True, exist_ok=True)
    markdown_path.write_text("\n".join(md), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate regression retirement candidates from test history.")
    parser.add_argument("--history", required=True, help="Path to test_cases.ndjson history file.")
    parser.add_argument("--policy", required=True, help="Path to retirement policy JSON file.")
    parser.add_argument("--markdown", required=True, help="Path to markdown report output.")
    parser.add_argument("--json", required=True, help="Path to JSON report output.")
    args = parser.parse_args()

    history_path = Path(args.history)
    policy_path = Path(args.policy)
    markdown_path = Path(args.markdown)
    json_path = Path(args.json)

    policy = load_policy(policy_path)
    history = read_case_history(history_path)
    summary = build_report(history["stats"], policy)
    summary["totals"]["history_rows"] = history["total_rows"]

    json_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    write_markdown(summary, markdown_path)

    print("Regression candidate report generated:")
    print(f"  JSON:      {json_path}")
    print(f"  Markdown:  {markdown_path}")


if __name__ == "__main__":
    main()
