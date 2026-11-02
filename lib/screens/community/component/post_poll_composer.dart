import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';

/// 글쓰기 입력 글꼴 — 제목·본문·설문 입력이 같이 쓴다.
TextStyle postWriteInputStyle(
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

/// 글쓰기 화면의 설문 작성 블록 — 질문 1개 + 선택지 2~[maxOptions]개 +
/// 복수 선택·결과 공개 스위치.
///
/// 컨트롤러는 화면(State)이 들고 있다 — 이 위젯이 만들면 재빌드마다 입력이
/// 날아가고, 임시저장·수정 진입에서 기존 값을 채워 넣을 수 없다. 선택지
/// 추가·삭제도 컨트롤러 수명을 쥔 쪽에서 해야 해서 콜백으로 올린다.
class PostPollComposer extends StatelessWidget {
  const PostPollComposer({
    super.key,
    required this.scale,
    required this.question,
    required this.options,
    required this.maxOptions,
    required this.allowMultiple,
    required this.alwaysShowResults,
    required this.onChanged,
    required this.onClose,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onAllowMultipleChanged,
    required this.onAlwaysShowResultsChanged,
  });

  final double scale;
  final TextEditingController question;
  final List<TextEditingController> options;
  final int maxOptions;
  final bool allowMultiple;
  final bool alwaysShowResults;

  /// 입력이 바뀔 때 — 제출 버튼 활성화·임시저장 변경 감지를 다시 계산한다.
  final VoidCallback onChanged;

  /// 우상단 X — 설문 자체를 접는다.
  final VoidCallback onClose;

  final VoidCallback onAddOption;
  final void Function(int index) onRemoveOption;
  final ValueChanged<bool> onAllowMultipleChanged;
  final ValueChanged<bool> onAlwaysShowResultsChanged;

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: postWriteInputStyle(
      scale,
      13,
    ).copyWith(color: AppColors.narDark300),
    isDense: true,
    counterText: '',
    filled: true,
    fillColor: AppColors.narDark500,
    contentPadding: EdgeInsets.symmetric(
      horizontal: 12 * scale,
      vertical: 9 * scale,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9 * scale),
      borderSide: BorderSide.none,
    ),
  );

  Widget _switchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
            fontSize: 12.5 * scale,
            height: 1.4,
            color: AppColors.narText3,
          ),
        ),
      ),
      SizedBox(
        height: 30 * scale,
        child: FittedBox(
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.narViolet3,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: AppColors.narDark600,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.narLine2, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.poll_outlined,
                size: 15 * scale,
                color: AppColors.narViolet3,
              ),
              SizedBox(width: 5 * scale),
              Expanded(
                child: Text(
                  l.communityPollLabel,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 13 * scale,
                    height: 1.45,
                    color: AppColors.narText,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: Icon(
                  Icons.close,
                  size: 16 * scale,
                  color: AppColors.narText2,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          TextField(
            controller: question,
            maxLength: 100,
            onChanged: (_) => onChanged(),
            style: postWriteInputStyle(scale, 13.5, weight: FontWeight.w600),
            cursorColor: AppColors.narViolet3,
            decoration: _fieldDecoration(l.communityPollQuestionHint),
          ),
          SizedBox(height: 8 * scale),
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) SizedBox(height: 6 * scale),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: options[i],
                    maxLength: 50,
                    onChanged: (_) => onChanged(),
                    style: postWriteInputStyle(scale, 13),
                    cursorColor: AppColors.narViolet3,
                    decoration: _fieldDecoration(
                      '${l.communityPollOptionHint} ${i + 1}',
                    ),
                  ),
                ),
                if (options.length > 2)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onRemoveOption(i),
                    child: Padding(
                      padding: EdgeInsets.only(left: 8 * scale),
                      child: Icon(
                        Icons.remove_circle_outline,
                        size: 17 * scale,
                        color: AppColors.narText2,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (options.length < maxOptions) ...[
            SizedBox(height: 8 * scale),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAddOption,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 15 * scale, color: AppColors.narViolet3),
                  SizedBox(width: 4 * scale),
                  Text(
                    l.communityPollAddOption,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5 * scale,
                      height: 1.4,
                      color: AppColors.narViolet3,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 10 * scale),
          _switchRow(
            label: l.communityPollAllowMultiple,
            value: allowMultiple,
            onChanged: onAllowMultipleChanged,
          ),
          _switchRow(
            label: l.communityPollAlwaysShowResults,
            value: alwaysShowResults,
            onChanged: onAlwaysShowResultsChanged,
          ),
        ],
      ),
    );
  }
}
