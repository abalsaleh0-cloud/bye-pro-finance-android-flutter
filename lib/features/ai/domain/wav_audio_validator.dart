import 'dart:typed_data';

/// Accepts only PCM WAV audio matching the model's 16 kHz mono input.
bool isValidGemmaWavAudio(Uint8List bytes) {
  if (bytes.length < 44 ||
      String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
    return false;
  }
  final data = ByteData.sublistView(bytes);
  return data.getUint16(20, Endian.little) == 1 &&
      data.getUint16(22, Endian.little) == 1 &&
      data.getUint32(24, Endian.little) == 16000 &&
      data.getUint32(28, Endian.little) == 32000 &&
      data.getUint16(32, Endian.little) == 2 &&
      data.getUint16(34, Endian.little) == 16 &&
      data.getUint32(40, Endian.little) > 0 &&
      data.getUint32(40, Endian.little) <= bytes.length - 44;
}
