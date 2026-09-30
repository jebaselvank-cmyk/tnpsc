import 'package:flutter/material.dart';
import '../models/question.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../utils/app_log.dart';
import 'quiz_screen.dart';

class ExamPapersScreen extends StatefulWidget {
  const ExamPapersScreen({super.key});

  @override
  State<ExamPapersScreen> createState() => _ExamPapersScreenState();
}

class _ExamPapersScreenState extends State<ExamPapersScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  String _selectedExam = "All";
  List<Map<String, dynamic>> _papers = [];

  final List<String> _examCategories = ["All", "Group 4", "Group 2/2A", "Group 1", "VAO"];

  @override
  void initState() {
    super.initState();
    _fetchPapers();
  }

  Future<void> _fetchPapers() async {
    setState(() => _isLoading = true);
    try {
      final list = await _firestoreService.getExamPapers(examType: _selectedExam);
      setState(() {
        _papers = list;
        _isLoading = false;
      });
    } catch (e) {
      AppLog.e("Error fetching exam papers for users: $e");
      setState(() => _isLoading = false);
    }
  }

  void _startExamPaperQuiz(Map<String, dynamic> paper) {
    List<dynamic> rawQuestions = paper['questions'] ?? [];
    if (rawQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("No questions available in this paper yet."),
      ));
      return;
    }

    List<Question> questions = rawQuestions.map((q) {
      var map = Map<String, dynamic>.from(q as Map);
      map['quiz_type'] = 'pyq_paper';
      map['subject'] = paper['examType'] ?? 'General Studies';
      return Question.fromMap(map);
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          subjectTitle: paper['title'] ?? 'TNPSC Exam Paper',
          customQuestions: questions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isTa = AppLanguage.languageNotifier.value == 'ta';

    // Group papers by year
    Map<int, List<Map<String, dynamic>>> yearGrouped = {};
    for (var p in _papers) {
      int y = p['year'] is int ? p['year'] : 2025;
      yearGrouped.putIfAbsent(y, () => []).add(p);
    }
    var sortedYears = yearGrouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text(isTa ? "முந்தைய ஆண்டு வினாத்தாள்கள்" : "Previous Year Exam Papers"),
      ),
      body: Column(
        children: [
          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: _examCategories.map((cat) {
                bool selected = (_selectedExam == cat);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    selectedColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : (isDark ? Colors.white70 : AppTheme.textMainColor),
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedExam = cat);
                        _fetchPapers();
                      }
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
                            Icon(Icons.assignment_rounded, size: 64, color: isDark ? Colors.white54 : Colors.black45),
                            const SizedBox(height: 12),
                            Text(
                              isTa
                                  ? "'$_selectedExam' வினாத்தாள்கள் எதுவும் கிடைக்கவில்லை"
                                  : "No exam papers found for '$_selectedExam'",
                              style: AppTheme.getStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sortedYears.length,
                        itemBuilder: (ctx, yearIdx) {
                          int year = sortedYears[yearIdx];
                          List<Map<String, dynamic>> papersForYear = yearGrouped[year]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        "$year",
                                        style: AppTheme.getStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
                                  ],
                                ),
                              ),
                              ...papersForYear.map((paper) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                paper['examType'] ?? 'Group 4',
                                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "${paper['totalQuestions'] ?? 0} ${isTa ? 'வினாக்கள்' : 'Questions'}",
                                              style: AppTheme.getStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          paper['title'] ?? 'Exam Paper',
                                          style: AppTheme.getStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 44,
                                          child: ElevatedButton.icon(
                                            onPressed: () => _startExamPaperQuiz(paper),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primaryColor,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            icon: const Icon(Icons.play_arrow_rounded),
                                            label: Text(
                                              isTa ? "தேர்வு எழுது (Start Test)" : "Start Exam Test",
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
