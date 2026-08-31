---
name: content-pipeline
description: "콘텐츠 파이프라인을 실행합니다."
---

# /content-pipeline Command

인수(argument)를 파싱해서 동작을 결정합니다:

| 인수 패턴 | 동작 |
|-----------|------|
| (인수 없음) | 주제를 물어본 뒤 파이프라인 실행 |
| [주제] | 해당 주제로 바로 파이프라인 실행 |

---

## 실행

이 커맨드가 호출되면 `skills/content-pipeline/SKILL.md`를 읽고 워크플로우를 따라 실행합니다.

1. Read `skills/content-pipeline/SKILL.md`
2. 인수가 있으면 해당 주제로 Step 0부터 시작
3. 인수가 없으면 AskUserQuestion으로 주제를 물어본 뒤 시작

예시:
- `/content-pipeline 벚꽃 명소 카드뉴스` → "벚꽃 명소" 주제로 바로 실행
- `/content-pipeline` → "어떤 주제로 콘텐츠를 만들까요?" 질문 후 실행
