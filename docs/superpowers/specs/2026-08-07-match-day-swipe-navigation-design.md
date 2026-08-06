# 경기 일정 날짜별 화면 스와이프 이동 설계

## 배경

경기 일정 캘린더(`ScheduleScreen`)에서 날짜를 탭하면 그 날의 경기 리스트를 보여주는 `MatchDayScreen`이 열린다. 지금은 그 날짜 하나만 보여주고 끝이라, 옆 날짜 경기를 보려면 뒤로 가서 캘린더에서 다른 날짜를 다시 탭해야 한다. 이 화면에서 좌우로 스와이프하면 전날/다음날 경기 리스트로 바로 넘어가도록 만든다.

저장소 전체에 `PageView` 사용 사례가 없고(`grep -rn "PageView" ./lib` 결과 없음), 유일한 유사 제스처는 `ScheduleCalendar`의 `onHorizontalDragEnd`(월 이동용, 애니메이션 없이 즉시 전환)뿐이다. 이번 기능은 실제 슬라이드 애니메이션이 있는 스와이프를 새로 도입한다.

## 범위

- **대상**: `MatchDayScreen`(캘린더에서 날짜 탭 시 여는 '그 날의 경기 리스트' 화면)만.
- **대상 아님**: `MatchDetailScreen`(개별 경기 상세: 챔피언픽/라이브이벤트/선수평점 탭), `ScheduleCalendar`의 월 스와이프, `match_list_screen.dart`(경기리스트 탭). 전부 현재 상태 유지.
- 스와이프 이동 범위는 상/하한 없음 — `ScheduleViewModel.shiftMonth`가 상/하한 없이 무제한 이동을 허용하는 것과 동일한 정책.

## 아키텍처

### 신규 ViewModel: `MatchDayPagerViewModel`

`lib/viewmodel/match_day/match_day_pager_viewmodel.dart`, `ChangeNotifier` 상속. 스와이프 윈도우(전날/오늘/다음날) 관리를 View가 아니라 ViewModel에 둔다.

- 생성자: `{required DateTime initialDate, List<String> leagues = const ['LCK'], List<int>? teamIds, ScheduleRepository? repository}`. 생성 시 `initialDate-1`, `initialDate`, `initialDate+1` 세 날짜로 `MatchDayViewModel`을 즉시 생성해 **양옆 날짜를 프리페치**한다.
- `dates: List<DateTime>` — 길이 3, 항상 `[중심-1, 중심, 중심+1]` 순서.
- `pages: List<MatchDayViewModel>` — 길이 3, `dates`와 인덱스 대응. 각 `MatchDayViewModel`은 생성자에서 알아서 `load()`를 호출한다(기존 동작 그대로).
- `spoilerPreventionEnabled: bool` / `setSpoilerPreventionEnabled(bool value)` — 스포일러 방지 토글 상태를 여기로 끌어올려 3개 페이지가 공유한다.
  - 기존 `MatchDayViewModel.spoilerPreventionEnabled`는 인스턴스별 로컬 상태라, 페이지 3개가 각자 다른 값을 가지면 스와이프할 때마다 블러 여부가 깜빡인다.
  - `setSpoilerPreventionEnabled`는 현재 살아있는 `pages` 3개 전부에 `setSpoilerPreventionEnabled`를 호출해 값을 맞추고, 이후 새로 생성되는 `MatchDayViewModel`에도 이 값을 초기값으로 반영한다.
- `void shift(int direction)` (`direction`은 `1`(다음 날짜 방향) 또는 `-1`(이전 날짜 방향)):
  - 반대쪽 끝 `MatchDayViewModel`을 `dispose()`.
  - 새 끝 날짜(`direction == 1`이면 `dates.last + 1`, `direction == -1`이면 `dates.first - 1`)로 `MatchDayViewModel`을 새로 생성(현재 `spoilerPreventionEnabled` 값을 초기값으로 반영).
  - `dates`/`pages`를 한 칸 밀어 갱신, `notifyListeners()`.
- `dispose()`: 살아있는 `pages` 3개 전부 `dispose()`.

### View 변경

