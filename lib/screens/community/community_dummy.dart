import '../../model/community_comment.dart';
import '../../model/community_poll.dart';
import '../../model/community_post.dart';

// ponytail: 더미 전용 파일. 백엔드 API 가 붙으면 이 파일째 삭제하고
// CommunityRepository 로 갈아끼운다. 팀 목록·색도 여기서만 하드코딩한다
// (실서비스는 온보딩 팀 API 의 로고 URL 을 쓴다).

/// 로그인 여부. false 로 두면 게스트 화면을 확인할 수 있다.
const bool kDummyLoggedIn = true;

/// 내 응원팀 id. null 로 바꾸면 '응원팀 미설정' 회원 화면을 확인할 수 있다.
// 지금 값이 non-null 이라 린트가 붙지만, null 로 바꿔 화면을 확인하는 게 이
// 상수의 용도라 타입을 좁히면 안 된다.
// ignore: unnecessary_nullable_for_final_variable_declarations
const int? kDummyMyTeamId = 39;

/// 전체 게시판 + LCK 10팀.
///
/// `id` 는 **실제 팀 id**(`/auth/onboarding/teams` 응답)를 그대로 쓴다. 그래야
/// 팀 로고·이름을 그 API 에서 받아 정확히 붙일 수 있다. `name`·`color` 는 팀
/// 목록을 아직 못 받았을 때 쓰는 폴백이다.
const List<CommunityBoard> kDummyBoards = [
  CommunityBoard(id: CommunityBoard.allId, name: '전체', color: 0xFF909296),
  CommunityBoard(id: 39, name: 'T1', color: 0xFFE2012D),
  CommunityBoard(id: 23, name: 'Gen.G', color: 0xFFAA8A00),
  CommunityBoard(id: 80, name: '한화생명', color: 0xFFFF6B01),
  CommunityBoard(id: 78, name: 'Dplus KIA', color: 0xFF005AA0),
  CommunityBoard(id: 56, name: 'KT', color: 0xFFFF0A0A),
  CommunityBoard(id: 51, name: 'DRX', color: 0xFF5A8AE6),
  CommunityBoard(id: 53, name: '농심', color: 0xFFAA0000),
  CommunityBoard(id: 1, name: 'BNK', color: 0xFF00B5A3),
  CommunityBoard(id: 32, name: '브리온', color: 0xFF00A84F),
  CommunityBoard(id: 10, name: 'DN', color: 0xFF1E4B9E),
];

/// [id] 에 해당하는 게시판. 없으면 전체 게시판.
CommunityBoard dummyBoard(int id) {
  for (final board in kDummyBoards) {
    if (board.id == id) return board;
  }
  return kDummyBoards.first;
}

/// 팀 게시판만 (전체 제외).
List<CommunityBoard> get kDummyTeamBoards =>
    kDummyBoards.where((b) => !b.isAll).toList();

