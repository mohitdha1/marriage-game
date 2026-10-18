import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/import_sounds.dart';

/// A 16-bit WAV file at [sampleRate] holding [samples], interleaved across
/// [channels], with an odd-length chunk before the data, which is padded.
Uint8List wav(List<int> samples, {int channels = 1, int format = 1}) {
  final bytes = BytesBuilder();
  void ascii(String text) => bytes.add(text.codeUnits);
  void u16(int v) => bytes.add(
    (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List(),
  );
  void u32(int v) => bytes.add(
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List(),
  );

  ascii('RIFF');
  u32(0); // RIFF size, which decoding doesn't need
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(format);
  u16(channels);
  u32(sampleRate);
  u32(sampleRate * 2 * channels);
  u16(2 * channels);
  u16(16);
  ascii('LIST');
  u32(3);
  bytes.add([1, 2, 3, 0]);
  ascii('data');
  u32(samples.length * 2);
  for (final s in samples) {
    bytes.add(
      (ByteData(2)..setInt16(0, s, Endian.little)).buffer.asUint8List(),
    );
  }
  return bytes.toBytes();
}

void main() {
  group('decodeWav', () {
    test('reads mono samples, skipping other chunks', () {
      expect(decodeWav(wav([0, 16384, -16384])), [0, 0.5, -0.5]);
    });

    test('mixes stereo down to one channel', () {
      expect(decodeWav(wav([16384, 0, -16384, -16384], channels: 2)), [
        0.25,
        -0.5,
      ]);
    });

    test('reads the extensible format afconvert writes', () {
      expect(decodeWav(wav([16384], format: 0xFFFE)), [0.5]);
    });

    test('reads back what encodeWav writes', () {
      expect(decodeWav(encodeWav([0, 0.5, -0.5])), [
        0,
        closeTo(0.5, 1e-4),
        closeTo(-0.5, 1e-4),
      ]);
    });

    test('refuses anything that is not 16-bit PCM WAV', () {
      expect(
        () => decodeWav(Uint8List.fromList('not a wav file'.codeUnits)),
        throwsFormatException,
      );
      expect(() => decodeWav(wav([0], format: 3)), throwsFormatException);
    });
  });

  group('shape', () {
    final second = List.filled(sampleRate, 0.5);

    test('cuts the start and keeps the given length', () {
      const recipe = SoundRecipe('x', 'x', start: 0.25, length: 0.5, peakDb: 0);

      expect(shape(second, recipe), hasLength(sampleRate ~/ 2));
    });

    test('keeps the rest when no length is given', () {
      const recipe = SoundRecipe('x', 'x', start: 0.75, peakDb: 0);

      expect(shape(second, recipe), hasLength(sampleRate ~/ 4));
    });

    test('fades the end to silence', () {
      const recipe = SoundRecipe('x', 'x', fadeOut: 0.5, peakDb: 0);
      final shaped = shape(second, recipe);

      expect(shaped.first, closeTo(1, 1e-9));
      expect(shaped[sampleRate * 3 ~/ 4], closeTo(0.5, 0.01));
      expect(shaped.last, 0);
    });

    test('brings the loudest sample to the given level', () {
      const recipe = SoundRecipe('x', 'x', peakDb: -6);
      final peak = shape(second, recipe).map((s) => s.abs()).reduce(max);

      expect(20 * log(peak) / ln10, closeTo(-6, 1e-9));
    });

    test('leaves silence silent', () {
      const recipe = SoundRecipe('x', 'x', peakDb: -6);

      expect(shape(List.filled(10, 0.0), recipe), everyElement(0));
    });
  });

  test('every recipe makes a different file', () {
    final names = {for (final recipe in recipes) recipe.name};

    expect(names, hasLength(recipes.length));
  });
}
