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
    expect(formatted.contains('\nகாரணம் (R)'), isTrue);
  });
}
