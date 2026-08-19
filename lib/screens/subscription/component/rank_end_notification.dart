import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/notification_card.dart';
import '../../../config/app_language.dart';
import '../../../util/champion_name_map.dart';
import '../../../util/korean_particle.dart';

/// 선수 솔랭 **종료** 알림. 레이아웃은 [RankStartNotification] 과 같고 문구만 다르다.
///
/// 서버 `title`/`body` 대신 여기서 다시 조립하는 이유는 시작 알림과 같다 —
/// 서버 문구는 한국어 고정이라 영어 로케일을 못 맞춘다. 그래서 승패([win])와
/// KDA([kda]) 를 원자값으로 받아 로케일별로 편다.
///
/// [win], [kda], [durationSeconds] 는 각각 없을 수 있다. match-v5 결과를
/// 못 읽은 종료 알림은 win·kda 가 둘 다 비고, 그때는 '{챔피언} 경기 종료' 로만
/// 표시한다.
class RankEndNotification extends StatelessWidget {
  const RankEndNotification({
    super.key,
    required this.playerName,
    required this.champion,
    required this.dateTime,
    required this.relativeTime,
    this.win,
    this.kda,
    this.durationSeconds,
    this.scale = 1,
  });

  /// 선수명 (예: 'Faker').
  final String playerName;

  /// 챔피언명 (예: '아지르').
  final String champion;

  /// 승패. null 이면 결과를 못 읽은 경우.
  final bool? win;

  /// 'K/D/A' 문자열 (예: '18/1/11'). null 이면 KDA 를 생략한다.
  final String? kda;

  /// 경기 길이(초). null 이거나 1분 미만이면 표기를 생략한다 —
  /// '0분' 은 정보가 아니라 오해를 만든다.
  final int? durationSeconds;

  final String dateTime;
  final String relativeTime;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isEn = !AppLanguage.instance.isKo;
    final resolvedChampion = isEn ? championToEn(champion) : champion;

    final String body;
    if (win == null) {
      body = l.rankEndBodyNoResult(resolvedChampion);
    } else {
      final particle = isEn ? '' : particleEuro(resolvedChampion);
      final result = win! ? l.rankEndWin : l.rankEndLose;
      final base = l.rankEndBodyResult(resolvedChampion, particle, result);
      // KDA 는 언어와 무관한 숫자라 로케일 문구 뒤에 그대로 붙인다.
      final withKda = (kda == null || kda!.isEmpty) ? base : '$base · $kda';
      final minutes = (durationSeconds ?? 0) ~/ 60;
      body = minutes < 1
          ? withKda
          : '$withKda · ${l.rankEndDurationMinutes(minutes)}';
    }

    return NotificationCard(
      icon: 'assets/icons/headset.svg',
      title: l.rankEndTitle(playerName),
      body: body,
      dateTime: dateTime,
      relativeTime: relativeTime,
      scale: scale,
    );
  }
}
