import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/document_import.dart';

enum DocumentFileSource { camera, gallery, file }

class DocumentFilePicker {
  Future<DocumentFile?> pick(DocumentFileSource source) async {
    if (source == DocumentFileSource.file) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null) return null;
      final file = result.files.single;
      if (file.size > 10000000 || file.bytes == null) throw StateError('document-file-invalid');
      return normalize(file.bytes!, pdf: true);
    }
    final image = await ImagePicker().pickImage(
      source: source == DocumentFileSource.camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2400,
      maxHeight: 2400,
      requestFullMetadata: false,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    if (kIsWeb) {
      final type = image.mimeType ?? 'image/jpeg';
      if (!['image/jpeg', 'image/png', 'image/webp'].contains(type) || bytes.length > 5000000) {
        throw StateError('document-file-invalid');
      }
      return DocumentFile(bytes: bytes, contentType: type);
    }
    return normalize(bytes, pdf: false);
  }

  static bool isSupportedImage(Uint8List bytes) {
    if (bytes.length < 12) return false;
    if (bytes[0] == 0xff && bytes[1] == 0xd8) return true;
    if (bytes[0] == 0x89 && String.fromCharCodes(bytes.sublist(1, 4)) == 'PNG') return true;
    if (String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return true;
    }
    return String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp' &&
        {
          'heic',
          'heix',
          'hevc',
          'hevx',
          'mif1',
          'msf1',
          'heif',
        }.contains(String.fromCharCodes(bytes.sublist(8, 12)));
  }

  static Future<DocumentFile> normalize(Uint8List bytes, {required bool pdf}) async {
    if (pdf) {
      if (bytes.length < 5 ||
          bytes.length > 10000000 ||
          String.fromCharCodes(bytes.take(5)) != '%PDF-') {
        throw StateError('document-file-invalid');
      }
      return DocumentFile(bytes: bytes, contentType: 'application/pdf');
    }
    if (bytes.isEmpty || bytes.length > 20000000) throw StateError('document-file-invalid');
    final normalized = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 2400,
      minHeight: 2400,
      quality: 90,
      keepExif: false,
      format: CompressFormat.jpeg,
    );
    if (normalized.isEmpty || normalized.length > 5000000) {
      throw StateError('document-file-invalid');
    }
    return DocumentFile(bytes: normalized, contentType: 'image/jpeg');
  }
}
