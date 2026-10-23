import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../repository/ad/ad_repository.dart';
import '../screens/cheer_ad/cheer_ad_screen.dart';
import '../styles/app_colors.dart';

/// 광고 자리(홈·경기 리스트·경기 상세)의 배너. 백오피스에서 등록한 광고가 [placement] 에
/// 노출 중이면 그 이미지를, 없으면 '우리 선수 응원 광고' 모집 배너([CheerAdBannerCard])를 둔다.
/// 모집 배너는 누르면 [CheerAdScreen], 등록 광고는 이동 주소가 있으면 외부 브라우저로 연다.
class CheerAdBanner extends StatefulWidget {
  const CheerAdBanner({
    super.key,
    required this.placement,
    required this.scale,
    this.topPadding = 28,
    this.bottomPadding = 0,
    this.horizontalPadding = 16,
  });

  /// 백오피스 광고 위치 키: home | match_list | match_detail.
  final String placement;
  final double scale;
  final double topPadding;
  final double bottomPadding;

  /// 좌우 여백. 홈은 양옆 카드들과 맞춰 16 을 두고, 경기 리스트·경기 상세는
  /// 0 을 넘겨 화면 폭을 꽉 채운다.
  final double horizontalPadding;

  @override
  State<CheerAdBanner> createState() => _CheerAdBannerState();
}

class _CheerAdBannerState extends State<CheerAdBanner> {
  late final Future<Ad?> _ad = AdRepository.instance.forPlacement(
    widget.placement,
  );

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding * scale,
        widget.topPadding * scale,
        widget.horizontalPadding * scale,
        widget.bottomPadding * scale,
      ),
      // 기다리는 동안 모집 배너를 그려 둔다 — 빈 자리를 두지 않는다. 광고는
      // 이미지 해석까지 끝난 뒤에만 들어오므로(AdRepository.forPlacement) 교체가
      // '모집 배너 → 완성된 광고' 한 번으로 끝난다. 스플래시에서 미리 받아 두면
      // (warmUp) 첫 프레임부터 광고라 교체 자체가 안 보인다.
      child: FutureBuilder<Ad?>(
        future: _ad,
        builder: (context, snapshot) {
          final ad = snapshot.data;
          if (ad == null) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CheerAdScreen()),
              ),
              child: CheerAdBannerCard(scale: scale),
            );
          }
          return RegisteredAdCard(ad: ad, scale: scale);
        },
      ),
    );
  }
}

/// 백오피스에 등록된 광고 한 건을 [slot] 규격 비율로 그린다. 이동 주소가 있으면
/// 눌러서 외부 브라우저로 연다. 다섯 자리(배너 3곳·스플래시·팝업)가 함께 쓴다.
class RegisteredAdCard extends StatelessWidget {
  const RegisteredAdCard({
    super.key,
    required this.ad,
    required this.scale,
    this.slot = CheerAdSlot.banner,
    this.radius,
  });

  final Ad ad;
  final double scale;
  final CheerAdSlot slot;

  /// 모서리 반경. 비우면 12. 팝업처럼 바깥 컨테이너가 이미 잘라 주면 0 으로 넘긴다.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final link = ad.linkUrl;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: link == null
          ? null
          : () => launchUrl(
              Uri.parse(link),
              mode: LaunchMode.externalApplication,
            ),
      child: AspectRatio(
        aspectRatio: slot.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular((radius ?? 12) * scale),
          child: Stack(
            children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: ad.imageUrl,
                  fit: BoxFit.cover,
                  // 여기 오기 전에 AdRepository 가 이미지 해석까지 끝내 두므로
                  // 보통은 첫 프레임에 그려진다. 캐시가 밀려나 다시 받는 드문
                  // 경우에만 회색 자리를 쓴다 — 모집 배너로 바꿨다 되돌리면 깜빡여서.
                  placeholder: (_, _) =>
                      const ColoredBox(color: AppColors.narDark500),
                  errorWidget: (_, _, _) =>
                      const ColoredBox(color: AppColors.narDark500),
                ),
              ),
              // 실제 광고일수록 표시가 필요하다 — 모집 배너와 같은 자리에 둔다.
              Positioned(
                top: 8 * scale,
                right: 8 * scale,
                child: AdBadge(scale: scale),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 스플래시 자리. **첫 프레임에 정하고 끝까지 바꾸지 않는다** — 이미 받아 둔 광고가
/// 있으면 그 광고를, 없으면 모집 배너를 그린다. 기다리는 빈 자리가 없다.
///
/// 스플래시는 1~2초만 떠 있고 사용자는 부팅을 기다리는 중이다. 이 화면에서 그림이
/// 바뀌면 전부 눈에 띄므로 조용한 쪽을 택했다. 교체를 허용해도 대개 실패한다 —
/// 화면이 먼저 사라져서, 늦게 도착한 이미지는 '전환만 보이고 끝나는' 최악이 된다.
/// 그래서 캐시가 빈 첫 실행은 모집 배너로 보내고, 그 사이 받아 둔 이미지는 다음
/// 실행의 첫 프레임에 쓴다([AdRepository.warmUp]).
///
/// 여백·탭 동작은 호출 쪽에 맡긴다(스플래시는 눌리지 않는다).
class CheerAdSlotView extends StatefulWidget {
  const CheerAdSlotView({
    super.key,
    required this.placement,
    required this.scale,
    required this.slot,
  });

  /// 백오피스 광고 위치 키: splash.
  final String placement;
  final double scale;
  final CheerAdSlot slot;

  @override
  State<CheerAdSlotView> createState() => _CheerAdSlotViewState();
}

class _CheerAdSlotViewState extends State<CheerAdSlotView> {
  /// 진입 시점에 한 번만 읽는다. 이후 도착하는 광고는 이 화면에 반영하지 않는다.
  late final Ad? _ad = AdRepository.instance.readyFor(widget.placement);

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) {
      return CheerAdBannerCard(scale: widget.scale, slot: widget.slot);
    }
    return RegisteredAdCard(ad: ad, scale: widget.scale, slot: widget.slot);
  }
}

