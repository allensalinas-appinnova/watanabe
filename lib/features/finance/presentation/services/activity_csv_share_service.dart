import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

abstract interface class ActivityCsvShareService {
  Future<void> shareCsv({
    required String fileName,
    required String contents,
    required String subject,
  });
}

class NativeActivityCsvShareService implements ActivityCsvShareService {
  const NativeActivityCsvShareService();

  @override
  Future<void> shareCsv({
    required String fileName,
    required String contents,
    required String subject,
  }) async {
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(contents)),
      mimeType: 'text/csv',
      name: fileName,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        fileNameOverrides: [fileName],
        subject: subject,
      ),
    );
  }
}

final activityCsvShareServiceProvider = Provider<ActivityCsvShareService>(
  (ref) => const NativeActivityCsvShareService(),
);
