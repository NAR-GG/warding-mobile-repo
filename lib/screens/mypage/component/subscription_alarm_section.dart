import 'package:flutter/material.dart';

import '../../../components/nar_toggle.dart';
import '../../../styles/app_colors.dart';

/// 구독 팀별 알림 설정값.
/// 팀명/로고와 세트 시작·종료·라이브 이벤트 알림 ON/OFF 를 가진다.
class TeamAlarmSetting {
  TeamAlarmSetting({
    required this.teamName,
    this.logoAsset,
    this.setStart = true,
    this.setEnd = true,
    this.liveEvent = true,
  });

  final String teamName;

  /// 팀 로고 자산 경로. 없으면 placeholder 로 렌더링.
  final String? logoAsset;

  bool setStart;
  bool setEnd;
  bool liveEvent;
}

/// 마이페이지 — 구독 팀 알림 설정 섹션 (양옆 20 패딩).
///
/// 상단: '구독 팀 알림 설정' 타이틀 + '구독 관리' 액션.
/// 하단: narDark600 카드 안에 팀별 블록(로고/팀명 + 알림 토글 3개).
/// 토글은 공용 [NarToggle] 을 사용한다.
class SubscriptionAlarmSection extends StatefulWidget {
  const SubscriptionAlarmSection({
    super.key,
    this.scale = 1,
    this.onManageTap,
  });

  final double scale;
  final VoidCallback? onManageTap;

  @override
  State<SubscriptionAlarmSection> createState() =>
      _SubscriptionAlarmSectionState();
}

class _SubscriptionAlarmSectionState extends State<SubscriptionAlarmSection> {
  // TODO: API 연결 후 실제 구독 팀·알림 설정으로 교체 (현재 mock).
  final List<TeamAlarmSetting> _teams = [
    TeamAlarmSetting(teamName: 'T1', liveEvent: false),
    TeamAlarmSetting(teamName: 'DN SOOPers'),
    TeamAlarmSetting(teamName: 'Hanwha Life Esports'),
  ];

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더: 타이틀 + 구독 관리.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '구독 팀 알림 설정',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 17 * scale,
                  height: 25 / 17,
                  color: AppColors.narText,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onManageTap,
                child: Text(
                  '구독 관리',
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
          SizedBox(height: 16 * scale),
          // 카드: 팀별 블록을 8 간격으로 쌓는다.
          Container(
            padding: EdgeInsets.only(top: 10 * scale, bottom: 20 * scale),
            decoration: BoxDecoration(
              color: AppColors.narDark600,
              borderRadius: BorderRadius.circular(10 * scale),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _teams.length; i++) ...[
                  if (i > 0) SizedBox(height: 8 * scale),
                  _TeamAlarmBlock(
                    team: _teams[i],
                    onChanged: () => setState(() {}),
                    scale: scale,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 팀 한 블록: 팀 헤더(로고+팀명) + 알림 토글 3행.
class _TeamAlarmBlock extends StatelessWidget {
  const _TeamAlarmBlock({
    required this.team,
    required this.onChanged,
    required this.scale,
  });

  final TeamAlarmSetting team;
  final VoidCallback onChanged;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 팀 헤더 (padding 8/20).
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20 * scale,
            vertical: 8 * scale,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // TODO: 팀 로고 이미지 연결 — 현재 원형 placeholder.
              Container(
                width: 33 * scale,
                height: 33 * scale,
                decoration: const BoxDecoration(
                  color: AppColors.narDark200,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8 * scale),
              Text(
                team.teamName,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 16 * scale,
                  height: 19 / 16,
                  letterSpacing: 0.21 * scale,
                  color: AppColors.narText,
                ),
              ),
            ],
          ),
        ),
        // 알림 토글 3행.
        _AlarmRow(
          label: '세트 시작 알림',
          value: team.setStart,
          onChanged: (v) {
            team.setStart = v;
            onChanged();
          },
          scale: scale,
        ),
        _AlarmRow(
          label: '세트 종료 알림',
          value: team.setEnd,
          onChanged: (v) {
            team.setEnd = v;
            onChanged();
          },
          scale: scale,
        ),
        _AlarmRow(
          label: '라이브 이벤트 알림',
          value: team.liveEvent,
          onChanged: (v) {
            team.liveEvent = v;
            onChanged();
          },
          scale: scale,
        ),
      ],
    );
  }
}

/// 알림 토글 한 행: 라벨 + [NarToggle] (padding 2/20/2/60).
class _AlarmRow extends StatelessWidget {
  const _AlarmRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.scale,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(60 * scale, 2 * scale, 20 * scale, 2 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
              fontSize: 14 * scale,
              color: AppColors.narText,
            ),
          ),
          NarToggle(value: value, onChanged: onChanged, scale: scale),
        ],
      ),
    );
  }
}
