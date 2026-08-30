---
name: content-pipeline
description: This skill should be used when the user asks to "콘텐츠 만들어줘", "카드뉴스 만들어줘", "카드뉴스 영상 만들어줘", "리서치부터 영상까지", "콘텐츠 파이프라인", "content pipeline", "주제로 콘텐츠 만들어줘". 주제 하나로 리서치→카드뉴스→영상까지 풀 파이프라인을 자동 실행합니다. Make sure to use this skill whenever the user mentions content creation that involves research, card news, or video generation from a topic.
---

# 콘텐츠 파이프라인

> 주제 하나 던지면 리서치 → 카드뉴스 → 영상까지 자동으로 만들어주는 올인원 콘텐츠 제작 스킬.

---

## 출력 경로 규칙

`{output}`은 **현재 작업 디렉토리** 기준으로 생성한다:

```
{현재 작업 디렉토리}/{주제명}-{YYYYMMDD}/
├── 01-리서치-보고서.md
├── 02-카드뉴스-기획서.md
├── images/
├── card-news.html
├── 05-tts-script.md
├── audio/
└── output.mp4
```

`SKILL_DIR`은 이 SKILL.md가 위치한 디렉토리의 절대 경로다. 스크립트/참조 파일 경로에만 사용한다.

---

## 워크플로우

### Step 0: 환경 검사 + 온보딩
**타입**: script

스킬 실행 전, 필요한 도구와 설정을 확인한다.

**1. Python3 확인:**
```bash
python3 --version
```
없으면: "Python3이 필요해요. 설치 후 다시 시도해주세요." → 중단.

**2. .env 파일 확인:**
```bash
ls "${SKILL_DIR}/.env"
```

**.env가 없으면 온보딩 시작** — 아래 안내를 사용자에게 보여준다:

```
이 스킬을 처음 사용하시네요! API 키 설정이 필요해요.

━━━ 설정 가이드 (약 3분) ━━━

1. .env 파일 생성:
   ! cp "${SKILL_DIR}/.env.example" "${SKILL_DIR}/.env"

2. 이미지 생성용 API 키 발급 (Google AI Studio):
   → https://aistudio.google.com/apikey
   → "Create API key" 클릭 → 키 복사

3. TTS 음성용 API 키 (OpenAI):
   → https://platform.openai.com/api-keys
   → "Create new secret key" → 키 복사

4. .env 파일에 키 입력:
   ! nano "${SKILL_DIR}/.env"
   → NANOBANANA_API_KEY=여기에_구글_키_붙여넣기
   → OPENAI_API_KEY=여기에_오픈AI_키_붙여넣기

완료되면 저한테 말씀해주세요!
```

**중요**: 온보딩 완료 후, 사용자가 처음에 요청했던 내용을 이어서 바로 처리한다.

**.env가 있으면** API 키 유효성을 간단히 확인한다:
- `NANOBANANA_API_KEY`가 비어있으면: "이미지 생성 API 키가 없어요. 텍스트 온리로 진행할게요."
- `OPENAI_API_KEY`가 비어있으면: "TTS API 키가 없어요. 음성/영상 단계는 건너뛸게요."

가용 범위를 안내한다:
```
환경 확인 완료!
✅ 리서치 → 카드뉴스 기획 → HTML 카드뉴스
✅/❌ AI 이미지 생성
✅/❌ TTS 음성 생성 (OpenAI)
✅/❌ 영상 렌더링 (Remotion)
```

### Step 1: 리서치
**타입**: prompt (WebSearch 활용)

사용자가 입력한 주제로 웹 리서치를 실행한다.

1. WebSearch로 주제 관련 최신 자료 5~10건 수집
2. 각 소스에서 핵심 정보 추출
3. 종합 분석하여 리서치 보고서 마크다운으로 정리

출력: `{output}/01-리서치-보고서.md`

보고서 구조:
- 주제 개요
- 핵심 포인트 5~10개 (출처 포함)
- 종합 분석
- 카드뉴스에 활용할 핵심 메시지 후보

검색 결과가 3건 미만이면: 대안 키워드 3개 제안.

**체크포인트** — AskUserQuestion:
```
"리서치 결과예요. 핵심 내용이 잘 담겼는지 확인해주세요."
옵션: 진행 (추천) / 수정 요청 / 여기서 종료
```

### Step 2: 카드뉴스 기획
**타입**: prompt + rag

리서치 보고서를 읽고 카드뉴스 기획서를 생성한다. `references/card-news-guide.md`를 참조하여 디자인 규칙과 유형 분류를 적용한다.

