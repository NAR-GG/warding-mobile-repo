# 루프 엔지니어링 워크플로우 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Discord `/intent` 커맨드 → intent.md/spec.md 자동 초안 → 개발자 셀프 머지 → Plan.md
기반 구현 → CI 게이트, 그리고 CI 반복 실패 시 자동 에스컬레이션까지 이어지는 루프를 이 레포에
도입한다.

**Architecture:** GitHub Actions `repository_dispatch`를 단일 진입점으로 삼아 Discord(Vercel
브릿지)와 CI 에스컬레이션이 동일한 `intent-autodraft.yml` / `spec-autodraft.yml`을 재사용한다.
문서 초안은 Anthropic Messages API를 curl로 직접 호출해 생성하고, 실제 코드 수정은 항상
로컬 Build 단계(개발자+에이전트, TDD)에서만 일어난다.

**Tech Stack:** GitHub Actions(bash, jq, curl, gh CLI), Node.js 20(Vercel Function),
discord-interactions, Anthropic Messages API(`claude-sonnet-5`), Flutter 3.44.0(fvm).

**Spec:** `intent/loop-engineering-workflow/spec.md` (관련 Intent: `intent/loop-engineering-workflow/intent.md`)

## Global Constraints

- 저장소: `NAR-GG/warding-mobile-repo`. Flutter 버전은 `.fvmrc`에 고정된 `3.44.0` (fvm 사용).
- Intent/Spec/Plan 파일명은 항상 소문자: `intent.md`, `spec.md`, `plan.md`.
- Anthropic API 호출은 문서 초안 생성에만 사용한다 — 어떤 워크플로우도 코드 파일을 자동으로
  고치지 않는다.
- 새 Node/Vercel 코드는 `tools/discord-bridge/`에 격리하고 Flutter 툴체인(`flutter analyze`
  등)에 영향을 주지 않는다.
- 기존 `.github/workflows/pr-discord-notify.yml`, `test/` 폴더 구조(= `lib/` 미러링)를 깨지
  않는다.
- Slug 형식은 정규식 `^[a-z0-9]+(-[a-z0-9]+)*$` (kebab-case)만 허용한다.
- Anthropic API 호출용 모델 ID: `claude-sonnet-5`.
- Shorebird release/patch는 이번 작업의 대상이 아니다 (계속 수동).

---

## Phase 1 — 문서 템플릿 & PR 템플릿

### Task 1: Intent/Spec/Plan 빈 템플릿

**Files:**
- Create: `intent/_template/intent.md`
- Create: `intent/_template/spec.md`
- Create: `intent/_template/plan.md`

**Interfaces:**
- Produces: 앞으로 모든 `intent/<slug>/*.md`가 이 구조를 따른다. Task 5의 `check-intent-docs.sh`가
  참조하는 필수 섹션 헤더와 정확히 일치해야 한다.

- [ ] **Step 1: `intent/_template/intent.md` 작성**

```markdown
# Intent: <제목>

## Problem


## Proposed outcome


## Affected users and systems


## Constraints


## Open questions
```

- [ ] **Step 2: `intent/_template/spec.md` 작성**

```markdown
# Spec: <제목>

Intent: [intent.md](./intent.md) (있다면)

## Summary


## Requirements


## Design / Approach


## Decisions


## Out of scope


## Open questions
```

- [ ] **Step 3: `intent/_template/plan.md` 작성**

```markdown
# Plan: <제목>

## Context

- Intent: `intent/<slug>/intent.md` (있다면)
- Spec: `intent/<slug>/spec.md` (있다면)

## Changes


## Verification
```

- [ ] **Step 4: 필수 섹션이 다 있는지 육안 확인**

```bash
grep -c '^## ' "intent/_template/intent.md"   # 5
grep -c '^## ' "intent/_template/spec.md"     # 6
```

Expected: 각각 `5`, `6` 출력.

- [ ] **Step 5: 커밋**

```bash
git add intent/_template
git commit -m "docs: intent/spec/plan 빈 템플릿 추가"
```

---

### Task 2: PR 템플릿 3종

**Files:**
- Create: `.github/pull_request_template.md`
- Create: `.github/PULL_REQUEST_TEMPLATE/intent.md`
- Create: `.github/PULL_REQUEST_TEMPLATE/spec.md`

**Interfaces:**
- Consumes: 없음 (신규).
- Produces: `gh pr create --template intent.md` / `--template spec.md`로 개발자가 수동
  선택 가능. 기본(`pull_request_template.md`)은 `gh pr create` 시 자동 프리필된다.

- [ ] **Step 1: 기본 PR 템플릿**

```markdown
## 요약


## 관련 문서
- Plan: `intent/<slug>/plan.md` (있다면)
- Spec: `intent/<slug>/spec.md` (있다면)

## 테스트 방법
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] (UI 변경 시) 시뮬레이터에서 직접 확인

## 스크린샷 (UI 변경 시)


## 체크리스트
- [ ] 색상은 `AppColors`만 참조했다 (하드코딩 없음)
- [ ] MVVM 규칙을 지켰다 (ViewModel엔 BuildContext 의존 없음)
- [ ] 새 화면/컴포넌트는 CLAUDE.md의 폴더 규칙 위치에 있다
```

파일 경로: `.github/pull_request_template.md`

- [ ] **Step 2: Intent PR 템플릿**

```markdown
## Intent: <slug>

- 문서: `intent/<slug>/intent.md`

## 체크리스트
- [ ] Problem이 "누가 어떤 문제를 겪는지" 구체적으로 쓰여 있다
- [ ] Proposed outcome이 검증 가능한 형태로 쓰여 있다
- [ ] Affected users and systems를 다 나열했다
- [ ] Open questions 중 이번 Spec 단계에서 다룰 수 없는 게 있다면 표시했다

머지 = Intent 승인. 다음 단계는 Spec 작성입니다.
```

파일 경로: `.github/PULL_REQUEST_TEMPLATE/intent.md`

- [ ] **Step 3: Spec PR 템플릿**

```markdown
## Spec: <slug>

- 문서: `intent/<slug>/spec.md`
- Intent: `intent/<slug>/intent.md` (있다면)

## 체크리스트
- [ ] Requirements가 Intent의 Proposed outcome을 커버한다
- [ ] Design / Approach에 애매한 부분이 없다
- [ ] Decisions에 "왜 이렇게 정했는지"가 적혀 있다
- [ ] Out of scope를 명시했다

머지 = Spec 승인. 다음 단계는 Plan 작성 후 구현입니다.
```

