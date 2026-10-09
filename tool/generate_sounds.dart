// Synthesises the game's placeholder sound effects as WAV files in
// assets/sounds/. They're generated rather than downloaded, so there are no
// licensing questions; Phase 3 replaces them with polished sounds.
//
// Run from the project folder:  dart run tool/generate_sounds.dart

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sampleRate = 44100;

void main() {
  final random = Random(7);
  final sounds = {
    'shuffle': shuffle(random),
    'card_snap': cardSnap(random),
    'select': select(),
    'win': winJingle(),
    'round_over': roundOver(),
  };
  Directory('assets/sounds').createSync(recursive: true);
  for (final MapEntry(key: name, value: samples) in sounds.entries) {
    final file = File('assets/sounds/$name.wav')
      ..writeAsBytesSync(encodeWav(samples));
    stdout.writeln('${file.path}: ${samples.length / sampleRate}s');
  }
}

/// A riffle: a run of short, quieter and quieter bursts of noise.
List<double> shuffle(Random random) {
  final samples = List.filled((0.55 * sampleRate).round(), 0.0);
  for (var burst = 0; burst < 22; burst++) {
    final start = (burst * 0.022 * sampleRate).round();
    final length = (0.012 * sampleRate).round();
    final loudness = 0.5 * (1 - burst / 30);
    for (var i = 0; i < length && start + i < samples.length; i++) {
      final fade = 1 - i / length;
      samples[start + i] += (random.nextDouble() * 2 - 1) * loudness * fade;
    }
  }
  return samples;
}

/// A card landing on the table: a sharp click of noise over a low thud.
List<double> cardSnap(Random random) {
  final length = (0.09 * sampleRate).round();
  return [
    for (var i = 0; i < length; i++)
      _decay(i, 0.012) * (random.nextDouble() * 2 - 1) * 0.4 +
          _decay(i, 0.03) * sin(2 * pi * 140 * i / sampleRate) * 0.25,
  ];
}

/// A soft, short tick for selecting a card.
List<double> select() {
  final length = (0.05 * sampleRate).round();
  return [
    for (var i = 0; i < length; i++)
      _decay(i, 0.01) * sin(2 * pi * 1800 * i / sampleRate) * 0.35,
  ];
}

/// A rising major arpeggio (C, E, G, high C) for winning a round.
List<double> winJingle() => _notes([523.25, 659.25, 783.99, 1046.5], 0.14);

/// A gentle falling pair of notes for when someone else wins.
List<double> roundOver() => _notes([587.33, 440.0], 0.2);

/// [frequencies] played one after another, each [noteSeconds] long, as soft
/// bell-like tones that ring on slightly.
List<double> _notes(List<double> frequencies, double noteSeconds) {
  final noteLength = (noteSeconds * sampleRate).round();
  final samples = List.filled(
    noteLength * frequencies.length + (0.3 * sampleRate).round(),
    0.0,
  );
  for (var n = 0; n < frequencies.length; n++) {
    final start = n * noteLength;
    for (var i = 0; start + i < samples.length; i++) {
      final t = i / sampleRate;
      final tone =
          sin(2 * pi * frequencies[n] * t) +
          0.3 * sin(2 * pi * 2 * frequencies[n] * t);
      samples[start + i] += tone * _decay(i, 0.18) * 0.25;
    }
  }
  return samples;
}

/// An exponential fade: 1 at the start, falling by e every [seconds].
double _decay(int sample, double seconds) =>
    exp(-sample / (seconds * sampleRate));

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
