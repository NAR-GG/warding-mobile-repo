/// 커뮤니티 글쓰기 임시저장 한 건.
///
/// 블록 본문은 [DraftBlock.encodeList] 로 이미 인코딩된 JSON 문자열([blocksJson])로
/// 든다 — 서버 전송용 [CommunityPostBlock]과 달리 로컬 사진 경로(localPath)까지
/// 보존해야 해서 이 모델은 그 형식을 몰라도 되게 문자열째로 다룬다.
class CommunityDraft {
  const CommunityDraft({
    this.id,
    required this.boardTeamId,
    this.editPostId,
    required this.title,
    required this.blocksJson,
    this.existingImageUrls = const [],
    required this.savedAt,
    this.pollEnabled = false,
    this.pollQuestion = '',
    this.pollOptions = const [],
    this.pollAllowMultiple = false,
    this.pollAlwaysShowResults = false,
  });

  /// 로컬 저장소 내 식별자. 아직 저장 전(새 드래프트)이면 null.
  final int? id;

  final int? boardTeamId;

  /// 글 수정 중 저장한 드래프트면 대상 글 id, 새 글 드래프트면 null.
  final int? editPostId;

  final String title;

  final String blocksJson;

  /// 수정 모드 드래프트에서 남아 있던 기존 첨부 사진 URL.
  final List<String> existingImageUrls;

  final DateTime savedAt;

  /// 투표 컴포저 상태(작성 시에만 붙는 v1 — 마감 시각은 UI 미노출이라 안 든다).
  final bool pollEnabled;
  final String pollQuestion;
  final List<String> pollOptions;
  final bool pollAllowMultiple;
  final bool pollAlwaysShowResults;

  CommunityDraft copyWith({int? id}) => CommunityDraft(
    id: id ?? this.id,
    boardTeamId: boardTeamId,
    editPostId: editPostId,
    title: title,
    blocksJson: blocksJson,
    existingImageUrls: existingImageUrls,
    savedAt: savedAt,
    pollEnabled: pollEnabled,
    pollQuestion: pollQuestion,
    pollOptions: pollOptions,
    pollAllowMultiple: pollAllowMultiple,
    pollAlwaysShowResults: pollAlwaysShowResults,
  );

  factory CommunityDraft.fromJson(Map<String, dynamic> json) => CommunityDraft(
    id: json['id'] as int?,
    boardTeamId: json['boardTeamId'] as int?,
    editPostId: json['editPostId'] as int?,
    title: json['title'] as String? ?? '',
    blocksJson: json['blocksJson'] as String? ?? '[]',
    existingImageUrls: [
      for (final u in (json['existingImageUrls'] as List? ?? const []))
        u as String,
    ],
    savedAt:
        DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
    pollEnabled: json['pollEnabled'] as bool? ?? false,
    pollQuestion: json['pollQuestion'] as String? ?? '',
    pollOptions: [
      for (final o in (json['pollOptions'] as List? ?? const [])) o as String,
    ],
    pollAllowMultiple: json['pollAllowMultiple'] as bool? ?? false,
    pollAlwaysShowResults: json['pollAlwaysShowResults'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'boardTeamId': boardTeamId,
    'editPostId': editPostId,
    'title': title,
    'blocksJson': blocksJson,
    'existingImageUrls': existingImageUrls,
    'savedAt': savedAt.toIso8601String(),
    'pollEnabled': pollEnabled,
    'pollQuestion': pollQuestion,
    'pollOptions': pollOptions,
    'pollAllowMultiple': pollAllowMultiple,
    'pollAlwaysShowResults': pollAlwaysShowResults,
  };
}