파일 경로: `.github/PULL_REQUEST_TEMPLATE/spec.md`

- [ ] **Step 4: gh CLI로 템플릿 선택이 되는지 확인**

```bash
gh pr create --help | grep -A2 "\-\-template"
```

Expected: `--template` 옵션 설명이 출력됨 (템플릿 선택 기능 자체가 gh CLI에 있는지 확인).

- [ ] **Step 5: 커밋**

```bash
git add .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE
git commit -m "docs: intent/spec/기본 PR 템플릿 3종 추가"
```

---

## Phase 2 — Flutter CI 게이트

### Task 3: `ci-flutter-test.yml` (test job)

**Files:**
- Create: `.github/workflows/ci-flutter-test.yml`

**Interfaces:**
- Consumes: `secrets.DISCORD_PR_WEBHOOK_URL` (기존 시크릿, `pr-discord-notify.yml`과 공유).
- Produces: GitHub Check run 이름 `test` — Task 4의 브랜치 보호 규칙이 이 이름을 참조한다.

- [ ] **Step 1: 워크플로우 작성**

```yaml
name: Flutter CI

on:
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.0'
          channel: 'stable'

      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test

      - name: Discord 실패 알림
        if: failure()
        env:
          WEBHOOK: ${{ secrets.DISCORD_PR_WEBHOOK_URL }}
          PR_TITLE: ${{ github.event.pull_request.title }}
          PR_URL: ${{ github.event.pull_request.html_url }}
          PR_NUM: ${{ github.event.pull_request.number }}
          REPO: ${{ github.repository }}
        run: |
          set -euo pipefail
          jq -n \
            --arg t "🔴 CI 실패 — $REPO #$PR_NUM" \
            --arg d "[$PR_TITLE]($PR_URL)" \
            --argjson c 15158332 \
            '{embeds:[{title:$t,description:$d,color:$c}]}' \
            | curl -sf -H "Content-Type: application/json" -X POST "$WEBHOOK" -d @-
```

파일 경로: `.github/workflows/ci-flutter-test.yml`

- [ ] **Step 2: YAML 문법 검증**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci-flutter-test.yml'))" && echo OK
```

Expected: `OK` 출력.

- [ ] **Step 3: 로컬에서 동일 커맨드가 실제로 통과하는지 확인**

```bash
fvm flutter pub get && fvm flutter analyze && fvm flutter test
```

Expected: 셋 다 에러 없이 종료 (현재 main 기준으로 이미 통과해야 함 — 실패하면 CI 도입 전에
먼저 그 실패를 고친다).

- [ ] **Step 4: 커밋**

```bash
git add .github/workflows/ci-flutter-test.yml
git commit -m "ci: PR마다 flutter analyze/test 실행"
```

- [ ] **Step 5: 실제로 PR을 열어 워크플로우가 도는지 확인**

이 브랜치를 push하고 PR을 열어 Actions 탭에서 `Flutter CI / test`가 실행·통과하는지 확인한다.
(이 Plan 자체를 구현하는 PR로 겸용 가능.)

---

### Task 4: 브랜치 보호 규칙 활성화

**Files:**
- 코드 변경 없음 — GitHub 저장소 설정 변경.

**Interfaces:**
- Consumes: Task 3에서 만든 체크 이름 `test`.

- [ ] **Step 1: 현재 상태 확인 (보호 규칙 없음을 재확인)**

```bash
gh api repos/NAR-GG/warding-mobile-repo/branches/main/protection 2>&1 || true
```

Expected: `404 Branch not protected`.

- [ ] **Step 2: Task 3의 워크플로우가 최소 1회 실행된 뒤 보호 규칙 적용**

```bash
cat <<'JSON' | gh api -X PUT repos/NAR-GG/warding-mobile-repo/branches/main/protection --input -
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["test"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null
}
JSON
```

- [ ] **Step 3: 적용 확인**

```bash
gh api repos/NAR-GG/warding-mobile-repo/branches/main/protection --jq '.required_status_checks.contexts'
```

Expected: `["test"]`

- [ ] **Step 4: 실제로 막히는지 확인**

일부러 `flutter analyze`가 실패하는 커밋을 임시 브랜치에 만들어 PR을 열고, "Merge" 버튼이
비활성화되는지 확인한 뒤 그 브랜치는 삭제한다.

---

## Phase 3 — Intent/Spec 문서 린트

### Task 5: `check-intent-docs.sh` + `ci-doc-lint.yml`

**Files:**
- Create: `.github/scripts/check-intent-docs.sh`
- Create: `.github/workflows/ci-doc-lint.yml`

**Interfaces:**
- Consumes: `intent/_template/intent.md`, `intent/_template/spec.md`에서 정의된 섹션 헤더 목록
  (Task 1과 정확히 일치해야 함).
- Produces: `check-intent-docs.sh <file...>` — 성공 시 exit 0, 누락 섹션 있으면 exit 1 + stderr에
  `❌ <file>: 필수 섹션 누락 — <header>` 출력.

- [ ] **Step 1: 실패하는 상황을 먼저 손으로 확인 (스크립트 없음)**

```bash
mkdir -p /tmp/doc-lint-fixture
printf '## Problem\nx\n' > /tmp/doc-lint-fixture/intent.md
```

이 파일은 5개 섹션 중 1개만 있으므로, 앞으로 만들 스크립트가 이걸 실패시켜야 한다.

- [ ] **Step 2: `check-intent-docs.sh` 작성**

```bash
#!/usr/bin/env bash
# 사용법: check-intent-docs.sh <파일1> [파일2] ...
# intent.md/spec.md 파일에 필수 섹션 헤더가 다 있는지 검사한다.
set -euo pipefail

FAIL=0

check_file() {
  local file="$1"
  local base
  base=$(basename "$file")
  local -a required

  case "$base" in
    intent.md)
      required=("## Problem" "## Proposed outcome" "## Affected users and systems" "## Constraints" "## Open questions")
      ;;
    spec.md)
      required=("## Summary" "## Requirements" "## Design / Approach" "## Decisions" "## Out of scope" "## Open questions")
      ;;
    *)
      echo "건너뜀 (검사 대상 아님): $file"
      return 0
      ;;
  esac

  local h
  for h in "${required[@]}"; do
    if ! grep -qF "$h" "$file"; then
      echo "❌ $file: 필수 섹션 누락 — $h"
      FAIL=1
    fi
  done
}

