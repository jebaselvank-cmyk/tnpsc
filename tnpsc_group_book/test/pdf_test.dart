import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Extract text from PDF using syncfusion_flutter_pdf', () async {
    File file = File('pdf/TNPSC-Group-4-2025-General-Studies.pdf');
    if (!file.existsSync()) {
      print('PDF file does not exist at path');
      return;
    }
    List<int> bytes = await file.readAsBytes();
    print('Read ${bytes.length} bytes from PDF');

    PdfDocument document = PdfDocument(inputBytes: bytes);
    print('Total pages: ${document.pages.count}');

    String text = PdfTextExtractor(document).extractText();
    print('Extracted ${text.length} characters of text!');
    document.dispose();

    print('Preview of first 500 characters:');
    print(text.substring(0, text.length > 500 ? 500 : text.length));

    expect(text.length, greaterThan(100));
  });
}
