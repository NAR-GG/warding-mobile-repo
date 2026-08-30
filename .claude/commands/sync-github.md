---
description: GitHub warding 보드를 읽어 warding-okf 번들의 github-project.md를 갱신하고 viz.html을 재생성
allowed-tools: Bash(python3:*)
---

`warding-okf/sync_github.py`를 실행해서 NAR-GG `warding` 프로젝트 보드의 **현재 상태**로
`warding-okf/references/github-project.md`를 다시 쓰고 `viz.html`을 재생성한다.

실행:

```bash
python3 warding-okf/sync_github.py
```

실행 후, 진행 중 / 할 일 / 완료 개수와 직전 대비 **달라진 항목(상태가 바뀐 이슈)** 이 있으면 간단히 요약해줘.
(GitHub이 진실이고 이 문서는 단방향 미러다 — 번들을 고친다고 GitHub 이슈가 바뀌진 않는다.)
