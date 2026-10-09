import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';
import '../../../viewmodel/home/solo_cheer_controller.dart';

/// 천 단위 쉼표 — 응원 수는 수천~수만 단위로 커진다.
String formatCheerCount(int n) => NumberFormat.decimalPattern().format(n);

/// 솔랭 라이브 카드 + 하단 응원 영역을 한 장으로 묶는다.
///
/// 시안(warding-docs `features/cheer/mockup.html`)의 `.hcol` + `.cheer`. 눌린 만큼
/// 카드 테두리가 달아오르는 heat(0.2~1)를 여기서 들고 있다 — 탭마다 +0.07, 400ms 마다
/// -0.035 식어 0.2 로 돌아간다. 카드마다 따로 센다.
class SoloCheerCard extends StatefulWidget {
  const SoloCheerCard({
    super.key,
    required this.hero,
    required this.heroHeight,
    required this.playerName,
    required this.controller,
    required this.scale,
  });

  /// 위쪽 솔랭 카드. 모서리·테두리는 이 위젯이 그린다.
  final Widget hero;

  /// 위쪽 솔랭 카드 높이(스케일 적용 전 값이 아니라 이미 곱한 값).
  final double heroHeight;

  /// 응원 집계 키 겸 표시 이름.
  final String playerName;
  final SoloCheerController controller;
  final double scale;

  static Key totalKey(String name) => ValueKey('homeCheerTotal-$name');
  static Key mineKey(String name) => ValueKey('homeCheerMine-$name');
  static Key buttonKey(String name) => ValueKey('homeCheerButton-$name');

  /// 응원 영역 높이(스케일 전).
  static const double barHeight = 74;

  @override
  State<SoloCheerCard> createState() => _SoloCheerCardState();
}

