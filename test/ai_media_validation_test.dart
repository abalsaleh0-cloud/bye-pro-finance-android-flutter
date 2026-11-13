import 'dart:typed_data';

import 'package:expense_app/features/ai/domain/wav_audio_validator.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _wav({required int channels}) {
  const sampleRate = 16000;
  const bitsPerSample = 16;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final byteRate = sampleRate * blockAlign;
  final bytes = Uint8List(46);
  final data = ByteData.sublistView(bytes);
  void writeText(int offset, String value) {
    bytes.setRange(offset, offset + value.length, value.codeUnits);
  }

  writeText(0, 'RIFF');
  data.setUint32(4, 38, Endian.little);
  writeText(8, 'WAVE');
  writeText(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, byteRate, Endian.little);
  data.setUint16(32, blockAlign, Endian.little);
  data.setUint16(34, bitsPerSample, Endian.little);
  writeText(36, 'data');
  data.setUint32(40, 2, Endian.little);
  bytes[44] = 1;
  bytes[45] = 2;
  return bytes;
}

void main() {
  test('accepts 16 kHz mono PCM WAV', () {
    expect(isValidGemmaWavAudio(_wav(channels: 1)), isTrue);
  });

  test('rejects stereo WAV even when sample rate and bit depth match', () {
    expect(isValidGemmaWavAudio(_wav(channels: 2)), isFalse);
  });

  test('rejects malformed or truncated WAV data', () {
    expect(isValidGemmaWavAudio(Uint8List(12)), isFalse);
    expect(isValidGemmaWavAudio(_wav(channels: 1).sublist(0, 44)), isFalse);
  });
}
