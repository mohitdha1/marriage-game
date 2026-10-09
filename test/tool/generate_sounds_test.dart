import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_sounds.dart';

void main() {
  group('encodeWav', () {
    final bytes = encodeWav([0, 0.5, -0.5, 1.0, -1.0, 2.0]);
    final data = ByteData.sublistView(bytes);
    String ascii(int offset) =>
        String.fromCharCodes(bytes.sublist(offset, offset + 4));

    test('writes a 44-byte RIFF/WAVE header for mono 16-bit PCM', () {
      expect(ascii(0), 'RIFF');
      expect(ascii(8), 'WAVE');
      expect(ascii(12), 'fmt ');
      expect(ascii(36), 'data');
      expect(data.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(data.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(data.getUint32(24, Endian.little), sampleRate);
      expect(data.getUint16(34, Endian.little), 16, reason: 'bits');
    });

    test('sizes match the samples', () {
      expect(bytes.length, 44 + 6 * 2);
      expect(data.getUint32(40, Endian.little), 6 * 2);
      expect(data.getUint32(4, Endian.little), 36 + 6 * 2);
    });

    test('samples are scaled to 16 bits, and out-of-range ones clamped', () {
      int sample(int i) => data.getInt16(44 + i * 2, Endian.little);

      expect(sample(0), 0);
      expect(sample(1), 16384);
      expect(sample(2), -16384);
      expect(sample(3), 32767);
      expect(sample(4), -32767);
      expect(sample(5), 32767, reason: '2.0 is clamped to 1.0');
    });
  });

  test('every generated sound stays within range', () {
    final random = Random(1);
    for (final samples in [
      shuffle(random),
      cardSnap(random),
      select(),
      winJingle(),
      roundOver(),
    ]) {
      expect(samples, isNotEmpty);
      expect(samples.every((s) => s.abs() <= 1), isTrue);
    }
  });
}