const List<CommunityPost> kDummyPosts = [
  CommunityPost(
    id: 1,
    boardId: CommunityBoard.allId,
    title: '오늘 밴픽 진짜 이해가 안 되는데 나만 그럼?',
    body:
        '3세트 마지막 픽 순서가 계속 걸린다. 상대 조합 보고도 그 픽이 나올 줄은 몰랐음.\n'
        '다들 어떻게 보셨는지 궁금합니다.',
    authorName: '익명의워딩러',
    authorTeamId: 39,
    timeAgo: '12분 전',
    viewCount: '4,120',
    commentCount: 84,
    likeCount: 121,
  ),
  CommunityPost(
    id: 2,
    boardId: CommunityBoard.allId,
    title: '2R 순위표 정리해봤습니다 (플옵 경우의 수 포함)',
    body:
        '남은 경기 기준으로 각 팀 플레이오프 진출 경우의 수를 정리했습니다.\n'
        '틀린 부분 있으면 댓글로 알려주세요.',
    authorName: '겐지장인',
    authorTeamId: 23,
    timeAgo: '38분 전',
    viewCount: '2,860',
    commentCount: 27,
    likeCount: 64,
    // 더미라 로컬 에셋을 쓴다. 실서비스에서는 업로드된 URL 이 들어온다.
    images: ['assets/images/baron.png', 'assets/images/herald.png'],
  ),
  CommunityPost(
    id: 3,
    boardId: CommunityBoard.allId,
    title: '서머 관전 포인트 정리 — 정글 메타 바뀐 거 체감됨',
    body: '패치 이후로 초반 오브젝트 타이밍이 확실히 당겨졌습니다.',
    authorName: '담원사랑',
    authorTeamId: 78,
    timeAgo: '1시간 전',
    viewCount: '1,540',
    commentCount: 12,
    likeCount: 30,
  ),
  CommunityPost(
    id: 4,
    boardId: CommunityBoard.allId,
    title: '워딩 앱 알림 설정 어디서 바꾸나요?',
    body: '경기 시작 알림만 받고 싶은데 설정을 못 찾겠어요.',
    authorName: '뉴비',
    authorTeamId: null,
    timeAgo: '2시간 전',
    viewCount: '410',
    commentCount: 5,
    likeCount: 2,
  ),
  CommunityPost(
    id: 5,
    boardId: CommunityBoard.allId,
    title: '제우스 폼 올라온 듯. 지난 3경기 지표 봤는데',
    body: '라인전 지표가 확실히 회복됐습니다. 딜량도 같이 올라왔고요.',
    authorName: '불사대마',
    authorTeamId: 80,
    timeAgo: '3시간 전',
    viewCount: '3,270',
    commentCount: 41,
    likeCount: 88,
    images: ['assets/images/elder-dragon.png'],
  ),
  CommunityPost(
    id: 11,
    boardId: 39,
    title: '오늘 경기 후기 — 3세트 한타가 다 했다',
    body: '바론 앞 한타 한 번으로 경기가 끝났습니다. 진입 각이 완벽했음.',
    authorName: '페이커숭배',
    authorTeamId: 39,
    timeAgo: '5분 전',
    viewCount: '5,940',
    commentCount: 132,
    likeCount: 240,
  ),
  CommunityPost(
    id: 12,
    boardId: 39,
    title: '내일 직관 가시는 분 계신가요? 굿즈 같이 사요',
    body: '롤파크 근처에서 만나서 같이 줄 서실 분 구합니다.',
    authorName: '롤파크주민',
    authorTeamId: 39,
    timeAgo: '22분 전',
    viewCount: '880',
    commentCount: 18,
    likeCount: 9,
  ),
  CommunityPost(
    id: 13,
    boardId: 39,
    title: '탑 라인전 지표만 놓고 보면 아직 상위권이긴 함',
    body: '15분 CS 차이와 골드 차이 모두 리그 상위권입니다.',
    authorName: '데이터충',
    authorTeamId: 39,
    timeAgo: '1시간 전',
    viewCount: '2,110',
    commentCount: 46,
    likeCount: 71,
    images: [
      'assets/images/turret.png',
      'assets/images/nexus.png',
      'assets/images/inhibitor.png',
    ],
    poll: CommunityPoll(
      question: '3세트 패배 원인은?',
      options: [
        CommunityPollOption(label: '밴픽', votes: 796),
        CommunityPollOption(label: '정글 동선', votes: 398),
        CommunityPollOption(label: '그냥 상대가 잘함', votes: 90),
      ],
    ),
  ),
  CommunityPost(
    id: 21,
    boardId: 23,
    title: '미드 차이로 이긴 경기. 라인전 20분 골드 보소',
    body:
        '20분 골드 +3.2k 중에 미드에서만 1.9k 났습니다. 초반 정글 동선이 미드 '
        '위주로 짜인 것도 있지만, 라인전 CS 격차가 그대로 유지된 게 컸음.\n\n'
        '2세트도 비슷한 그림 나오면 그냥 밴을 해야 할 듯.',
    authorName: '겐지장인',
    authorTeamId: 23,
    timeAgo: '9분 전',
    viewCount: '2,410',
    commentCount: 95,
    likeCount: 188,
  ),
  CommunityPost(
    id: 22,
    boardId: 23,
    title: '플옵 대진 어디가 제일 편할까요',
    body: '상대 전적만 보면 답이 나오는데 최근 폼을 보면 또 다르네요.',
    authorName: '황금독수리',
    authorTeamId: 23,
    timeAgo: '44분 전',
    viewCount: '1,020',
    commentCount: 33,
    likeCount: 21,
    // 결과를 바로 공개하는 투표. 투표 전에도 막대가 보인다.
    poll: CommunityPoll(
      question: '4강에서 만나고 싶은 팀은?',
      options: [
        CommunityPollOption(label: 'T1', votes: 214),
        CommunityPollOption(label: '한화생명', votes: 331),
        CommunityPollOption(label: 'Dplus KIA', votes: 155),
      ],
      hideResultsUntilVoted: false,
    ),
  ),
  CommunityPost(
    id: 23,
    boardId: 23,
    title: '오늘 인터뷰 번역 정리해왔습니다',
    body: '경기 후 인터뷰 전문 번역입니다. 의역이 조금 있습니다.',
    authorName: '번역봇',
    authorTeamId: 23,
    timeAgo: '2시간 전',
    viewCount: '1,780',
    commentCount: 14,
    likeCount: 52,
  ),
];

/// [boardId] 게시판의 글 목록.
List<CommunityPost> dummyPosts(int boardId) =>
    kDummyPosts.where((p) => p.boardId == boardId).toList();

/// 글 상세용 댓글. 어느 글이든 같은 더미를 쓴다.
const List<CommunityComment> kDummyComments = [
  CommunityComment(
    id: 1,
    parentId: null,
    authorName: '황금독수리',
    authorTeamId: 23,
    body: '이거 진짜 체감됐음. 갱 안 와도 알아서 벌림',
    timeAgo: '9분 전',
    likeCount: 24,
  ),
  CommunityComment(
    id: 2,
    parentId: 1,
    authorName: '번역봇',
    authorTeamId: 23,
    body: '인터뷰에서도 본인이 라인전 자신 있었다고 했어요',
    timeAgo: '7분 전',
    likeCount: 11,
  ),
  CommunityComment(
    id: 3,
    parentId: 1,
    authorName: '겐지장인',
    authorTeamId: 23,
    mention: '@번역봇',
    body: '그 인터뷰 링크 좀요',
    timeAgo: '4분 전',
    likeCount: 2,
  ),
  CommunityComment(
    id: 4,
    parentId: null,
    authorName: '익명의워딩러',
    authorTeamId: 23,
    body: '정글 동선 자체가 미드 우선이라 지표는 좀 걸러 봐야',
    timeAgo: '2분 전',
    likeCount: 8,
  ),
];
