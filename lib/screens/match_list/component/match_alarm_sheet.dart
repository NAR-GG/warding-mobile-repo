import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/app_bottom_sheet.dart';
import '../../../components/common_button.dart';
import '../../../components/nar_toggle.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';

/// 경기 카드의 벨 아이콘을 탭했을 때 뜨는 '경기 알림 설정' 바텀시트를 띄운다.
/// 하단 확인 버튼으로 닫히면 true, 닫기(X)나 바깥 탭으로 닫히면 null 을 반환한다.
Future<bool?> showMatchAlarmSheet({
  required BuildContext context,
  required String homeName,
  String? homeLogoUrl,
  required String awayName,
  String? awayLogoUrl,
}) {
  return showAppBottomSheet<bool>(
    context: context,
    child: MatchAlarmSheet(
      homeName: homeName,
      homeLogoUrl: homeLogoUrl,
      awayName: awayName,
      awayLogoUrl: awayLogoUrl,
    ),
  );
}

/// 경기 알림 설정 시트 본문.
/// 상단 [타이틀 + 대진 표시] · 닫기 버튼, 알림 토글 3행, 하단 확인 버튼.
///
/// 토글은 현재 화면 안에서만 유지되는 로컬 상태다(서버 연동 없음).
class MatchAlarmSheet extends StatefulWidget {
  const MatchAlarmSheet({
    super.key,
    required this.homeName,
    this.homeLogoUrl,
    required this.awayName,
    this.awayLogoUrl,
  });

  final String homeName;
  final String? homeLogoUrl;
  final String awayName;
  final String? awayLogoUrl;

  @override
  State<MatchAlarmSheet> createState() => _MatchAlarmSheetState();
}

class _MatchAlarmSheetState extends State<MatchAlarmSheet> {
  bool _setStart = true;
  bool _setEnd = true;
  bool _liveEvent = true;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          homeName: widget.homeName,
          homeLogoUrl: widget.homeLogoUrl,
          awayName: widget.awayName,
          awayLogoUrl: widget.awayLogoUrl,
          scale: scale,
          onClose: () => Navigator.of(context).pop(),
        ),
        SizedBox(height: 12 * scale),
        _AlarmRow(
          label: '세트 시작 알림',
          value: _setStart,
          onChanged: (v) => setState(() => _setStart = v),
          scale: scale,
        ),
        _AlarmRow(
          label: '세트 종료 알림',
          value: _setEnd,
          onChanged: (v) => setState(() => _setEnd = v),
          scale: scale,
        ),
        _AlarmRow(
          label: '라이브 이벤트 알림',
          value: _liveEvent,
          onChanged: (v) => setState(() => _liveEvent = v),
          scale: scale,
        ),
        SizedBox(height: 24 * scale),
        CommonButton(
          label: '확인',
          scale: scale,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// 헤더: [타이틀 + 대진(팀 로고·이름 VS 팀 로고·이름)] · 우측 닫기(44×44).
class _Header extends StatelessWidget {
  const _Header({
    required this.homeName,
    required this.homeLogoUrl,
    required this.awayName,
    required this.awayLogoUrl,
    required this.scale,
    required this.onClose,
  });

  final String homeName;
  final String? homeLogoUrl;
  final String awayName;
  final String? awayLogoUrl;
  final double scale;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 8 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '경기 알림 설정',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w700,
                    fontSize: 16 * scale,
                    height: 1.5, // line-height 150%
                    color: AppColors.narTextGnbDefault, // #CED4DA
                  ),
                ),
                SizedBox(height: 4 * scale),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TeamBadge(name: homeName, logoUrl: homeLogoUrl, scale: scale),
                    SizedBox(width: 12 * scale),
                    Text(
                      'VS',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        fontSize: 16 * scale,
                        height: 19 / 16,
                        letterSpacing: 0.21 * scale,
                        color: AppColors.narText,
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    _TeamBadge(name: awayName, logoUrl: awayLogoUrl, scale: scale),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: SizedBox(
              width: 44 * scale,
              height: 44 * scale,
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/close.svg',
                  width: 24 * scale,
                  height: 24 * scale,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 팀 로고(33 원형) + 팀명 한 쌍.
class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.name, required this.logoUrl, required this.scale});

  final String name;
  final String? logoUrl;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 33 * scale;
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.narDark200,
        shape: BoxShape.circle,
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        hasLogo
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: resolveImageUrl(logoUrl)!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 150),
                  errorWidget: (_, _, _) => placeholder,
                ),
              )
            : placeholder,
        SizedBox(width: 8 * scale),
        Text(
          name,
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
    );
  }
}

/// 알림 토글 한 행: 라벨 + [NarToggle] (좌우 20 패딩, 높이 38).
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
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 2 * scale),
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
