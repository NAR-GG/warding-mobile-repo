import 'dart:ui';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

import '../repository/auth/auth_service.dart';
import '../screens/login/login_screen.dart';
import '../styles/app_colors.dart';
import 'nar_button.dart';

/// 비회원(JWT 없음) 진입 시 [child]를 블러 처리하고, 가운데에
/// '로그인 후 사용 가능' 버튼을 띄운다. 버튼을 누르면 로그인 화면으로 이동한다.
///
/// 로그인 여부는 화면 진입·앱 포그라운드 복귀 시 다시 확인한다
/// (로그인/로그아웃 후 같은 화면으로 돌아와도 상태가 맞게 반영되도록).
class GuestLockOverlay extends StatefulWidget {
  const GuestLockOverlay({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  State<GuestLockOverlay> createState() => _GuestLockOverlayState();
}

class _GuestLockOverlayState extends State<GuestLockOverlay>
    with WidgetsBindingObserver {
  /// null = 아직 확인 전(블러 없이 노출), true = 비회원.
  bool? _isGuest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkGuest();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkGuest();
  }

  Future<void> _checkGuest() async {
    final jwt = await AuthService.instance.jwt;
    if (!mounted) return;
    setState(() => _isGuest = jwt == null || jwt.isEmpty);
  }

  Future<void> _goToLogin() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
    // 뒤로가기로 돌아왔을 수 있으니 로그인 여부를 다시 확인한다.
    _checkGuest();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scale = widget.scale;
    return Stack(
      children: [
        widget.child,
        if (_isGuest == true)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: AppColors.narDark800.withValues(alpha: 0.4),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 200 * scale,
                    child: NarButton(
                      label: l.loginRequired,
                      variant: NarButtonVariant.set1,
                      scale: scale,
                      onPressed: _goToLogin,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
