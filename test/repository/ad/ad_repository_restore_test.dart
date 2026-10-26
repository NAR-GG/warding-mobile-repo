import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warding/repository/ad/ad_repository.dart';
import 'package:warding/util/api_client.dart' show setApiClientForTesting;

/// 스플래시 광고는 **첫 프레임에 한 번** `readyFor` 를 읽고 끝까지 안 바꾼다.
/// 그 값을 들고 있는 `_ready` 는 메모리에만 있어서, 복원이 없으면 앱을 켤 때마다
/// 비어 있고 스플래시 광고가 **영원히** 안 뜬다(#408 리뷰에서 잡힌 버그).
/// 그래서 지난 실행에서 적어 둔 광고를 `restoreSplash` 가 되살리는지 값으로 박아 둔다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = 'ad_ready_splash';

  test('적어 둔 스플래시 광고를 첫 프레임 전에 되살린다', () async {
    SharedPreferences.setMockInitialValues({
      key: jsonEncode({
        'placement': 'splash',
        'imageUrl': 'https://cdn.example.com/a.png',
        'linkUrl': 'https://example.com',
      }),
    });

    await AdRepository.instance.restoreSplash();

    final ad = AdRepository.instance.readyFor('splash');
    expect(ad, isNotNull, reason: '복원이 안 되면 스플래시 광고가 영원히 안 뜬다');
    expect(ad!.imageUrl, 'https://cdn.example.com/a.png');
    expect(ad.linkUrl, 'https://example.com');
  });

  test('적어 둔 게 없으면 null — 모집 배너로 간다', () async {
    SharedPreferences.setMockInitialValues({});

    await AdRepository.instance.restoreSplash();

    // 앞 테스트가 싱글턴에 남긴 값과 섞이지 않게 다른 자리를 본다.
    expect(AdRepository.instance.readyFor('popup'), isNull);
  });

  test('깨진 JSON 이 적혀 있어도 터지지 않는다', () async {
    SharedPreferences.setMockInitialValues({key: '{이건 JSON 이 아니다'});

    // 예외가 밖으로 새면 main 의 Future.wait 가 깨져 첫 화면이 늦어진다.
    await expectLater(AdRepository.instance.restoreSplash(), completes);
  });

  group('집행이 끝난 스플래시 광고', () {
    tearDown(() {
      setApiClientForTesting(null);
      AdRepository.instance.resetForTest();
    });

    test('응답에 splash 가 없으면 적어 둔 것도 지운다', () async {
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'placement': 'splash',
          'imageUrl': 'https://cdn.example.com/old.png',
          'linkUrl': null,
        }),
      });
      AdRepository.instance.resetForTest();
      // 서버가 광고를 더 이상 안 내려준다(집행 종료).
      setApiClientForTesting(MockClient((_) async => http.Response('[]', 200)));

      AdRepository.instance.warmUp(const ['splash']);
      // warmUp 은 기다리지 않으므로 응답·삭제가 끝날 틈을 준다.
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(
        AdRepository.instance.readyFor('splash'),
        isNull,
        reason: '집행이 끝났는데 메모리에 남으면 이번 실행에 그대로 뜬다',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), isNull, reason: '기기에 남으면 다음 실행에서 되살아난다');
    });

    test('조회가 실패하면 지우지 않는다 — 비행기 모드로 켠 것과 구분한다', () async {
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'placement': 'splash',
          'imageUrl': 'https://cdn.example.com/live.png',
          'linkUrl': null,
        }),
      });
      AdRepository.instance.resetForTest();
      // 네트워크 장애 — 빈 응답과 똑같이 보이면 안 된다.
      setApiClientForTesting(
        MockClient((_) async => throw const SocketException('offline')),
      );

      AdRepository.instance.warmUp(const ['splash']);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(key),
        isNotNull,
        reason: '조회 실패를 집행 종료로 오해하면 멀쩡한 광고가 지워진다',
      );
    });

    test('5xx 응답에도 지우지 않는다', () async {
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'placement': 'splash',
          'imageUrl': 'https://cdn.example.com/live.png',
          'linkUrl': null,
        }),
      });
      AdRepository.instance.resetForTest();
      setApiClientForTesting(
        MockClient((_) async => http.Response('oops', 500)),
      );

      AdRepository.instance.warmUp(const ['splash']);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), isNotNull);
    });

    test('응답에 splash 가 있으면 적어 둔 것을 지우지 않는다', () async {
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'placement': 'splash',
          'imageUrl': 'https://cdn.example.com/keep.png',
          'linkUrl': null,
        }),
      });
      AdRepository.instance.resetForTest();
      setApiClientForTesting(
        MockClient(
          (_) async => http.Response(
            jsonEncode([
              {
                'placement': 'splash',
                'imageUrl': 'https://cdn.example.com/keep.png',
                'linkUrl': null,
              },
            ]),
            200,
          ),
        ),
      );

      // 이미지 받기(warmUp)를 타지 않도록 응답만 보는 경로로 확인한다.
      await AdRepository.instance.restoreSplash();
      expect(AdRepository.instance.readyFor('splash'), isNotNull);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(key),
        isNotNull,
        reason: '집행 중인 광고를 지우면 다음 실행이 모집 배너로 샌다',
      );
    });
  });
}
