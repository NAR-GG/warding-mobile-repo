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
