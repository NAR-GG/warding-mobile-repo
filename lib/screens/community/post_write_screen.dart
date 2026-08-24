import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../components/nar_detail_header.dart';
import '../../l10n/app_localizations.dart';
import '../../model/community_post.dart';
import '../../styles/app_colors.dart';
import 'community_dummy.dart';
import 'community_permission.dart';
import 'community_rules.dart';
import 'community_teams.dart';
import 'component/community_rules_sheet.dart';

/// 글쓰기 — 제목 · 본문 · 사진 · 투표.
///
/// 게시판 선택 UI 는 두지 않는다. 글쓰기는 전체 게시판이나 내 응원팀 게시판에서
/// 들어오는데, 그 두 곳이 애초에 쓸 수 있는 전부라 고를 게 없다. 어디에 쓰는지는
/// 헤더에 게시판 이름으로 보여준다.
///
/// 본문 아래에는 커뮤니티 이용규칙 요약이 연하게 깔린다. 글을 쓰기 직전이
/// 규칙을 읽을 유일한 순간이라, 별도 화면으로 빼면 아무도 안 본다.
class PostWriteScreen extends StatefulWidget {
  const PostWriteScreen({super.key, required this.initialBoardId});

  final int initialBoardId;

  @override
  State<PostWriteScreen> createState() => _PostWriteScreenState();
}

class _PostWriteScreenState extends State<PostWriteScreen> {
  static const int _maxPhotos = 5;

  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  late int _boardId = widget.initialBoardId;

  final List<String> _photos = [];

  /// 투표. null 이면 투표를 붙이지 않은 상태다.
  _PollDraft? _poll;

