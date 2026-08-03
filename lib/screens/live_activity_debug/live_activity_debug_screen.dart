import 'package:flutter/material.dart';

import '../../model/live_match_activity.dart';
import '../../repository/live_activity/live_activity_service.dart';
import '../../styles/app_colors.dart';

/// 실시간 경기 Live Activity 확인용 화면.
///
/// 실제 경기 데이터 연동 전에 잠금화면/Dynamic Island 렌더링을
/// 눈으로 확인하기 위한 개발용 화면이다.
class LiveActivityDebugScreen extends StatefulWidget {
  const LiveActivityDebugScreen({super.key});

  @override
  State<LiveActivityDebugScreen> createState() =>
      _LiveActivityDebugScreenState();
}

class _LiveActivityDebugScreenState extends State<LiveActivityDebugScreen> {
  final _service = LiveActivityService.instance;

  bool _supported = false;
  bool _running = false;
  String _log = '';

  // 테스트용 경기 정보.
  int _setNumber = 1;
  int _scoreA = 0;
  int _scoreB = 0;
  DateTime _setStartedAt = DateTime.now();

  // lolesports CDN 원본 URL. akamai 리사이즈 경유 URL은 404 라 직접 받는다.
  static const _teamALogo =
      'https://static.lolesports.com/teams/1672933861879_Heretics-Full-Color.png';
  static const _teamBLogo =
      'https://static.lolesports.com/teams/1675865863968_Vitality_FullColor.png';

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    final ok = await _service.isSupported();
    if (!mounted) return;
    setState(() {
      _supported = ok;
      _log = ok ? '지원됨 — 시작 버튼을 눌러보세요.' : 'Live Activity 미지원 또는 설정에서 꺼짐';
    });
  }

  void _appendLog(String msg) {
    if (!mounted) return;
    setState(() => _log = msg);
  }

  Future<void> _start() async {
    _appendLog('로고 다운로드 중...');
    final logoA = await _service.fetchLogoBase64(_teamALogo);
    final logoB = await _service.fetchLogoBase64(_teamBLogo);

    _setStartedAt = DateTime.now();
    final ok = await _service.start(
      config: LiveMatchActivityConfig(
        matchId: 'debug-match-1',
        teamAName: 'TH',
        teamACode: 'TH',
        teamBName: 'VIT',
        teamBCode: 'VIT',
        leagueName: 'LCK 플레이-인 토너먼트',
        teamALogoBase64: logoA,
        teamBLogoBase64: logoB,
        // 하트 표시 확인용 — 왼쪽 팀을 응원 팀으로 둔다.
        favoriteTeamCode: 'TH',
      ),
      state: LiveMatchActivityState(
        phase: LiveMatchPhase.playing,
        setNumber: _setNumber,
        scoreA: _scoreA,
        scoreB: _scoreB,
        setStartedAt: _setStartedAt,
      ),
    );
    setState(() => _running = ok);
    _appendLog(ok ? '시작됨 — 잠금화면을 확인하세요 (LIVE 배지 깜빡임)' : '시작 실패');
  }

  Future<void> _updatePlaying() async {
    final ok = await _service.update(
      LiveMatchActivityState(
        phase: LiveMatchPhase.playing,
        setNumber: _setNumber,
        scoreA: _scoreA,
        scoreB: _scoreB,
        setStartedAt: _setStartedAt,
      ),
    );
    _appendLog(ok ? '경기 중 상태로 갱신 ($_scoreA:$_scoreB, $_setNumber세트)' : '갱신 실패');
  }

  Future<void> _setEnded() async {
    final elapsed = DateTime.now().difference(_setStartedAt);
    final frozen = '${elapsed.inMinutes.toString().padLeft(2, '0')}:'
        '${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    final ok = await _service.update(
      LiveMatchActivityState(
        phase: LiveMatchPhase.setEnded,
        setNumber: _setNumber,
        scoreA: _scoreA,
        scoreB: _scoreB,
        frozenTime: frozen,
        statusLabel: '다음 세트 준비 중',
      ),
    );
    _appendLog(ok ? '세트 종료 상태 (SET END 배지, 시간 $frozen 고정)' : '갱신 실패');
  }

  Future<void> _matchEnded() async {
    final elapsed = DateTime.now().difference(_setStartedAt);
    final frozen = '${elapsed.inMinutes.toString().padLeft(2, '0')}:'
        '${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    final ok = await _service.update(
      LiveMatchActivityState(
        phase: LiveMatchPhase.matchEnded,
        setNumber: _setNumber,
        scoreA: _scoreA,
        scoreB: _scoreB,
        frozenTime: frozen,
        statusLabel: '경기 종료',
        winnerTeamCode: _scoreA > _scoreB ? 'TH' : 'VIT',
      ),
    );
    _appendLog(ok ? '경기 종료 상태 (END 배지)' : '갱신 실패');
  }

  Future<void> _end() async {
    final ok = await _service.end(
      LiveMatchActivityState(
        phase: LiveMatchPhase.matchEnded,
        setNumber: _setNumber,
        scoreA: _scoreA,
        scoreB: _scoreB,
        statusLabel: '경기 종료',
      ),
    );
    setState(() => _running = !ok);
    _appendLog(ok ? '액티비티 종료됨' : '종료 실패');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      appBar: AppBar(
        backgroundColor: AppColors.narDark800,
        foregroundColor: AppColors.narText,
        title: Text(
          'Live Activity 테스트',
          style: TextStyle(fontSize: 17 * scale, color: AppColors.narText),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusCard(scale),
            SizedBox(height: 20 * scale),
            _scoreControls(scale),
            SizedBox(height: 20 * scale),
            _actionButton(scale, '① 시작 (경기 중)', _supported ? _start : null),
            SizedBox(height: 10 * scale),
            _actionButton(
              scale,
              '② 갱신 (스코어 반영)',
              _running ? _updatePlaying : null,
            ),
            SizedBox(height: 10 * scale),
            _actionButton(scale, '③ 세트 종료', _running ? _setEnded : null),
            SizedBox(height: 10 * scale),
            _actionButton(scale, '④ 경기 종료', _running ? _matchEnded : null),
            SizedBox(height: 10 * scale),
            _actionButton(scale, '⑤ 액티비티 내리기', _running ? _end : null),
            SizedBox(height: 20 * scale),
            Text(
              '※ 잠금화면 또는 Dynamic Island 에서 확인하세요.\n'
              '설정 > Warding > 실시간 활동 이 켜져 있어야 합니다.',
              style: TextStyle(
                fontSize: 12 * scale,
                color: AppColors.narText2,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(double scale) {
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _supported ? '● 지원됨' : '● 미지원',
            style: TextStyle(
              fontSize: 13 * scale,
              color: _supported ? const Color(0xFF51CF66) : AppColors.narTextRed,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            _log,
            style: TextStyle(fontSize: 13 * scale, color: AppColors.narText3),
          ),
        ],
      ),
    );
  }

  Widget _scoreControls(double scale) {
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      child: Column(
        children: [
          _counterRow(scale, 'TH 스코어', _scoreA, (v) {
            setState(() => _scoreA = v);
          }),
          SizedBox(height: 8 * scale),
          _counterRow(scale, 'VIT 스코어', _scoreB, (v) {
            setState(() => _scoreB = v);
          }),
          SizedBox(height: 8 * scale),
          _counterRow(scale, '세트', _setNumber, (v) {
            setState(() => _setNumber = v.clamp(1, 5));
          }),
        ],
      ),
    );
  }

  Widget _counterRow(
    double scale,
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14 * scale, color: AppColors.narText),
          ),
        ),
        IconButton(
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: AppColors.narText,
        ),
        SizedBox(
          width: 30 * scale,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w700,
              color: AppColors.narText,
            ),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
          color: AppColors.narText,
        ),
      ],
    );
  }

  Widget _actionButton(double scale, String label, VoidCallback? onPressed) {
    return SizedBox(
      height: 48 * scale,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF3B5BDB),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10 * scale),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15 * scale,
            fontWeight: FontWeight.w600,
            color: onPressed != null ? Colors.white : AppColors.narText2,
          ),
        ),
      ),
    );
  }
}
