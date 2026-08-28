import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/nar_detail_header.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/community/post_write_viewmodel.dart';
import 'community_rules.dart';
import 'community_teams.dart';
import 'component/community_rules_sheet.dart';

/// 글쓰기 — 제목 · 본문 · 사진.
///
/// 게시판 선택 UI 는 두지 않는다. 글쓰기는 전체 게시판이나 내 응원팀 게시판에서
/// 들어오는데, 그 두 곳이 애초에 쓸 수 있는 전부라 고를 게 없다. 어디에 쓰는지는
/// 헤더에 게시판 이름으로 보여준다.
///
/// 본문 아래에는 커뮤니티 이용규칙 요약이 연하게 깔린다. 글을 쓰기 직전이
/// 규칙을 읽을 유일한 순간이라, 별도 화면으로 빼면 아무도 안 본다.
///
/// 등록에 성공하면 새 글 id 를 결과로 pop 한다.
class PostWriteScreen extends StatefulWidget {
  const PostWriteScreen({super.key, required this.boardTeamId});

  /// null 이면 전체 게시판.
  final int? boardTeamId;

  @override
  State<PostWriteScreen> createState() => _PostWriteScreenState();
}

class _PostWriteScreenState extends State<PostWriteScreen> {
  late final PostWriteViewModel _vm = PostWriteViewModel(
    boardTeamId: widget.boardTeamId,
  );

  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();

  @override
  void initState() {
    super.initState();
    _title.addListener(_onChanged);
    _body.addListener(_onChanged);
    _vm.addListener(_showError);
  }

  @override
  void dispose() {
    _vm.removeListener(_showError);
    _title.dispose();
    _body.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _showError() {
    final message = _vm.error;
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _submittable =>
      _title.text.trim().isNotEmpty &&
      _body.text.trim().isNotEmpty &&
      !_vm.submitting;

  Future<void> _submit() async {
    final id = await _vm.submit(title: _title.text, body: _body.text);
    if (id == null || !mounted) return;
    Navigator.of(context).pop<int>(id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    final team = communityTeam(widget.boardTeamId);
    // 상세와 같은 이유로 팀 코드를 쓴다 — 헤더 가운데 슬롯이 좁아 팀 이름
    // ('Hanwha Life Esports')을 그대로 넣으면 '등록하기' 옆에서 잘린다.
    final board = team == null
        ? l.communityBoardAll
        : l.communityBoardTeam(team.code.isNotEmpty ? team.code : team.name);

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _vm,
            builder: (context, _) => Column(
              children: [
                NarDetailHeader(
                  title: board,
                  scale: scale,
                  trailing: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _submittable ? _submit : null,
                    // NarDetailHeader 의 슬롯 높이가 34*scale 이라 세로 패딩을
                    // 주면 글자가 위아래로 잘린다. 좌우로만 넓혀 탭 영역을
                    // 확보한다.
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                      child: Text(
                        _vm.submitting
                            ? l.communityWriteSubmitting
                            : l.communityWriteSubmit,
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
                        maxLength: 100,
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
                      if (_vm.photos.isNotEmpty) ...[
                        SizedBox(height: 14 * scale),
                        _photoStrip(scale),
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
      ),
    );
  }

  Widget _photoStrip(double scale) {
    final photos = _vm.photos;

    return SizedBox(
      height: 72 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => SizedBox(width: 8 * scale),
        itemBuilder: (context, i) => Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8 * scale),
              child: Image.file(
                File(photos[i]),
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
                onTap: () => _vm.removePhoto(i),
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
    final photos = _vm.photos;
    final full = photos.length >= PostWriteViewModel.maxPhotos;

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
            label: photos.isEmpty
                ? l.communityAttachPhoto
                : l.communityPhotoCount(photos.length),
            active: photos.isNotEmpty,
            scale: scale,
            onTap: full ? null : _vm.pickPhotos,
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
    counterText: '',
    contentPadding: EdgeInsets.symmetric(vertical: 10 * scale),
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.narLine2, width: 1),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.narChipActive, width: 1),
    ),
  );
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
