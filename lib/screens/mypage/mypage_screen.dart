import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/common_button.dart';
import '../../components/guest_lock_overlay.dart';
import '../../components/nar_alert_dialog.dart';
import '../../components/nar_banner.dart';
import '../../model/team.dart';
import '../../repository/auth/auth_service.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import '../../viewmodel/mypage/mypage_viewmodel.dart';
import 'component/language_setting_sheet.dart';
import 'component/subscription_alarm_section.dart';
import '../login/login_screen.dart';
import '../match_list/match_list_screen.dart';
import '../my_review/my_review_screen.dart';
import '../profile_edit/profile_edit_screen.dart';
import '../schedule/schedule_screen.dart';
import '../subscription/subscription_screen.dart';
import '../subscription/subscription_settings_screen.dart';

/// 마이페이지. 하단 네비 '마이페이지' 탭에 해당한다.
class MypageScreen extends StatefulWidget {
  const MypageScreen({super.key});

  @override
  State<MypageScreen> createState() => _MypageScreenState();
}

class _MypageScreenState extends State<MypageScreen> {
  final MypageViewModel _viewModel = MypageViewModel();
  final _subscriptionAlarmKey = GlobalKey<SubscriptionAlarmSectionState>();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// 프로필 수정 화면으로 이동. 이동 시 안내 배너는 더 이상 노출하지 않는다.
  /// 수정 화면이 `true` 로 pop 하면 회원 정보(닉네임·응원팀)를 새로고침한다.
  Future<void> _goToProfileEdit() async {
    _viewModel.dismissTeamBanner();
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ProfileEditScreen()),
    );
    if (updated == true) {
      await _viewModel.load();
    }
  }

  /// 로그아웃 — 소셜·자체 토큰을 정리하고 로그인 화면으로 되돌린다.
  Future<void> _logout() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// 회원탈퇴 — 확인 다이얼로그 후 계정 삭제, 로그인 화면으로 이동.
  Future<void> _withdraw() async {
    final confirmed = await showNarConfirmDialog(
      context: context,
      title: '회원탈퇴',
      message: '계정과 구독·알림·평점 등 모든 데이터가\n삭제되며 되돌릴 수 없습니다.',
      confirmLabel: '탈퇴',
    );
    if (confirmed != true || !mounted) return;
    try {
      await AuthService.instance.withdraw();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원탈퇴에 실패했습니다. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// 구독 관리 — 구독 설정 화면으로 이동.
  /// 돌아오면 팀 구독이 바뀌었을 수 있으니 구독 팀 알림 설정을 새로고침한다.
  Future<void> _goToSubscriptionSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SubscriptionSettingsScreen(),
      ),
    );
    await _subscriptionAlarmKey.currentState?.reload();
  }

  /// 외부 URL을 기본 브라우저(또는 앱)로 연다.
  Future<void> _launchUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// 하단 네비 탭 선택. 다른 탭이면 해당 화면으로 전환한다.
  /// '마이페이지'는 현재 화면이라 별도 처리하지 않는다.
  void _onTabSelected(BuildContext context, AppNavTab tab) {
    if (tab == AppNavTab.schedule) {
      Navigator.of(context).pushReplacement(tabRoute(const ScheduleScreen()));
    } else if (tab == AppNavTab.list) {
      Navigator.of(context).pushReplacement(tabRoute(const MatchListScreen()));
    } else if (tab == AppNavTab.subscription) {
      Navigator.of(
        context,
      ).pushReplacement(tabRoute(const SubscriptionScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Stack(
          children: [
            GuestLockOverlay(
              scale: scale,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MypageHeader(
                      scale: scale,
                      onGlobeTap: () {
                        showLanguageSettingSheet(
                          context: context,
                          onChanged: (lang) {
                            // TODO: 앱 전역 로케일 변경 연동.
                            debugPrint('[MyPage] 언어 변경: $lang');
                          },
                        );
                      },
                      onBellTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 4 * scale),
                    ListenableBuilder(
                      listenable: _viewModel,
                      builder: (context, _) => _MypageProfile(
                        scale: scale,
                        onEditTap: _goToProfileEdit,
                        nickname: _viewModel.nickname,
                        email: _viewModel.email,
                        favoriteTeam: _viewModel.favoriteTeam,
                        profileImageUrl: _viewModel.profileImageUrl,
                      ),
                    ),
                    // 응원팀 자동 설정 안내 배너 — 최초 진입 시 한 번만 노출.
                    // 노출과 동시에 '봤음'으로 저장돼 재진입엔 뜨지 않고,
                    // 탭해 프로필 수정으로 이동하면 즉시 사라진다.
                    ListenableBuilder(
                      listenable: _viewModel,
                      builder: (context, _) => _viewModel.showTeamBanner
                          ? NarBanner(
                              scale: scale,
                              onTap: _goToProfileEdit,
                              icon: SvgPicture.asset(
                                'assets/icons/heart.svg',
                                width: 24 * scale,
                                height: 24 * scale,
                              ),
                              text: '설문 기반으로 응원하는 팀이 자동으로 설정됐어요!',
                            )
                          : const SizedBox.shrink(),
                    ),
                    SizedBox(height: 20 * scale),
                    SubscriptionAlarmSection(
                      key: _subscriptionAlarmKey,
                      scale: scale,
                      onManageTap: _goToSubscriptionSettings,
                    ),
                    SizedBox(height: 16 * scale),
                    ListenableBuilder(
                      listenable: _viewModel,
                      builder: (context, _) => _MypageLinkRow(
                        title: '내 리뷰/평점',
                        count: _viewModel.reviewCount,
                        scale: scale,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MyReviewScreen(),
                            ),
                          );
                          // 리뷰 화면에서 삭제했을 수 있으니 건수를 새로고침한다.
                          await _viewModel.load();
                        },
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    _MypageLinkRow(
                      title: '고객센터/문의',
                      scale: scale,
                      onTap: () => _launchUrl(
                        'https://docs.google.com/forms/d/e/1FAIpQLSf66NkvON3YrFR0n_CSbnzyjXlEEfO8eiIc9W_2TBYulvihMA/viewform',
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    _MypageLinkRow(
                      title: '나르지지 웹사이트',
                      scale: scale,
                      onTap: () => _launchUrl('https://nar.kr/'),
                    ),
                    SizedBox(height: 16 * scale),
                    _AppInfoRow(
                      // TODO: 실제 버전 정보로 교체 (현재 mock).
                      versionStatus: '최신 버전입니다.',
                      versionLabel: '(현재 버전 1.1.0)',
                      scale: scale,
                    ),
                    // 맨 아래 로그아웃/회원탈퇴 — 80 간격 후, 가운데 정렬·40 간격.
                    SizedBox(height: 80 * scale),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CommonButton(
                          label: '로그아웃',
                          variant: CommonButtonVariant.logout,
                          scale: scale,
                          onPressed: _logout,
                        ),
                        SizedBox(width: 40 * scale),
                        CommonButton(
                          label: '회원탈퇴',
                          variant: CommonButtonVariant.text,
                          scale: scale,
                          onPressed: _withdraw,
                        ),
                      ],
                    ),
                    // 하단 네비에 가리지 않도록 여백.
                    SizedBox(height: 166 * scale),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 26,
              child: AppBottomNav(
                currentTab: AppNavTab.mypage,
                onTabSelected: (tab) => _onTabSelected(context, tab),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 마이페이지 헤더. 좌측 타이틀 + 우측 지구본·알림(bell) 아이콘 (양옆 20 패딩).
class _MypageHeader extends StatelessWidget {
  const _MypageHeader({required this.scale, this.onGlobeTap, this.onBellTap});

  final double scale;
  final VoidCallback? onGlobeTap;
  final VoidCallback? onBellTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 17 * scale, 20 * scale, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '마이 페이지',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w700,
              fontSize: 22 * scale,
              height: 1.4,
              letterSpacing: 0,
              color: AppColors.narText,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onGlobeTap,
                child: SvgPicture.asset(
                  'assets/icons/globe.svg',
                  width: 24 * scale,
                  height: 24 * scale,
                  colorFilter: const ColorFilter.mode(
                    AppColors.narText,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              SizedBox(width: 16 * scale),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBellTap,
                child: SvgPicture.asset(
                  'assets/icons/bell.svg',
                  width: 24 * scale,
                  height: 24 * scale,
                  colorFilter: const ColorFilter.mode(
                    AppColors.narText,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 마이페이지 프로필 섹션 (양옆 20 패딩).
///
/// 좌측: 기본 프로필 이미지(59) + 닉네임/팀 뱃지 + 이메일.
/// 우측: '프로필 수정' 텍스트 버튼.
class _MypageProfile extends StatelessWidget {
  const _MypageProfile({
    required this.scale,
    this.onEditTap,
    this.nickname = '',
    this.email,
    this.favoriteTeam,
    this.profileImageUrl,
  });

  final double scale;
  final VoidCallback? onEditTap;

  /// 회원 닉네임. 비어 있으면 placeholder 를 보인다.
  final String nickname;

  /// 회원 이메일. 없으면 빈 줄.
  final String? email;

  /// 응원 팀(로고 뱃지용). 없으면 회색 원 placeholder.
  final Team? favoriteTeam;

  /// 프로필 이미지 URL. 없으면 기본 이미지(person.png).
  final String? profileImageUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 좌측: 프로필 이미지 + 닉네임/이메일.
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 프로필 이미지 — 없으면 기본 이미지(person.png).
                _ProfileImage(url: profileImageUrl, scale: scale),
                SizedBox(width: 16 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 닉네임 + 팀 프로필 뱃지.
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              nickname.isEmpty ? '닉네임' : nickname,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w600,
                                fontSize: 16 * scale,
                                height: 1.55,
                                color: AppColors.narText,
                              ),
                            ),
                          ),
                          SizedBox(width: 8 * scale),
                          // 응원 팀 로고 뱃지. 없으면 회색 원 placeholder.
                          _TeamBadge(team: favoriteTeam, scale: scale),
                        ],
                      ),
                      // 이메일 — `GET /api/auth/me` 의 email 필드.
                      Text(
                        email ?? '',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                          fontSize: 14 * scale,
                          height: 1.55,
                          color: AppColors.narText2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8 * scale),
          // 우측: 프로필 수정.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onEditTap,
            child: Text(
              '프로필 수정',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 14 * scale,
                height: 1.55,
                color: AppColors.narTextTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 프로필 이미지 — 59×59 원형. [url] 이 없거나 로드 실패 시 기본 이미지.
class _ProfileImage extends StatelessWidget {
  const _ProfileImage({required this.url, required this.scale});

  final String? url;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 59 * scale;
    final fallback = Image.asset(
      'assets/images/person.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
    final hasUrl = url != null && url!.isNotEmpty;
    return ClipOval(
      child: hasUrl
          ? CachedNetworkImage(
              imageUrl: url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 150),
              errorWidget: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}

/// 응원 팀 로고 뱃지 — 23×23 원형. 팀이 없으면 회색 원 placeholder.
class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.team, required this.scale});

  final Team? team;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 23 * scale;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.narDark200,
        shape: BoxShape.circle,
      ),
    );
    final url = team?.imageUrl;
    if (url == null || url.isEmpty) return placeholder;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 150),
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}

/// 마이페이지 진입 행 (padding 좌20 우10, 높이 44).
///
/// 좌측 타이틀 + 우측 chevron. [count] 가 주어지면 chevron 앞에
/// 'N건'을 그라데이션 텍스트로 표시한다.
/// 예) '내 리뷰/평점'(건수 표시), '고객센터/문의'(건수 없음).
class _MypageLinkRow extends StatelessWidget {
  const _MypageLinkRow({
    required this.title,
    required this.scale,
    this.count,
    this.onTap,
  });

  final String title;
  final int? count;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44 * scale,
        child: Padding(
          padding: EdgeInsets.only(left: 20 * scale, right: 10 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 17 * scale,
                  height: 25 / 17,
                  color: AppColors.narText,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (count != null) ...[
                    // 'N건' — narBg 그라데이션 텍스트.
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.narBg.createShader(bounds),
                      child: Text(
                        '$count건',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                          fontSize: 14 * scale,
                          height: 25 / 14,
                          // ShaderMask 가 덮어쓰므로 흰색이어야 그라데이션이 보인다.
                          color: AppColors.narText,
                        ),
                      ),
                    ),
                    SizedBox(width: 10 * scale),
                  ],
                  SizedBox(
                    width: 44 * scale,
                    height: 44 * scale,
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/chevron-right.svg',
                        width: 24 * scale,
                        height: 24 * scale,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 마이페이지 앱정보 행 (padding 10/20, 상단 정렬).
///
/// 좌측 '앱정보' 타이틀 + 우측 버전 상태/버전 라벨 2줄.
class _AppInfoRow extends StatelessWidget {
  const _AppInfoRow({
    required this.versionStatus,
    required this.versionLabel,
    required this.scale,
  });

  /// 예) '최신 버전입니다.'
  final String versionStatus;

  /// 예) '(현재 버전 1.1.0)'
  final String versionLabel;

  final double scale;

  @override
  Widget build(BuildContext context) {
    final versionStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w500,
      fontSize: 12 * scale,
      height: 1.45,
      color: AppColors.narText2,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 10 * scale,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '앱정보',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 17 * scale,
              height: 25 / 17,
              color: AppColors.narText,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(versionStatus, style: versionStyle),
              Text(versionLabel, style: versionStyle),
            ],
          ),
        ],
      ),
    );
  }
}
