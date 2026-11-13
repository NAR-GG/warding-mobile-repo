/// 홈·선수 화면의 목업 데이터 소스를 켜는 빌드 플래그.
///
/// 백엔드가 아직 없는 섹션(솔랭·평점·뉴스)을 디버그·시뮬레이터에서 보기 위한
/// 것이다. 릴리즈 빌드에는 빈 소스가 나가고, 릴리즈에서 목업을 보려면
/// `--dart-define=HOME_MOCKS=true` 를 준다.
///
/// `core/config` 에 있는 이유는 홈 전용이 아니라서다 — `player_repository` 도
/// 같은 플래그로 목업을 가른다.
const bool kHomeMocks = bool.fromEnvironment('HOME_MOCKS');
