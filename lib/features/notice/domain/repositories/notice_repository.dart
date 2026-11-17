import 'package:fpdart/fpdart.dart';

import 'package:warding/core/error/failure.dart';
import 'package:warding/features/notice/domain/notice.dart';

/// 공지사항 조회.
///
/// 공개 API 라 인증이 필수는 아니지만, ADMIN 계정 토큰을 실어 보내면 임시저장
/// 공지도 내려온다(앱 검수용).
abstract interface class NoticeRepository {
  /// 공지 목록 (발행분만, 고정 먼저, 최신순). ADMIN 토큰이면 임시저장 포함.
  Future<Either<Failure, NoticePage>> fetchNotices({int page, int size});

  /// 앱 전용 고정 페이지(예: `ad-guide`).
  Future<Either<Failure, Notice>> fetchPage(String slug);

  /// 공지 조회수 +1.
  ///
  /// [Failure] 를 돌려주지 않는다. 화면 표시와 무관한 집계이고 열람 자체는 이미
  /// 성공한 상태라, 호출부가 실패를 알아도 할 일이 없다.
  Future<void> markViewed(int id);

  /// 캘린더 상단 띠배너 대상 공지 (최신 발행순, 최대 5건).
  ///
  /// 같은 조회가 이미 떠 있거나 방금 끝났으면 그 결과를 재사용한다.
  /// [forceRefresh] 를 주면 캐시를 건너뛴다.
  Future<Either<Failure, List<Notice>>> fetchPromoted({bool forceRefresh});

  /// 유효한 캐시가 있으면 그 배너 공지 목록, 없으면 null.
  ///
  /// 홈이 **첫 프레임을 그리기 전에** 배너 유무를 정하는 데 쓴다. 같은 값을
  /// [fetchPromoted] 로 받으면 아무리 빨라도 한 프레임 뒤라, 그 사이에 배너
  /// 없는 화면이 한 번 그려졌다가 배너가 끼어들며 캘린더를 밀어낸다.
  List<Notice>? get cachedPromoted;
}
