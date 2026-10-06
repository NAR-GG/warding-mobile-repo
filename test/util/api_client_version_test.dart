import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/util/api_client.dart';

/// 닫혔는지만 기록하는 클라이언트. [MockClient] 는 close() 를 지켜볼 수 없다.
class _ClosableClient extends http.BaseClient {
  _ClosableClient(this.onClose);

  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 200);

  @override
  void close() => onClose();
}

void main() {
  test('모든 요청에 X-App-Version 헤더를 붙인다', () async {
    final seen = <String?>[];
    final inner = MockClient((req) async {
      seen.add(req.headers['X-App-Version']);
      return http.Response('', 200);
    });
    final client = VersionedClient(inner, () => '1.0.31+69');

    await client.get(Uri.parse('https://example.com/a'));
    await client.post(Uri.parse('https://example.com/b'), body: 'x');

    expect(seen, ['1.0.31+69', '1.0.31+69']);
  });

  // BaseClient.close() 기본 구현은 아무것도 하지 않아, 재정의하지 않으면
  // 감싼 클라이언트의 연결 풀이 그대로 남는다.
  test('close() 는 감싼 클라이언트까지 닫는다', () {
    var innerClosed = false;
    final inner = _ClosableClient(() => innerClosed = true);

    VersionedClient(inner, () => '1.0.0+1').close();

    expect(innerClosed, isTrue);
  });

  test('버전을 못 읽으면 헤더 없이 요청은 나간다', () async {
    String? seen = 'unset';
    final inner = MockClient((req) async {
      seen = req.headers['X-App-Version'];
      return http.Response('', 200);
    });
    final client = VersionedClient(inner, () => null);

    final res = await client.get(Uri.parse('https://example.com/a'));

    expect(res.statusCode, 200);
    expect(seen, isNull);
  });
}
