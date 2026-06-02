import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/common_button.dart';
import '../../../components/nar_star_rating_input.dart';
import '../../../styles/app_colors.dart';
import '../../../util/lane_asset.dart';

/// 평점·코멘트 남기기 바텀시트를 띄운다.
/// 등록 시 입력된 (평점, 코멘트)를 반환하고, 닫으면 null 을 반환한다.
Future<({double rating, String comment})?> showRatingCommentSheet({
  required BuildContext context,
  required String teamName,
  required String playerName,
  required String position,
}) {
  return showModalBottomSheet<({double rating, String comment})>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder:
        (sheetContext) => Padding(
          // 키보드가 올라오면 시트를 그만큼 밀어 올린다.
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: RatingCommentSheet(
            teamName: teamName,
            playerName: playerName,
            position: position,
          ),
        ),
  );
}

/// 평점·코멘트 남기기 바텀시트 본문.
///
/// bg narDark800, 상단 라운드 10, padding 20.
/// 헤더(타이틀 + X) → 선수 정보 → 별점 입력([NarStarRatingInput]) →
/// 코멘트 입력박스 + 글자수(0/150) → 안내문 → 등록 버튼.
class RatingCommentSheet extends StatefulWidget {
  const RatingCommentSheet({
    super.key,
    required this.teamName,
    required this.playerName,
    required this.position,
  });

  final String teamName;
  final String playerName;
  final String position;

  @override
  State<RatingCommentSheet> createState() => _RatingCommentSheetState();
}

class _RatingCommentSheetState extends State<RatingCommentSheet> {
  static const int _maxLength = 150;

  final TextEditingController _controller = TextEditingController();
  double _rating = 0;
  int _length = 0;

  // 별점만 있어도 등록 가능, 코멘트만은 불가 — 평점이 있어야 활성.
  bool get _canSubmit => _rating > 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop((rating: _rating, comment: _controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.narDark800,
        borderRadius: BorderRadius.vertical(top: Radius.circular(10 * scale)),
      ),
      padding: EdgeInsets.all(20 * scale),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더: 타이틀 + 닫기.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '평점·코멘트 남기기',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 14 * scale,
                  height: 1.45,
                  color: AppColors.narText,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: SvgPicture.asset(
                  'assets/icons/close.svg',
                  width: 24 * scale,
                  height: 24 * scale,
                  colorFilter: const ColorFilter.mode(
                    AppColors.narLine2,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          // 선수 정보.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${widget.teamName} ${widget.playerName}',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 18 * scale,
                  height: 1.45,
                  color: AppColors.narText,
                ),
              ),
              SizedBox(width: 8 * scale),
              // 포지션 mini 아이콘 — 라인별 svg. 매칭 라인이 없으면 회색 placeholder.
              _buildLaneIcon(widget.position, scale),
              SizedBox(width: 8 * scale),
              Text(
                widget.position,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 16 * scale,
                  height: 1.45,
                  color: AppColors.narText,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          // 별점 입력(공용 컴포넌트).
          Align(
            alignment: Alignment.centerLeft,
            child: NarStarRatingInput(
              rating: _rating,
              onChanged: (v) => setState(() => _rating = v),
              starSize: 32,
              scale: scale,
            ),
          ),
          SizedBox(height: 15 * scale),
          // 코멘트 입력박스.
          Container(
            height: 125 * scale,
            padding: EdgeInsets.all(14 * scale),
            decoration: BoxDecoration(
              color: AppColors.narDark600,
              borderRadius: BorderRadius.circular(10 * scale),
            ),
            child: TextField(
              controller: _controller,
              maxLength: _maxLength,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              cursorColor: AppColors.narText,
              onChanged: (v) => setState(() => _length = v.characters.length),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 14 * scale,
                height: 1.45,
                color: AppColors.narText,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                counterText: '', // 기본 카운터 숨기고 아래에 직접 표시.
                hintText: '선수의 활약에 대한 의견을 남겨보세요.',
                hintStyle: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  fontSize: 14 * scale,
                  height: 1.45,
                  color: AppColors.narText2,
                ),
              ),
            ),
          ),
          SizedBox(height: 11 * scale),
          // 글자수 카운터 — 입력 수는 narText2, '/최대'는 화이트.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$_length'),
                TextSpan(
                  text: '/$_maxLength',
                  style: const TextStyle(color: AppColors.narText),
                ),
              ],
            ),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              fontSize: 16 * scale,
              height: 1.45,
              color: AppColors.narText2,
            ),
          ),
          SizedBox(height: 11 * scale),
          // 안내문.
          Text(
            '선수에 대한 지나친 비방 및 부적절한 표현은 운영 정책에 따라 사전 안내 없이 삭제될 수 있습니다.',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              fontSize: 14 * scale,
              height: 1.45,
              color: AppColors.narText2,
            ),
          ),
          SizedBox(height: 16 * scale),
          // 등록 버튼(공용 버튼). 평점 미선택 시 onPressed null → 비활성.
          CommonButton(
            label: '등록하기',
            onPressed: _canSubmit ? _submit : null,
            scale: scale,
          ),
        ],
      ),
    );
  }

  /// 포지션명을 라인 svg 아이콘으로 렌더링. 매칭 라인이 없으면 회색 placeholder.
  Widget _buildLaneIcon(String position, double scale) {
    final asset = laneAssetPath(position);
    final size = 14 * scale;
    if (asset == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.narDark200,
          borderRadius: BorderRadius.circular(3 * scale),
        ),
      );
    }
    return SvgPicture.asset(asset, width: size, height: size);
  }
}