class _SoloCheerCardState extends State<SoloCheerCard>
    with SingleTickerProviderStateMixin {
  static const double _baseHeat = 0.2;

  double _heat = _baseHeat;
  Timer? _coolTimer;
  final List<_Fx> _fx = [];
  int _fxSeq = 0;
  final math.Random _rng = math.Random();

  late final AnimationController _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void dispose() {
    _coolTimer?.cancel();
    _bump.dispose();
    super.dispose();
  }

  void _onTap() {
    widget.controller.tap(widget.playerName);
    setState(() => _heat = math.min(1, _heat + 0.07));
    _coolTimer ??= Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      setState(() => _heat = math.max(_baseHeat, _heat - 0.035));
      if (_heat <= _baseHeat) {
        _coolTimer?.cancel();
        _coolTimer = null;
      }
    });

    // 모션 줄이기 설정이면 +1·불꽃 파티클·숫자 튕김을 생략한다.
    if (MediaQuery.disableAnimationsOf(context)) return;
    _bump.forward(from: 0);
    final dx = _rng.nextDouble() * 44 - 22;
    final sparks = [
      for (var i = 0; i < 4; i++)
        () {
          final a =
              (-90 + (i - 1.5) * 38 + _rng.nextDouble() * 14) * math.pi / 180;
          final d = 30 + _rng.nextDouble() * 16;
          return Offset(math.cos(a) * d, math.sin(a) * d);
        }(),
    ];
    setState(() => _fx.add(_Fx(_fxSeq++, dx, sparks)));
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final radius = BorderRadius.circular(14 * scale);
    final glow = AppColors.narChipActive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: _heat * 0.35),
            blurRadius: (8 + 24 * _heat) * scale,
          ),
          BoxShadow(
            color: glow.withValues(alpha: _heat * 0.6),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: AppColors.narLine),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            children: [
              SizedBox(height: widget.heroHeight, child: widget.hero),
              Container(
                height: SoloCheerCard.barHeight * scale,
                decoration: const BoxDecoration(
                  color: AppColors.narBgTertiary,
                  border: Border(top: BorderSide(color: AppColors.narDark500)),
                ),
                padding: EdgeInsets.fromLTRB(15 * scale, 0, 12 * scale, 0),
                child: _buildBar(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scale = widget.scale;
    final name = widget.playerName;
    return Row(
      children: [
        Expanded(
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 12 * scale,
                      color: AppColors.narGuideAccent,
                    ),
                    SizedBox(width: 6 * scale),
                    Text(
                      l.homeCheerLabel,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 11.5 * scale,
                        color: AppColors.narText2,
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    ScaleTransition(
                      scale: TweenSequence<double>([
                        TweenSequenceItem(
                          tween: Tween(begin: 1.0, end: 1.06),
                          weight: 40,
                        ),
                        TweenSequenceItem(
                          tween: Tween(begin: 1.06, end: 1.0),
                          weight: 60,
                        ),
                      ]).animate(_bump),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatCheerCount(widget.controller.totalOf(name)),
                        key: SoloCheerCard.totalKey(name),
                        style: TextStyle(
                          fontFamily: 'Open Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 26 * scale,
                          height: 1.15,
                          letterSpacing: -0.26 * scale,
                          color: AppColors.narText,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    SizedBox(width: 7 * scale),
                    Text(
                      '+${formatCheerCount(widget.controller.mineOf(name))}',
                      key: SoloCheerCard.mineKey(name),
                      style: TextStyle(
                        fontFamily: 'Open Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 14 * scale,
                        color: AppColors.narGuideAccent,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 10 * scale),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            _CheerButton(
              key: SoloCheerCard.buttonKey(name),
              label: l.homeCheerButton,
              semanticsLabel: l.homeCheerButtonSemantics(name),
              scale: scale,
              onTap: _onTap,
            ),
            for (final fx in _fx)
              _FxLayer(
                key: ValueKey(fx.id),
                fx: fx,
                scale: scale,
                onDone: () {
                  if (mounted) setState(() => _fx.remove(fx));
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// 한 번의 탭이 만드는 효과 — `+1` 이 떠오르는 방향과 불꽃 조각의 도착 위치.
class _Fx {
  _Fx(this.id, this.dx, this.sparks);
  final int id;
  final double dx;
  final List<Offset> sparks;
}

/// 응원하기 버튼. **눌렀을 때 한 번만** 반응한다 — 누르고 있어도 연타되지
/// 않는다(`onPointerDown` 은 접촉당 한 번만 불린다).
class _CheerButton extends StatefulWidget {
  const _CheerButton({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.scale,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final double scale;
  final VoidCallback onTap;

  @override
  State<_CheerButton> createState() => _CheerButtonState();
}

class _CheerButtonState extends State<_CheerButton> {
  bool _down = false;

  void _release(PointerEvent _) {
    if (_down) setState(() => _down = false);
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          setState(() => _down = true);
          widget.onTap();
        },
        onPointerUp: _release,
        onPointerCancel: _release,
        child: AnimatedScale(
          scale: _down ? 0.93 : 1,
          duration: const Duration(milliseconds: 80),
          child: Container(
            height: 44 * scale,
            padding: EdgeInsets.symmetric(horizontal: 18 * scale),
            decoration: BoxDecoration(
              gradient: AppColors.narBg,
              borderRadius: BorderRadius.circular(10 * scale),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 16 * scale,
                  color: AppColors.narText,
                ),
                SizedBox(width: 6 * scale),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 15 * scale,
                    color: AppColors.narText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `+1` 떠오름(0.8초) + 작은 불꽃 조각 4개(0.55초). 끝나면 [onDone].
class _FxLayer extends StatelessWidget {
  const _FxLayer({
    super.key,
    required this.fx,
    required this.scale,
    required this.onDone,
  });

  final _Fx fx;
  final double scale;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            onEnd: onDone,
            builder: (context, t, child) => Transform.translate(
              offset: Offset(fx.dx * scale, (-14 - 60 * t) * scale),
              child: Opacity(
                opacity: 1 - t,
                child: Transform.scale(scale: 0.8 + 0.35 * t, child: child),
              ),
            ),
            child: Text(
              '+1',
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontWeight: FontWeight.w700,
                fontSize: 15 * scale,
                color: AppColors.narGuideAccent,
              ),
            ),
          ),
          for (final to in fx.sparks)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOut,
              builder: (context, t, child) => Transform.translate(
                offset: Offset(to.dx * t * scale, to.dy * t * scale),
                child: Opacity(
                  opacity: 1 - t,
                  child: Transform.scale(scale: 0.7 - 0.5 * t, child: child),
                ),
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 11 * scale,
                color: AppColors.narGuideAccent,
              ),
            ),
        ],
      ),
    );
  }
}
