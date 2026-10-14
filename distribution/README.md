# distribution — 스토어 릴리스 노트

릴리즈마다 **여기 내용을 고친 뒤** 태그를 찍는다. 워크플로우가 이 파일들을 그대로
스토어에 올린다. 고치지 않으면 **지난 릴리즈의 노트가 그대로 나간다.**

```
distribution/
├── whatsnew/                     Google Play 용
│   ├── whatsnew-ko-KR            (500자 제한)
│   └── whatsnew-en-US
└── metadata/                     App Store 용
    ├── ko/release_notes.txt      (4000자 제한)
    └── en-US/release_notes.txt
```

## 양식

이전 릴리즈부터 쓰던 형태를 그대로 따른다. 스토어에 연속으로 보이는 글이라 릴리즈마다
모양이 달라지면 안 된다.

```
■ 아시안게임 순위표를 볼 수 있어요!
  - 홈 순위표에서 아시안게임을 고르면 A·B 그룹별 순위와 국가 국기가 보여요.
  - 아직 순위 데이터가 준비되지 않은 리그는 점선으로 표시돼 눌러도 열리지 않아요.

■ 새로 열린 리그 경기도 놓치지 않아요!
  - 아시안게임처럼 새 리그의 경기만 있는 날에도 경기 목록이 비지 않고 제대로 보여요.
```

- 묶음 제목은 `■` 로 시작하고 **느낌표로 끝낸다.** 기능 단위로 묶는다.
- 하위 항목은 두 칸 들여쓴 `- ` 로 쓰고, 그 변경이 사용자에게 무엇을 해 주는지 적는다.
- **"~해요" 체**로 쓴다.
- 여러 커밋이 한 기능이면 묶어서 결과만 쓴다. 색상값·PR 번호는 사용자에게 의미가 없다.

## AI 초안

릴리즈 빌드가 끝나면 워크플로우가 커밋 로그를 읽어 **이 양식으로 초안을 만들어 Discord 에
보낸다.** 초안은 자동으로 커밋되지 않는다 — 보고 판단해서 이 파일들에 반영한다.

사용자가 체감할 변경이 없는 릴리즈(CI·문서·리팩터링만 있는 경우)면 초안 대신 "체감할
변경이 없어 보인다"고 알린다. 없는 기능을 지어내지 않게 한 것이다.

## 왜 같은 내용을 두 벌 쓰나

스토어마다 요구하는 디렉터리 구조와 파일명이 다르다. Play 는
`whatsnew-<locale>`(확장자 없음), App Store 는 `<locale>/release_notes.txt` 다.
로케일 표기도 다르다 — Play 는 `ko-KR`, App Store 는 `ko`.

내용이 같아도 되므로, 한쪽을 쓰고 복사하면 된다.

```bash
cp distribution/whatsnew/whatsnew-ko-KR distribution/metadata/ko/release_notes.txt
cp distribution/whatsnew/whatsnew-en-US distribution/metadata/en-US/release_notes.txt
```

## 어디에 쓰이나

| 파일 | 쓰는 곳 | 시점 |
|---|---|---|
| `whatsnew/*` | `release-deploy.yml` → Play 내부테스트 업로드 | 태그 push |
| `metadata/*/release_notes.txt` | `submit-for-review.yml` → App Store 심사 제출 | 버튼 실행 |

Play 는 업로드할 때 노트가 붙고, production 승격 때는 그 노트가 그대로 따라간다.
App Store 는 심사 제출 시점에 "새로운 기능" 칸으로 들어간다.

## 주의

- **Play 500자 제한**은 워크플로우가 업로드 전에 검사해 넘으면 실패시킨다.
- `metadata/` 에는 **`release_notes.txt` 만 둔다.** `deliver` 는 이 디렉터리에 있는
  파일만 덮어쓰므로, 설명·키워드 파일을 추가하면 App Store Connect 에 있는 값을
  덮어쓰게 된다. 지금은 릴리스 노트만 코드로 관리한다.
- 사용자에게 보이는 글이다. 내부 용어(`BottomActionBar`, 커밋 해시 등)를 쓰지 않는다.
