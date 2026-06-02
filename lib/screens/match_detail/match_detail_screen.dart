import 'package:flutter/material.dart';

import '../../components/app_bottom_sheet.dart';
import '../../components/nar_badge.dart';
import '../../components/nar_button.dart';
import '../../components/nar_detail_header.dart';
import '../../components/nar_dropdown.dart';
import '../../components/nar_tab_bar.dart';
import '../../styles/app_colors.dart';
import '../player_rating/player_rating_screen.dart';
import 'component/match_detail_champion_pick_section.dart';
import 'component/match_detail_live_event_section.dart';
import 'component/match_detail_player_rating_section.dart';
import 'component/match_detail_score_section.dart';
import 'component/match_detail_team_rating_section.dart';

/// 경기 상세 페이지. 경기 리스트에서 카드를 탭하면 진입한다.
class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({super.key});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  static const List<String> _tabs = ['챔피언 픽', '라이브 이벤트', '선수 평점'];
  int _tabIndex = 0;

  // TODO: API 연결 후 매치 데이터에서 세트 목록 동적 수신 (현재 Bo5 mock).
  static const List<String> _sets = ['세트 1', '세트 2', '세트 3', '세트 4', '세트 5'];
  String _currentSet = '세트 1';

  /// 헤더의 세트 드롭다운 탭 시 호출. 세트 목록 바텀시트를 띄우고 선택값으로 갱신.
  Future<void> _showSetSheet() async {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    final selected = await showAppBottomSheet<String>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final setLabel in _sets)
            InkWell(
              onTap: () => Navigator.of(context).pop(setLabel),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 14 * scale,
                ),
                child: Text(
                  setLabel,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight:
                        setLabel == _currentSet
                            ? FontWeight.w600
                            : FontWeight.w400,
                    fontSize: 16 * scale,
                    color:
                        setLabel == _currentSet
                            ? AppColors.narText
                            : AppColors.narText2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (selected != null && selected != _currentSet) {
      setState(() => _currentSet = selected);
    }
  }

  /// 선수 평점 행 탭 시 호출. 선수 평점 상세 페이지로 이동한다.
  void _openPlayerRating(PlayerRating player, String teamName, BadgeSide side) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PlayerRatingScreen(
              player: player,
              teamName: teamName,
              side: side,
              sets: _sets,
              initialSet: _currentSet,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 헤더·스코어·중계 버튼·탭바: 스크롤 시 함께 위로 밀려 올라간다.
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NarDetailHeader(
                    title: '경기 상세',
                    trailing: NarDropdown(
                      variant: NarDropdownVariant.round,
                      value: _currentSet,
                      onTap: _showSetSheet,
                      scale: scale,
                    ),
                    scale: scale,
                  ),
                  MatchDetailScoreSection(
                    leagueName: 'LCK 2025 스프링',
                    dateText: '25.04.13',
                    isLive: true,
                    time: '17:00',
                    blueTeamName: 'DNS',
                    redTeamName: 'T1',
                    blueTeamScore: 2,
                    redTeamScore: 1,
                    setLabel: 'SET 1 진행중',
                    scale: scale,
                  ),
                  SizedBox(height: 16 * scale),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                    child: NarButton(
                      variant: NarButtonVariant.set1,
                      label: '중계 보기',
                      onPressed: () {
                        // TODO: 중계 영상/링크 연결
                      },
                      scale: scale,
                    ),
                  ),
                  SizedBox(height: 16 * scale),
                  NarTabBar(
                    tabs: _tabs,
                    selectedIndex: _tabIndex,
                    onChanged: (i) => setState(() => _tabIndex = i),
                    scale: scale,
                  ),
                ],
              ),
            ),
            if (_tabIndex == 0)
              SliverToBoxAdapter(
                child: MatchDetailChampionPickSection(
                  blueTeamName: 'DNS',
                  redTeamName: 'T1',
                  blueBans: const [null, null, null, null, null],
                  redBans: const [null, null, null, null, null],
                  bluePicks: const [null, null, null, null, null],
                  redPicks: const [null, null, null, null, null],
                  bluePlayerNames: const ['bin', 'XUN', 'Knight', 'ELK', 'ON'],
                  redPlayerNames: const [
                    'Doran',
                    'Oner',
                    'Faker',
                    'Gumayusi',
                    'Keria',
                  ],
                  scale: scale,
                ),
              ),
            if (_tabIndex == 1)
              SliverToBoxAdapter(
                child: MatchDetailLiveEventSection(scale: scale),
              ),
            // 선수 평점 탭: 배너+멀티셀렉터가 pinned 되는 슬리버 묶음을 직접 넣는다.
            if (_tabIndex == 2)
              MatchDetailPlayerRatingSection(
                setLabel: _currentSet,
                blueTeamName: 'DNS',
                redTeamName: 'T1',
                // TODO: API 연결 후 실제 선수별 평점 데이터로 교체 (현재 mock).
                bluePlayers: const [
                  PlayerRating(
                    name: 'DuDu',
                    position: '탑',
                    rating: 4.5,
                    raterCount: 23,
                  ),
                  PlayerRating(
                    name: 'Pyosik',
                    position: '정글',
                    rating: 4.5,
                    raterCount: 23,
                  ),
                  PlayerRating(
                    name: 'Clozer',
                    position: '미드',
                    rating: 4.5,
                    raterCount: 23,
                  ),
                  PlayerRating(
                    name: 'deokdam',
                    position: '원딜',
                    rating: 4.5,
                    raterCount: 23,
                  ),
                  PlayerRating(
                    name: 'Peter',
                    position: '서폿',
                    rating: 4.5,
                    raterCount: 23,
                  ),
                ],
                redPlayers: const [
                  PlayerRating(
                    name: 'Doran',
                    position: '탑',
                    rating: 4.5,
                    raterCount: 23,
                  ),
                  PlayerRating(
                    name: 'Oner',
                    position: '정글',
                    rating: 4.5,
                    raterCount: 23,
                  ),
                  PlayerRating(
                    name: 'Faker',
                    position: '미드',
                    rating: 4.5,
                    raterCount: 23,
                  ),
                  PlayerRating(
                    name: 'Gumayusi',
                    position: '원딜',
                    rating: 4.5,
                    raterCount: 23,
                  ),
                  PlayerRating(
                    name: 'Keria',
                    position: '서폿',
                    rating: 4.5,
                    raterCount: 23,
                  ),
                ],
                onPlayerTap: _openPlayerRating,
                scale: scale,
              ),
          ],
        ),
      ),
    );
  }
}
