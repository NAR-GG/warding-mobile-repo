import 'package:flutter/material.dart';

import '../../components/nar_detail_header.dart';
import '../../components/nar_search_bar.dart';
import '../../model/player_subscription.dart';
import '../../model/team_notification_subscription.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/subscription/subscription_settings_viewmodel.dart';
import 'component/all_subscription_section.dart';
import 'component/subscribed_section.dart';

/// 구독 설정 페이지.
///
/// 마이 구독 화면의 우상단 ⚙️ 아이콘에서 진입한다.
/// 팀은 `notification-subscriptions`, 선수는 `player-subscriptions` API 로
/// 구독 목록을 받아 토글한다. (팀 알림 세부 설정은 마이페이지에서 한다.)
class SubscriptionSettingsScreen extends StatefulWidget {
  const SubscriptionSettingsScreen({super.key});

  @override
  State<SubscriptionSettingsScreen> createState() =>
      _SubscriptionSettingsScreenState();
}

class _SubscriptionSettingsScreenState
    extends State<SubscriptionSettingsScreen> {
  final SubscriptionSettingsViewModel _viewModel =
      SubscriptionSettingsViewModel();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// '전체 목록' 섹션 탭. 0: 팀, 1: 선수.
  int _allTab = 0;

  /// 팀명이 [query] 를 포함하면(대소문자 무시) true. 빈 검색어면 항상 true.
  bool _teamMatches(TeamNotificationSubscription t, String query) =>
      query.isEmpty || t.teamName.toLowerCase().contains(query);

  /// 검색을 실행한다. 선수는 서버 조회, 팀은 이미 받아둔 목록을 클라에서 거른다.
  /// 검색 후에는 결과가 있는 탭으로 전환해 (build 에서) 결과 섹션을 최상단에 노출한다.
  Future<void> _onSearch(String query) async {
    await _viewModel.searchPlayers(query);
    if (!mounted) return;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return;
    final hasPlayers = _viewModel.availablePlayers.isNotEmpty;
    final hasTeams = _viewModel.availableTeams.any((t) => _teamMatches(t, q));
    // 선수 결과가 있으면 '선수', 없고 팀만 있으면 '팀' 탭으로.
    setState(() => _allTab = hasPlayers ? 1 : (hasTeams ? 0 : 1));
  }

  @override
  void initState() {
    super.initState();
    // 끝에 가까워지면 다음 선수 페이지를 이어 붙인다. (전체 목록 '선수' 무한 스크롤)
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _viewModel.loadMorePlayers();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _viewModel.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 팀 → 섹션 행 데이터 변환.
  SubscribedItem _teamItem(TeamNotificationSubscription t) => SubscribedItem(
        name: t.teamName,
        logoUrl: t.teamImageUrl,
        subscribed: t.subscribed,
      );

  /// 선수 → 섹션 행 데이터 변환.
  SubscribedItem _playerItem(PlayerSubscription p) => SubscribedItem(
        name: p.playerName,
        logoUrl: p.playerImageUrl,
        subscribed: p.subscribed,
      );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            final subscribedTeams = _viewModel.subscribedTeams;
            final subscribedPlayers = _viewModel.subscribedPlayers;
            final query = _viewModel.query.trim().toLowerCase();
            // 팀은 클라에서 검색어로 거른다(선수는 서버가 이미 걸러 내려준다).
            final allTeams = [
              for (final t in _viewModel.availableTeams)
                if (_teamMatches(t, query)) t,
            ];
            final allPlayers = _viewModel.availablePlayers;
            // 검색어가 있으면 검색 결과(전체 목록) 섹션을 최상단으로 올린다.
            final hasQuery = query.isNotEmpty;

            final subscribedSections = <Widget>[
              SubscribedSection(
                title: '구독중인 팀',
                items: [for (final t in subscribedTeams) _teamItem(t)],
                onToggle: (i) {
                  final t = subscribedTeams[i];
                  _viewModel.toggleTeam(t.teamId, t.subscribed);
                },
                scale: scale,
              ),
              SizedBox(height: 14 * scale),
              SubscribedSection(
                title: '구독중인 선수',
                items: [for (final p in subscribedPlayers) _playerItem(p)],
                onToggle: (i) {
                  final p = subscribedPlayers[i];
                  _viewModel.togglePlayer(p.playerId, p.subscribed);
                },
                scale: scale,
              ),
            ];

            final allSection = AllSubscriptionSection(
              teams: [for (final t in allTeams) _teamItem(t)],
              players: [for (final p in allPlayers) _playerItem(p)],
              selectedTab: _allTab,
              onTabChanged: (i) => setState(() => _allTab = i),
              onTeamToggle: (i) {
                final t = allTeams[i];
                _viewModel.toggleTeam(t.teamId, t.subscribed);
              },
              onPlayerToggle: (i) {
                final p = allPlayers[i];
                _viewModel.togglePlayer(p.playerId, p.subscribed);
              },
              playersLoading: _viewModel.loadingAvailablePlayers,
              playersLoadingMore: _viewModel.loadingMorePlayers,
              scale: scale,
            );

            return ListView(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              children: [
                NarDetailHeader(title: '구독 설정', scale: scale),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20 * scale,
                    vertical: 10 * scale,
                  ),
                  // 입력 후 검색(엔터/돋보기)하면 선수 목록을 다시 조회한다.
                  child: NarSearchBar(
                    controller: _searchController,
                    scale: scale,
                    onSubmitted: _onSearch,
                    onSearchTap: () => _onSearch(_searchController.text),
                  ),
                ),
                SizedBox(height: 7 * scale),
                // 검색 중이면 결과(전체 목록) 섹션을 검색창 바로 아래에 둔다.
                if (hasQuery) ...[
                  allSection,
                  SizedBox(height: 14 * scale),
                  ...subscribedSections,
                ] else ...[
                  ...subscribedSections,
                  SizedBox(height: 14 * scale),
                  allSection,
                ],
                SizedBox(height: 20 * scale),
              ],
            );
          },
        ),
      ),
    );
  }
}
