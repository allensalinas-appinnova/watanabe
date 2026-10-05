import 'package:image_picker/image_picker.dart';

import '../../domain/entities/receipt_attachment.dart';

abstract interface class ReceiptImagePicker {
  Future<ReceiptAttachment?> pick(ImageSource source);
}

class NativeReceiptImagePicker implements ReceiptImagePicker {
  NativeReceiptImagePicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<ReceiptAttachment?> pick(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (image == null) return null;

    final extension = image.name.split('.').last.toLowerCase();
    final contentType =
        image.mimeType ??
        switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        };
    return ReceiptAttachment(
      bytes: await image.readAsBytes(),
      contentType: contentType,
    );
  }
}
