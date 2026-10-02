import 'package:flutter_test/flutter_test.dart';
import 'package:tnpsc_group_book/models/question.dart';

void main() {
  test('Question model serialization and formatting test', () {
    final q = Question(
      question: 'கீழ்க்காண்பனவற்றை பொருத்துக:\n(a) A — 1. X\n(b) B — 2. Y\n(c) C — 3. Z\n(d) D — 4. W',
      options: ['(a)-1, (b)-2, (c)-3, (d)-4', '(a)-2, (b)-1, (c)-4, (d)-3', '(a)-3, (b)-4, (c)-1, (d)-2', '(a)-4, (b)-3, (c)-2, (d)-1'],
      correctOptionIndex: 0,
      explanation: 'விளக்கம்',
    );

    expect(q.correctOptionIndex, 0);
    expect(q.options.length, 4);

    final map = q.toMap();
    final reconstructed = Question.fromMap(map);
    expect(reconstructed.correctOptionIndex, 0);
    expect(reconstructed.question, contains('(a) A — 1. X'));
  });
}
