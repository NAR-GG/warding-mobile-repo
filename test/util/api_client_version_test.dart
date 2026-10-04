import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/util/api_client.dart';

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
