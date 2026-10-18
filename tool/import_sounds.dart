// Builds the game's sound effects in assets/sounds/ from Kenney's CC0 sound
// packs (https://kenney.nl): Casino Audio, Interface Sounds and Music
// Jingles. Each sound is cut to length, faded out and brought to a quiet,
// even level, then saved as a mono 16-bit WAV, which plays on every
// platform without a decoder.
//
// Download and unzip the three packs into one folder, then run from the
// project folder on macOS (afconvert, which ships with macOS, decodes the
// packs' Ogg files):
//   dart run tool/import_sounds.dart <folder with the unzipped packs>

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sampleRate = 44100;

/// How one of the game's sounds is made from a file in a Kenney pack.
class SoundRecipe {
  const SoundRecipe(
    this.name,
    this.source, {
    this.start = 0,
    this.length,
    this.fadeOut = 0,
    required this.peakDb,
  });

  /// The file written to assets/sounds/, without `.wav`.
  final String name;

  /// The source file, relative to the folder holding the unzipped packs.
  final String source;

  /// Seconds cut from the start, and how many seconds to keep after that
  /// (all of the rest when `null`).
  final double start;
  final double? length;

  /// Seconds over which the end fades to silence.
  final double fadeOut;

  /// The loudest sample's level, in decibels below full scale.
  final double peakDb;
}

const recipes = [
  SoundRecipe(
    'shuffle',
    'kenney_casino-audio/Audio/card-shuffle.ogg',
    length: 1.2,
    fadeOut: 0.3,
    peakDb: -3,
  ),
  SoundRecipe(
    'card_snap',
    'kenney_casino-audio/Audio/card-place-2.ogg',
    start: 0.02,
    length: 0.28,
    fadeOut: 0.05,
    peakDb: -4,
  ),
  SoundRecipe(
    'select',
    'kenney_interface-sounds/Audio/select_001.ogg',
    peakDb: -14,
  ),
  SoundRecipe(
    'your_turn',
    'kenney_interface-sounds/Audio/glass_001.ogg',
    peakDb: -12,
  ),
  SoundRecipe(
    'joker_reveal',
    'kenney_interface-sounds/Audio/maximize_006.ogg',
    peakDb: -14,
  ),
  SoundRecipe(
    'win',
    'kenney_music-jingles/Audio/Steel jingles/jingles_STEEL02.ogg',
    peakDb: -13,
  ),
  SoundRecipe(
    'round_over',
    'kenney_music-jingles/Audio/Pizzicato jingles/jingles_PIZZI01.ogg',
    peakDb: -15,
  ),
];

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/import_sounds.dart <packs folder>');
    exit(64);
  }
  final temp = await Directory.systemTemp.createTemp('sounds');
  try {
    Directory('assets/sounds').createSync(recursive: true);
    for (final recipe in recipes) {
      final decoded = '${temp.path}/${recipe.name}.wav';
      final result = await Process.run('afconvert', [
        '-f', 'WAVE', '-d', 'LEI16@$sampleRate', '-c', '1', //
        '${args.single}/${recipe.source}', decoded,
      ]);
      if (result.exitCode != 0) {
        stderr.writeln('Could not decode ${recipe.source}: ${result.stderr}');
        exit(1);
      }
      final samples = shape(decodeWav(File(decoded).readAsBytesSync()), recipe);
      final file = File('assets/sounds/${recipe.name}.wav')
        ..writeAsBytesSync(encodeWav(samples));
      stdout.writeln('${file.path}: ${samples.length / sampleRate}s');
    }
  } finally {
    temp.deleteSync(recursive: true);
  }
}

/// [samples] cut, faded and levelled as [recipe] says.
List<double> shape(List<double> samples, SoundRecipe recipe) {
  final from = min((recipe.start * sampleRate).round(), samples.length);
  final to = switch (recipe.length) {
    final length? => min(from + (length * sampleRate).round(), samples.length),
    null => samples.length,
  };
  final cut = samples.sublist(from, to);
  final fade = (recipe.fadeOut * sampleRate).round();
  for (var i = 0; i < fade && i < cut.length; i++) {
    cut[cut.length - 1 - i] *= i / fade;
  }
  final peak = cut.fold(0.0, (loudest, s) => max(loudest, s.abs()));
  if (peak == 0) return cut;
  final gain = pow(10, recipe.peakDb / 20) / peak;
  return [for (final s in cut) s * gain];
}

/// The samples (each from −1 to 1) of a 16-bit PCM WAV file at
/// [sampleRate], with its channels mixed down to one.
List<double> decodeWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  String ascii(int offset) =>
      String.fromCharCodes(bytes.sublist(offset, offset + 4));
  if (ascii(0) != 'RIFF' || ascii(8) != 'WAVE') {
    throw const FormatException('Not a WAV file');
  }
  int? channels;
  for (var offset = 12; offset + 8 <= bytes.length;) {
    final id = ascii(offset);
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      // 1 is plain PCM; 0xFFFE is the extensible format, which afconvert
      // writes and which holds the same PCM samples.
      final format = data.getUint16(body, Endian.little);
      final bits = data.getUint16(body + 14, Endian.little);
      final rate = data.getUint32(body + 4, Endian.little);
      if (!(format == 1 || format == 0xFFFE) || bits != 16) {
        throw FormatException('Not 16-bit PCM: format $format, $bits bits');
      }
      if (rate != sampleRate) throw FormatException('Sample rate $rate');
      channels = data.getUint16(body + 2, Endian.little);
    } else if (id == 'data') {
      if (channels == null) throw const FormatException('Data before format');
      final frames = size ~/ (2 * channels);
      return [
        for (var frame = 0; frame < frames; frame++)
          [
                for (var c = 0; c < channels; c++)
                  data.getInt16(
                    body + (frame * channels + c) * 2,
                    Endian.little,
                  ),
              ].reduce((a, b) => a + b) /
              channels /
              32768,
      ];
    }
    // Chunks are padded to an even length.
    offset = body + size + (size & 1);
  }
  throw const FormatException('No audio data');
}

/// [samples] (each from −1 to 1) as a mono, 16-bit PCM WAV file.
Uint8List encodeWav(List<double> samples) {
  final dataBytes = samples.length * 2;
  final bytes = ByteData(44 + dataBytes);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes
    ..setUint32(16, 16, Endian.little) // size of the format section
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little) // bytes per second
    ..setUint16(32, 2, Endian.little) // bytes per sample
    ..setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  bytes.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final value = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    bytes.setInt16(44 + i * 2, value, Endian.little);
  }
  return bytes.buffer.asUint8List();
}
