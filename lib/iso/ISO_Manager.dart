import 'package:dio/dio.dart';
import 'package:boot_helper/misc/logger.dart';

class ISOManager {
  static Future<void> downloadISO(String ISO, String savePath) async {
    final dio = Dio();

    await dio.download(
      ISO,
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          AppLogger.info('${(received / total * 100).toStringAsFixed(0)}%');
        }
      },
    );
  }
}