  @override
  void initState() {
    super.initState();
    // 화면이 열린 게시판에 쓸 권한이 없으면 전체 게시판으로 떨어뜨린다.
    if (!_can(_boardId)) _boardId = CommunityBoard.allId;
    _title.addListener(_onChanged);
    _body.addListener(_onChanged);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _poll?.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool _can(int boardId) => canWriteToBoard(
    loggedIn: kDummyLoggedIn,
    myTeamId: kDummyMyTeamId,
    boardId: boardId,
  );

  bool get _submittable =>
      _title.text.trim().isNotEmpty &&
      _body.text.trim().isNotEmpty &&
      (_poll?.valid ?? true);

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) return;
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 85,
        limit: remaining,
      );
      if (picked.isEmpty || !mounted) return;
      setState(() {
        _photos.addAll(picked.take(remaining).map((x) => x.path));
      });
    } on Exception catch (e) {
      // 취소는 빈 목록으로 오므로 여기 오는 건 진짜 실패뿐이다.
      debugPrint('[Community] 사진 선택 실패: $e');
    }
  }

  void _togglePoll() {
    setState(() {
      if (_poll == null) {
        _poll = _PollDraft()..addListener(_onChanged);
      } else {
        _poll!.dispose();
        _poll = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    final board = _boardId == CommunityBoard.allId
        ? l.communityBoardAll
        : l.communityBoardTeam(boardDisplayName(dummyBoard(_boardId)));
    final poll = _poll;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              NarDetailHeader(
                title: board,
                scale: scale,
                trailing: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _submittable
                      ? () => Navigator.of(context).pop()
                      : null,
                  // NarDetailHeader 의 슬롯 높이가 34*scale 이라 세로 패딩을 주면
                  // 글자가 위아래로 잘린다. 좌우로만 넓혀 탭 영역을 확보한다.
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                    child: Text(
                      l.communityWriteSubmit,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        fontSize: 14 * scale,
                        height: 1.45,
                        color: _submittable
                            ? AppColors.narViolet3
                            : AppColors.narDark300,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    20 * scale,
                    10 * scale,
                    20 * scale,
                    20 * scale,
                  ),
                  children: [
                    TextField(
                      controller: _title,
                      style: _inputStyle(scale, 16, weight: FontWeight.w700),
                      cursorColor: AppColors.narViolet3,
                      decoration: _underlined(
                        l.communityWriteTitleHint,
                        scale,
                        16,
                        weight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 14 * scale),
                    TextField(
                      controller: _body,
                      minLines: 6,
                      maxLines: null,
                      style: _inputStyle(scale, 14),
                      cursorColor: AppColors.narViolet3,
                      decoration: InputDecoration(
                        hintText: l.communityWriteBodyHint,
                        hintStyle: _inputStyle(
                          scale,
                          14,
                        ).copyWith(color: AppColors.narDark300),
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (_photos.isNotEmpty) ...[
                      SizedBox(height: 14 * scale),
                      _photoStrip(scale),
                    ],
                    if (poll != null) ...[
                      SizedBox(height: 16 * scale),
                      _PollEditor(
                        draft: poll,
                        scale: scale,
                        onRemove: _togglePoll,
                      ),
                    ],
                    SizedBox(height: 24 * scale),
                    _rules(l, scale),
                  ],
                ),
              ),
              _toolbar(l, scale),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoStrip(double scale) {
    return SizedBox(
      height: 72 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _photos.length,
        separatorBuilder: (_, _) => SizedBox(width: 8 * scale),
        itemBuilder: (context, i) => Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8 * scale),
              child: Image.file(
                File(_photos[i]),
                width: 72 * scale,
                height: 72 * scale,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 72 * scale,
                  height: 72 * scale,
                  color: AppColors.narDark500,
                ),
              ),
            ),
            Positioned(
              top: -6 * scale,
              right: -6 * scale,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _photos.removeAt(i)),
                child: Container(
                  width: 22 * scale,
                  height: 22 * scale,
                  decoration: const BoxDecoration(
                    color: AppColors.narDark400,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 13 * scale,
                    color: AppColors.narText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 규칙 요약 + 전문 보기. 본문 아래에 연하게 깔아 방해하지 않되, 스크롤하면
  /// 반드시 지나가도록 둔다.
  Widget _rules(AppLocalizations l, double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showCommunityRulesSheet(context),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 9 * scale,
            ),
            decoration: BoxDecoration(
              color: AppColors.narDark600,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.communityRulesSeeAll,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 12 * scale,
                    height: 1.45,
                    color: AppColors.narText3,
                  ),
                ),
                SizedBox(width: 4 * scale),
                Icon(
                  Icons.chevron_right,
                  size: 15 * scale,
                  color: AppColors.narText3,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12 * scale),
        Text(
          kCommunityRulesSummary.trim(),
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 12 * scale,
            height: 1.7,
            color: AppColors.narDark300,
          ),
        ),
      ],
    );
  }

  Widget _toolbar(AppLocalizations l, double scale) {
    final full = _photos.length >= _maxPhotos;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 10 * scale,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.narLine, width: 1)),
      ),
      child: Row(
        children: [
          _ToolButton(
            asset: 'assets/icons/photo-edit.svg',
            label: _photos.isEmpty
                ? l.communityAttachPhoto
                : l.communityPhotoCount(_photos.length),
            active: _photos.isNotEmpty,
            scale: scale,
            onTap: full ? null : _pickPhotos,
          ),
          SizedBox(width: 8 * scale),
          _ToolButton(
            asset: 'assets/icons/check.svg',
            label: l.communityAttachPoll,
            active: _poll != null,
            scale: scale,
            onTap: _togglePoll,
          ),
        ],
      ),
    );
  }

  TextStyle _inputStyle(
    double scale,
    double size, {
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: 'Pretendard',
    fontWeight: weight,
    fontSize: size * scale,
    height: 1.55,
    color: AppColors.narText,
  );

  InputDecoration _underlined(
    String hint,
    double scale,
    double size, {
    FontWeight weight = FontWeight.w400,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: _inputStyle(
      scale,
      size,
      weight: weight,
    ).copyWith(color: AppColors.narDark300),
    isDense: true,
    contentPadding: EdgeInsets.symmetric(vertical: 10 * scale),
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.narLine2, width: 1),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.narChipActive, width: 1),
    ),
  );
}

/// 작성 중인 투표. 항목 컨트롤러를 들고 있어 [ChangeNotifier] 로 둔다.
class _PollDraft extends ChangeNotifier {
  _PollDraft() {
    for (var i = 0; i < 2; i++) {
      addOption();
    }
    question.addListener(notifyListeners);
  }

  final TextEditingController question = TextEditingController();
  final List<TextEditingController> options = [];

  /// 투표해야 결과를 보여줄지. 기본은 켬(밴드왜건 방지).
  bool hideResultsUntilVoted = true;

  void toggleHideResults() {
    hideResultsUntilVoted = !hideResultsUntilVoted;
    notifyListeners();
  }

