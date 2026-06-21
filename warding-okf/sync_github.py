#!/usr/bin/env python3
"""Sync warding-okf/references/github-project.md from the live GitHub project board.

Reads the NAR-GG `warding` project board (and open issues) via the `gh` CLI,
rewrites references/github-project.md grouped by status, then regenerates viz.html.
One-directional: GitHub is the source of truth; this only mirrors it into the bundle.

Usage:  python3 warding-okf/sync_github.py
"""
import json, os, subprocess, sys
from datetime import datetime, timezone

BUNDLE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(BUNDLE, "references", "github-project.md")
GEN = os.path.join(BUNDLE, "gen_viz.py")

OWNER = "NAR-GG"
PROJECT_NUMBER = "1"
REPO = "NAR-GG/warding-mobile-repo"
BOARD_URL = "https://github.com/orgs/NAR-GG/projects/1"

# Issue number -> bundle concept id (best-effort; unmapped issues render as plain text)
ISSUE_CONCEPT = {
    8: "features/matches", 14: "features/matches", 16: "features/matches",
    19: "features/matches", 23: "features/matches", 24: "features/matches",
    33: "features/matches", 34: "features/matches",
    9: "features/solo-rank-alarm",
    15: "features/player-ratings", 27: "features/player-ratings",
    28: "features/player-ratings", 29: "features/player-ratings",
    31: "features/player-ratings",
    17: "features/live-notifications", 21: "features/live-notifications",
    20: "features/profile", 35: "features/profile",
    11: "features/onboarding", 12: "features/onboarding",
    10: "design/ui-scaling",
}

def run(cmd):
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        sys.stderr.write(f"$ {' '.join(cmd)}\n{p.stderr}\n")
        sys.exit(f"command failed (is `gh` authenticated?): {' '.join(cmd)}")
    return p.stdout

def link(num, title):
    cid = ISSUE_CONCEPT.get(num)
    suffix = f" → [{title}](/{cid}.md)" if cid else f" {title}"
    return f"- #{num}{suffix}"

def main():
    raw = run(["gh", "project", "item-list", PROJECT_NUMBER,
               "--owner", OWNER, "--limit", "100", "--format", "json"])
    items = json.loads(raw).get("items", [])

    buckets = {"In Progress": [], "Todo": [], "Done": [], "_other": []}
    for it in items:
        status = (it.get("status") or "").strip()
        title = it.get("title", "(no title)")
        content = it.get("content") or {}
        num = content.get("number")
        if num is None:
            continue
        key = status if status in buckets else "_other"
        buckets[key].append((num, title, status))
    for k in buckets:
        buckets[k].sort(key=lambda x: -x[0])

    now = datetime.now(timezone.utc)
    stamp = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    date = now.strftime("%Y-%m-%d")

    lines = []
    lines.append("---")
    lines.append("type: Reference")
    lines.append("title: GitHub 프로젝트 보드")
    lines.append("description: NAR-GG/warding 보드 기반 작업 현황. GitHub에서 자동 동기화됨.")
    lines.append(f"resource: {BOARD_URL}")
    lines.append("tags: [reference, project-board, issues, status, synced]")
    lines.append(f"timestamp: {stamp}")
    lines.append("---")
    lines.append("")
    lines.append("# 개요")
    lines.append("")
    lines.append(f"`gh`로 NAR-GG `warding` 보드에서 자동 생성됨 (최종 동기화: **{date}**). "
                 "GitHub이 진실(source of truth)이며 이 문서는 단방향 미러다. "
                 "`python3 warding-okf/sync_github.py`로 갱신한다.")
    lines.append("")

    def section(heading, key, emoji=""):
        rows = buckets.get(key, [])
        lines.append(f"# {emoji}{heading} ({len(rows)})")
        lines.append("")
        if rows:
            for num, title, _ in rows:
                lines.append(link(num, title))
        else:
            lines.append("- (없음)")
        lines.append("")

    section("진행 중 (In Progress)", "In Progress", "🟡 ")
    section("할 일 (Todo)", "Todo", "🔴 ")
    section("완료 (Done)", "Done", "✅ ")
    if buckets["_other"]:
        section("기타", "_other")

    lines.append("# Citations")
    lines.append("")
    lines.append(f"[1] [NAR-GG / warding 보드]({BOARD_URL})")
    lines.append(f"[2] [{REPO} 이슈](https://github.com/{REPO}/issues)")
    lines.append("")

    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    counts = {k: len(v) for k, v in buckets.items() if v}
    print(f"wrote {OUT}  ({counts})")

    # regenerate viz.html so the graph reflects the refreshed snapshot
    if os.path.isfile(GEN):
        subprocess.run([sys.executable, GEN, BUNDLE,
                        os.path.join(BUNDLE, "viz.html"), "Warding OKF"],
                       check=False)

if __name__ == "__main__":
    main()
