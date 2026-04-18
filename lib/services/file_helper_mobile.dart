import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileHelper {
  static Future<void> saveAndShare(List<int> bytes, String fileName) async {
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = io.File(filePath);
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(filePath)], text: fileName);
  }
}