  bool get canAddOption => options.length < 5;

  /// 주제와 항목 2개 이상이 채워져야 등록할 수 있다.
  bool get valid =>
      question.text.trim().isNotEmpty &&
      options.where((c) => c.text.trim().isNotEmpty).length >= 2;

  void addOption() {
    if (!canAddOption) return;
    final controller = TextEditingController()..addListener(notifyListeners);
    options.add(controller);
    notifyListeners();
  }

  void removeOption(int index) {
    if (options.length <= 2) return;
    options.removeAt(index).dispose();
    notifyListeners();
  }

  @override
  void dispose() {
    question.dispose();
    for (final option in options) {
      option.dispose();
    }
    super.dispose();
  }
}

class _PollEditor extends StatelessWidget {
  const _PollEditor({
    required this.draft,
    required this.scale,
    required this.onRemove,
  });

  final _PollDraft draft;
  final double scale;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => Container(
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(
          color: AppColors.narChipBadgeBg,
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: AppColors.narChipActive, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _field(
                    draft.question,
                    l.communityPollQuestionHint,
                    scale,
                    bold: true,
                  ),
                ),
                SizedBox(width: 8 * scale),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: Text(
                    l.communityPollRemove,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 11 * scale,
                      height: 1.45,
                      color: AppColors.narTextRed,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8 * scale),
            for (var i = 0; i < draft.options.length; i++) ...[
              if (i > 0) SizedBox(height: 6 * scale),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      draft.options[i],
                      l.communityPollOptionHint(i + 1),
                      scale,
                    ),
                  ),
                  if (draft.options.length > 2)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => draft.removeOption(i),
                      child: Padding(
                        padding: EdgeInsets.only(left: 6 * scale),
                        child: Icon(
                          Icons.remove_circle_outline,
                          size: 18 * scale,
                          color: AppColors.narText2,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (draft.canAddOption) ...[
              SizedBox(height: 9 * scale),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: draft.addOption,
                child: Text(
                  '＋ ${l.communityPollAddOption}',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 12 * scale,
                    height: 1.45,
                    color: AppColors.narViolet3,
                  ),
                ),
              ),
            ],
            SizedBox(height: 10 * scale),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: draft.toggleHideResults,
              child: Row(
                children: [
                  Container(
                    width: 16 * scale,
                    height: 16 * scale,
                    decoration: BoxDecoration(
                      color: draft.hideResultsUntilVoted
                          ? AppColors.narChipActive
                          : null,
                      borderRadius: BorderRadius.circular(4 * scale),
                      border: Border.all(
                        color: draft.hideResultsUntilVoted
                            ? AppColors.narChipActive
                            : AppColors.narLine2,
                        width: 1,
                      ),
                    ),
                    child: draft.hideResultsUntilVoted
                        ? Icon(
                            Icons.check,
                            size: 12 * scale,
                            color: AppColors.narText,
                          )
                        : null,
                  ),
                  SizedBox(width: 8 * scale),
                  Text(
                    l.communityPollHideResults,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      fontSize: 12 * scale,
                      height: 1.45,
                      color: AppColors.narText3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    double scale, {
    bool bold = false,
  }) {
    final style = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      fontSize: (bold ? 13.5 : 13) * scale,
      height: 1.45,
      color: AppColors.narText,
    );

    return TextField(
      controller: controller,
      style: style,
      cursorColor: AppColors.narViolet3,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: style.copyWith(color: AppColors.narDark300),
        isDense: true,
        filled: true,
        fillColor: AppColors.narDark600,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 8 * scale,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7 * scale),
          borderSide: const BorderSide(color: AppColors.narLine2, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7 * scale),
          borderSide: const BorderSide(color: AppColors.narLine2, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7 * scale),
          borderSide: const BorderSide(
            color: AppColors.narChipActive,
            width: 1,
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.asset,
    required this.label,
    required this.active,
    required this.scale,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool active;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? AppColors.narDark300
        : active
        ? AppColors.narViolet3
        : AppColors.narText3;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 38 * scale,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.narChipBadgeBg : null,
            borderRadius: BorderRadius.circular(9 * scale),
            border: Border.all(
              color: active ? AppColors.narChipActive : AppColors.narLine2,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                asset,
                width: 15 * scale,
                height: 15 * scale,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              SizedBox(width: 6 * scale),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5 * scale,
                  height: 1.45,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
