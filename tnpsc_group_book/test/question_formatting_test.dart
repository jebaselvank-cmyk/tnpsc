import 'package:flutter_test/flutter_test.dart';
import 'package:tnpsc_group_book/models/question.dart';

void main() {
  test('Question.formatQuestionText formats Match the following with newlines', () {
    String sample = "கீழ்க்காணும் சிற்றிலக்கிய வகைகளை அவற்றின் விளக்கங்களுடன் பொருத்துக: (a) பரணி — 1. தூது செல்லும் இலக்கியம் (b) தூது — 2. யானைப்படையை வென்றவர் மீது பாடுவது (c) உலா — 3. 96 வகைச் சிற்றிலக்கியங்களில் ஒன்று (d) குறவஞ்சி — 4. வீதியில் உலா வரும் தலைவனைக் கண்டு பாடுவது";
    
    String formatted = Question.formatQuestionText(sample);
    print('--- FORMATTED OUTPUT ---');
    print(formatted);
    print('------------------------');
    
    expect(formatted.contains('\n(a)'), isTrue);
    expect(formatted.contains('\n(b)'), isTrue);
    expect(formatted.contains('\n(c)'), isTrue);
    expect(formatted.contains('\n(d)'), isTrue);
  });

  test('Question.formatQuestionText formats Statement and Reason with newlines', () {
    String sample = "கூற்று (A): சிலப்பதிகாரமும் மணிமேகலையும் இரட்டைக் காப்பியங்கள். காரணம் (R): இரண்டும் ஒரே காலக்கட்டத்தில் தோன்றியவை.";
    String formatted = Question.formatQuestionText(sample);
    expect(formatted.contains('காரணம் (R)'), isTrue);
  });

  test('Question.cleanOptionText preserves (a) in matching options', () {
    String opt = "(a)-2, (b)-3, (c)-4, (d)-1";
    String cleaned = Question.cleanOptionText(opt);
    expect(cleaned, equals("(a)-2, (b)-3, (c)-4, (d)-1"));
  });

  test('Question.cleanOptionText auto-repairs stripped matching options', () {
    String opt = "-2, (b)-1, (c)-4, (d)-3";
    String cleaned = Question.cleanOptionText(opt);
    expect(cleaned, equals("(a)-2, (b)-1, (c)-4, (d)-3"));
  });

  test('Question.cleanOptionText preserves sequence options with (1)', () {
    String opt = "(1), (3), (4), (2)";
    String cleaned = Question.cleanOptionText(opt);
    expect(cleaned, equals("(1), (3), (4), (2)"));
  });

  test('Question.cleanOptionText preserves Assertion and Reason options', () {
    String opt = "கூற்று (A) மற்றும் காரணம் (R) இரண்டும் சரி";
    String cleaned = Question.cleanOptionText(opt);
    expect(cleaned, equals("கூற்று (A) மற்றும் காரணம் (R) இரண்டும் சரி"));
  });

  test('Question.cleanOptionText preserves chronological order options without stripping leading digits', () {
    String opt1 = "3 4 1 2";
    String opt2 = "3, 4, 1, 2";
    expect(Question.cleanOptionText(opt1), equals("3 4 1 2"));
    expect(Question.cleanOptionText(opt2), equals("3, 4, 1, 2"));
  });

  test('Question.formatQuestionText formats chronological list items with newlines', () {
    String sample = "காலவரிசைப்படுத்துக: 1. பிளாசி போர் 2. பக்சார் போர் 3. வெல்லசிலி பிரபு வருகை 4. ஏழாம் மைசூர் போர்";
    String formatted = Question.formatQuestionText(sample);
    expect(formatted.contains('\n1.'), isTrue);
    expect(formatted.contains('\n2.'), isTrue);
    expect(formatted.contains('\n3.'), isTrue);
    expect(formatted.contains('\n4.'), isTrue);
  });

  test('Question.cleanOptionText cleans leading commas in sequence options', () {
    String opt = ", (1), (2), (4)";
    String cleaned = Question.cleanOptionText(opt);
    expect(cleaned, equals("(1), (2), (4)"));
  });

  test('Question.formatQuestionText keeps match pairs on the same line after dash', () {
    String sample = "கீழ்க்காண்பன தேசிய இயக்க நிகழ்வுகளை அவற்றுடன் தொடர்புடைய சரியான ஆண்டுகளுடன் பொருத்துக: (a) முசுலீம் லீக் உருவாக்கம் — 1. 1916 (b) லக்னோ ஒப்பந்தம் — 2. 1906";
    String formatted = Question.formatQuestionText(sample);
    expect(formatted.contains('— 1. 1916'), isTrue);
    expect(formatted.contains('— 2. 1906'), isTrue);
  });
}
