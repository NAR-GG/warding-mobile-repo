import 'package:warding/features/solo_rank/domain/solo_rank_snapshot.dart';

// 솔랭 데이터 소스 계약. 구현은 `data/` 에 있다(API·목업·빈 소스).
//
// repository 인터페이스를 domain 에 두는 프로젝트 규칙과 같다 — 화면·규칙은
// 이 계약만 알고, 어디서 받아오는지는 모른다.

/// 구독 선수 솔랭 상태 소스.
abstract class SoloRankSource {
  Future<SoloRankSnapshot> fetch();
}

/// 월즈 솔랭 소스.
abstract class WorldsSoloSource {
  Future<WorldsSoloSnapshot> fetch();
}

/// 솔랭 응원 전송 소스. count 는 1..30 이다.
abstract class CheerSource {
  Future<CheerResult> send(int playerId, int count);
}