if [ "$#" -eq 0 ]; then
  echo "검사할 파일 없음"
  exit 0
fi

for f in "$@"; do
  check_file "$f"
done

if [ "$FAIL" -eq 1 ]; then
  exit 1
fi
echo "✅ 모든 필수 섹션 확인됨"
```

파일 경로: `.github/scripts/check-intent-docs.sh`

- [ ] **Step 3: 실행 권한 부여 후 실패/성공 케이스 검증**

```bash
chmod +x .github/scripts/check-intent-docs.sh

# 실패 케이스 (Step 1의 fixture)
.github/scripts/check-intent-docs.sh /tmp/doc-lint-fixture/intent.md; echo "exit=$?"
```

Expected: `❌ ...: 필수 섹션 누락 — ...`가 4줄 출력되고 `exit=1`.

```bash
# 성공 케이스
cp intent/_template/intent.md /tmp/doc-lint-fixture/intent.md
sed -i '' 's/^## /## x - /' /tmp/doc-lint-fixture/intent.md 2>/dev/null || true
cp intent/_template/intent.md /tmp/doc-lint-fixture/intent.md
.github/scripts/check-intent-docs.sh /tmp/doc-lint-fixture/intent.md; echo "exit=$?"
rm -rf /tmp/doc-lint-fixture
```

Expected: `✅ 모든 필수 섹션 확인됨`, `exit=0`.

- [ ] **Step 4: `ci-doc-lint.yml` 작성**

```yaml
name: Intent 문서 검사

on:
  pull_request:
    branches: [main]
    paths:
      - 'intent/**/intent.md'
      - 'intent/**/spec.md'

jobs:
  doc-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: 변경된 문서 검사
        run: |
          set -euo pipefail
          FILES=$(git diff --name-only "origin/${{ github.base_ref }}...HEAD" -- 'intent/**/intent.md' 'intent/**/spec.md')
          if [ -z "$FILES" ]; then
            echo "검사할 파일 없음"
            exit 0
          fi
          chmod +x .github/scripts/check-intent-docs.sh
          ./.github/scripts/check-intent-docs.sh $FILES
```

파일 경로: `.github/workflows/ci-doc-lint.yml`

- [ ] **Step 5: YAML 문법 검증 후 커밋**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci-doc-lint.yml'))" && echo OK
git add .github/scripts/check-intent-docs.sh .github/workflows/ci-doc-lint.yml
git commit -m "ci: intent/spec 문서 필수 섹션 검사 추가"
```

---

## Phase 4 — 시뮬레이터 `run` 스킬

### Task 6: `run-warding` 프로젝트 스킬

**Files:**
- Create: `.claude/skills/run-warding/SKILL.md`

**Interfaces:**
- 없음 (Claude Code 스킬 — 다른 태스크가 이 파일을 참조하지 않음).

- [ ] **Step 1: 스킬 파일 작성**

```markdown
---
name: run-warding
description: warding Flutter 앱을 iOS 시뮬레이터에서 빌드·실행하고 화면을 스크린샷으로 확인한다. UI 변경을 눈으로 검증해야 할 때 사용한다.
---

# warding 앱 실행 & UI 확인

## 1. 시뮬레이터 준비

부팅된 시뮬레이터가 있는지 확인한다:

\`\`\`bash
xcrun simctl list devices booted -j
\`\`\`

부팅된 게 없으면 설치된 최신 iOS 런타임의 iPhone 시뮬레이터를 하나 띄운다:

\`\`\`bash
DEVICE=$(xcrun simctl list devices available -j \
  | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; \
    rt=[k for k in d if 'iOS' in k][-1]; \
    print([x['udid'] for x in d[rt] if 'iPhone' in x['name']][-1])")
xcrun simctl boot "$DEVICE"
open -a Simulator
\`\`\`

## 2. 앱 실행

\`\`\`bash
cd "/Volumes/Extreme SSD/Projects/teamProject/warding"
fvm flutter run -d "$DEVICE" &
\`\`\`

빌드 로그에 `Flutter run key commands`가 보이면 앱이 뜬 것이다. 최초 빌드는 1~3분 걸릴 수 있다.

## 3. 화면 확인

\`\`\`bash
xcrun simctl io "$DEVICE" screenshot /tmp/warding-screen.png
\`\`\`

Read 도구로 `/tmp/warding-screen.png`를 열어서 실제로 확인한다. 탭 이동 등 조작이 필요한
시나리오는 사람에게 조작을 요청하거나, 진행 방법을 명확히 안내한다.

## 4. 종료

\`\`\`bash
kill %1   # 백그라운드로 띄운 flutter run 종료
\`\`\`
```

파일 경로: `.claude/skills/run-warding/SKILL.md`

- [ ] **Step 2: 프론트매터 검증**

```bash
python3 -c "
import re
text = open('.claude/skills/run-warding/SKILL.md').read()
m = re.match(r'^---\n(.*?)\n---\n', text, re.S)
assert m, '프론트매터 없음'
assert 'name: run-warding' in m.group(1)
assert 'description:' in m.group(1)
print('OK')
"
```

Expected: `OK`.

- [ ] **Step 3: 실제로 시뮬레이터를 띄워 스킬 절차가 동작하는지 1회 실행**

Step 1~3의 커맨드를 그대로 실행해 `/tmp/warding-screen.png`가 생성되고 Read 도구로 열었을 때
warding 앱 화면이 보이는지 확인한다.

- [ ] **Step 4: 커밋**

```bash
git add .claude/skills/run-warding
git commit -m "chore: iOS 시뮬레이터 실행·확인용 run-warding 스킬 추가"
```

---

## Phase 5 — Discord 브릿지 인프라

### Task 7: `tools/discord-bridge/` 스캐폴딩 (Vercel Function)

**Files:**
- Create: `tools/discord-bridge/package.json`
- Create: `tools/discord-bridge/vercel.json`
- Create: `tools/discord-bridge/.gitignore`
- Create: `tools/discord-bridge/lib/slugify.js`
- Test: `tools/discord-bridge/lib/slugify.test.js`
- Create: `tools/discord-bridge/api/discord/interactions.js`

