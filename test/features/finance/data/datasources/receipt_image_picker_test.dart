import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/features/finance/data/datasources/receipt_image_picker.dart';

class _MockImagePicker extends Mock implements ImagePicker {}

void main() {
  late _MockImagePicker imagePicker;
  late NativeReceiptImagePicker receiptImagePicker;

  setUp(() {
    imagePicker = _MockImagePicker();
    receiptImagePicker = NativeReceiptImagePicker(imagePicker: imagePicker);
  });

  test('reads a selected image and preserves its supported format', () async {
    final sourceImage = XFile.fromData(
      Uint8List.fromList([1, 2, 3, 4]),
      mimeType: 'image/png',
    );
    when(
      () => imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      ),
    ).thenAnswer((_) async => sourceImage);

    final attachment = await receiptImagePicker.pick(ImageSource.gallery);

    expect(attachment?.bytes, [1, 2, 3, 4]);
    expect(attachment?.contentType, 'image/png');
    verify(
      () => imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      ),
    ).called(1);
  });

  test('returns null when the user cancels image selection', () async {
    when(
      () => imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      ),
    ).thenAnswer((_) async => null);

    expect(await receiptImagePicker.pick(ImageSource.camera), isNull);
  });
}
