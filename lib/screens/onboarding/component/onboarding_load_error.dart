import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 온보딩 선택 그리드(리그/팀/선수) 로딩 실패 시 보여주는 안내.
///
/// 한 줄 안내 메시지와 디버그용 에러 내용, '다시 시도' 버튼을 가운데에 그린다.
class OnboardingLoadError extends StatelessWidget {
  const OnboardingLoadError({
    super.key,
    required this.message,
    required this.error,
    required this.onRetry,
  });

  /// 사용자에게 보여줄 한 줄 안내. 예: '팀 목록을 불러오지 못했어요'.
  final String message;

  /// 디버그용 에러 객체.
  final Object error;

  /// '다시 시도' 콜백.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: AppColors.narText2)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.narText2, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
