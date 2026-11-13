import 'dart:typed_data';

/// Accepts PCM WAV files matching the model's 16 kHz mono input.
///
/// RIFF chunks are walked instead of assuming that the fmt and data chunks
/// always occur at fixed byte offsets; valid WAV files may contain metadata
/// chunks before or between them.
bool isValidGemmaWavAudio(Uint8List bytes) {
  if (bytes.length < 12 ||
      String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
    return false;
  }

  final data = ByteData.sublistView(bytes);
  final riffSize = data.getUint32(4, Endian.little);
  final riffEnd = 8 + riffSize;
  if (riffSize < 4 || riffEnd > bytes.length) {
    return false;
  }

  int? audioFormat;
  int? channels;
  int? sampleRate;
  int? byteRate;
  int? blockAlign;
  int? bitsPerSample;
  int? audioDataSize;

  var offset = 12;
  while (offset + 8 <= riffEnd) {
    final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final chunkSize = data.getUint32(offset + 4, Endian.little);
    final chunkStart = offset + 8;
    final chunkEnd = chunkStart + chunkSize;
    if (chunkEnd > riffEnd) {
      return false;
    }

    if (chunkId == 'fmt ') {
      if (chunkSize < 16) {
        return false;
      }
      audioFormat = data.getUint16(chunkStart, Endian.little);
      channels = data.getUint16(chunkStart + 2, Endian.little);
      sampleRate = data.getUint32(chunkStart + 4, Endian.little);
      byteRate = data.getUint32(chunkStart + 8, Endian.little);
      blockAlign = data.getUint16(chunkStart + 12, Endian.little);
      bitsPerSample = data.getUint16(chunkStart + 14, Endian.little);
    } else if (chunkId == 'data') {
      audioDataSize = chunkSize;
    }

    offset = chunkEnd + (chunkSize.isOdd ? 1 : 0);
    if (offset > riffEnd) {
      return false;
    }
  }

  return offset == riffEnd &&
      audioFormat == 1 &&
      channels == 1 &&
      sampleRate == 16000 &&
      byteRate == 32000 &&
      blockAlign == 2 &&
      bitsPerSample == 16 &&
      audioDataSize != null &&
      audioDataSize > 0 &&
      audioDataSize % 2 == 0;
}
