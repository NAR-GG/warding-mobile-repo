import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/app_bottom_sheet.dart';
import '../../components/nar_chip_multi_select.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import '../match_list/match_list_screen.dart';
import '../mypage/mypage_screen.dart';
import '../schedule/schedule_screen.dart';
import 'component/live_event_notification.dart';
import 'component/match_end_notification.dart';
import 'component/match_start_notification.dart';
import 'component/player_filter_chip.dart';
import 'component/player_select_sheet.dart';
import 'component/rank_start_notification.dart';
import 'subscription_settings_screen.dart';

/// 마이 구독 페이지. 하단 네비 '마이 구독' 탭에 해당한다.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  /// 이벤트 타입 필터 옵션. 첫 항목 '전체'는 나머지와 배타적으로 동작한다.
  static const List<String> _eventTypes = ['전체', '세트 시작', '세트 종료'];

  /// 구독한 선수 목록 (추후 구독 데이터 API 연동).
  static const List<String> _players = [
    'Faker',
    '선수2',
    '선수3',
    '선수4',
    '선수5',
    '선수6',
  ];

  // 초기 상태 — 필터 없음('전체'만 활성).
  Set<String> _selectedTypes = {'전체'};
  Set<String> _selectedPlayers = {};

  /// '전체' 활성 조건을 다른 필터와 동기화한다.
  /// 세트 타입·선수 중 하나라도 선택돼 있으면 '전체'를 해제하고,
  /// 아무 필터도 없으면 '전체'를 활성한다.
  void _syncAll() {
    final hasFilter =
        _selectedTypes.any((t) => t != '전체') || _selectedPlayers.isNotEmpty;
    _selectedTypes = hasFilter ? (_selectedTypes..remove('전체')) : {'전체'};
  }

  /// 이벤트 타입 필터 토글. '전체'를 고르면 세트 타입·선수 필터를 모두 비운다.
  void _onTypesChanged(Set<String> next) {
    final added = next.difference(_selectedTypes);
    setState(() {
      if (added.contains('전체')) {
        _selectedTypes = {'전체'};
        _selectedPlayers = {};
      } else {
        _selectedTypes = next;
        _syncAll();
      }
    });
  }

  /// '선수전체' 드롭다운 탭 → 선수 선택 바텀시트. 조회 시 선택 결과를 반영한다.
  /// 선수를 고르면 '전체' 필터는 자동 해제된다.
  Future<void> _openPlayerSelect() async {
    final result = await showAppBottomSheet<Set<String>>(
      context: context,
      child: PlayerSelectSheet(
        players: _players,
        initialSelected: _selectedPlayers,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedPlayers = result;
        _syncAll();
      });
    }
  }

  /// 하단 네비 탭 선택. '마이 구독'을 제외한 탭이면 해당 화면으로 전환한다.
  void _onTabSelected(AppNavTab tab) {
    if (tab == AppNavTab.schedule) {
      Navigator.of(context).pushReplacement(tabRoute(const ScheduleScreen()));
    } else if (tab == AppNavTab.list) {
      Navigator.of(context).pushReplacement(tabRoute(const MatchListScreen()));
    } else if (tab == AppNavTab.mypage) {
      Navigator.of(context).pushReplacement(tabRoute(const MypageScreen()));
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SubscriptionHeader(
                  scale: scale,
                  onSettingsTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionSettingsScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 14 * scale), // 헤더 ↔ 필터 간격
                NarChipMultiSelect(
                  options: _eventTypes,
                  selectedValues: _selectedTypes,
                  onChanged: _onTypesChanged,
                  pinned: const {'전체'}, // '전체'는 항상 맨 앞 고정
                  scale: scale,
                  trailing: [
                    (
                      widget: PlayerFilterChip(
                        players: _players,
                        selected: _selectedPlayers,
                        scale: scale,
                        onTap: _openPlayerSelect,
                        onClear: () => setState(() {
                          _selectedPlayers = {};
                          _syncAll();
                        }),
                      ),
                      // 선택되면(보라 활성) 앞으로 정렬에 참여.
                      selected: _selectedPlayers.isNotEmpty,
                    ),
                  ],
                ),
                // 알림 피드 — 네비바에 가리지 않게 하단 패딩.
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(bottom: 120 * scale),
                    children: [
                      RankStartNotification(
                        playerName: 'Faker',
                        champion: '아지르',
                        dateTime: '2026-05-07 15:47',
                        relativeTime: '30분 전',
                        scale: scale,
                      ),
                      MatchEndNotification(
                        teamA: 'T1',
                        teamB: 'GEN',
                        season: 'LCK 2026 시즌',
                        dateTime: '2026-05-07 15:47',
                        relativeTime: '1시간 전',
                        onRatingTap: () {
                          // TODO: 경기 평점 화면 연결
                        },
                        scale: scale,
                      ),
                      LiveEventNotification(
                        teamA: 'T1',
                        teamB: 'GEN',
                        season: 'LCK 2026 시즌',
                        dateTime: '2026-05-07',
                        relativeTime: '2시간 전',
                        events: const [
                          LiveEventData(
                            time: '17:34',
                            source: LiveActor.champion(name: 'Faker'),
                            target: LiveActor.objective(
                              name: '드래곤',
                              asset: 'assets/images/cloud-dragon.png',
                            ),
                          ),
                          LiveEventData(
                            time: '10:34',
                            source: LiveActor.champion(name: 'Faker'),
                            target: LiveActor.champion(name: 'Chovy'),
                          ),
                        ],
                        scale: scale,
                      ),
                      MatchStartNotification(
                        teamA: 'T1',
                        teamB: 'GEN',
                        season: 'LCK 2026 시즌',
                        dateTime: '2026-05-07 15:47',
                        relativeTime: '3시간 전',
                        scale: scale,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 26,
              child: AppBottomNav(
                currentTab: AppNavTab.subscription,
                onTabSelected: _onTabSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 마이 구독 헤더. 좌측 타이틀 + 우측 설정 아이콘 (양옆 20 패딩).
class _SubscriptionHeader extends StatelessWidget {
  const _SubscriptionHeader({required this.scale, this.onSettingsTap});

  final double scale;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 17 * scale, 20 * scale, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '마이 구독',
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
            onTap: onSettingsTap,
            child: SvgPicture.asset(
              'assets/icons/settings.svg',
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
