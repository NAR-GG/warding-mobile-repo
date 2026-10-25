import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/player_detail.dart';

PlayerSoloAccount _a(String? tier) =>
    PlayerSoloAccount(region: 'KR', riotId: 'x#1', live: false, tier: tier);

void main() {
  test('아는 티어는 문장 키와 나머지로 나눈다', () {
    expect(_a('Master 1,213LP').tierCrest, ('master', '1,213LP'));
    expect(_a('Diamond 2 75LP').tierCrest, ('diamond', '2 75LP'));
    expect(_a('GM 1,779LP').tierCrest, ('grandmaster', '1,779LP'));
    expect(_a('Ch 1,204LP').tierCrest, ('challenger', '1,204LP'));
  });

  test('모르는 티어·빈 값은 null', () {
    expect(_a('Unranked').tierCrest, isNull);
    expect(_a(null).tierCrest, isNull);
  });
}
