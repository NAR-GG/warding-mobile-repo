---
type: Concept
title: 공용 컴포넌트
description: lib/components/ 의 앱 전역 공용 위젯 — 칩·버튼·카드·섹션 제목. 화면마다 같은 모양을 다시 만들지 않는다.
tags: [design, components, ui]
timestamp: 2026-10-26T00:00:00Z
---

# 원칙

화면에 같은 모양이 두 번째로 필요해지면, 그 화면 폴더에 복사하지 말고 `lib/components/` 로
올려서 둘 다 그걸 쓴다. 색은 [색상 토큰](color-tokens.md), 수치는
[UI 스케일](ui-scaling.md) 규칙을 따른다(모든 공용 위젯이 `scale` 파라미터를 받는다).

변형이 필요하면 **새 위젯을 만들지 말고 기존 위젯에 variant/size 를 더한다.** 한 곳에서만
쓰는 모양(예: 선수 페이지 한줄평의 33×21 평점 배지)은 올리지 않고 그 화면에 둔다 — 호출부가
하나뿐인 공용 컴포넌트는 재사용이 아니라 겉도는 층이다.

# 주요 공용 위젯

| 위젯 | 파일 | 쓰임 |
|------|------|------|
| `NarChip` / `NarChipMultiSelect` | `nar_chip.dart`, `nar_chip_multi_select.dart` | 선택 칩과 가로 스크롤 칩 줄. `.single` 은 탭처럼 하나만 고른다 |
| `SubscribeBell` | `subscribe_bell.dart` | 선수 구독 벨(원형 36, 구독 중이면 보라 체크) |
| `NarStatBox` / `NarStatRow` | `nar_stat_box.dart` | 작은 라벨 + 큰 값 지표 상자, 같은 폭으로 나란히 |
| `NarProgressBar` | `nar_progress_bar.dart` | 둥근 비율 막대(승률·분포) |
| `WinLossText` | `win_loss_text.dart` | "5승 2패" — 승만 빨강, 0판이면 "—" |
| `RatingDistributionSection` | `screens/player_rating/component/` | 평균·별점·점수별 분포. 선수 평점 상세와 선수 페이지 팬 평점이 공유 |
| `NarButton` | `nar_button.dart` | 디자인 토큰 버튼(type1·type2·set1·구독) |
| `NarMoreButton` | `nar_more_button.dart` | "전체 N개 보기"·"더 보기" 줄. `.inCard` 는 카드 마지막 줄 |
| `NarCard` | `nar_card.dart` | narBgTertiary + narLine + radius 12 카드 틀. `.list` 는 행 사이 구분선 |
| `NarSectionTitle` | `nar_section_title.dart` | 굵은 제목 + 회색 부제 + 우측 "전체 보기" 링크 |
| `NarTabBar` | `nar_tab_bar.dart` | 페이지 상단 탭(page) / 섹션 내부 콤팩트 탭(compact) |
| `NarSelectDropdownField` | `nar_select_dropdown_field.dart` | 셀렉트 박스 + 펼침 체크박스 드롭다운. 경기 일정 필터와 경기 리스트 필터가 공유한다. `LabeledField` 로 감싸 쓴다 |
| `NarDetailHeader` | `nar_detail_header.dart` | 상세 화면 상단 바(뒤로·제목·trailing) |
| `NarBadge` 외 | `nar_badge.dart` | 시간·진영(BLUE/RED)·LIVE 배지 |

# 아직 안 모은 것

같은 모양이 여러 화면에 흩어져 있지만 아직 공용으로 안 올린 것들 — 손댈 일이 생기면 함께 정리한다.

- 홈 `HomeSectionHeader`(`screens/home/component/home_section_header.dart`)는 `NarSectionTitle`
  과 같은 구성이다. 홈 5개 호출부를 옮기면 지울 수 있다.
- 홈 `HomeListBox` 와 순위표·뉴스·월즈 선수 시트의 인라인 카드 장식은 `NarCard` 로 대체 가능하다.
- 홈 순위표의 "전체 보기"·"접기" 줄 2곳은 `NarMoreButton.inCard` 와 같은 모양이다.
- 내 선수 월즈 줄의 `_BellButton`·홈 월즈 솔랭 벨은 `SubscribeBell` 로 모을 수 있다(상수가 조금씩 어긋나 있다).
- 내 선수 월즈 시트의 `_TodayStats`/`_StatBox` 는 `NarStatBox` 로 대체 가능하다.
- "N승 M패" 표기가 화면마다 다르다(`worlds_player_sheet`·`home_standings_section`·`player_next_match_card`). `WinLossText` 로 통일할 수 있다.
- `screens/community/component/team_chip_rail.dart` 의 `_Chip` 은 `NarChip(leading:)` 로 대체 가능하다.

# 관련

- [색상 토큰](color-tokens.md), [UI 스케일](ui-scaling.md)
- [파일 생성 규칙](/architecture/file-conventions.md)
- [선수 페이지](/features/player-page.md)
