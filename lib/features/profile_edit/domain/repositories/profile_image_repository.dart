import 'dart:io';

import 'package:fpdart/fpdart.dart';

import 'package:warding/core/domain/failure.dart';

/// 프로필 이미지 업로드.
abstract interface class ProfileImageRepository {
  /// [file] 을 업로드하고 저장용 URL 을 돌려준다.
  ///
  /// 백엔드에서 Cloudinary 서명을 발급받아 앱이 직접 올리는 2 단계라, 어느
  /// 단계에서 실패했는지는 [Failure] 종류로 구분되지 않는다 — 호출부가 할 수
  /// 있는 일이 "다시 시도" 하나뿐이어서 구분할 이유도 없다. 단계 정보는
  /// Sentry 로 남긴다.
  Future<Either<Failure, String>> upload(File file);
}
