import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/api_config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';

/// 로그인 화면 하단 동의 고지.
///
/// **링크만 두면 안 된다.** App Store 심사(Guideline 1.2)는 이용자 생성 콘텐츠를
/// 다루는 앱에 대해 "이용자가 약관에 동의해야 한다"를 요구한다. 문서를 열어볼 수
/// 있게만 해두는 건 제공이지 동의가 아니라, "로그인하면 동의한 것으로 봅니다"라는
/// 문장이 함께 있어야 한다.
///
/// 문서는 외부 브라우저로 연다. 인앱 웹뷰(`webview_flutter`)는 네이티브 의존성이라
/// 넣는 순간 Shorebird 코드푸시로 못 나가고 스토어 재제출이 필요해진다. 약관을
/// 읽히자고 낼 비용이 아니다.
class LoginConsentNotice extends StatelessWidget {
  const LoginConsentNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    const base = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
      color: AppColors.narText2,
      height: 1.5,
    );
    final link = base.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.narText3,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.narText3,
    );

    // 문장 가운데에 링크 두 개가 박히는 형태라, 문구를 자리표시자로 두고
    // 앞뒤를 잘라 쓴다. 번역마다 링크 위치가 달라져도 이 방식이면 깨지지 않는다.
    const termsToken = '{{terms}}';
    const privacyToken = '{{privacy}}';
    final sentence = l.loginConsentNotice(termsToken, privacyToken);

    final spans = <InlineSpan>[];
    var rest = sentence;
    while (true) {
      final termsAt = rest.indexOf(termsToken);
      final privacyAt = rest.indexOf(privacyToken);
      final hasTerms = termsAt >= 0;
      final hasPrivacy = privacyAt >= 0;
      if (!hasTerms && !hasPrivacy) {
        spans.add(TextSpan(text: rest));
        break;
      }
      final isTermsFirst =
          hasTerms && (!hasPrivacy || termsAt < privacyAt);
      final at = isTermsFirst ? termsAt : privacyAt;
      final token = isTermsFirst ? termsToken : privacyToken;

      if (at > 0) spans.add(TextSpan(text: rest.substring(0, at)));
      spans.add(
        TextSpan(
          text: isTermsFirst ? l.termsOfService : l.privacyPolicy,
          style: link,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _open(
              isTermsFirst ? ApiConfig.termsUrl : ApiConfig.privacyUrl,
            ),
        ),
      );
      rest = rest.substring(at + token.length);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24 * scale),
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.center,
        style: base.copyWith(fontSize: 11.5 * scale),
      ),
    );
  }

  Future<void> _open(String url) async {
    // 실패해도 로그인 흐름을 막지 않는다. 링크가 안 열리는 것보다
    // 로그인이 멈추는 쪽이 나쁘다.
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on Exception catch (e) {
      debugPrint('[Login] 약관 링크 열기 실패: $url — $e');
    }
  }
}
