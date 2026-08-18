import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/guest_lock_overlay.dart';
import '../../components/guide_popup.dart';
import '../../components/nar_banner.dart';
import '../../model/team.dart';
import '../../config/app_language.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import '../../viewmodel/mypage/mypage_viewmodel.dart';
import 'component/language_setting_sheet.dart';
import 'component/mypage_card_section.dart';
import 'component/quiet_hours_section.dart';
import '../account_setting/account_setting_screen.dart';
import '../calendar_setting/calendar_setting_screen.dart';
import '../match_list/match_list_screen.dart';
import '../match_list_setting/match_list_setting_screen.dart';
import '../my_review/my_review_screen.dart';
import '../my_subscription_setting/my_subscription_setting_screen.dart';
import '../notice/notice_screen.dart';
import '../profile_edit/profile_edit_screen.dart';
import '../schedule/schedule_screen.dart';
import '../subscription/subscription_screen.dart';

/// 마이페이지. 하단 네비 '마이페이지' 탭에 해당한다.
class MypageScreen extends StatefulWidget {
  const MypageScreen({super.key});

  @override
  State<MypageScreen> createState() => _MypageScreenState();
}

class _MypageScreenState extends State<MypageScreen> {
  final MypageViewModel _viewModel = MypageViewModel();

  /// 목록을 내리는 동안 하단 네비를 살짝 줄이는 상태.
  final BottomNavShrinkController _navShrink = BottomNavShrinkController();

  @override
  void dispose() {
    _viewModel.dispose();
    _navShrink.dispose();
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
            NotificationListener<ScrollNotification>(
              onNotification: _navShrink.handleNotification,
              child: GuestLockOverlay(
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
                            currentLanguage: AppLanguage.toLabel(AppLanguage.instance.current),
                            onChanged: (lang) {
                              AppLanguage.instance.setLanguage(AppLanguage.fromLabel(lang));
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
                                text: AppLocalizations.of(context)!.teamAutoSetBanner,
                              )
                            : const SizedBox.shrink(),
                      ),
                      SizedBox(height: 11 * scale),
                      // 내 활동 — 리뷰/평점 등 사용자 활동 진입점.
                      // 행을 늘리려면 items 에 MypageCardItem 만 추가하면 된다.
                      ListenableBuilder(
                        listenable: _viewModel,
                        builder: (context, _) => MypageCardSection(
                          scale: scale,
                          label: AppLocalizations.of(context)!.myActivity,
                          items: [
                            MypageCardItem(
                              title: AppLocalizations.of(context)!.myReviewRating,
                              count: _viewModel.reviewCount,
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
                          ],
                        ),
                      ),
                      SizedBox(height: 16 * scale),
                      // 화면 설정 — 화면별 표시 설정 진입점.
                      // 하위 설정 화면이 준비되면 각 항목에 onTap 만 연결하면 된다.
                      MypageCardSection(
                        scale: scale,
                        label: AppLocalizations.of(context)!.screenSetting,
                        items: [
                          MypageCardItem(
                            title: AppLocalizations.of(context)!.mySubscription,
                            leadingIcon: 'assets/icons/empty-stars.svg',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const MySubscriptionSettingScreen(),
                                ),
                              );
                            },
                          ),
                          MypageCardItem(
                            title: AppLocalizations.of(
                              context,
                            )!.screenSettingMatchList,
                            leadingIcon: 'assets/icons/layout-list.svg',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const MatchListSettingScreen(),
                                ),
                              );
                            },
                          ),
                          MypageCardItem(
                            title: AppLocalizations.of(
                              context,
                            )!.screenSettingCalendar,
                            leadingIcon: 'assets/icons/calendar-event.svg',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const CalendarSettingScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 16 * scale),
                      // 일반 설정 — 방해 금지 모드.
                      QuietHoursSection(scale: scale),
                      SizedBox(height: 16 * scale),
                      // 고객 지원 — 공지사항·문의·계정·나르지지 웹사이트.
                      // '계정'은 하위 화면이 준비되면 onTap 만 연결하면 된다.
                      MypageCardSection(
                        scale: scale,
                        label: AppLocalizations.of(context)!.customerSupport,
                        items: [
                          MypageCardItem(
                            title: AppLocalizations.of(context)!.notice,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const NoticeScreen(),
                                ),
                              );
                            },
                          ),
                          MypageCardItem(
                            title: AppLocalizations.of(context)!.guideMenu,
                            // 직접 찾아 들어온 경로라 안내 팝업을 거치지 않고
                            // 가이드 본문을 바로 연다.
                            onTap: () => openGuideScreen(context),
                          ),
                          MypageCardItem(
                            title: AppLocalizations.of(context)!.customerService,
                            onTap: () => _launchUrl(
                              'https://docs.google.com/forms/d/e/1FAIpQLSf66NkvON3YrFR0n_CSbnzyjXlEEfO8eiIc9W_2TBYulvihMA/viewform',
                            ),
                          ),
                          MypageCardItem(
                            title: AppLocalizations.of(context)!.account,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const AccountSettingScreen(),
                                ),
                              );
                            },
                          ),
                          MypageCardItem(
                            title: AppLocalizations.of(context)!.narWebsite,
                            description: AppLocalizations.of(
                              context,
                            )!.narWebsiteDescription,
                            onTap: () => _launchUrl('https://nar.kr/'),
                          ),
                        ],
                      ),
                      SizedBox(height: 16 * scale),
                      ListenableBuilder(
                        listenable: _viewModel,
                        builder: (context, _) => _AppInfoRow(
                          versionStatus: AppLocalizations.of(context)!.latestVersion,
                          versionLabel: _viewModel.appVersion.isNotEmpty
                              ? AppLocalizations.of(context)!.currentVersion(_viewModel.appVersion)
                              : '',
                          scale: scale,
                        ),
                      ),
                      // 하단 네비에 가리지 않도록 여백.
                      SizedBox(height: 166 * scale),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 26,
              child: ListenableBuilder(
                listenable: _navShrink,
                builder: (context, _) => AppBottomNav(
                  currentTab: AppNavTab.mypage,
                  onTabSelected: (tab) => _onTabSelected(context, tab),
                  compact: _navShrink.compact,
                ),
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
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 17 * scale, 20 * scale, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l.myPage,
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
    final l = AppLocalizations.of(context)!;
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
                              nickname.isEmpty ? l.nicknamePlaceholder : nickname,
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
              l.profileEdit,
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
    final l = AppLocalizations.of(context)!;
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
            l.appInfo,
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
