/// 앱 전역 공용 HTTP 클라이언트.
///
/// `package:http` 의 최상위 함수(`http.get` 등)는 요청마다 `Client` 를 새로
/// 만들고 곧바로 닫는다. 그래서 요청 하나하나가 TCP 연결과 TLS 핸드셰이크를
/// 처음부터 다시 치른다 — 유선에서도 20~30ms, 셀룰러에선 그 몇 배가 매 요청에
/// 얹힌다. 화면 하나가 API 를 서너 번 부르는 구조라 체감 지연이 그만큼 곱해진다.
///
/// 이 파일은 같은 이름의 함수를 살아있는 단일 [http.Client] 위에 다시 구현한다.
/// 호출부는 `package:http/http.dart` 대신 이 파일을 `as http` 로 임포트하기만
/// 하면 되고, 코드는 그대로 두면 keep-alive 로 연결이 재사용된다.
///
/// 타임아웃도 여기서 함께 건다. 네트워크가 끊기다시피 한 상태에서 요청이
/// 응답 없이 매달려 있으면 화면은 스피너만 계속 돌린다 — 실패로 끝나는 편이
/// 재시도 버튼이라도 보여줄 수 있어 낫다.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

// 호출부가 이 파일 하나만 임포트해도 되도록, 쓰이는 타입들을 다시 내보낸다.
export 'package:http/http.dart'
    show Response, StreamedResponse, BaseRequest, Request, MultipartRequest,
        MultipartFile, ByteStream, Client, ClientException;

/// 응답을 기다리는 최대 시간.
///
/// 서버 정상 응답은 100ms 안팎이라 15초를 넘겼다면 사실상 실패한 요청이다.
/// 이미지 업로드처럼 오래 걸릴 수 있는 요청은 호출부에서 [timeout] 으로 늘린다.
const Duration kDefaultApiTimeout = Duration(seconds: 15);

/// 앱이 살아있는 동안 유지되는 단일 클라이언트. 닫지 않는다 —
/// 닫는 순간 연결 풀이 비워져 이 파일의 목적이 사라진다.
final http.Client _client = http.Client();

/// 테스트에서 주입한 클라이언트. null 이면 [_client] 를 쓴다.
http.Client? _override;

/// 테스트용 — 이후 모든 요청을 [client] 로 보낸다. null 로 되돌리면 원상복구.
///
/// 프로덕션 코드에서는 호출하지 않는다.
void setApiClientForTesting(http.Client? client) => _override = client;

http.Client get _c => _override ?? _client;

Future<http.Response> get(
  Uri url, {
  Map<String, String>? headers,
  Duration? timeout,
}) =>
    _c.get(url, headers: headers).timeout(timeout ?? kDefaultApiTimeout);

/// 본문 없이 헤더만 받는다. 주소가 살아 있는지만 확인할 때 쓴다 —
/// [get] 으로 확인하면 쓰지도 않을 본문을 통째로 받게 된다.
Future<http.Response> head(
  Uri url, {
  Map<String, String>? headers,
  Duration? timeout,
}) =>
    _c.head(url, headers: headers).timeout(timeout ?? kDefaultApiTimeout);

Future<http.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
  Duration? timeout,
}) =>
    _c
        .post(url, headers: headers, body: body, encoding: encoding)
        .timeout(timeout ?? kDefaultApiTimeout);

Future<http.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
  Duration? timeout,
}) =>
    _c
        .put(url, headers: headers, body: body, encoding: encoding)
        .timeout(timeout ?? kDefaultApiTimeout);

Future<http.Response> patch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
  Duration? timeout,
}) =>
    _c
        .patch(url, headers: headers, body: body, encoding: encoding)
        .timeout(timeout ?? kDefaultApiTimeout);

Future<http.Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
  Duration? timeout,
}) =>
    _c
        .delete(url, headers: headers, body: body, encoding: encoding)
        .timeout(timeout ?? kDefaultApiTimeout);

/// 스트리밍 요청(멀티파트 업로드 등)을 공용 클라이언트로 보낸다.
///
/// 업로드는 파일 크기·회선에 따라 오래 걸리므로 기본 타임아웃을 걸지 않는다.
Future<http.StreamedResponse> send(http.BaseRequest request) =>
    _c.send(request);
