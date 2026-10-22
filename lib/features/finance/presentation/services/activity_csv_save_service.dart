import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class ActivityCsvSaveService {
  /// Opens the platform save dialog. Returns false when the user cancels it.
  Future<bool> saveCsv({required String fileName, required String contents});
}

class NativeActivityCsvSaveService implements ActivityCsvSaveService {
  const NativeActivityCsvSaveService();

  @override
  Future<bool> saveCsv({required String fileName, required String contents}) async {
    final savedPath = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        data: Uint8List.fromList(utf8.encode(contents)),
        fileName: fileName,
        mimeTypesFilter: const ['text/csv'],
      ),
    );
    return savedPath != null;
  }
}

final activityCsvSaveServiceProvider = Provider<ActivityCsvSaveService>(
  (ref) => const NativeActivityCsvSaveService(),
);