**Interfaces:**
- Consumes env: `DISCORD_PUBLIC_KEY`, `GITHUB_DISPATCH_TOKEN`, `GITHUB_REPO`
  (`NAR-GG/warding-mobile-repo`).
- Produces: `POST /api/discord/interactions` — Discord Interactions 규격에 맞는 응답.
  `slugify(input: string): string`.

- [ ] **Step 1: 실패하는 테스트 작성 (`slugify`)**

```js
// tools/discord-bridge/lib/slugify.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { slugify } from './slugify.js';

test('lowercases and hyphenates', () => {
  assert.equal(slugify('Match Detail TOC Drag'), 'match-detail-toc-drag');
});

test('strips leading/trailing separators', () => {
  assert.equal(slugify('  --Hello World!--  '), 'hello-world');
});

test('collapses repeated separators', () => {
  assert.equal(slugify('a___b   c'), 'a-b-c');
});
```

- [ ] **Step 2: 테스트가 실패하는지 확인 (구현 파일 없음)**

```bash
cd tools/discord-bridge && node --test lib/slugify.test.js
```

Expected: `Cannot find module './slugify.js'` 류의 에러로 FAIL.

- [ ] **Step 3: `slugify` 구현**

```js
// tools/discord-bridge/lib/slugify.js
export function slugify(input) {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
cd tools/discord-bridge && node --test lib/slugify.test.js
```

Expected: 3개 테스트 모두 PASS.

- [ ] **Step 5: `package.json` 작성**

```json
{
  "name": "warding-discord-bridge",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "node --test"
  },
  "dependencies": {
    "discord-interactions": "^3.4.0"
  }
}
```

파일 경로: `tools/discord-bridge/package.json`

- [ ] **Step 6: `.gitignore` 작성**

```
node_modules/
.vercel/
```

파일 경로: `tools/discord-bridge/.gitignore`

- [ ] **Step 7: 의존성 설치 후 전체 테스트 실행**

```bash
cd tools/discord-bridge && npm install && npm test
```

Expected: 3개 테스트 PASS.

- [ ] **Step 8: 인터랙션 핸들러 작성**

```js
// tools/discord-bridge/api/discord/interactions.js
import { verifyKey, InteractionType, InteractionResponseType } from 'discord-interactions';
import { slugify } from '../../lib/slugify.js';

export const config = { api: { bodyParser: false } };

async function readRawBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  return Buffer.concat(chunks);
}

async function dispatchIntentRequest({ slug, description, requestedBy }) {
  const res = await fetch(
    `https://api.github.com/repos/${process.env.GITHUB_REPO}/dispatches`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.GITHUB_DISPATCH_TOKEN}`,
        Accept: 'application/vnd.github+json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        event_type: 'intent-request',
        client_payload: { slug, description, requestedBy, source: 'discord' },
      }),
    }
  );
  if (!res.ok) {
    throw new Error(`repository_dispatch 실패: ${res.status} ${await res.text()}`);
  }
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).end();
    return;
  }

  const rawBody = await readRawBody(req);
  const signature = req.headers['x-signature-ed25519'];
  const timestamp = req.headers['x-signature-timestamp'];

  const isValid = await verifyKey(rawBody, signature, timestamp, process.env.DISCORD_PUBLIC_KEY);
  if (!isValid) {
    res.status(401).end('invalid request signature');
    return;
  }

  const interaction = JSON.parse(rawBody.toString('utf8'));

  if (interaction.type === InteractionType.PING) {
    res.status(200).json({ type: InteractionResponseType.PONG });
    return;
  }

  if (interaction.type === InteractionType.APPLICATION_COMMAND && interaction.data.name === 'intent') {
    res.status(200).json({
      type: InteractionResponseType.MODAL,
      data: {
        custom_id: 'intent_modal',
        title: 'Intent 초안 요청',
        components: [
          {
            type: 1,
            components: [
              {
                type: 4,
                custom_id: 'slug',
                label: 'slug (예: match-detail-toc-drag)',
                style: 1,
                required: true,
                max_length: 60,
              },
            ],
          },
          {
            type: 1,
            components: [
              {
                type: 4,
                custom_id: 'description',
                label: '기획안 설명',
                style: 2,
                required: true,
                max_length: 3000,
              },
            ],
          },
        ],
      },
    });
    return;
  }

  if (interaction.type === InteractionType.MODAL_SUBMIT && interaction.data.custom_id === 'intent_modal') {
    const fields = Object.fromEntries(
      interaction.data.components.map((row) => {
        const c = row.components[0];
        return [c.custom_id, c.value];
      })
    );
    const slug = slugify(fields.slug);
    const requestedBy = interaction.member?.user?.username ?? interaction.user?.username ?? 'unknown';

    res.status(200).json({
      type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
      data: { content: `✅ 접수됨 — \`${slug}\` intent 초안을 생성 중입니다.` },
    });

    await dispatchIntentRequest({ slug, description: fields.description, requestedBy });
    return;
  }

  res.status(400).end('unhandled interaction type');
}
```

파일 경로: `tools/discord-bridge/api/discord/interactions.js`

- [ ] **Step 9: `vercel.json` 작성**

```json
{
  "functions": {
    "api/discord/interactions.js": {
      "maxDuration": 10
    }
  }
}
```

파일 경로: `tools/discord-bridge/vercel.json`

- [ ] **Step 10: 구문 검증**

```bash
cd tools/discord-bridge && node --check api/discord/interactions.js && node --check lib/slugify.js
python3 -c "import json; json.load(open('vercel.json'))" && echo OK
python3 -c "import json; json.load(open('package.json'))" && echo OK
```

Expected: 에러 없이 `OK` 두 번 출력.

- [ ] **Step 11: Flutter 툴체인에 영향 없는지 확인**

```bash
cd "/Volumes/Extreme SSD/Projects/teamProject/warding" && fvm flutter analyze
```

Expected: `tools/discord-bridge` 관련 에러 없이 기존과 동일하게 통과 (Dart analyzer는 `.js`
파일을 애초에 보지 않으므로 영향 없어야 함).

- [ ] **Step 12: 커밋**

```bash
git add tools/discord-bridge
git commit -m "feat: Discord 인터랙션 브릿지(Vercel Function) 스캐폴딩"
```

---

### Task 8: 슬래시 커맨드 등록 스크립트

**Files:**
- Create: `scripts/register-discord-commands.mjs`

**Interfaces:**
- Consumes env: `DISCORD_APPLICATION_ID`, `DISCORD_BOT_TOKEN` (실행 시점에만 필요, 저장 안 함).

- [ ] **Step 1: 스크립트 작성**

```js
// scripts/register-discord-commands.mjs
// 1회 실행: /intent 슬래시 커맨드를 Discord Application에 등록한다.
// 실행: DISCORD_APPLICATION_ID=... DISCORD_BOT_TOKEN=... node scripts/register-discord-commands.mjs

