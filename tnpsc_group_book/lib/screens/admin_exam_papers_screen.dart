import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question.dart';
import '../data/seed_papers_2025.dart';
import '../services/firestore_service.dart';
import '../services/ai_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_log.dart';

class AdminExamPapersScreen extends StatefulWidget {
  const AdminExamPapersScreen({super.key});

  @override
  State<AdminExamPapersScreen> createState() => _AdminExamPapersScreenState();
}

class _AdminExamPapersScreenState extends State<AdminExamPapersScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  String _selectedExamFilter = "All";
  List<Map<String, dynamic>> _papers = [];
  bool _isChunkProcessing = false;

  List<int>? _selectedPdfBytes;
  String? _selectedPdfPath;
  String? _selectedPdfName;
  int _selectedPdfPages = 0;
  bool _selectedPdfIsScanned = false;

  final List<String> _examTypes = ["Group 4", "Group 2/2A", "Group 1", "VAO", "Other"];

  @override
  void initState() {
    super.initState();
    _fetchPapers();
  }

  Future<void> _fetchPapers() async {
    setState(() => _isLoading = true);
    try {
      final list = await _firestoreService.getExamPapers(examType: _selectedExamFilter);
      setState(() {
        _papers = list;
        _isLoading = false;
      });
    } catch (e) {
      AppLog.e("Error fetching exam papers in admin: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processNextChunk(Map<String, dynamic> paper) async {
    setState(() => _isChunkProcessing = true);
    String paperDocId = paper['docId'] ?? paper['id'];
    String rawText = paper['rawText'] ?? "";
    List<dynamic> currentQuestions = paper['questions'] ?? [];
    int startQuestionNum = currentQuestions.length + 1;
    int totalExpected = paper['totalQuestions'] is int ? paper['totalQuestions'] : 100;
    String examType = paper['examType'] ?? 'Group 4';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Processing Chunk from Question #$startQuestionNum with AI..."),
      duration: const Duration(seconds: 4),
    ));

    bool isScanned = rawText.contains('[SCANNED_PDF:') || paper['pdfPath'] != null;
    List<Map<String, dynamic>> newQuestions = [];

    if (isScanned) {
      List<int>? pdfBytes = _selectedPdfBytes;
      if (pdfBytes == null && paper['pdfPath'] != null) {
        final f = File(paper['pdfPath']);
        if (f.existsSync()) {
          pdfBytes = await f.readAsBytes();
        }
      }

      if (pdfBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Please select the PDF file to resume extraction."),
          ));
        }
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        List<PlatformFile> files = result?.files ?? [];
        if (files.isNotEmpty && files.first.path != null) {
          pdfBytes = await File(files.first.path!).readAsBytes();
          _selectedPdfBytes = pdfBytes;
          _selectedPdfPath = files.first.path;
        }
      }

      if (pdfBytes != null) {
        int totalPages = AiService.getPdfPageCount(pdfBytes);
        int processedPages = paper['processedPages'] is int ? paper['processedPages'] : 0;
        if (processedPages == 0 && currentQuestions.isNotEmpty) {
          processedPages = (currentQuestions.length * 0.7).floor().clamp(0, totalPages);
        }
        int pagesPerChunk = 6;
        int startPage = processedPages;
        if (startPage >= totalPages) startPage = 0;

        List<int>? sliced = AiService.slicePdfPages(pdfBytes, startPage, pagesPerChunk);
        newQuestions = await AiService.extractQuestionsFromPdfBytes(
          pdfBytes: sliced ?? pdfBytes,
          examType: examType,
          startQuestionNum: startQuestionNum,
          maxQuestions: 15,
        );

        if (newQuestions.isNotEmpty) {
          int newProcessedPages = (startPage + pagesPerChunk < totalPages) ? startPage + pagesPerChunk : totalPages;
          await FirebaseFirestore.instance.collection('exam_papers').doc(paperDocId).update({
            'processedPages': newProcessedPages,
          });
        }
      }
    } else {
      // Digital / Plain text chunking
      String chunkText = rawText;
      if (rawText.length > 3000) {
        int startOffset = (currentQuestions.length * 250);
        if (startOffset < rawText.length) {
          int endOffset = (startOffset + 3500 < rawText.length) ? startOffset + 3500 : rawText.length;
          chunkText = rawText.substring(startOffset, endOffset);
        }
      }

      newQuestions = await AiService.parseAndEnrichPdfChunk(
        rawChunkText: chunkText,
        startQuestionNum: startQuestionNum,
        examType: examType,
      );
    }

    if (newQuestions.isNotEmpty) {
      int totalNow = currentQuestions.length + newQuestions.length;
      bool isCompleted = totalNow >= totalExpected;

      bool ok = await _firestoreService.appendExamPaperChunk(
        paperDocId: paperDocId,
        newQuestionsChunk: newQuestions,
        isCompleted: isCompleted,
      );

      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Chunk Saved! Added ${newQuestions.length} Qs. Total: $totalNow / $totalExpected"),
        ));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("No questions extracted from this chunk. Try verifying or selecting PDF."),
        ));
      }
    }

    setState(() => _isChunkProcessing = false);
    _fetchPapers();
  }

  Future<void> _processAllChunksAuto(Map<String, dynamic> paper) async {
    setState(() => _isChunkProcessing = true);
    String paperDocId = paper['docId'] ?? paper['id'];
    String rawText = paper['rawText'] ?? "";
    String examType = paper['examType'] ?? 'Group 4';
    int totalExpected = paper['totalQuestions'] is int ? paper['totalQuestions'] : 100;
    bool isScanned = rawText.contains('[SCANNED_PDF:') || paper['pdfPath'] != null;

    List<int>? pdfBytes = _selectedPdfBytes;
    if (isScanned && pdfBytes == null && paper['pdfPath'] != null) {
      final f = File(paper['pdfPath']);
      if (f.existsSync()) {
        pdfBytes = await f.readAsBytes();
      }
    }

    if (isScanned && pdfBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("PDF file required. Please pick the PDF file to extract questions."),
        ));
      }
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      List<PlatformFile> files = result?.files ?? [];
      if (files.isNotEmpty && files.first.path != null) {
        pdfBytes = await File(files.first.path!).readAsBytes();
        _selectedPdfBytes = pdfBytes;
        _selectedPdfPath = files.first.path;
      } else {
        setState(() => _isChunkProcessing = false);
        return;
      }
    }

    int totalPages = (isScanned && pdfBytes != null) ? AiService.getPdfPageCount(pdfBytes) : 1;
    int maxLoops = 20; // Safety limit
    int loopCount = 0;

    while (loopCount < maxLoops) {
      loopCount++;

      DocumentSnapshot docSnap = await FirebaseFirestore.instance.collection('exam_papers').doc(paperDocId).get();
      if (!docSnap.exists) break;

      Map<String, dynamic> currentData = Map<String, dynamic>.from(docSnap.data() as Map);
      List<dynamic> currentQuestions = currentData['questions'] ?? [];
      int currentCount = currentQuestions.length;
      int processedPages = currentData['processedPages'] is int ? currentData['processedPages'] : 0;

      if (currentCount >= totalExpected || (isScanned && processedPages >= totalPages && processedPages > 0)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("✨ Auto Extraction Complete! Saved $currentCount / $totalExpected questions to Exam Paper."),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ));
        }
        break;
      }

      int startQuestionNum = currentCount + 1;
      int pagesPerChunk = 6;
      int startPage = processedPages;
      if (startPage >= totalPages) startPage = 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("🤖 Auto Extraction Loop $loopCount: Extracting Q#$startQuestionNum onwards (Pages ${startPage + 1}..${startPage + pagesPerChunk} of $totalPages)..."),
          duration: const Duration(seconds: 4),
        ));
      }

      List<Map<String, dynamic>> newQuestions = [];

      if (isScanned && pdfBytes != null) {
        List<int>? sliced = AiService.slicePdfPages(pdfBytes, startPage, pagesPerChunk);
        newQuestions = await AiService.extractQuestionsFromPdfBytes(
          pdfBytes: sliced ?? pdfBytes,
          examType: examType,
          startQuestionNum: startQuestionNum,
          maxQuestions: 15,
        );

        if (newQuestions.isNotEmpty) {
          int newProcessedPages = (startPage + pagesPerChunk < totalPages) ? startPage + pagesPerChunk : totalPages;
          await FirebaseFirestore.instance.collection('exam_papers').doc(paperDocId).update({
            'processedPages': newProcessedPages,
          });
        }
      } else {
        // Plain text extraction grouped by question boundaries
        List<String> textChunks = AiService.splitTextIntoQuestionChunks(rawText, targetQuestionsPerChunk: 15);
        int chunkIndex = (currentCount / 15).floor().clamp(0, textChunks.isNotEmpty ? textChunks.length - 1 : 0);
        String chunkText = textChunks.isNotEmpty ? textChunks[chunkIndex] : rawText;

        newQuestions = await AiService.parseAndEnrichPdfChunk(
          rawChunkText: chunkText,
          startQuestionNum: startQuestionNum,
          examType: examType,
        );
      }

      if (newQuestions.isEmpty) {
        AppLog.d("AI_DEBUG: Auto chunk $loopCount extracted 0 questions. Stopping loop.");
        break;
      }

      int totalNow = currentCount + newQuestions.length;
      bool isCompleted = totalNow >= totalExpected;

      await _firestoreService.appendExamPaperChunk(
        paperDocId: paperDocId,
        newQuestionsChunk: newQuestions,
        isCompleted: isCompleted,
      );

      await Future.delayed(const Duration(milliseconds: 1000));
    }

    setState(() => _isChunkProcessing = false);
    _fetchPapers();
  }

  Future<void> _deletePaper(String docId, String title) async {
    bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Confirm Delete / நீக்குதல்"),
            content: Text("Are you sure you want to delete '$title'?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Delete"),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      bool success = await _firestoreService.deleteExamPaper(docId);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Paper deleted successfully.")));
        }
        _fetchPapers();
      }
    }
  }

  Future<void> _pickFileAndFill(
    TextEditingController titleCtrl,
    TextEditingController rawTextCtrl,
    TextEditingController jsonCtrl, [
    StateSetter? setDialogState,
  ]) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'json'],
      );
      List<PlatformFile> files = result?.files ?? [];

      if (files.isNotEmpty) {
        PlatformFile file = files.first;
        String fileName = file.name;

        if (titleCtrl.text.trim().isEmpty) {
          String cleanTitle = fileName
              .replaceAll(RegExp(r'\.(pdf|txt|json)$', caseSensitive: false), '')
              .replaceAll('-', ' ')
              .replaceAll('_', ' ');
          titleCtrl.text = cleanTitle;
        }

        if (file.path != null) {
          if (fileName.toLowerCase().endsWith('.pdf')) {
            final bytes = await File(file.path!).readAsBytes();
            _selectedPdfBytes = bytes;
            _selectedPdfPath = file.path;
            _selectedPdfName = fileName;
            _selectedPdfPages = AiService.getPdfPageCount(bytes);

            _selectedPdfIsScanned = true;
            rawTextCtrl.text = "[SCANNED_PDF: $fileName | Pages: $_selectedPdfPages]";
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("Selected PDF '$fileName' ($_selectedPdfPages pages). Ready for High-Accuracy AI Vision extraction!"),
              ));
            }
            if (setDialogState != null) {
              setDialogState(() {});
            }
            return;
          }

          if (fileName.toLowerCase().endsWith('.json')) {
            String content = await File(file.path!).readAsString();
            jsonCtrl.text = content;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("Selected JSON '$fileName'! Ready to save."),
              ));
            }
            return;
          }

          // txt or other
          String content = await File(file.path!).readAsString();
          rawTextCtrl.text = content;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Selected '$fileName'! Extracted ${content.length} characters."),
            ));
          }
        }
      }
    } catch (e) {
      AppLog.e("Error picking file in admin: $e");
    }
  }

  void _showAddPaperDialog() {
    String examType = _examTypes.first;
    final yearController = TextEditingController(text: "2025");
    final titleController = TextEditingController();
    final totalController = TextEditingController(text: "100");
    final rawTextController = TextEditingController();
    final jsonController = TextEditingController();
    bool isOneClickExtracting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurfaceColor : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Add Exam Paper / புதிய வினாத்தாள்",
                        style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: examType,
                  decoration: const InputDecoration(labelText: "Exam Type / தேர்வு வகை", border: OutlineInputBorder()),
                  items: _examTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => examType = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: yearController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Year / ஆண்டு", border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: totalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Total Qs / மொத்த வினாக்கள்", border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickFileAndFill(titleController, rawTextController, jsonController, setDialogState),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text("Select & Upload PDF / File (PDF கோப்பைத் தேர்வுசெய்)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                if (_selectedPdfName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "$_selectedPdfName ($_selectedPdfPages pages - ${_selectedPdfIsScanned ? 'Scanned PDF' : 'Digital PDF'})",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ActionChip(
                        avatar: const Icon(Icons.bolt, size: 16, color: Colors.purple),
                        label: const Text("Preset: 2025 TN Paper", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          var paper = SeedPapers2025.getGroup4TamilPaper();
                          setDialogState(() {
                            examType = paper['examType'];
                            yearController.text = "${paper['year']}";
                            totalController.text = "${paper['totalQuestions']}";
                            titleController.text = paper['title'];
                            jsonController.text = jsonEncode(paper['questions']);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loaded 2025 Group 4 Tamil Preset!")));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ActionChip(
                        avatar: const Icon(Icons.bolt, size: 16, color: Colors.indigo),
                        label: const Text("Preset: 2025 GS Paper", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          var paper = SeedPapers2025.getGroup4GsPaper();
                          setDialogState(() {
                            examType = paper['examType'];
                            yearController.text = "${paper['year']}";
                            totalController.text = "${paper['totalQuestions']}";
                            titleController.text = paper['title'];
                            jsonController.text = jsonEncode(paper['questions']);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loaded 2025 Group 4 GS Preset!")));
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: "Paper Title / தலைப்பு",
                    hintText: "e.g. TNPSC Group 4 2025 Original Tamil Paper",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rawTextController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "Raw PDF Text / PDF உரை (Optional for Chunk Processing)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: jsonController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "Questions JSON Array (Optional)",
                    hintText: '[{"question_en":"...", "question_ta":"..."}]',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isOneClickExtracting
                        ? null
                        : () async {
                            if (titleController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text("Please enter a Paper Title / தலைப்பு"),
                              ));
                              return;
                            }

                            String pastedText = rawTextController.text.trim();
                            if (pastedText.isEmpty && _selectedPdfBytes == null && _selectedPdfPath == null && jsonController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text("Please paste Raw PDF Text or select a PDF file first!"),
                              ));
                              return;
                            }

                            setDialogState(() => isOneClickExtracting = true);
                            int year = int.tryParse(yearController.text.trim()) ?? 2025;
                            int total = int.tryParse(totalController.text.trim()) ?? 100;
                            String paperTitle = titleController.text.trim();

                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text("🚀 1-Click AI Extraction, Proofreading & Saving to Firestore in progress..."),
                              duration: Duration(seconds: 5),
                            ));

                            List<Map<String, dynamic>> extractedQuestions = [];

                            // Check if JSON array was provided
                            String jsonStr = jsonController.text.trim();
                            if (jsonStr.isNotEmpty) {
                              try {
                                int start = jsonStr.indexOf('[');
                                int end = jsonStr.lastIndexOf(']');
                                if (start != -1 && end != -1) {
                                  List parsed = jsonDecode(jsonStr.substring(start, end + 1));
                                  extractedQuestions = parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                                }
                              } catch (e) {
                                AppLog.e("Error parsing json input: $e");
                              }
                            }

                            // If JSON was empty, extract from pasted text or PDF
                            if (extractedQuestions.isEmpty && pastedText.isNotEmpty && !pastedText.contains('[SCANNED_PDF:')) {
                              List<String> textChunks = AiService.splitTextIntoQuestionChunks(pastedText, targetQuestionsPerChunk: 15);
                              int startQ = 1;

                              for (int i = 0; i < textChunks.length; i++) {
                                String chunk = textChunks[i];
                                List<Map<String, dynamic>> chunkQs = await AiService.parseAndEnrichPdfChunk(
                                  rawChunkText: chunk,
                                  startQuestionNum: startQ,
                                  examType: examType,
                                );

                                if (chunkQs.isNotEmpty) {
                                  extractedQuestions.addAll(chunkQs);
                                  startQ += chunkQs.length;
                                }

                                if (extractedQuestions.length >= total) break;
                              }
                            } else if (extractedQuestions.isEmpty && _selectedPdfBytes != null) {
                              int totalPages = AiService.getPdfPageCount(_selectedPdfBytes!);
                              int pagesPerChunk = 6;
                              int startPage = 0;

                              while (startPage < totalPages && extractedQuestions.length < total) {
                                List<int>? sliced = AiService.slicePdfPages(_selectedPdfBytes!, startPage, pagesPerChunk);
                                List<Map<String, dynamic>> chunkQs = await AiService.extractQuestionsFromPdfBytes(
                                  pdfBytes: sliced ?? _selectedPdfBytes!,
                                  examType: examType,
                                  startQuestionNum: extractedQuestions.length + 1,
                                  maxQuestions: 15,
                                );

                                if (chunkQs.isNotEmpty) {
                                  extractedQuestions.addAll(chunkQs);
                                } else {
                                  break;
                                }

                                startPage += pagesPerChunk;
                              }
                            }

                            // Spell-check & Proofread extracted questions
                            if (extractedQuestions.isNotEmpty) {
                              extractedQuestions = await AiService.proofreadAndFixExamPaperSpelling(extractedQuestions);
                            }

                            // Save directly to Firestore 'exam_papers' collection
                            bool ok = await _firestoreService.saveExamPaper(
                              examType: examType,
                              year: year,
                              title: paperTitle,
                              questions: extractedQuestions,
                              rawText: pastedText.isNotEmpty ? pastedText : null,
                              pdfPath: _selectedPdfPath,
                              totalQuestions: total,
                              processedCount: extractedQuestions.length,
                              isCompleted: extractedQuestions.isNotEmpty && extractedQuestions.length >= total,
                            );

                            setDialogState(() => isOneClickExtracting = false);

                            if (ok && mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text("✨ 1-Click Success! Saved ${extractedQuestions.length} proofread questions to Firestore!"),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 4),
                              ));
                              _fetchPapers();
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text("Failed to save exam paper. Please try again."),
                              ));
                            }
                          },
                    icon: isOneClickExtracting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.bolt_rounded, size: 20),
                    label: Text(
                      isOneClickExtracting
                          ? "AI Processing & Proofreading..."
                          : "⚡ 1-Click AI Extract, Proofread & Save to Firestore",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty) return;
                      int year = int.tryParse(yearController.text.trim()) ?? 2025;
                      int total = int.tryParse(totalController.text.trim()) ?? 100;

                      bool ok = await _firestoreService.saveExamPaper(
                        examType: examType,
                        year: year,
                        title: titleController.text.trim(),
                        questions: [],
                        rawText: rawTextController.text.trim().isNotEmpty ? rawTextController.text.trim() : null,
                        pdfPath: _selectedPdfPath,
                        totalQuestions: total,
                        processedCount: 0,
                        isCompleted: false,
                      );

                      if (ok && mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Draft Exam Paper saved!")));
                        _fetchPapers();
                      }
                    },
                    child: const Text("Save Draft Only (without AI extraction)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isAiVerifying = false;

  Future<void> _runAiVerification(Map<String, dynamic> paper, StateSetter modalSetState) async {
    List<dynamic> rawQuestions = paper['questions'] ?? [];
    String rawText = paper['rawText'] ?? "";
    String paperDocId = paper['docId'] ?? paper['id'];
    String examType = paper['examType'] ?? 'Group 4';
    int totalExpected = paper['totalQuestions'] is int ? paper['totalQuestions'] : 100;

    if (rawQuestions.isEmpty) {
      bool isScanned = rawText.contains('[SCANNED_PDF:') || paper['pdfPath'] != null;

      modalSetState(() => _isAiVerifying = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("AI is extracting & verifying questions from PDF with Vision..."),
        duration: Duration(seconds: 4),
      ));

      List<Map<String, dynamic>> extracted = [];

      if (isScanned || rawText.isEmpty) {
        List<int>? pdfBytes = _selectedPdfBytes;
        if (pdfBytes == null && paper['pdfPath'] != null) {
          final f = File(paper['pdfPath']);
          if (f.existsSync()) {
            pdfBytes = await f.readAsBytes();
          }
        }

        if (pdfBytes == null) {
          modalSetState(() => _isAiVerifying = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Please select the PDF file to extract questions."),
            ));
          }
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
          );
          List<PlatformFile> files = result?.files ?? [];
          if (files.isNotEmpty && files.first.path != null) {
            pdfBytes = await File(files.first.path!).readAsBytes();
            _selectedPdfBytes = pdfBytes;
            _selectedPdfPath = files.first.path;
            modalSetState(() => _isAiVerifying = true);
          } else {
            return;
          }
        }

        int totalPages = AiService.getPdfPageCount(pdfBytes);
        int pagesPerChunk = 6;
        List<int>? sliced = AiService.slicePdfPages(pdfBytes, 0, pagesPerChunk);

        extracted = await AiService.extractQuestionsFromPdfBytes(
          pdfBytes: sliced ?? pdfBytes,
          examType: examType,
          startQuestionNum: 1,
          maxQuestions: 15,
        );

        if (extracted.isNotEmpty) {
          await FirebaseFirestore.instance.collection('exam_papers').doc(paperDocId).update({
            'processedPages': pagesPerChunk < totalPages ? pagesPerChunk : totalPages,
          });
        }
      } else {
        // Plain text extraction
        extracted = await AiService.parseAndEnrichPdfChunk(
          rawChunkText: rawText,
          startQuestionNum: 1,
          examType: examType,
        );
      }

      if (extracted.isNotEmpty) {
        bool ok = await _firestoreService.saveExamPaper(
          id: paperDocId,
          examType: examType,
          year: paper['year'] is int ? paper['year'] : 2025,
          title: paper['title'] ?? 'Exam Paper',
          questions: extracted,
          rawText: rawText.isNotEmpty ? rawText : null,
          pdfPath: paper['pdfPath'] ?? _selectedPdfPath,
          totalQuestions: totalExpected,
          processedCount: extracted.length,
          isCompleted: extracted.length >= totalExpected,
        );

        modalSetState(() => _isAiVerifying = false);
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Successfully generated ${extracted.length} questions from PDF!"),
          ));
          Navigator.pop(context);
          _fetchPapers();
        }
        return;
      } else {
        modalSetState(() => _isAiVerifying = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Failed to extract questions from PDF. Please verify PDF file quality."),
          ));
        }
        return;
      }
    }

    modalSetState(() => _isAiVerifying = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("AI Fact-checking answer keys and generating explanations..."),
      duration: Duration(seconds: 4),
    ));

    List<Map<String, dynamic>> questionsMap = rawQuestions.map((q) => Map<String, dynamic>.from(q as Map)).toList();

    List<Map<String, dynamic>> verified = await AiService.verifyAndEnrichExamPaperQuestions(questionsMap);

    bool ok = await _firestoreService.saveExamPaper(
      id: paperDocId,
      examType: examType,
      year: paper['year'] is int ? paper['year'] : 2025,
      title: paper['title'] ?? 'Exam Paper',
      questions: verified,
      rawText: paper['rawText'],
      pdfPath: paper['pdfPath'],
      totalQuestions: paper['totalQuestions'],
      processedCount: verified.length,
      isCompleted: verified.length >= (paper['totalQuestions'] ?? 100),
    );

    modalSetState(() => _isAiVerifying = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("AI Verification Complete! Answer keys & explanations updated."),
      ));
      Navigator.pop(context);
      _fetchPapers();
    }
  }

  bool _isAiSpellChecking = false;

  Future<void> _runAiSpellCheck(Map<String, dynamic> paper, StateSetter modalSetState) async {
    List<dynamic> rawQuestions = paper['questions'] ?? [];
    String paperDocId = paper['docId'] ?? paper['id'];
    String examType = paper['examType'] ?? 'Group 4';

    if (rawQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("No questions to proofread. Please extract questions first."),
      ));
      return;
    }

    modalSetState(() => _isAiSpellChecking = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("✨ AI is proofreading & fixing Tamil spelling for all ${rawQuestions.length} questions..."),
      duration: const Duration(seconds: 5),
    ));

    List<Map<String, dynamic>> questionsMap = rawQuestions.map((q) => Map<String, dynamic>.from(q as Map)).toList();

    List<Map<String, dynamic>> proofread = await AiService.proofreadAndFixExamPaperSpelling(questionsMap);

    bool ok = await _firestoreService.saveExamPaper(
      id: paperDocId,
      examType: examType,
      year: paper['year'] is int ? paper['year'] : 2025,
      title: paper['title'] ?? 'Exam Paper',
      questions: proofread,
      rawText: paper['rawText'],
      pdfPath: paper['pdfPath'],
      totalQuestions: paper['totalQuestions'],
      processedCount: proofread.length,
      isCompleted: paper['isCompleted'] ?? false,
    );

    modalSetState(() => _isAiSpellChecking = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("✨ All Tamil spelling & option typos fixed successfully by AI!"),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context);
      _fetchPapers();
    }
  }

  void _showAnswerKeyEditor(Map<String, dynamic> paper) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String paperDocId = paper['docId'] ?? paper['id'];
    List<dynamic> rawQuestions = paper['questions'] ?? [];
    List<Question> questions = rawQuestions.map((q) => Question.fromMap(Map<String, dynamic>.from(q as Map))).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, modalSetState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (ctx, scrollController) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBgColor : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(paper['title'] ?? 'Answer Key Editor',
                              style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text("${paper['examType']} (${paper['year']}) - ${questions.length} Questions",
                              style: AppTheme.getStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                if (questions.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_isAiVerifying || _isAiSpellChecking) ? null : () => _runAiVerification(paper, modalSetState),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _isAiVerifying
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.auto_awesome, size: 16),
                          label: const Text(
                            "Verify Answers",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_isAiVerifying || _isAiSpellChecking) ? null : () => _runAiSpellCheck(paper, modalSetState),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _isAiSpellChecking
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.spellcheck, size: 16),
                          label: const Text(
                            "✨ Fix Tamil Spelling",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isAiVerifying ? null : () => _runAiVerification(paper, modalSetState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isAiVerifying
                          ? const SizedBox(width: 16, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: const Text(
                        "✨ Extract All Questions & Answers with AI",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
                const Divider(),
                Expanded(
                  child: questions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, size: 64, color: AppTheme.primaryColor),
                                const SizedBox(height: 16),
                                Text(
                                  "No questions generated yet (0 Questions)",
                                  style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Click the purple button above to let AI extract all questions & answer keys from the PDF text and generate explanations automatically!",
                                  textAlign: TextAlign.center,
                                  style: AppTheme.getStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _isAiVerifying ? null : () => _runAiVerification(paper, modalSetState),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  icon: _isAiVerifying
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.auto_awesome),
                                  label: Text(
                                    _isAiVerifying ? "Generating Questions..." : "Extract All Questions & Answers with AI",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: questions.length,
                          itemBuilder: (ctx, index) {
                            Question q = questions[index];
                            return _AnswerKeyQuestionCard(
                              paperDocId: paperDocId,
                              index: index,
                              question: q,
                              onUpdated: () => _fetchPapers(),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Exam Papers & Answer Keys"),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _showAddPaperDialog),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ["All", ..._examTypes].map((filter) {
                bool selected = (_selectedExamFilter == filter);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: selected,
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primaryColor,
                    onSelected: (val) {
                      setState(() => _selectedExamFilter = filter);
                      _fetchPapers();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _papers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 64, color: isDark ? Colors.white54 : Colors.black45),
                            const SizedBox(height: 12),
                            Text("No exam papers found for '$_selectedExamFilter'",
                                style: AppTheme.getStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showAddPaperDialog,
                              icon: const Icon(Icons.add),
                              label: const Text("Add New Exam Paper"),
                            )
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _papers.length,
                        itemBuilder: (ctx, index) {
                          var paper = _papers[index];
                          List<dynamic> qList = paper['questions'] ?? [];
                          int processed = qList.length;
                          int total = paper['totalQuestions'] is int ? paper['totalQuestions'] : (processed > 0 ? processed : 100);
                          bool isCompleted = paper['isCompleted'] == true || (total > 0 && processed >= total);
                          double progressRatio = total > 0 ? (processed / total).clamp(0.0, 1.0) : 1.0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isCompleted
                                            ? Colors.green.withValues(alpha: 0.1)
                                            : AppTheme.primaryColor.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isCompleted ? Icons.check_circle_outlined : Icons.assignment_outlined,
                                        color: isCompleted ? Colors.green : AppTheme.primaryColor,
                                      ),
                                    ),
                                    title: Text(
                                      paper['title'] ?? 'Exam Paper',
                                      style: AppTheme.getStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Chip(
                                            label: Text(paper['examType'] ?? 'Group 4',
                                                style: const TextStyle(fontSize: 10, color: Colors.white)),
                                            backgroundColor: AppTheme.primaryColor,
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              "Year: ${paper['year']}  •  $processed / $total Qs",
                                              style: AppTheme.getStyle(
                                                  fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.fact_check_outlined, color: Colors.green),
                                          tooltip: "Verify & Edit Answer Keys",
                                          onPressed: () => _showAnswerKeyEditor(paper),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          tooltip: "Delete Paper",
                                          onPressed: () => _deletePaper(paper['docId'], paper['title'] ?? ''),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Progress Bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progressRatio,
                                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isCompleted ? Colors.green : AppTheme.primaryColor,
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (!isCompleted && (paper['rawText'] != null || paper['pdfPath'] != null)) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _isChunkProcessing ? null : () => _processAllChunksAuto(paper),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.deepPurple,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                            ),
                                            icon: _isChunkProcessing
                                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                                : const Icon(Icons.bolt, size: 16),
                                            label: const Text(
                                              "⚡ Auto Extract All",
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _isChunkProcessing ? null : () => _processNextChunk(paper),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.orange.shade800,
                                              side: BorderSide(color: Colors.orange.shade800),
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                            ),
                                            icon: _isChunkProcessing
                                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                                                : const Icon(Icons.play_arrow_rounded, size: 16),
                                            label: Text(
                                              "Chunk #${processed + 1} Only",
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _AnswerKeyQuestionCard extends StatefulWidget {
  final String paperDocId;
  final int index;
  final Question question;
  final VoidCallback onUpdated;

  const _AnswerKeyQuestionCard({
    required this.paperDocId,
    required this.index,
    required this.question,
    required this.onUpdated,
  });

  @override
  State<_AnswerKeyQuestionCard> createState() => _AnswerKeyQuestionCardState();
}

class _AnswerKeyQuestionCardState extends State<_AnswerKeyQuestionCard> {
  late int _selectedCorrectIndex;
  late TextEditingController _questionTaController;
  late List<TextEditingController> _optionControllers;
  late TextEditingController _explanationEnController;
  late TextEditingController _explanationTaController;
  bool _isEditingText = false;
  bool _isSaving = false;
  bool _isFixingSingle = false;

  @override
  void initState() {
    super.initState();
    _selectedCorrectIndex = widget.question.correctOptionIndex;
    _questionTaController = TextEditingController(
      text: widget.question.questionTa ?? widget.question.question,
    );

    final rawOpts = widget.question.optionsTa ?? widget.question.options;
    _optionControllers = List.generate(
      rawOpts.length,
      (i) => TextEditingController(
        text: rawOpts[i].replaceAll(RegExp(r'[\r\n]+'), ' ').trim(),
      ),
    );

    _explanationEnController = TextEditingController(text: widget.question.explanationEn ?? "");
    _explanationTaController = TextEditingController(text: widget.question.explanationTa ?? "");
  }

  @override
  void dispose() {
    _questionTaController.dispose();
    for (var c in _optionControllers) {
      c.dispose();
    }
    _explanationEnController.dispose();
    _explanationTaController.dispose();
    super.dispose();
  }

  Future<void> _fixSingleQuestionWithAi() async {
    setState(() => _isFixingSingle = true);
    try {
      List<Map<String, String>> currentOpts = [];
      for (int i = 0; i < _optionControllers.length; i++) {
        String ta = Question.cleanOptionText(_optionControllers[i].text.trim());
        currentOpts.add({'en': ta, 'ta': ta});
      }

      Map<String, dynamic> singleQ = {
        'question_ta': _questionTaController.text.trim(),
        'question_en': widget.question.questionEn ?? _questionTaController.text.trim(),
        'options': currentOpts,
        'correctOptionIndex': _selectedCorrectIndex,
        'explanation_ta': _explanationTaController.text.trim(),
        'explanation_en': _explanationEnController.text.trim(),
      };

      List<Map<String, dynamic>> result = await AiService.proofreadAndFixExamPaperSpelling([singleQ]);

      if (result.isNotEmpty) {
        Map<String, dynamic> fixed = result.first;
        _questionTaController.text = (fixed['question_ta'] ?? fixed['question'] ?? '').toString();

        if (fixed['options'] is List) {
          List opts = fixed['options'];
          for (int i = 0; i < opts.length && i < _optionControllers.length; i++) {
            if (opts[i] is Map) {
              _optionControllers[i].text = (opts[i]['ta'] ?? opts[i]['en'] ?? '').toString();
            } else if (opts[i] is String) {
              _optionControllers[i].text = opts[i].toString();
            }
          }
        }

        if (fixed['correctOptionIndex'] is int &&
            fixed['correctOptionIndex'] >= 0 &&
            fixed['correctOptionIndex'] < _optionControllers.length) {
          _selectedCorrectIndex = fixed['correctOptionIndex'];
        }

        if (fixed['explanation_ta'] != null && fixed['explanation_ta'].toString().isNotEmpty) {
          _explanationTaController.text = fixed['explanation_ta'].toString();
        }
        if (fixed['explanation_en'] != null && fixed['explanation_en'].toString().isNotEmpty) {
          _explanationEnController.text = fixed['explanation_en'].toString();
        }

        await _saveChanges();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✨ AI fixed Tamil spelling & updated Firestore!"),
            backgroundColor: Colors.green,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Fix Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isFixingSingle = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    final fs = FirestoreService();

    List<Map<String, String>> updatedOptions = [];
    final optsEn = widget.question.optionsEn;
    for (int i = 0; i < _optionControllers.length; i++) {
      String ta = Question.cleanOptionText(_optionControllers[i].text.trim());
      String en = (optsEn != null && i < optsEn.length) ? optsEn[i] : ta;
      updatedOptions.add({'en': en, 'ta': ta});
    }

    bool ok = await fs.updateQuestionAnswerKey(
      paperDocId: widget.paperDocId,
      questionIndex: widget.index,
      newCorrectOptionIndex: _selectedCorrectIndex,
      newQuestionTa: _questionTaController.text.trim(),
      newQuestionEn: widget.question.questionEn,
      newOptions: updatedOptions,
      newExplanationEn: _explanationEnController.text.trim(),
      newExplanationTa: _explanationTaController.text.trim(),
    );

    setState(() => _isSaving = false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Q${widget.index + 1} Question details updated successfully!"),
        duration: const Duration(seconds: 1),
      ));
      widget.onUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Question ${widget.index + 1}",
                    style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                TextButton.icon(
                  onPressed: () => setState(() => _isEditingText = !_isEditingText),
                  icon: Icon(_isEditingText ? Icons.visibility : Icons.edit_note, size: 18),
                  label: Text(_isEditingText ? "Preview" : "✏️ Edit Text / திருத்து"),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_isEditingText) ...[
              TextField(
                controller: _questionTaController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "வினா உரை (Question Tamil)",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Text("Edit Options Text / விடைகளை திருத்து:",
                  style: AppTheme.getStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...List.generate(_optionControllers.length, (optIdx) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TextField(
                    controller: _optionControllers[optIdx],
                    decoration: InputDecoration(
                      labelText: "Option ${String.fromCharCode(65 + optIdx)}",
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                );
              }),
            ] else ...[
              Text(
                _questionTaController.text,
                style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            Text("Select Correct Option / சரியான விடையைத் தேர்வு செய்:",
                style: AppTheme.getStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.black54)),
            const SizedBox(height: 6),
            Column(
              children: List.generate(_optionControllers.length, (optIdx) {
                bool isSelected = (_selectedCorrectIndex == optIdx);
                String optText = _optionControllers[optIdx].text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
                return RadioListTile<int>(
                  value: optIdx,
                  groupValue: _selectedCorrectIndex,
                  activeColor: Colors.green,
                  title: Text(
                    "${String.fromCharCode(65 + optIdx)}) $optText",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.green : null,
                    ),
                  ),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCorrectIndex = val);
                  },
                );
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _explanationTaController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "விளக்கம் (Tamil Explanation)",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _explanationEnController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Explanation (English)",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: (_isSaving || _isFixingSingle) ? null : _fixSingleQuestionWithAi,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    side: BorderSide(color: Colors.indigo.shade300),
                  ),
                  icon: _isFixingSingle
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigo))
                      : const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text("✨ Auto-Fix with AI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                ElevatedButton.icon(
                  onPressed: (_isSaving || _isFixingSingle) ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text("Save Changes"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
