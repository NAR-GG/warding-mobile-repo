import 'package:flutter/material.dart';

import '../../components/nar_detail_header.dart';
import '../../components/nar_search_bar.dart';
import '../../styles/app_colors.dart';
import 'component/all_subscription_section.dart';
import 'component/subscribed_section.dart';

/// 구독 설정 페이지.
///
/// 마이 구독 화면의 우상단 ⚙️ 아이콘에서 진입한다.
/// 상단은 공용 [NarDetailHeader] 의 '구독 설정' 타이틀로 통일.
class SubscriptionSettingsScreen extends StatefulWidget {
  const SubscriptionSettingsScreen({super.key});

  @override
  State<SubscriptionSettingsScreen> createState() =>
      _SubscriptionSettingsScreenState();
}

class _SubscriptionSettingsScreenState
    extends State<SubscriptionSettingsScreen> {
  // TODO: API 연결 후 실제 구독 데이터로 교체 (현재 mock).
  List<SubscribedItem> _allTeams = const [
    SubscribedItem(name: 'T1', subscribed: true),
    SubscribedItem(name: 'DN SOOPers', subscribed: false),
    SubscribedItem(name: 'Hanwha Life Esports', subscribed: false),
    SubscribedItem(name: 'Gen.G', subscribed: false),
    SubscribedItem(name: 'HANJIN BRLON', subscribed: false),
  ];
  List<SubscribedItem> _allPlayers = const [
    SubscribedItem(name: 'Faker', subscribed: true),
    SubscribedItem(name: 'Chovy', subscribed: false),
    SubscribedItem(name: 'Zeus', subscribed: false),
    SubscribedItem(name: 'Keria', subscribed: false),
  ];

  /// [list] 의 index 행의 subscribed 를 토글한 새 리스트를 반환.
  List<SubscribedItem> _toggleAt(List<SubscribedItem> list, int index) {
    return [
      for (var i = 0; i < list.length; i++)
        if (i == index)
          SubscribedItem(
            name: list[i].name,
            logoUrl: list[i].logoUrl,
            subscribed: !list[i].subscribed,
          )
        else
          list[i],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    // 구독중인 항목만 필터링 — 상단 섹션들은 이걸 보여준다.
    final subscribedTeams = _allTeams.where((t) => t.subscribed).toList();
    final subscribedPlayers = _allPlayers.where((p) => p.subscribed).toList();

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            NarDetailHeader(title: '구독 설정', scale: scale),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20 * scale,
                vertical: 10 * scale,
              ),
              child: NarSearchBar(scale: scale),
            ),
            SizedBox(height: 7 * scale), // 검색바 ↔ 구독중인 팀 간격
            SubscribedSection(
              title: '구독중인 팀',
              items: subscribedTeams,
              // 구독중 섹션에서 토글하면 _allTeams 의 같은 이름 항목을 찾아 갱신.
              onToggle: (i) => setState(() {
                final target = subscribedTeams[i];
                final idx = _allTeams.indexWhere((t) => t.name == target.name);
                if (idx >= 0) _allTeams = _toggleAt(_allTeams, idx);
              }),
              scale: scale,
            ),
            SizedBox(height: 14 * scale), // 구독중인 팀 ↔ 구독중인 선수 간격
            SubscribedSection(
              title: '구독중인 선수',
              items: subscribedPlayers,
              onToggle: (i) => setState(() {
                final target = subscribedPlayers[i];
                final idx =
                    _allPlayers.indexWhere((p) => p.name == target.name);
                if (idx >= 0) _allPlayers = _toggleAt(_allPlayers, idx);
              }),
              scale: scale,
            ),
            SizedBox(height: 14 * scale), // 구독중인 선수 ↔ 전체 목록 간격
            AllSubscriptionSection(
              teams: _allTeams,
              players: _allPlayers,
              onTeamToggle: (i) =>
                  setState(() => _allTeams = _toggleAt(_allTeams, i)),
              onPlayerToggle: (i) =>
                  setState(() => _allPlayers = _toggleAt(_allPlayers, i)),
              scale: scale,
            ),
          ],
        ),
      ),
    );
  }
}
