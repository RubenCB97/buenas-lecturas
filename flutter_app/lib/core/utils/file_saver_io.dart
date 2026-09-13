import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

/// Devuelve `true` si el usuario pudo guardarlo o compartirlo.
Future<bool> saveFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) async {
  final result = await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: mimeType, name: fileName)],
      fileNameOverrides: [fileName],
      subject: fileName,
    ),
  );
  return result.status != ShareResultStatus.unavailable;
}