기획서 포함 내용:
1. 유형 선택 (나열형/스토리텔링형/집중형 등) + 선택 이유
2. 총 장수 (10~15장)
3. 장별 테이블: 장번호 | 파트(표지/본문/마무리) | 핵심 메시지 | 필요한 이미지 설명
4. 디자인 컬러/무드: **주제에 맞게 자동 결정** (예: 벚꽃→핑크/파스텔, 테크→다크/네온, 음식→따뜻한 톤)

출력: `{output}/02-카드뉴스-기획서.md`

이 기획서가 이후 모든 Step의 기준 문서(single source of truth)가 된다.

**체크포인트** — AskUserQuestion:
```
"기획서예요. 장수나 내용 흐름을 확인해주세요."
옵션: 진행 (추천) / 수정 요청 / 여기서 종료
```

### Step 3: 이미지 생성
**타입**: script

기획서의 "필요한 이미지 설명" 목록을 보고, 내장 스크립트로 카드별 이미지를 생성한다.

**사전 조건**: `.env`의 `NANOBANANA_API_KEY`가 필요하다. 없으면 텍스트 온리로 폴백.

**이미지 생성 순서:**

1. 기획서에서 이미지가 필요한 카드 목록 추출
2. 각 카드별 영문 프롬프트 작성

**프롬프트 작성 규칙 (필수):**
- **텍스트 절대 금지**: 프롬프트 시작에 반드시 `"DO NOT include any text, letters, words, numbers, watermarks, logos, or typography in the image. Pure visual only."` 포함
- **사진은 풀 컬러**: 주제에 맞는 생생한 컬러로 생성한다. 흑백으로 만들지 않는다. (B&W 에디토리얼은 HTML 레이아웃 스타일이지 사진 스타일이 아니다)
- 에디토리얼 매거진 사진 스타일 (구도, 조명, 피사계 심도)
- 200~400단어 영문 프롬프트

3. 내장 스크립트로 이미지 **병렬 생성**:

**병렬 실행 규칙:**
- Bash 도구를 **동시에 3~4개** 호출하여 병렬 생성
- 한 배치(3~4장) 완료 후 다음 배치 → API rate limit 방지
- 배치마다 진행 안내: "이미지 생성 중... (2/4 배치 완료)"

```bash
python3 "${SKILL_DIR}/scripts/generate_image.py" \
  --mode generate \
  --prompt "{영문 프롬프트}" \
  --output "{output}/images/card-{NN}.png" \
  --aspect-ratio "3:4" \
  --image-size "2K" \
  --thinking-level "high" \
  --env-file "${SKILL_DIR}/.env"
```

**파라미터 유효값 (반드시 이 값만 사용):**
- `--aspect-ratio`: `1:1`, `16:9`, `9:16`, `4:3`, `3:4`, `4:1`, `1:4`
- `--image-size`: `512`, `1K`, `2K`, `4K` (숫자 단독 사용 금지 — '2048' 아닌 '2K')
- `--thinking-level`: `minimal`, `high`

이미지 생성 실패 시: 텍스트 온리 폴백 제안.

**체크포인트** — AskUserQuestion:
```
"이미지들이에요. 마음에 안 드는 건 재생성할 수 있어요."
옵션: 진행 (추천) / 일부 재생성 / 텍스트 온리로 진행
```

### Step 4: 카드뉴스 HTML 생성
**타입**: generate

기획서 + 이미지를 합쳐 에디토리얼 매거진 스타일의 HTML 카드뉴스를 생성한다.

