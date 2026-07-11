import 'package:flutter_test/flutter_test.dart';

import 'package:warding/model/player.dart';

Player _player(String name, String role) =>
    Player(id: name.hashCode, name: name, imageUrl: '', role: role);

void main() {
  test('roleOrder는 탑→정글→미드→바텀→서포터, 미상은 맨 뒤', () {
    final players = [
      _player('Keria', 'Support'),
      _player('Faker', 'Mid'),
      _player('Unknown', ''),
      _player('Gumayusi', 'ADC'),
      _player('Oner', 'Jungle'),
      _player('Doran', 'Top'),
    ]..sort((a, b) => a.roleOrder.compareTo(b.roleOrder));

    expect(
      players.map((p) => p.name).toList(),
      ['Doran', 'Oner', 'Faker', 'Gumayusi', 'Keria', 'Unknown'],
    );
  });
}
