# Content Pipeline — Claude Code 콘텐츠 자동 생성 스킬

> 주제 하나 던지면 리서치 → 카드뉴스 → 영상까지 자동으로 만들어주는 올인원 콘텐츠 제작 스킬

"벚꽃 명소 카드뉴스 만들어줘" 한 마디로 6단계 파이프라인이 자동 실행됩니다.

---

## 주요 기능

- WebSearch 기반 주제 리서치 → 보고서 자동 생성
- 카드뉴스 기획서 자동 작성 (유형/장수/메시지/이미지 설명)
- AI 이미지 생성 (3~4장씩 병렬 배치, 텍스트 없는 풀컬러)
- 에디토리얼 매거진 스타일 HTML 카드뉴스
- OpenAI TTS 나레이션 음성 생성
- Remotion 기반 카드뉴스 + 음성 합성 영상 (MP4)
- 각 단계마다 체크포인트 — 확인/수정/건너뛰기 가능

---

## 설치

### 방법 1: 스킬 폴더에 직접 복사

```bash
git clone https://github.com/fivetaku/content-pipeline.git
cp -r content-pipeline/ your-project/.claude/skills/content-pipeline/
```

### 방법 2: .claude/skills에 클론

```bash
cd your-project/.claude/skills
git clone https://github.com/fivetaku/content-pipeline.git
```

---

## 설정

첫 실행 시 자동으로 온보딩 가이드가 표시됩니다. 또는 수동으로:

```bash
cd .claude/skills/content-pipeline
cp .env.example .env
```

`.env` 파일에 API 키를 입력합니다:

| 키 | 용도 | 발급처 |
|---|------|--------|
| `NANOBANANA_API_KEY` | AI 이미지 생성 | [Google AI Studio](https://aistudio.google.com/apikey) |
| `OPENAI_API_KEY` | TTS 음성 생성 | [OpenAI Platform](https://platform.openai.com/api-keys) |

API 키 없이도 리서치 → 기획 → HTML 카드뉴스(텍스트 온리)까지는 동작합니다.

---

## 사용법

Claude Code에서:

```
"AI 트렌드 카드뉴스 만들어줘"
"벚꽃 명소 콘텐츠 만들어줘"
"리서치부터 영상까지 자동으로 만들어줘"
```

### 파이프라인 단계

| Step | 내용 | 결과물 |
|------|------|--------|
| 0 | 환경 검사 + 온보딩 | - |
| 1 | 주제 리서치 (WebSearch) | `01-리서치-보고서.md` |
| 2 | 카드뉴스 기획 | `02-카드뉴스-기획서.md` |
| 3 | AI 이미지 생성 (병렬 3~4장) | `images/card-*.png` |
| 4 | HTML 카드뉴스 생성 | `card-news.html` |
| 5 | TTS 나레이션 스크립트 | `05-tts-script.md` |
| 6 | 음성 생성 + 영상 렌더링 | `audio/narration.mp3` + `output.mp4` |

---

## 의존성

| 도구 | 필수 | 용도 |
|------|------|------|
| Python 3 | 필수 | 이미지 생성, TTS 스크립트 실행 |
| `google-genai` | 이미지 생성 시 | `pip install google-genai` |
| `openai` | TTS 시 | `pip install openai` |
| `Pillow` | 이미지 처리 시 | `pip install Pillow` |

---

## 파일 구조

```
content-pipeline/
├── SKILL.md              # 스킬 정의 (파이프라인 워크플로우)
├── .env.example          # API 키 설정 템플릿
├── commands/
│   └── content-pipeline.md  # /content-pipeline 슬래시 커맨드
├── references/
│   └── card-news-guide.md   # 카드뉴스 디자인 가이드
└── scripts/
    ├── generate_image.py    # AI 이미지 생성 (google-genai SDK)
    ├── tts_openai.py        # OpenAI TTS 음성 생성
    └── tts.sh               # edge-tts 래퍼 (폴백용)
```

---

## 라이선스

MIT
