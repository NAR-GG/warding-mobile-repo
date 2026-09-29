import 'package:flutter/foundation.dart';

import '../onboarding/onboarding_repository.dart';

/// 팀 코드 → 로고 URL 사전. 팀 코드만 내려오는 화면(홈 솔랭·한줄평, 내 선수 등)이
/// 로고를 그릴 때 쓴다.
///
/// 팀 목록은 [OnboardingRepository.fetchTeams] 가 캐시하므로 여기서는 한 번만
/// 채운다. 실패하면 [_retryAfter] 뒤에 다시 시도하고, 그동안 배지는 빈 원으로
/// 그려진다.
class TeamLogoDirectory {
  TeamLogoDirectory({Future<List<TeamLogoEntry>> Function()? load})
    : _load = load ?? _loadFromOnboarding;

  static final TeamLogoDirectory instance = TeamLogoDirectory();

  static const Duration _retryAfter = Duration(seconds: 30);

  final Future<List<TeamLogoEntry>> Function() _load;

  /// 팀 코드(대문자) → 로고 URL. 로드 전에는 비어 있다.
  final ValueNotifier<Map<String, String>> logos = ValueNotifier(const {});

  bool _loading = false;
  DateTime? _failedAt;

  /// 아직 안 채웠으면 채운다. 여러 번 불려도 요청은 하나다.
  void ensureLoaded() {
    if (_loading || logos.value.isNotEmpty) return;
    final failedAt = _failedAt;
    if (failedAt != null && DateTime.now().difference(failedAt) < _retryAfter) {
      return;
    }
    _loading = true;
    _fill();
  }

  Future<void> _fill() async {
    try {
      final entries = await _load();
      logos.value = {
        for (final e in entries)
          if (e.code.isNotEmpty && e.imageUrl.isNotEmpty)
            e.code.toUpperCase(): e.imageUrl,
      };
      _failedAt = null;
    } catch (e) {
      debugPrint('[TeamLogo] 팀 로고 목록 조회 실패: $e');
      _failedAt = DateTime.now();
    } finally {
      _loading = false;
    }
  }

  /// [teamCode] 의 로고 URL. 없으면 null.
  String? logoFor(String teamCode) => logos.value[teamCode.toUpperCase()];

  /// 테스트 전용 — 싱글톤([instance])이 이전 테스트의 로드 성공/실패 상태를
  /// 들고 있어 생기는 테스트 간 간섭을 막는다.
  @visibleForTesting
  void resetForTesting() {
    logos.value = const {};
    _loading = false;
    _failedAt = null;
  }

  static Future<List<TeamLogoEntry>> _loadFromOnboarding() async {
    final teams = await OnboardingRepository.instance.fetchTeams();
    return [for (final t in teams) TeamLogoEntry(t.code, t.imageUrl)];
  }
}

class TeamLogoEntry {
  const TeamLogoEntry(this.code, this.imageUrl);

  final String code;
  final String imageUrl;
}
