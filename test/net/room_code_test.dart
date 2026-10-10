import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/net/room_code.dart';

void main() {
  test('a code is 7 characters split 3–4, from the unambiguous alphabet', () {
    final code = roomCodeFor('192.168.1.23');

    expect(
      code,
      matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]{3}-[0-9A-HJKMNP-TV-Z]{4}$')),
    );
  });

  test('every code reads back to the address it came from', () {
    for (final address in [
      '192.168.1.23',
      '192.168.43.1',
      '10.0.0.2',
      '172.20.10.1',
      '0.0.0.0',
      '255.255.255.255',
    ]) {
      expect(addressFromRoomCode(roomCodeFor(address)), address);
    }
  });

  test(
    'reading a code forgives case, spaces, a missing dash and look-alikes',
    () {
      final code = roomCodeFor('192.168.43.1');
      final sloppy = code.toLowerCase().replaceAll('-', ' ');

      expect(addressFromRoomCode(sloppy), '192.168.43.1');
      expect(
        addressFromRoomCode(code.replaceAll('0', 'O').replaceAll('1', 'I')),
        '192.168.43.1',
      );
    },
  );

  test('anything that isn\'t a code reads as null', () {
    for (final junk in ['', 'ABC', 'ABC-DEFGH', 'UUU-UUUU', 'ZZZ-ZZZZ']) {
      expect(addressFromRoomCode(junk), isNull, reason: junk);
    }
  });

  test('only IPv4 addresses have codes', () {
    expect(() => roomCodeFor('fe80::1'), throwsArgumentError);
    expect(() => roomCodeFor('192.168.1.300'), throwsArgumentError);
  });
}