- 기존 `MatchDayScreen._buildBody`(날짜 헤더 + 카드 리스트 + 로딩 스켈레톤 + 빈 상태)를 `MatchDayView` 위젯(`lib/screens/match_day/component/match_day_view.dart`)으로 추출한다. `MatchDayViewModel viewModel`, `DateTime date`, `bool spoilerPreventionEnabled`, `double scale`를 받아 렌더링만 담당(로직 없음). 스와이프 페이지 3개가 이 위젯을 재사용한다.
- `MatchDayScreen`은 `NarDetailHeader`(제목 "일정" + 스포일러 토글)는 그대로 화면 상단에 고정해 스와이프 영역 밖에 둔다. 그 아래 `Expanded` 내부를 `PageView.builder(controller: _pageController, itemCount: 3, itemBuilder: ...)`로 교체한다. 각 아이템은 `pager.dates[i]`/`pager.pages[i]`로 `MatchDayView`를 렌더링.
- `_pageController = PageController(initialPage: 1)`은 State가 소유(애니메이션 제어는 View 책임).
- `onPageChanged(int index)`:
  - `index == 1`이면 아무 것도 하지 않는다(가운데로 프로그램적으로 복귀했을 때 재호출되는 경우).
  - `index == 0` 또는 `index == 2`면 `pager.shift(index == 2 ? 1 : -1)` 호출 후, 프레임이 끝난 뒤(`WidgetsBinding.instance.addPostFrameCallback`) `_pageController.jumpToPage(1)`로 애니메이션 없이 가운데로 복귀시킨다. (전형적인 "3페이지 롤링 윈도우" 무한 스와이프 패턴.)
- 스포일러 토글 `onChanged`는 `pager.setSpoilerPreventionEnabled`를 호출하도록 변경(기존엔 `_viewModel.setSpoilerPreventionEnabled`).

## 데이터 흐름

- `leagues`/`teamIds`는 캘린더에서 넘어온 필터 그대로 세 날짜 모두에 고정 적용된다(스와이프 중 바뀌지 않음).
- 화면 최초 진입 시 세 날짜(전날/오늘/다음날)가 동시에 `fetchMatchesByDate`로 조회된다. 스와이프해도 이미 로드가 끝난 상태라 로딩 없이 바로 보인다.
- 윈도우가 한 칸 이동하면 새로 노출되는 끝 날짜 하나만 새로 API를 호출하고(반대쪽 끝은 dispose), 현재 보고 있는 가운데 페이지는 항상 이미 로드된 상태를 유지한다.
- 경기가 없는 날은 기존과 동일하게 "경기 없음" 빈 상태가 표시된다.

## 에러 처리

- 페이지별 에러는 기존과 동일하게 그 페이지의 `MatchDayViewModel.error`로 개별 표시된다(재시도 UI는 기존에도 없었고 이번 스코프에도 추가하지 않는다).
- 한 페이지의 조회 실패가 다른(옆) 페이지 스와이프에 영향을 주지 않는다 — 각 날짜가 독립된 `MatchDayViewModel` 인스턴스이기 때문.

## 테스트 계획

- `test/viewmodel/match_day/match_day_pager_viewmodel_test.dart`(신규, 순수 Dart 단위 테스트, `test/viewmodel/schedule/filter_viewmodel_test.dart`와 동일한 패턴):
  - 초기 생성 시 `dates`/`pages`가 `[초기일-1, 초기일, 초기일+1]`로 채워지는지.
  - `shift(1)`/`shift(-1)` 후 윈도우가 올바르게 한 칸씩 밀리는지, 반대쪽 끝 `MatchDayViewModel`이 dispose 되는지.
  - `setSpoilerPreventionEnabled` 호출이 현재 살아있는 3개 `MatchDayViewModel`에 모두 전파되는지, 이후 `shift`로 새로 생기는 `MatchDayViewModel`에도 그 값이 유지되는지.
- 위젯 레벨(`PageView` 실제 스와이프 제스처)은 이 프로젝트에 화면 위젯 테스트 관례가 없어(기존에도 `match_day_screen_test.dart` 없음) 스코프 밖으로 두고, 시뮬레이터에서 실제 스와이프 동작(전날/다음날 전환, 스포일러 토글 유지, 뒤로가기)을 육안으로 확인한다.
