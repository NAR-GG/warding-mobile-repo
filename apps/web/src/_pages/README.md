# `_pages/` — 화면 조립 (FSD pages 레이어)

[FSD 공식 Next.js 가이드](https://feature-sliced.design/docs/guides/tech/with-nextjs)가
권하는 구조를 그대로 따른다.

```
app/                      Next 라우트. 화면을 re-export 만 한다
src/
├── _pages/{화면}/
│   ├── index.ts          공개 API
│   └── ui/               화면 컴포넌트
├── shared/               웹 전용 공용 코드 (브리지 등)
└── (widgets · features · entities 는 필요할 때)
packages/ui               여러 화면이 쓰는 공용 컴포넌트
packages/api              서버 호출 + 도메인 타입 + 매퍼
```

## 왜 `_pages` 인가 (밑줄이 붙는 이유)

Next 는 `app/` 과 `pages/` 를 라우터 디렉터리로 쓴다. FSD 레이어 이름과 충돌하므로
공식 문서가 경고 박스로 못박는다 — **"쓰는 라우터와 무관하게 `app`·`pages` FSD
레이어를 둘 다 `_app`·`_pages` 로 바꿔라."** 공식 린터(Steiger)도 이 이름을 인식한다.

**`views`·`screens` 로 바꾸면 안 된다.** Steiger 는 커스텀 레이어명을 지원하지
않는다 — 접두사만 붙은 `_pages` 는 공식이 호환을 보장하지만 다른 이름은 레이어
인식에서 벗어난다. (실사용 레포 중 `views` 를 쓰는 사례가 있으나 공식 근거가 없다.)

**루트에 빈 `pages/` 를 두는 구 방식은 폐기됐다.** 2026-06 이전 공식 문서는
`src/pages` 를 유지하고 루트에 빈 `pages/` 를 두라고 했는데, 그 방식이 Next 16 에서
빌드를 깨고 `next/navigation` 훅 시그니처를 조용히 바꾸는 문제가 있어 공식이
접두사 방식으로 교체했다.

실측으로 확인한 충돌 3가지 — 전부 빌드가 깨진다.

| 시도 | 결과 |
|---|---|
| 루트에 `pages/` | Next 가 라우트로 인식 → `pages/x/index.ts` 를 `/x` 페이지로 보고 "default export 없음" |
| 라우트를 `src/app` 으로 이동 | Next 15 가 타입 검증기 상대경로를 잘못 생성 (`Cannot find module '../../app/.../page.js'`) |
| `pageExtensions` 로 좁히기 | App Router 라우트가 전부 소멸 — 404 만 남는다 |

`app/` 을 **루트에 남기고** FSD 레이어만 `src/` 로 내리면 셋 다 피한다. 공식 트리가
그렇게 되어 있는 이유다.

## 라우트는 re-export 한 줄

```tsx
// app/community/post/[id]/page.tsx
export { CommunityPostPage as default } from '@/_pages/community-post';
```

조립 로직을 라우트에 두면 `app/` 이 다시 두꺼워진다. 화면은 `_pages` 가 갖고
라우트는 경로 ↔ 화면 연결만 한다.

## 세그먼트는 목적별로 나눈다

`ui`·`model`·`api`·`lib`·`config` 처럼 **무엇을 위한 코드인지**로 가른다.
`components`·`hooks`·`providers` 같은 **종류별** 이름은 쓰지 않는다 — 한 기능의
코드가 종류별로 흩어져 결국 "그 외 전부" 폴더가 생긴다.

`_app` 은 예외가 하나 있다: **`ui` 세그먼트를 두지 않는다.** 린터
(`fsd/no-ui-in-app`)가 잡는다. 대신 `layout`·`styles`·`config` 처럼 역할로 쓴다.

```
src/_app/
├── config/metadata.ts     metadata · viewport
├── layout/RootLayout.tsx  루트 레이아웃
└── styles/globals.css     전역 CSS
```

## 서버 전용 코드는 `index.server.ts` 로 가른다

한 슬라이스에 클라이언트·서버 모듈이 섞인 채 `index.ts` 하나로 내보내면,
**클라이언트 컴포넌트가 그 슬라이스를 import 하는 순간** 서버 전용
사이드이펙트가 클라이언트 모듈 그래프로 번져 빌드가 깨진다.

`packages/api` 가 그렇게 갈라져 있다.

| 경로 | 내용 |
|---|---|
| `warding-api` | 타입 · 매퍼 · 순수 함수 (클라이언트 OK) |
| `warding-api/server` | `fetch*` · `getJson` (`import 'server-only'`) |

실수하면 **빌드가 깨진다** — 클라이언트 컴포넌트에서 `warding-api/server` 를
당겨 보고 확인했다. 타입이 아니라 번들러가 막는다.

## `export *` 를 쓰지 않는다

무엇이 공개되는지 `index.ts` 만 보고 알 수 있어야 하고, 내부 구현이 늘 때
조용히 새지 않는다. 내부 `lib/` 은 기본 비공개다.

## 레이어를 다 만들지 않는다

- **`entities` 를 두지 않는다.** 서버 응답을 아는 코드는 `packages/api` 한 곳에
  모은다 — 타입(`types.ts`)과 매퍼(`mappers.ts`)가 붙어 있어야 서버 형식이 바뀔 때
  한 군데만 고친다. 나누면 같은 변경이 두 곳으로 번진다.
- **`features`·`widgets` 는 필요해질 때.** 좋아요·스크랩처럼 사용자 행동과 상태가
  생기면 `features/`, 화면 2개가 같은 블록을 쓰면 `widgets/` 다. 지금은 읽기 전용
  화면뿐이라 만들지 않는다 — 빈 폴더는 구조가 아니라 소음이다.
- **`packages/ui` 로 올리는 기준은 화면 2개 이상.** Flutter 의 "한 기능 전용 위젯은
  `core/ui` 에 두지 않는다" 와 같은 규칙이다.