/// 응원 광고가 들어가는 자리. 비율은 백오피스 광고 안내의 이미지 규격과 같고,
/// [asset] 은 그 자리에 광고가 어떻게 보이는지 보여주는 예시 사진이다.
/// [focus] 는 폰 목업 사진에서 광고가 있는 위치(세로)다 — 그 부분이 보이게 맞춘다.
enum CheerAdSlot {
  banner(
    'assets/images/cheer_ad/banner.png',
    960 / 300,
    Alignment(0, -0.52),
    16,
    12,
    zoom: 0.8,
  ),
  splash(
    'assets/images/cheer_ad/splash.png',
    1080 / 720,
    // 이 에셋은 폰 목업이 아니라 광고 부분만 잘라낸 그림이다. 줄여서 넣어
    // 위아래 여백이 보이게 한다.
    Alignment(0, 0),
    22,
    15,
    zoom: 0.78,
  ),
  popup(
    'assets/images/cheer_ad/popup.png',
    1080 / 1440,
    Alignment(0, -0.32),
    24,
    // 부제가 길어 15 에서는 두 줄로 쪼개진다("...올려보세 / 요").
    13,
    zoom: 0.32,
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
    this.radius,
  });

  final double scale;
  final CheerAdSlot slot;

  /// 모서리 반경. 비우면 12 (팝업 안에서는 0).
  final double? radius;

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
            // 스플래시 예시 사진은 광고만 잘라낸 그림이라 가운데에 둔다(오른쪽에
            // 붙이면 줄여 넣었을 때 한쪽으로 쏠린다).
            alignment: Alignment(
              portrait || slot == CheerAdSlot.splash ? 0 : 1,
              slot.focus.y,
            ),
            // zoom > 1 로 확대하려면 폭 제한도 함께 풀어야 한다 — area.maxWidth 로
            // 묶어 두면 SizedBox 가 그 값으로 잘려 확대가 먹지 않는다.
            maxWidth: area.maxWidth * (slot.zoom > 1 ? slot.zoom : 1),
            minHeight: 0,
            maxHeight: double.infinity,
            child: SizedBox(
              width: area.maxWidth * slot.zoom,
              child: slot == CheerAdSlot.splash
                  // 에셋 오른쪽 끝에 폰 베젤의 어두운 테두리가 남아 있어 세로선처럼
                  // 보인다. 왼쪽을 기준으로 살짝 키워 오른쪽 끝을 바깥 ClipRect 밖으로
                  // 밀어낸다. (OverflowBox 가 폭을 영역에 꽉 채워 zoom 이 먹지 않아
                  // Align.widthFactor 로는 자를 수 없다.)
                  ? Transform.scale(
                      scale: 1.05,
                      alignment: Alignment.centerLeft,
                      child: Image.asset(slot.asset, fit: BoxFit.fitWidth),
                    )
                  : Image.asset(slot.asset, fit: BoxFit.fitWidth),
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
          borderRadius: BorderRadius.circular((radius ?? 12) * scale),
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
                  // 스플래시 예시 사진은 광고만 잘라낸 그림이라 넓게 보여준다.
                  width:
                      c.maxWidth * (slot == CheerAdSlot.splash ? 0.52 : 0.45),
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
              // 예시 사진 안에도 뱃지가 찍혀 있지만 페이드·크롭에 묻혀 잘 안 보인다.
              // 광고 자리라는 표시는 항상 읽혀야 하므로 앱이 따로 얹는다.
              Positioned(
                top: 8 * scale,
                right: 8 * scale,
                child: AdBadge(scale: scale),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 광고 자리임을 알리는 둥근 'AD' 뱃지. 배너·스플래시·팝업 세 자리에 모두 붙는다.
///
/// 스토어 심사(App Store 3.2.2 / Play 광고 정책)가 광고임을 알아볼 수 있게 표시하도록
/// 요구한다. 콘텐츠를 가리지 않게 작게 두되, 사진 위에 올라가도 읽히도록 반투명 검정
/// 배경을 깐다.
class AdBadge extends StatelessWidget {
  const AdBadge({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: AppColors.narAdBadgeBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'AD',
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
          fontSize: 9 * scale,
          height: 1.2,
          letterSpacing: 0.3 * scale,
          color: AppColors.narAdBadgeText,
        ),
      ),
    );
  }
}
