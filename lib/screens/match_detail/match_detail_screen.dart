import 'package:flutter/material.dart';

import '../../components/app_bottom_sheet.dart';
import '../../components/nar_button.dart';
import '../../components/nar_tab_bar.dart';
import '../../styles/app_colors.dart';
import 'component/match_detail_champion_pick_section.dart';
import 'component/match_detail_header.dart';
import 'component/match_detail_live_event_section.dart';
import 'component/match_detail_score_section.dart';

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
                    fontWeight: setLabel == _currentSet
                        ? FontWeight.w600
                        : FontWeight.w400,
                    fontSize: 16 * scale,
                    color: setLabel == _currentSet
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MatchDetailHeader(
                setLabel: _currentSet,
                onSetTap: _showSetSheet,
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
                padding: EdgeInsets.symmetric(horizontal: 10 * scale),
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
              if (_tabIndex == 0)
                MatchDetailChampionPickSection(
                  blueTeamName: 'DNS',
                  redTeamName: 'T1',
                  blueBans: const [null, null, null, null, null],
                  redBans: const [null, null, null, null, null],
                  bluePicks: const [null, null, null, null, null],
                  redPicks: const [null, null, null, null, null],
                  bluePlayerNames: const ['bin', 'XUN', 'Knight', 'ELK', 'ON'],
                  redPlayerNames: const ['Doran', 'Oner', 'Faker', 'Gumayusi', 'Keria'],
                  scale: scale,
                ),
              if (_tabIndex == 1)
                MatchDetailLiveEventSection(scale: scale),
            ],
          ),
        ),
      ),
    );
  }
}