**디자인 원칙:**
- **레이아웃/타이포**: 블랙앤화이트 에디토리얼 매거진 (다크 배경 + 흰 텍스트, 세리프 제목, 비대칭 구도)
- **이미지**: 풀 컬러 그대로 사용. 이미지 위에 그라디언트 마스크 + 텍스트 오버레이
- 주제 분위기에 맞는 포인트 컬러 1개 추가 가능 (예: 벚꽃→#FFB7C5, 테크→#2563EB)

| 항목 | 설정 |
|------|------|
| 사이즈 | 1080 x 1350px (4:5 세로형) |
| 배경 | #0A0A0A (딥블랙) / #FAFAFA (오프화이트) 교차 |
| 이미지 | **풀 컬러** 히어로 이미지 (카드 면적 60%+) |
| 폰트 | 제목 세리프 + 본문 산세리프 |
| 레이아웃 | 장마다 다른 구도 (풀블리드/스플릿/오버레이) |
| 페이지 표시 | 하단 중앙 "3/13" 형식 |

**모바일 가독성 폰트 사이즈 규칙 (필수):**

1080px 캔버스는 모바일에서 ~375px로 축소되어 약 1/2.88로 줄어든다. 모바일 최소 가독 사이즈 12px을 확보하기 위해 아래 기준을 지킨다.

| 요소 | 캔버스 최소 | 모바일 체감 | 비고 |
|------|-----------|-----------|------|
| 제목 (h2) | **48px** | ~17px | 세리프, bold |
| 본문 (desc) | **36px** | ~12px | 핵심 설명 |
| 날짜/태그 (date) | **32px** | ~11px | 보조 정보 |
| 위치/출처 (info) | **30px** | ~10px | 최소 보조 |
| 페이지 번호 | **28px** | ~10px | |
| **절대 최소** | **24px** | ~8px | 이 이하 금지 |

- 본문은 한 카드에 **2~3줄 이내**로 압축 (폰트가 크므로 길면 넘침)
- 요소 간 간격(gap/margin)을 충분히 확보 — 빽빽하면 가독성 저하

**레이아웃별 페이지 번호 위치:**
- 풀블리드(type-a), 상하분할(type-b): 카드 하단 중앙
- **좌우분할(type-c): 텍스트 영역 하단 중앙** (이미지 위에 놓지 않는다)

HTML 요구사항:
- 단일 HTML 파일 (인라인 CSS, 외부 의존성 없음)
- 각 카드는 `<section>`으로 구분
- 브라우저에서 열면 매거진처럼 보이는 수준

출력: `{output}/card-news.html`

**체크포인트** — AskUserQuestion:
```
"카드뉴스 HTML이에요. 브라우저에서 열어보세요!"
옵션: 진행 (추천) / 수정 요청 / 여기서 종료 (카드뉴스만 완성)
```

### Step 5: 영상 오디오 선택 + 스크립트 작성
**타입**: prompt + ask

먼저 영상에 어떤 오디오를 넣을지 사용자에게 물어본다.

**체크포인트** — AskUserQuestion:
```
"영상에 어떤 오디오를 넣을까요?"
옵션:
- "오디오 없이 (추천)" — 무음 영상으로 만들어요. 카드뉴스 자체로 충분해요.
- "TTS 나레이션" — AI 음성으로 카드별 설명을 읽어줘요. (OpenAI API 키 필요, 유료)
- "배경 음악만" — 가지고 있는 음악 파일을 깔아요. 감성적인 영상에 어울려요.
- "TTS + 배경 음악" — 나레이션 위에 배경 음악도 깔아요. (OpenAI API 키 필요, 유료)
```

**무음 선택 시 → Step 6으로 바로 진행** (카드당 기본 5초)

**TTS 선택 시 → 나레이션 스크립트 작성:**

카드뉴스 기획서를 기반으로 **카드 1장 = 섹션 1개** 구조로 나레이션 원고를 작성한다.

스크립트 구조:
```
## 인트로 (약 10초)
나레이션 텍스트...

## 카드 2: 제목 (약 15초)
나레이션 텍스트...
```

규칙:
- 카드 수와 섹션 수가 정확히 일치해야 한다 (13장이면 13섹션)
- TTS 친화적: 영문→한글 발음 병기, 숫자 풀어쓰기, 줄임말 풀어쓰기
- 톤: 친근하지만 전문적

출력: `{output}/05-tts-script.md`

**배경 음악 선택 시:**
사용자에게 음악 파일 경로를 물어본다: "배경 음악 파일 경로를 알려주세요 (MP3/WAV)"
제공된 파일을 `{output}/audio/bgm.mp3`로 복사한다.

**체크포인트** — AskUserQuestion:
```
"나레이션 원고예요. 톤이나 길이를 확인해주세요." (TTS 시)
옵션: 진행 (추천) / 수정 요청 / 여기서 종료
```

### Step 6: 음성 생성 + 영상화
**타입**: script

**6-1. 카드별 TTS 음성 생성 (TTS 선택 시):**

`--section-mode`로 TTS 스크립트를 자동 분리하여 카드별 MP3 + 타이밍 JSON을 한 번에 생성한다.

```bash
python3 "${SKILL_DIR}/scripts/tts_openai.py" \
  --input "{output}/05-tts-script.md" \
  --output "{output}/audio/cards" \
  --voice "shimmer" \
  --section-mode \
  --env-file "${SKILL_DIR}/.env"
```

이 명령 하나로:
- `## ` 헤더 기준 섹션 자동 분리
- 마크다운 문법 자동 제거 (순수 나레이션만 추출)
- 카드별 MP3 생성: `card-01.mp3` ~ `card-{N}.mp3`
- 각 MP3의 실제 재생 시간 ffprobe로 측정
- `card-timings.json` 자동 생성:
```json
[
  {"card": 1, "duration_sec": 10.32, "frames": 310, "file": "card-01.mp3"},
  {"card": 2, "duration_sec": 17.06, "frames": 512, "file": "card-02.mp3"}
]
```

출력: `{output}/audio/cards/card-*.mp3` + `card-timings.json`

**6-2. Remotion 영상 렌더링 (React 컴포넌트 방식):**

card-news.html의 CSS/레이아웃을 **React JSX 컴포넌트로 변환**하여 Remotion에서 직접 렌더링한다.

**Step A: 보일러플레이트 복사**
`references/remotion-boilerplate/`를 `{output}/remotion/`에 복사한다. 이미 검증된 프로젝트 구조(package.json, tsconfig.json, Root.tsx, CardNewsVideo.tsx, SubtitleOverlay.tsx, cards/CardTemplate.tsx)가 포함되어 있다.

```bash
cp -r "${SKILL_DIR}/references/remotion-boilerplate/" "{output}/remotion/"
cd "{output}/remotion" && npm install
```

**Step B: 카드 컴포넌트 생성**
card-news.html의 각 카드(section)를 **개별 React 컴포넌트**로 변환한다:
- `src/cards/Card01.tsx` ~ `Card{N}.tsx`
- `src/cards/CardTemplate.tsx`의 3가지 패턴(FullBleed/Split/TextOnly) 중 카드에 맞는 것을 선택하여 복사 후 내용 채우기
- CSS → React 인라인 스타일
- 이미지: `staticFile("card-XX.png")` 참조
- 레이아웃 카드별로 다르게 구현
- `src/cards/index.ts`에 모든 카드 컴포넌트 export 등록

**Step C: data.ts 생성**
`card-timings.json`을 읽고 `src/data.ts`를 생성한다. 아래 스키마를 준수:

```typescript
// data.ts 필수 export
export const FPS = 30;
export const CARD_WIDTH = 1080;
export const CARD_HEIGHT = 1350;

// TTS 있을 때: card-timings.json의 frames 배열 그대로 사용
// 무음일 때: 카드당 150프레임 (5초) 균등 배분
const ACTUAL_CARD_FRAMES = [310, 512, ...]; // card-timings.json에서 복사
export const TOTAL_FRAMES = ACTUAL_CARD_FRAMES.reduce((a, b) => a + b, 0);

// CARD_DURATIONS = 실제 프레임 배열
export const CARD_DURATIONS = ACTUAL_CARD_FRAMES;

// SUBTITLE_LINES: 카드별 나레이션 텍스트 (자막용, 선택)
export const SUBTITLE_LINES: string[][] = [...];
```

**Step D: 오디오 + 이미지 복사**
`{output}/images/card-*.png` + `{output}/audio/cards/card-*.mp3` → `public/` 폴더에 복사

**Step E: 렌더링**
자막 없는 버전(CardNewsVideoClean)을 기본으로 렌더링:
```bash
cd "{output}/remotion" && npx remotion render src/index.ts CardNewsVideoClean --output "../output.mp4" --concurrency=4
```

Remotion 미설치 또는 실패 시: "HTML 카드뉴스는 완성됐어요. 영상은 별도 편집 도구로 합치셔도 돼요."

출력: `{output}/output.mp4`

**체크포인트** — AskUserQuestion:
```
"영상 완성! 확인해주세요."
옵션: 완료 / 수정 요청
```

---

## 실패 시 부분 완성 안내

어느 단계에서 실패하든, 완료된 단계의 결과물을 명확히 안내한다:

```
완성된 결과물:
✅ Step 1: 리서치 보고서 → {output}/01-리서치-보고서.md
✅ Step 2: 카드뉴스 기획서 → {output}/02-카드뉴스-기획서.md
✅ Step 3: 이미지 → {output}/images/
✅ Step 4: 카드뉴스 HTML → {output}/card-news.html
❌ Step 5~6: (건너뜀)
```

---

## References
- **`references/card-news-guide.md`** — 카드뉴스 디자인 가이드 (유형 분류, 디자인 규칙, 테마 스펙)

## Scripts
- **`scripts/generate_image.py`** — 이미지 생성 (google-genai SDK). generate/edit/chat 3가지 모드.
- **`scripts/tts_openai.py`** — OpenAI TTS 음성 생성 (마크다운 파싱 내장, 텍스트 → MP3)
- **`scripts/tts.sh`** — edge-tts 래퍼 (폴백용)

## Settings

| 설정 | 기본값 | 변경 방법 |
|------|--------|-----------|
| 이미지 API 키 | (필수) | `.env`의 `NANOBANANA_API_KEY` |
| 이미지 모델 | gemini-3-pro-image-preview | `.env`의 `NANOBANANA_MODEL` |
| OpenAI API 키 | (TTS 선택 시 필수) | `.env`의 `OPENAI_API_KEY` |
| TTS 음성 | shimmer | "남자 목소리로" → onyx, "차분하게" → nova |
| 카드 장수 | 10~15장 | "5장으로" 등 요청 시 변경 |
| 무음 시 카드당 시간 | 5초 | "카드당 3초로" 등 요청 시 변경 |
| 출력 폴더 | {주제명}-{YYYYMMDD} | 현재 작업 디렉토리에 자동 생성 |
