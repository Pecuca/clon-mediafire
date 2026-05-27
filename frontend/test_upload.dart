import 'dart:typed_data';
import 'package:pointycastle/export.dart';

void main() {
  final plaintext = Uint8List.fromList(List.generate(100, (i) => i));
  final key = Uint8List(32);
  final iv = Uint8List(16);

  final cipher = GCMBlockCipher(AESEngine());
  cipher.init(
    true,
    AEADParameters(
      KeyParameter(key),
      128,
      iv,
      Uint8List(0),
    ),
  );

  final maxOutputSize = cipher.getOutputSize(plaintext.length);
  final outputWithTag = Uint8List(maxOutputSize);
  
  final len = cipher.processBytes(plaintext, 0, plaintext.length, outputWithTag, 0);
  final len2 = cipher.doFinal(outputWithTag, len);
  
  final totalLen = len + len2;
  
  print('maxOutputSize: $maxOutputSize');
  print('processBytes len: $len');
  print('doFinal len: $len2');
  print('totalLen: $totalLen');
  
  // What happens if we do not use totalLen?
  final cipherText = outputWithTag.sublist(0, outputWithTag.length - 16);
  final authTag = outputWithTag.sublist(outputWithTag.length - 16);
  print('cipherText length: ${cipherText.length}');
  print('authTag length: ${authTag.length}');
}