const APPLICATION_ID = process.env.DISCORD_APPLICATION_ID;
const BOT_TOKEN = process.env.DISCORD_BOT_TOKEN;

if (!APPLICATION_ID || !BOT_TOKEN) {
  console.error('DISCORD_APPLICATION_ID, DISCORD_BOT_TOKEN 환경변수가 필요합니다.');
  process.exit(1);
}

const commands = [
  {
    name: 'intent',
    description: '기획안으로 intent.md 초안 + PR을 자동 생성한다',
    type: 1,
  },
];

const res = await fetch(`https://discord.com/api/v10/applications/${APPLICATION_ID}/commands`, {
  method: 'PUT',
  headers: {
    Authorization: `Bot ${BOT_TOKEN}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(commands),
});

if (!res.ok) {
  console.error(`커맨드 등록 실패: ${res.status} ${await res.text()}`);
  process.exit(1);
}

console.log('✅ /intent 커맨드 등록 완료');
```

파일 경로: `scripts/register-discord-commands.mjs`

- [ ] **Step 2: 구문 검증**

```bash
node --check scripts/register-discord-commands.mjs
```

Expected: 에러 없음.

- [ ] **Step 3: 커밋**

```bash
git add scripts/register-discord-commands.mjs
git commit -m "chore: Discord /intent 슬래시 커맨드 등록 스크립트 추가"
```

실제 실행(Discord 토큰 필요)은 Task 9의 수동 설정 단계에서 한다.

---

### Task 9: 수동 설정 체크리스트 (사용자가 직접 수행)

**Files:** 없음 — 계정/서비스 설정.

- [ ] **Step 1: Discord Application 생성**

https://discord.com/developers/applications → New Application → 이름 "Warding Bot" →
General Information 탭에서 `APPLICATION ID`, `PUBLIC KEY` 복사. Bot 탭 → Add Bot → Token
복사(재발급 시 무효화되니 안전한 곳에 보관).

- [ ] **Step 2: Vercel 프로젝트 연결**

```bash
cd tools/discord-bridge
vercel link   # Root Directory를 tools/discord-bridge로
vercel env add DISCORD_PUBLIC_KEY production
vercel env add GITHUB_DISPATCH_TOKEN production
vercel env add GITHUB_REPO production   # 값: NAR-GG/warding-mobile-repo
vercel env add NODEJS_HELPERS production   # 값: 0
vercel deploy --prod
```

`GITHUB_DISPATCH_TOKEN`은 GitHub fine-grained PAT — 이 저장소(`warding-mobile-repo`)에
`Contents: Read and write`, `Pull requests: Read and write` 권한만 부여해 발급한다.

`NODEJS_HELPERS=0`은 필수다 — Vercel의 일반 Node.js 함수는 기본적으로 요청 바디를 미리
파싱해버리는데, `interactions.js`는 Discord 서명 검증을 위해 원본(raw) 바디가 그대로
필요하다. 이 환경변수 없이는 서명 검증이 항상 실패해 모든 요청이 401로 막힌다 (Task 7
리뷰에서 발견 — `config.api.bodyParser`는 Next.js 전용 관례라 이 프로젝트엔 적용되지 않음).

- [ ] **Step 3: Discord에 Interactions Endpoint 등록**

Discord Developer Portal → General Information → Interactions Endpoint URL에
`https://<vercel-project>.vercel.app/api/discord/interactions` 입력 후 저장. 저장 시 Discord가
PING을 보내 서명 검증을 통과해야 저장됨 — 실패하면 Task 7의 `DISCORD_PUBLIC_KEY` 값을 재확인한다.

- [ ] **Step 4: 슬래시 커맨드 등록**

```bash
DISCORD_APPLICATION_ID=<복사한 값> DISCORD_BOT_TOKEN=<복사한 값> \
  node scripts/register-discord-commands.mjs
```

Expected: `✅ /intent 커맨드 등록 완료`.

- [ ] **Step 5: GitHub Actions 시크릿 등록**

```bash
gh secret set ANTHROPIC_API_KEY --repo NAR-GG/warding-mobile-repo
gh secret set GITHUB_DISPATCH_TOKEN --repo NAR-GG/warding-mobile-repo
```

(`DISCORD_PR_WEBHOOK_URL`은 이미 등록되어 있으므로 재등록 불필요.)

`GITHUB_DISPATCH_TOKEN`은 Step 2에서 Vercel에 등록한 것과 같은 PAT 값을 그대로 쓴다.
`intent-merge-continue.yml`과 `ci-flutter-test.yml`의 `escalate` job이 다른 워크플로우를
트리거하는 `repository_dispatch` 호출에 기본 `GITHUB_TOKEN` 대신 이 PAT을 쓴다 — 기본
토큰으로 만든 이벤트가 다른 워크플로우를 못 띄울 수 있다는 GitHub의 재귀 방지 정책을
확실히 피하기 위함 (Task 13 리뷰에서 발견).

- [ ] **Step 6: 봇을 서버에 초대**

Discord Developer Portal → OAuth2 → URL Generator → Scopes에서 `applications.commands`만 체크
→ 생성된 URL로 봇을 대상 서버에 초대 (별도 권한 불필요, 슬래시 커맨드만 쓰므로 `bot` scope도
불필요).

- [ ] **Step 7: 종단 확인**

Discord 채널에서 `/intent` 입력 → 모달이 뜨는지 확인. (실제 PR 생성까지의 확인은 Phase 6
완료 후 진행한다.)

---

## Phase 6 — Intent/Spec 자동 초안 워크플로우

### Task 10: `intent-autodraft.yml`

**Files:**
- Create: `.github/workflows/intent-autodraft.yml`

**Interfaces:**
- Consumes: `repository_dispatch` payload `{ slug, description, requestedBy }` (event_type
  `intent-request`), `secrets.ANTHROPIC_API_KEY`.
- Produces: `intent/<slug>` 브랜치 + PR, `intent/<slug>/intent.md` 파일.

- [ ] **Step 1: 워크플로우 작성**

```yaml
name: Intent 자동 초안

on:
  repository_dispatch:
    types: [intent-request]

permissions:
  contents: write
  pull-requests: write

jobs:
  draft:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: 입력 검증
        id: input
        env:
          SLUG: ${{ github.event.client_payload.slug }}
        run: |
          set -euo pipefail
          if [[ ! "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
            echo "잘못된 slug: $SLUG" >&2
            exit 1
          fi
          if [ -f "intent/$SLUG/intent.md" ]; then
            echo "이미 존재하는 intent: intent/$SLUG/intent.md" >&2
            exit 1
          fi
          echo "slug=$SLUG" >> "$GITHUB_OUTPUT"

      - name: intent.md 초안 생성 (Anthropic API)
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          DESCRIPTION: ${{ github.event.client_payload.description }}
          SLUG: ${{ steps.input.outputs.slug }}
        run: |
          set -euo pipefail
          PROMPT=$(jq -n --arg desc "$DESCRIPTION" '
            "다음 기획안을 바탕으로 intent.md를 작성해라. 정확히 이 5개 섹션만 이 순서로, 마크다운 헤더(##)로 써라: Problem, Proposed outcome, Affected users and systems, Constraints, Open questions. 한국어로, 불릿(-)으로 구체적으로 써라. 앞뒤 설명 없이 마크다운 본문만 출력해라.\n\n기획안:\n" + $desc
          ')
          jq -n --argjson prompt "$PROMPT" '{model:"claude-sonnet-5", max_tokens:2000, messages:[{role:"user", content:$prompt}]}' > /tmp/req.json
          curl -sf https://api.anthropic.com/v1/messages \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d @/tmp/req.json > /tmp/res.json
          mkdir -p "intent/$SLUG"
          jq -r '.content[0].text' /tmp/res.json > "intent/$SLUG/intent.md"

      - name: 브랜치 생성 & 커밋
        env:
          SLUG: ${{ steps.input.outputs.slug }}
        run: |
          set -euo pipefail
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git checkout -b "intent/$SLUG"
          git add "intent/$SLUG/intent.md"
          git commit -m "intent: $SLUG 초안 자동 생성"
          git push origin "intent/$SLUG"

      - name: PR 오픈
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SLUG: ${{ steps.input.outputs.slug }}
          REQUESTER: ${{ github.event.client_payload.requestedBy }}
        run: |
          set -euo pipefail
          BODY=$(printf '## Intent: %s\n\n- 문서: `intent/%s/intent.md`\n- 요청자: %s\n\n자동 생성된 초안입니다 — 머지 전에 내용을 검토·수정하세요.\n' "$SLUG" "$SLUG" "$REQUESTER")
          gh pr create --title "intent: $SLUG" --base main --head "intent/$SLUG" --body "$BODY"
```

파일 경로: `.github/workflows/intent-autodraft.yml`

> `$REQUESTER`, `$DESCRIPTION` 같은 신뢰할 수 없는 입력은 `jq --arg`(JSON 조립) 또는
> `printf '%s'`(리터럴 출력)로만 다룬다 — heredoc에 직접 보간하지 않는다. `printf`의 인자로
> 들어간 문자열은 셸이 다시 해석하지 않으므로 `$(...)` 같은 문자열이 값에 들어 있어도 실행되지
> 않는다.

- [ ] **Step 2: YAML 문법 검증**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/intent-autodraft.yml'))" && echo OK
```

- [ ] **Step 3: `gh workflow run`으로 수동 트리거해 로컬에서 payload 시뮬레이션**

```bash
gh api repos/NAR-GG/warding-mobile-repo/dispatches \
  -f event_type=intent-request \
  -f "client_payload.slug=loop-workflow-smoke-test" \
  -f "client_payload.description=이건 자동 생성 파이프라인 점검용 더미 요청입니다." \
  -f "client_payload.requestedBy=manual-test"
```

Actions 탭에서 `Intent 자동 초안`이 실행되고 `intent/loop-workflow-smoke-test` PR이 열리는지
확인한다. 확인 후 그 브랜치/PR은 삭제한다.

- [ ] **Step 4: 커밋**

```bash
git add .github/workflows/intent-autodraft.yml
git commit -m "ci: intent.md 자동 초안 생성 워크플로우 추가"
```

---

### Task 11: `intent-merge-continue.yml`

**Files:**
- Create: `.github/workflows/intent-merge-continue.yml`

**Interfaces:**
- Consumes: `pull_request` closed 이벤트, `intent/<slug>/intent.md` 파일 존재.
- Produces: `repository_dispatch` event_type `spec-request` (Task 12가 소비).

- [ ] **Step 1: 워크플로우 작성**

```yaml
name: Intent 머지 → Spec 요청

on:
  pull_request:
    types: [closed]
    branches: [main]

jobs:
  continue:
    if: github.event.pull_request.merged == true && startsWith(github.event.pull_request.head.ref, 'intent/')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: main

      - name: spec-request 디스패치
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          REPO: ${{ github.repository }}
          HEAD_REF: ${{ github.event.pull_request.head.ref }}
        run: |
          set -euo pipefail
          SLUG="${HEAD_REF#intent/}"
          if [ ! -f "intent/$SLUG/intent.md" ]; then
            echo "intent/$SLUG/intent.md 없음 — 스킵"
            exit 0
          fi
          if [ -f "intent/$SLUG/spec.md" ]; then
            echo "이미 spec.md 있음 — 스킵"
            exit 0
          fi
          DESCRIPTION=$(cat "intent/$SLUG/intent.md")
          gh api "repos/$REPO/dispatches" \
            -f event_type="spec-request" \
            -f "client_payload.slug=$SLUG" \
            -f "client_payload.description=$DESCRIPTION" \
            -f "client_payload.requestedBy=intent-merge" \
            -f "client_payload.source=intent-merge"
```

파일 경로: `.github/workflows/intent-merge-continue.yml`

- [ ] **Step 2: YAML 문법 검증**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/intent-merge-continue.yml'))" && echo OK
```

- [ ] **Step 3: 커밋**

```bash
git add .github/workflows/intent-merge-continue.yml
git commit -m "ci: Intent PR 머지 시 spec-request 자동 디스패치"
```

(종단 확인은 Task 12까지 만든 뒤 Task 9-Step 7 이어서 진행.)

---

### Task 12: `spec-autodraft.yml`

**Files:**
- Create: `.github/workflows/spec-autodraft.yml`

**Interfaces:**
- Consumes: `repository_dispatch` payload `{ slug, description }` (event_type `spec-request`) —
  Task 11(정상 흐름) 또는 Task 13(에스컬레이션)이 호출.
- Produces: `spec/<slug>` 브랜치 + PR, `intent/<slug>/spec.md` 파일.

- [ ] **Step 1: 워크플로우 작성**

```yaml
name: Spec 자동 초안

on:
  repository_dispatch:
    types: [spec-request]

permissions:
  contents: write
  pull-requests: write

jobs:
  draft:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: 입력 검증
        id: input
        env:
          SLUG: ${{ github.event.client_payload.slug }}
        run: |
          set -euo pipefail
          if [[ ! "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
            echo "잘못된 slug: $SLUG" >&2
            exit 1
          fi
          if [ -f "intent/$SLUG/spec.md" ]; then
            echo "이미 존재하는 spec: intent/$SLUG/spec.md" >&2
            exit 1
          fi
          echo "slug=$SLUG" >> "$GITHUB_OUTPUT"

      - name: spec.md 초안 생성 (Anthropic API)
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          DESCRIPTION: ${{ github.event.client_payload.description }}
          SLUG: ${{ steps.input.outputs.slug }}
        run: |
          set -euo pipefail
          PROMPT=$(jq -n --arg src "$DESCRIPTION" '
            "다음 내용을 material로 삼아 spec.md를 작성해라. 정확히 이 6개 섹션만 이 순서로, 마크다운 헤더(##)로 써라: Summary, Requirements, Design / Approach, Decisions, Out of scope, Open questions. 한국어로, 구체적으로 써라. 앞뒤 설명 없이 마크다운 본문만 출력해라.\n\nmaterial:\n" + $src
          ')
          jq -n --argjson prompt "$PROMPT" '{model:"claude-sonnet-5", max_tokens:2500, messages:[{role:"user", content:$prompt}]}' > /tmp/req.json
          curl -sf https://api.anthropic.com/v1/messages \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d @/tmp/req.json > /tmp/res.json
          mkdir -p "intent/$SLUG"
          jq -r '.content[0].text' /tmp/res.json > "intent/$SLUG/spec.md"

      - name: 브랜치 생성 & 커밋
        env:
          SLUG: ${{ steps.input.outputs.slug }}
        run: |
          set -euo pipefail
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git checkout -b "spec/$SLUG"
          git add "intent/$SLUG/spec.md"
          git commit -m "spec: $SLUG 초안 자동 생성"
          git push origin "spec/$SLUG"

      - name: PR 오픈
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SLUG: ${{ steps.input.outputs.slug }}
        run: |
          set -euo pipefail
          BODY=$(printf '## Spec: %s\n\n- 문서: `intent/%s/spec.md`\n- Intent: `intent/%s/intent.md` (있다면)\n\n자동 생성된 초안입니다 — 머지 전에 내용을 검토·수정하세요.\n' "$SLUG" "$SLUG" "$SLUG")
          gh pr create --title "spec: $SLUG" --base main --head "spec/$SLUG" --body "$BODY"
```

파일 경로: `.github/workflows/spec-autodraft.yml`

- [ ] **Step 2: YAML 문법 검증**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/spec-autodraft.yml'))" && echo OK
```

- [ ] **Step 3: 커밋**

```bash
git add .github/workflows/spec-autodraft.yml
git commit -m "ci: spec.md 자동 초안 생성 워크플로우 추가"
```

- [ ] **Step 4: Phase 6 전체 종단 확인**

Task 10-Step 3처럼 `intent-request`를 더미로 디스패치 → PR이 열리면 그 PR을 실제로 머지 →
`intent-merge-continue.yml`이 돌아 `spec-request`가 디스패치되는지 → `spec-autodraft.yml`이
돌아 `spec/loop-workflow-smoke-test` PR이 열리는지까지 Actions 탭에서 확인한다. 확인 후 만든
브랜치/PR/폴더는 정리한다.

- [ ] **Step 5: Task 9-Step 7 마저 진행**

Discord에서 실제로 `/intent`를 실행해 모달을 채우고, `intent/<slug>` PR이 열리는지, 머지 후
`spec/<slug>` PR이 이어서 열리는지 실제로 확인한다.

---

## Phase 7 — CI 반복 실패 에스컬레이션

### Task 13: `ci-flutter-test.yml`에 `escalate` job 추가

**Files:**
- Modify: `.github/workflows/ci-flutter-test.yml`

**Interfaces:**
- Consumes: Task 3의 `test` job 결과, `secrets.ANTHROPIC_API_KEY`.
- Produces: `plan` 등급이면 같은 브랜치에 `intent/<slug>/plan.md` 커밋. `spec`/`intent` 등급이면
  Task 10/12가 소비하는 `repository_dispatch`(`intent-request`/`spec-request`)를 슬러그
  `<slug>-fix`로 재사용.

- [ ] **Step 1: `escalate` job을 `jobs:` 아래에 추가 (기존 `test` job은 그대로 둔다)**

```yaml
  escalate:
    needs: test
    if: failure() && github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    permissions:
      contents: write
      actions: read
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: 직전 커밋도 실패했는지 확인
        id: check
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          REPO: ${{ github.repository }}
          HEAD_SHA: ${{ github.event.pull_request.head.sha }}
        run: |
          set -euo pipefail
          PREV_SHA=$(git rev-parse "$HEAD_SHA~1" 2>/dev/null || echo "")
          SHOULD="false"
          if [ -n "$PREV_SHA" ]; then
            STATUS=$(gh api "repos/$REPO/commits/$PREV_SHA/check-runs" \
              --jq '[.check_runs[] | select(.name == "test")][0].conclusion // "none"')
            if [ "$STATUS" = "failure" ]; then
              SHOULD="true"
            fi
          fi
          echo "should_escalate=$SHOULD" >> "$GITHUB_OUTPUT"

      - name: 실패 로그 수집
        if: steps.check.outputs.should_escalate == 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          RUN_ID: ${{ github.run_id }}
        run: gh run view "$RUN_ID" --log-failed > /tmp/failure.log || true

      - name: 등급 분류 + 문서 초안 (Anthropic API)
        if: steps.check.outputs.should_escalate == 'true'
        id: classify
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          set -euo pipefail
          LOG=$(tail -c 8000 /tmp/failure.log)
          PROMPT=$(jq -n --arg log "$LOG" '
            "아래는 같은 브랜치에서 2회 연속 실패한 Flutter CI 로그다. 이 실패를 다음 세 등급 중 하나로 분류해라: plan(원인이 명확한 단순 버그), spec(설계 결정이 더 필요한 문제), intent(문제 정의 자체가 잘못됐을 가능성). 정확히 아래 JSON 형식으로만 답해라(다른 텍스트나 코드펜스 없이): {\"tier\": \"plan\", \"markdown\": \"...\"} tier는 plan/spec/intent 중 하나. plan이면 markdown에 Context/Changes/Verification 3섹션, spec이면 Summary/Requirements/Design / Approach/Decisions/Out of scope/Open questions 6섹션, intent면 Problem/Proposed outcome/Affected users and systems/Constraints/Open questions 5섹션을 마크다운 헤더(##)로 써라. 한국어로 작성해라.\n\nCI 실패 로그:\n" + $log
          ')
          jq -n --argjson prompt "$PROMPT" '{model:"claude-sonnet-5", max_tokens:3000, messages:[{role:"user", content:$prompt}]}' > /tmp/req.json
          curl -sf https://api.anthropic.com/v1/messages \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d @/tmp/req.json > /tmp/res.json
          jq -r '.content[0].text' /tmp/res.json > /tmp/classification.json
          TIER=$(jq -r '.tier' /tmp/classification.json)
          jq -r '.markdown' /tmp/classification.json > /tmp/doc.md
          echo "tier=$TIER" >> "$GITHUB_OUTPUT"

      - name: 등급별 문서 반영
        if: steps.check.outputs.should_escalate == 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          TIER: ${{ steps.classify.outputs.tier }}
          HEAD_REF: ${{ github.event.pull_request.head.ref }}
          REPO: ${{ github.repository }}
        run: |
          set -euo pipefail
          RAW_SLUG=$(basename "$HEAD_REF")
          SLUG=$(echo "$RAW_SLUG" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed -E 's/-+/-/g; s/^-|-$//g')
          case "$TIER" in
            plan)
              git config user.name "github-actions[bot]"
              git config user.email "github-actions[bot]@users.noreply.github.com"
              git fetch origin "$HEAD_REF"
              git checkout "$HEAD_REF"
              mkdir -p "intent/$SLUG"
              cp /tmp/doc.md "intent/$SLUG/plan.md"
              git add "intent/$SLUG/plan.md"
              git commit -m "plan: CI 2회 연속 실패로 자동 생성"
              git push origin "$HEAD_REF"
              ;;
            spec)
              MATERIAL=$(cat /tmp/doc.md)
              gh api "repos/$REPO/dispatches" \
                -f event_type="spec-request" \
                -f "client_payload.slug=${SLUG}-fix" \
                -f "client_payload.description=$MATERIAL" \
                -f "client_payload.requestedBy=ci-escalation" \
                -f "client_payload.source=ci-escalation"
              ;;
            intent)
              MATERIAL=$(cat /tmp/doc.md)
              gh api "repos/$REPO/dispatches" \
                -f event_type="intent-request" \
                -f "client_payload.slug=${SLUG}-fix" \
                -f "client_payload.description=$MATERIAL" \
                -f "client_payload.requestedBy=ci-escalation" \
                -f "client_payload.source=ci-escalation"
              ;;
          esac

      - name: Discord 알림
        if: steps.check.outputs.should_escalate == 'true'
        env:
          WEBHOOK: ${{ secrets.DISCORD_PR_WEBHOOK_URL }}
          TIER: ${{ steps.classify.outputs.tier }}
          PR_URL: ${{ github.event.pull_request.html_url }}
        run: |
          set -euo pipefail
          jq -n --arg t "⚠️ 2회 연속 CI 실패 — $TIER 자동 생성됨" --arg d "$PR_URL" --argjson c 16776960 \
            '{embeds:[{title:$t,description:$d,color:$c}]}' \
            | curl -sf -H "Content-Type: application/json" -X POST "$WEBHOOK" -d @-
```

- [ ] **Step 2: YAML 문법 검증**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci-flutter-test.yml'))" && echo OK
```

- [ ] **Step 3: 2회 연속 실패 시나리오로 종단 확인**

임시 브랜치에서 일부러 실패하는 커밋을 2번 연속 push해 PR CI가 2번 연속 실패하게 만든다.
Actions 탭에서 `escalate` job이 돌고, `tier`에 따라 같은 브랜치에 `plan.md`가 추가되거나
새 `spec/*-fix`·`intent/*-fix` PR이 열리는지, Discord에 "⚠️ 2회 연속 CI 실패" 알림이 오는지
확인한다. 확인 후 임시 브랜치/PR은 정리한다.

- [ ] **Step 4: 커밋**

```bash
git add .github/workflows/ci-flutter-test.yml
git commit -m "ci: 2회 연속 실패 시 plan/spec/intent 자동 에스컬레이션"
```

---

## Self-Review 메모 (계획 작성자용)

- **Spec coverage**: 저장 구조/진입점 유연성(Task 1), PR 템플릿 3종(Task 2), Flutter CI +
  브랜치 보호(Task 3-4), 문서 린트(Task 5), run 스킬(Task 6), Discord 브릿지+커맨드 등록+수동
  설정(Task 7-9), intent/spec 자동 초안 + 머지 연쇄(Task 10-12), CI 에스컬레이션(Task 13) —
  spec.md의 전 섹션이 태스크로 매핑됨.
- **Placeholder scan**: TBD/TODO 없음. 모든 코드 블록이 실제 내용.
- **Type/이름 일관성**: `event_type`은 `intent-request`/`spec-request` 두 가지로 전 태스크에서
  통일. `client_payload` 필드명(`slug`, `description`, `requestedBy`, `source`)도 Task
  7/10/11/12/13에서 동일하게 사용. 체크 이름 `test`가 Task 3(생성)·4(브랜치 보호)·13(조회)에서
  일관됨.
