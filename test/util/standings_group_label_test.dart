import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/util/standings_group_label.dart';

/// 순위표 그룹 이름 표시 규칙. 서버는 표시 문구가 아니라 코드를 준다
/// (실측 2026-10-06: LCK `LEGEND`·`RISE`, ASIAN_GAMES `A`·`B`).
void main() {
  late AppLocalizations l;

  setUp(() {
    l = lookupAppLocalizations(const Locale('ko'));
  });

  test('아는 LCK 코드는 한국어 그룹명으로 바꾼다', () {
    expect(standingsGroupLabel('LEGEND', l), '레전드 그룹');
    expect(standingsGroupLabel('RISE', l), '라이즈 그룹');
    // 서버가 대소문자를 바꿔도 같게 본다.
    expect(standingsGroupLabel('legend', l), '레전드 그룹');
  });

  test('영숫자 기호 하나면 "그룹"을 앞에 붙인다', () {
    expect(standingsGroupLabel('A', l), '그룹 A');
    expect(standingsGroupLabel('B', l), '그룹 B');
    expect(standingsGroupLabel('1', l), '그룹 1');
    expect(standingsGroupLabel('a', l), '그룹 A');
  });

  test('짧은 한글 이름에는 "그룹"을 붙이지 않는다', () {
    // "결승" 이 "그룹 결승" 이 되면 안 된다.
    expect(standingsGroupLabel('결승', l), '결승');
    expect(standingsGroupLabel('4강', l), '4강');
  });

  test('이미 읽을 수 있는 문구는 그대로 둔다', () {
    expect(standingsGroupLabel('그룹 스테이지', l), '그룹 스테이지');
    expect(standingsGroupLabel('플레이-인', l), '플레이-인');
  });

  test('처음 보는 코드도 그대로 둔다 — 빈칸보다 서버 값이 낫다', () {
    expect(standingsGroupLabel('CHALLENGE', l), 'CHALLENGE');
  });

  test('비었거나 공백뿐이면 null — 호출부가 자체 폴백을 쓴다', () {
    expect(standingsGroupLabel('', l), isNull);
    expect(standingsGroupLabel('   ', l), isNull);
  });

  test('앞뒤 공백은 떼고 본다', () {
    expect(standingsGroupLabel('  RISE  ', l), '라이즈 그룹');
    expect(standingsGroupLabel(' A ', l), '그룹 A');
  });
}
