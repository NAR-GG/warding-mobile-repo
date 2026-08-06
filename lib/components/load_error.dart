import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

import '../styles/app_colors.dart';

/// 데이터 로딩 실패 시 보여주는 공용 안내.
///
/// 한 줄 안내 메시지와 '다시 시도' 버튼을 가운데에 그린다.
class LoadError extends StatelessWidget {
  const LoadError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  /// 사용자에게 보여줄 한 줄 안내. 예: '팀 목록을 불러오지 못했어요'.
  final String message;

  /// '다시 시도' 콜백.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: AppColors.narText2)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(l.retry)),
        ],
      ),
    );
  }
}
