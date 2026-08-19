import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/notification_card.dart';
import '../../../config/app_language.dart';
import '../../../util/champion_name_map.dart';
import '../../../util/korean_particle.dart';

/// 선수 랭크 시작 감지 알림. 좌측 headset 아이콘 + 선수/챔피언/큐 정보.
/// OP.GG 이동은 카드 전체 탭으로 처리하므로 카드 안에는 링크를 두지 않는다.
class RankStartNotification extends StatelessWidget {
  const RankStartNotification({
    super.key,
    required this.playerName,
    required this.champion,
    required this.dateTime,
    required this.relativeTime,
    this.queueType,
    this.scale = 1,
  });

  /// 선수명 (예: 'Faker').
  final String playerName;

  /// 챔피언명 (예: '아지르').
  final String champion;

  /// 큐 타입 (예: '솔로 랭크'). null 이면 로케일에 맞는 기본값 사용.
  final String? queueType;

  final String dateTime;
  final String relativeTime;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isEn = !AppLanguage.instance.isKo;
    final resolvedQueue = isEn ? l.soloRank : (queueType ?? l.soloRank);
    final resolvedChampion = isEn ? championToEn(champion) : champion;
    final particle = isEn ? '' : particleEuro(resolvedChampion);
    return NotificationCard(
      icon: 'assets/icons/headset.svg',
      title: l.rankStartTitle(playerName),
      body: l.rankStartBody(resolvedChampion, particle, resolvedQueue),
      dateTime: dateTime,
      relativeTime: relativeTime,
      scale: scale,
    );
  }
}
