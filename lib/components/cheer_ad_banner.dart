import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/cheer_ad/cheer_ad_screen.dart';
import '../styles/app_colors.dart';

/// '우리 선수 응원 광고' 배너. 광고 자리(홈·경기 리스트·경기 상세)에 두고,
/// 누르면 [CheerAdScreen] 으로 이동한다.
class CheerAdBanner extends StatelessWidget {
  const CheerAdBanner({
    super.key,
    required this.scale,
    this.topPadding = 28,
    this.bottomPadding = 0,
  });

  final double scale;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        topPadding * scale,
        16 * scale,
        bottomPadding * scale,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const CheerAdScreen())),
        child: CheerAdBannerCard(scale: scale),
      ),
    );
  }
}

/// 응원 광고가 들어가는 자리. 비율은 백오피스 광고 안내의 이미지 규격과 같고,
/// [asset] 은 그 자리에 광고가 어떻게 보이는지 보여주는 예시 사진이다.
/// [focus] 는 폰 목업 사진에서 광고가 있는 위치(세로)다 — 그 부분이 보이게 맞춘다.
enum CheerAdSlot {
  banner(
    'assets/images/cheer_ad/banner.png',
    960 / 300,
    Alignment(0, 0.15),
    16,
    12,
  ),
  splash(
    'assets/images/cheer_ad/splash.png',
    1080 / 720,
    Alignment(0, 0.85),
    22,
    15,
    zoom: 0.72,
  ),
  popup(
    'assets/images/cheer_ad/popup.png',
    1080 / 1440,
    Alignment(0, -0.2),
    24,
    15,
    zoom: 0.72,
  );

  const CheerAdSlot(
    this.asset,
    this.aspectRatio,
    this.focus,
    this.titleSize,
    this.subtitleSize, {
    this.zoom = 1,
  });

  final String asset;
  final double aspectRatio;
  final Alignment focus;

  /// 카드 안 제목·부제 글자 크기(스케일 전). 카드가 클수록 키운다.
  final double titleSize;
  final double subtitleSize;

  /// 예시 사진 배율. 1 이면 영역 폭을 꽉 채우고, 작을수록 줄여서 더 넓게 보인다.
  final double zoom;
}

/// 회색 배너 본체(탭·여백 없음). 폭은 부모를 채우고 높이는 [slot] 규격 비율로 정한다.
/// 문구는 왼쪽, 예시 사진은 오른쪽에 두고, 세로형(팝업)은 사진을 위, 문구를 아래에 둔다.
class CheerAdBannerCard extends StatelessWidget {
  const CheerAdBannerCard({
    super.key,
    required this.scale,
    this.slot = CheerAdSlot.banner,
  });

  final double scale;
  final CheerAdSlot slot;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final portrait = slot.aspectRatio < 1;
    final image = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: portrait ? Alignment.bottomCenter : Alignment.centerLeft,
        end: portrait ? Alignment.topCenter : Alignment.centerRight,
        colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
        stops: const [0, 0.5],
      ).createShader(rect),
      child: LayoutBuilder(
        builder: (context, area) => ClipRect(
          child: OverflowBox(
            alignment: Alignment(portrait ? 0 : 1, slot.focus.y),
            maxWidth: area.maxWidth,
            minHeight: 0,
            maxHeight: double.infinity,
            child: SizedBox(
              width: area.maxWidth * slot.zoom,
              child: Image.asset(slot.asset, fit: BoxFit.fitWidth),
            ),
          ),
        ),
      ),
    );
    final text = Column(
      mainAxisAlignment: portrait
          ? MainAxisAlignment.end
          : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.homeCheerAdTitle,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
            fontSize: slot.titleSize * scale,
            color: AppColors.narText,
          ),
        ),
        SizedBox(height: 4 * scale),
        Text(
          l.homeCheerAdSubtitle,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: slot.subtitleSize * scale,
            color: AppColors.narText3,
          ),
        ),
      ],
    );
    return AspectRatio(
      aspectRatio: slot.aspectRatio,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.narDark500,
          borderRadius: BorderRadius.circular(12 * scale),
        ),
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              if (portrait)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: c.maxHeight * 0.68,
                  child: image,
                )
              else
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: c.maxWidth * 0.45,
                  child: image,
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16 * scale,
                  16 * scale,
                  16 * scale,
                  (portrait ? 40 : 16) * scale,
                ),
                child: text,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
