import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tnpsc_group_book/services/ai_service.dart';

void main() {
  test('AiService PDF utilities test with TNPSC Group 4 2025 PDF', () {
    final pdfFile = File('pdf/TNPSC-Group-4-2025-General-Studies.pdf');
    if (!pdfFile.existsSync()) {
      return;
    }
    final bytes = pdfFile.readAsBytesSync();

    // 1. Total page count
    int pageCount = AiService.getPdfPageCount(bytes);
    expect(pageCount, 79);

    // 2. Digital text extraction (should be 0 or empty for scanned PDF)
    String text = AiService.extractDigitalTextFromPdf(bytes);
    expect(text.length < 300, isTrue);

    // 3. Page slicing (first 5 pages)
    List<int>? slice = AiService.slicePdfPages(bytes, 0, 5);
    expect(slice, isNotNull);
    expect(slice!.isNotEmpty, isTrue);
    int slicePages = AiService.getPdfPageCount(slice);
    expect(slicePages, 5);

    // 4. Page slicing (pages 5 to 10)
    List<int>? slice2 = AiService.slicePdfPages(bytes, 5, 5);
    expect(slice2, isNotNull);
    int slice2Pages = AiService.getPdfPageCount(slice2!);
    expect(slice2Pages, 5);
  });
}
