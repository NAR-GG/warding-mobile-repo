import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/common_button.dart';
import '../../components/nar_banner.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import 'component/subscription_alarm_section.dart';
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
  /// 응원팀 자동 설정 안내 배너 노출 여부.
  /// 초반에만 노출하고, 배너를 탭해 프로필 수정으로 이동하면 사라진다.
  bool _showTeamBanner = true;

  /// 프로필 수정 화면으로 이동. 이동 시 안내 배너는 더 이상 노출하지 않는다.
  void _goToProfileEdit() {
    setState(() => _showTeamBanner = false);
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProfileEditScreen()));
  }

  /// 구독 관리 — 구독 설정 화면으로 이동.
  void _goToSubscriptionSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SubscriptionSettingsScreen(),
      ),
    );
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
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MypageHeader(
                    scale: scale,
                    onBellTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 4 * scale),
                  _MypageProfile(scale: scale, onEditTap: _goToProfileEdit),
                  // 응원팀 자동 설정 안내 배너 — 초반에만 노출, 탭하면 프로필 수정으로
                  // 이동하며 사라진다.
                  if (_showTeamBanner)
                    NarBanner(
                      scale: scale,
                      onTap: _goToProfileEdit,
                      icon: SvgPicture.asset(
                        'assets/icons/heart.svg',
                        width: 24 * scale,
                        height: 24 * scale,
                      ),
                      text: '설문 기반으로 응원하는 팀이 자동으로 설정됐어요!',
                    ),
                  SizedBox(height: 20 * scale),
                  SubscriptionAlarmSection(
                    scale: scale,
                    onManageTap: _goToSubscriptionSettings,
                  ),
                  SizedBox(height: 16 * scale),
                  _MypageLinkRow(
                    title: '내 리뷰/평점',
                    // TODO: 실제 리뷰/평점 건수로 교체 (현재 mock).
                    count: 3,
                    scale: scale,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MyReviewScreen(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 16 * scale),
                  _MypageLinkRow(
                    title: '고객센터/문의',
                    scale: scale,
                    onTap:
                        () => _launchUrl(
                          'https://discord.com/channels/1441277795945807874/1441304369470640138',
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
                        onPressed: () {
                          // TODO: 로그아웃 처리
                        },
                      ),
                      SizedBox(width: 40 * scale),
                      CommonButton(
                        label: '회원탈퇴',
                        variant: CommonButtonVariant.text,
                        scale: scale,
                        onPressed: () {
                          // TODO: 회원탈퇴 처리
                        },
                      ),
                    ],
                  ),
                  // 하단 네비에 가리지 않도록 여백.
                  SizedBox(height: 166 * scale),
                ],
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

/// 마이페이지 헤더. 좌측 타이틀 + 우측 알림(bell) 아이콘 (양옆 20 패딩).
class _MypageHeader extends StatelessWidget {
  const _MypageHeader({required this.scale, this.onBellTap});

  final double scale;
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
    );
  }
}

/// 마이페이지 프로필 섹션 (양옆 20 패딩).
///
/// 좌측: 기본 프로필 이미지(59) + 닉네임/팀 뱃지 + 이메일.
/// 우측: '프로필 수정' 텍스트 버튼.
class _MypageProfile extends StatelessWidget {
  const _MypageProfile({required this.scale, this.onEditTap});

  final double scale;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 좌측: 프로필 이미지 + 닉네임/이메일.
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 기본 프로필 이미지.
              ClipOval(
                child: Image.asset(
                  'assets/images/person.png',
                  width: 59 * scale,
                  height: 59 * scale,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(width: 16 * scale),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 닉네임 + 팀 프로필 뱃지.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        // TODO: 실제 닉네임으로 교체 (현재 mock).
                        '닉네임',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          fontSize: 16 * scale,
                          height: 1.55,
                          color: AppColors.narText,
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      // TODO: 팀 프로필 뱃지 이미지 연결 — 현재 원형 placeholder.
                      Container(
                        width: 23 * scale,
                        height: 23 * scale,
                        decoration: const BoxDecoration(
                          color: AppColors.narDark200,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  // 이메일.
                  Text(
                    // TODO: 실제 이메일로 교체 (현재 mock).
                    'faker99@email.com',
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
            ],
          ),
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
                      shaderCallback:
                          (bounds) => AppColors.narBg.createShader(bounds),
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
