import 'dart:typed_data';

import 'package:expense_app/features/ai/domain/wav_audio_validator.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _wav({required int channels, bool includeMetadataChunk = false}) {
  const sampleRate = 16000;
  const bitsPerSample = 16;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final byteRate = sampleRate * blockAlign;
  final metadataLength = includeMetadataChunk ? 10 : 0;
  final bytes = Uint8List(46 + metadataLength);
  final data = ByteData.sublistView(bytes);
  void writeText(int offset, String value) {
    bytes.setRange(offset, offset + value.length, value.codeUnits);
  }

  writeText(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  writeText(8, 'WAVE');

  var offset = 12;
  if (includeMetadataChunk) {
    writeText(offset, 'JUNK');
    data.setUint32(offset + 4, 2, Endian.little);
    bytes[offset + 8] = 7;
    bytes[offset + 9] = 8;
    offset += 10;
  }

  writeText(offset, 'fmt ');
  data.setUint32(offset + 4, 16, Endian.little);
  data.setUint16(offset + 8, 1, Endian.little);
  data.setUint16(offset + 10, channels, Endian.little);
  data.setUint32(offset + 12, sampleRate, Endian.little);
  data.setUint32(offset + 16, byteRate, Endian.little);
  data.setUint16(offset + 20, blockAlign, Endian.little);
  data.setUint16(offset + 22, bitsPerSample, Endian.little);
  offset += 24;

  writeText(offset, 'data');
  data.setUint32(offset + 4, 2, Endian.little);
  bytes[offset + 8] = 1;
  bytes[offset + 9] = 2;
  return bytes;
}

void main() {
  test('accepts 16 kHz mono PCM WAV', () {
    expect(isValidGemmaWavAudio(_wav(channels: 1)), isTrue);
  });

  test('accepts valid WAV with metadata chunk before format chunk', () {
    expect(
      isValidGemmaWavAudio(_wav(channels: 1, includeMetadataChunk: true)),
      isTrue,
    );
  });

  test('rejects stereo WAV even when sample rate and bit depth match', () {
    expect(isValidGemmaWavAudio(_wav(channels: 2)), isFalse);
  });

  test('rejects malformed or truncated WAV data', () {
    expect(isValidGemmaWavAudio(Uint8List(12)), isFalse);
    expect(isValidGemmaWavAudio(_wav(channels: 1).sublist(0, 44)), isFalse);
  });
}
