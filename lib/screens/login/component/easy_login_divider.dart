import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../styles/app_colors.dart';

/// 로그인 화면의 '간편 로그인' 구분선.
class EasyLoginDivider extends StatelessWidget {
  const EasyLoginDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.narLine2, thickness: 1, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11.5),
          child: Text(
            l.easyLogin,
            style: const TextStyle(color: AppColors.narText, fontSize: 16),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.narLine2, thickness: 1, height: 1),
        ),
      ],
    );
  }
}
