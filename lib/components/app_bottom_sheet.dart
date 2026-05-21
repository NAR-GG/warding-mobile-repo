import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 앱 공용 바텀시트 모달.
///
/// 화면 하단에서 올라오는 모달. 상단 모서리만 38만큼 둥글고, 디자인 시안의
/// 그림자(`0 4 20 #1011131F`)가 깔린다. 직접 쓰기보다 [showAppBottomSheet]
/// 헬퍼로 띄우는 걸 권장한다.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({super.key, required this.child});

  /// 시트 본문 위젯.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.narBgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(38 * scale)),
        boxShadow: [
          BoxShadow(
            color: AppColors.narBottomSheetShadow,
            offset: Offset(0, 4 * scale),
            blurRadius: 20 * scale,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 12 * scale,
        right: 16 * scale,
        bottom: 60 * scale,
        left: 16 * scale,
      ),
      child: child,
    );
  }
}

/// [AppBottomSheet] 를 모달로 띄운다.
///
/// 상단 모서리 38·위쪽 그림자 같은 디자인 스펙을 그대로 살리려고
/// [showModalBottomSheet] 의 배경을 투명하게 두고, 시트 모양은
/// [AppBottomSheet] 가 직접 그린다.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isScrollControlled = true,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    builder: (_) => AppBottomSheet(child: child),
  );
}
