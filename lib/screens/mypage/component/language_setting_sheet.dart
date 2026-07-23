import 'package:flutter/material.dart';

import '../../../components/app_bottom_sheet.dart';
import '../../../components/nar_dropdown.dart';
import '../../../styles/app_colors.dart';

/// 언어 설정 바텀시트에서 선택 가능한 언어 목록.
const _languageOptions = ['한국어', 'English'];

/// 마이페이지 언어 설정 바텀시트.
///
/// [AppBottomSheet] 안에 [NarDropdown] 을 두어 한국어 / English 를 선택한다.
/// 선택이 바뀌면 [onChanged] 로 알린다.
class LanguageSettingSheet extends StatefulWidget {
  const LanguageSettingSheet({
    super.key,
    this.initialLanguage = '한국어',
    this.onChanged,
  });

  final String initialLanguage;
  final ValueChanged<String>? onChanged;

  @override
  State<LanguageSettingSheet> createState() => _LanguageSettingSheetState();
}

class _LanguageSettingSheetState extends State<LanguageSettingSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLanguage;
  }

  void _showOptions() {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    showAppBottomSheet(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 12 * scale),
            child: Text(
              '언어 선택',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 16 * scale,
                height: 1.55,
                color: AppColors.narText,
              ),
            ),
          ),
          ..._languageOptions.map((lang) {
            final isSelected = lang == _selected;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _selected = lang);
                widget.onChanged?.call(lang);
                Navigator.of(context).pop();
              },
              child: Container(
                height: 48 * scale,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.narBgTertiary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                child: Text(
                  lang,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 15 * scale,
                    height: 1.55,
                    color: isSelected
                        ? AppColors.narText
                        : AppColors.narTextTertiary,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 드래그 핸들
        Center(
          child: Container(
            width: 36 * scale,
            height: 4 * scale,
            margin: EdgeInsets.only(bottom: 20 * scale),
            decoration: BoxDecoration(
              color: AppColors.narDark200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 16 * scale),
          child: Text(
            '언어 설정',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 18 * scale,
              height: 1.4,
              color: AppColors.narText,
            ),
          ),
        ),
        NarDropdown(
          value: _selected,
          scale: scale,
          onTap: _showOptions,
        ),
      ],
    );
  }
}

/// [LanguageSettingSheet] 를 [AppBottomSheet] 모달로 띄우는 헬퍼.
Future<void> showLanguageSettingSheet({
  required BuildContext context,
  String initialLanguage = '한국어',
  ValueChanged<String>? onChanged,
}) {
  return showAppBottomSheet(
    context: context,
    child: LanguageSettingSheet(
      initialLanguage: initialLanguage,
      onChanged: onChanged,
    ),
  );
}
