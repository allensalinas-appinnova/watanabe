import 'dart:typed_data';

class ReceiptAttachment {
  const ReceiptAttachment({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;

  String get fileExtension => switch (contentType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
}
