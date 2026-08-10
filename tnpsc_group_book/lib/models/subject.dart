import 'package:flutter/material.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';

class Subject {
  final String id;
  final String titleTa;
  final String titleEn;
  final String subtitleTa;
  final String subtitleEn;
  final IconData icon;
  final Color color;
  final List<String> topicsTa;
  final List<String> topicsEn;
  final Map<String, List<String>> subTopicsMapTa;
  final Map<String, List<String>> subTopicsMapEn;

  Subject({
    required this.id,
    required this.titleTa,
    required this.titleEn,
    required this.subtitleTa,
    required this.subtitleEn,
    required this.icon,
    required this.color,
    this.topicsTa = const [],
    this.topicsEn = const [],
    this.subTopicsMapTa = const {},
    this.subTopicsMapEn = const {},
  });

  String get title => AppLanguage.languageNotifier.value == 'ta' ? titleTa : titleEn;

  String get subtitle => AppLanguage.languageNotifier.value == 'ta' ? subtitleTa : subtitleEn;

  List<String> get topics => AppLanguage.languageNotifier.value == 'ta' ? topicsTa : topicsEn;

  String getTopicKey(int index) {
    if (index >= 0 && index < topicsTa.length) {
      return topicsTa[index];
    }
    return "";
  }

  String getSubTopicKey(int topicIndex, int subTopicIndex) {
    if (topicIndex >= 0 && topicIndex < topicsTa.length) {
      String tamilTopic = topicsTa[topicIndex];
      List<String> tamilSubTopics = subTopicsMapTa[tamilTopic] ?? [];
      if (subTopicIndex >= 0 && subTopicIndex < tamilSubTopics.length) {
        return tamilSubTopics[subTopicIndex];
      }
    }
    return "";
  }

  List<String> getSubTopics(int index) {
    if (AppLanguage.languageNotifier.value == 'ta') {
      if (index >= 0 && index < topicsTa.length) {
        return subTopicsMapTa[topicsTa[index]] ?? [];
      }
    } else {
      if (index >= 0 && index < topicsEn.length) {
        return subTopicsMapEn[topicsEn[index]] ?? [];
      }
    }
    return [];
  }
}

final List<Subject> tnpscSubjects = [
  Subject(
    id: '1',
    titleTa: 'பொதுத் தமிழ்',
    titleEn: 'General Tamil',
    subtitleTa: 'இலக்கணம், இலக்கியம் & தமிழ் அறிஞர்கள்',
    subtitleEn: 'Grammar, Literature & Tamil Scholars',
    icon: Icons.menu_book_rounded,
    color: Colors.orange,
    topicsTa: ['இலக்கணம்', 'இலக்கியம்', 'சொல்லகராதி & பயன்பாடு', 'தமிழ் அறிஞர்களும் வரலாறும்', 'முந்தைய ஆண்டு வினாக்கள்'],
    topicsEn: ['Grammar', 'Literature', 'Vocabulary & Usage', 'Scholars & History', 'Previous Year Questions'],
    subTopicsMapTa: {
      'இலக்கணம்': [
        'பெயர்ச்சொல்',
        'வினைச்சொல்',
        'புணர்ச்சி',
        'வேற்றுமை',
        'வாக்கிய அமைப்பு',
        'பிழை திருத்தம்',
        'இலக்கணக் குறிப்பு',
      ],
      'இலக்கியம்': [
        'திருக்குறள்',
        'சங்க இலக்கியம்',
        'காப்பியங்கள்',
        'பக்தி இலக்கியம்',
        'சிற்றிலக்கியம்',
        'அறநூல்கள்',
      ],
      'சொல்லகராதி & பயன்பாடு': [
        'சொல்லகராதி',
        'எதிர்ச்சொல்',
        'இணைச்சொல்',
        'ஒருபொருள் பலசொல்',
        'பலபொருள் ஒரு சொல்',
        'பழமொழிகள்',
        'மரபுத்தொடர்கள்',
        'வாசிப்புப் புரிதல்',
      ],
      'தமிழ் அறிஞர்களும் வரலாறும்': [
        'ஆசிரியர் மற்றும் நூல்கள்',
        'தமிழ் அறிஞர்கள்',
        'தமிழ் மொழி வரலாறு',
        'சங்க காலம்',
        'செம்மொழித் தமிழ்',
        'தமிழ் வளர்ச்சி',
      ],
      'முந்தைய ஆண்டு வினாக்கள்': ['2023 Questions', '2022 Questions', 'VAO Previous Questions'],
    },
    subTopicsMapEn: {
      'Grammar': [
        'Noun',
        'Verb',
        'Punarchi',
        'Case (Vethrumai)',
        'Sentence Structure',
        'Error Correction',
        'Grammar Notes',
      ],
      'Literature': [
        'Thirukkural',
        'Sangam Literature',
        'Epics',
        'Devotional Literature',
        'Minor Literature',
        'Didactic Books',
      ],
      'Vocabulary & Usage': [
        'Vocabulary',
        'Antonyms',
        'Synonyms',
        'One meaning many words',
        'One word many meanings',
        'Proverbs',
        'Idioms',
        'Reading Comprehension',
      ],
      'Scholars & History': [
        'Authors and Books',
        'Tamil Scholars',
        'Tamil History',
        'Sangam Era',
        'Classical Tamil',
        'Tamil Development',
      ],
      'Previous Year Questions': ['2023 Questions', '2022 Questions', 'VAO Previous Questions'],
    },
  ),
  Subject(
    id: '2',
    titleTa: 'பொது அறிவியல்',
    titleEn: 'General Science',
    subtitleTa: 'அறிவியல், தொழில்நுட்பம் & சூழலியல்',
    subtitleEn: 'Science, Tech & Ecology',
    icon: Icons.science_rounded,
    color: Colors.cyan,
    topicsTa: ['இயற்பியல் & வேதியியல்', 'உயிரியல் & சுற்றுச்சூழல்', 'அறிவியல் மற்றும் தொழில்நுட்பம்'],
    topicsEn: ['Physics & Chemistry', 'Biology & Environment', 'Science and Technology'],
    subTopicsMapTa: {
      'இயற்பியல் & வேதியியல்': [
        'Nature of Universe',
        'Mechanics & Energy',
        'Magnetism & Electricity',
        'Elements and Compounds',
        'Acids, Bases & Salts',
      ],
      'உயிரியல் & சுற்றுச்சூழல்': [
        'Classification of Living Organisms',
        'Nutrition & Human Diseases',
        'Genetics & Evolution',
        'Environment and Ecology',
      ],
      'அறிவியல் மற்றும் தொழில்நுட்பம்': [
        'Space Research (ISRO)',
        'Defense & Nuclear Power',
        'Information Technology',
        'Scientific Personalities',
      ],
    },
    subTopicsMapEn: {
      'Physics & Chemistry': [
        'Nature of Universe',
        'Mechanics & Energy',
        'Magnetism & Electricity',
        'Elements and Compounds',
        'Acids, Bases & Salts',
      ],
      'Biology & Environment': [
        'Classification of Living Organisms',
        'Nutrition & Human Diseases',
        'Genetics & Evolution',
        'Environment and Ecology',
      ],
      'Science and Technology': [
        'Space Research (ISRO)',
        'Defense & Nuclear Power',
        'Information Technology',
        'Scientific Personalities',
      ],
    },
  ),
  Subject(
    id: '3',
    titleTa: 'வரலாறு மற்றும் பண்பாடு',
    titleEn: 'History and Culture',
    subtitleTa: 'இந்திய வரலாறு & பண்பாடு',
    subtitleEn: 'History & Culture of India',
    icon: Icons.account_balance_rounded,
    color: Colors.blue,
    topicsTa: ['இந்திய வரலாறு', 'இந்திய தேசிய இயக்கம்'],
    topicsEn: ['Indian History', 'Indian National Movement'],
    subTopicsMapTa: {
      'இந்திய வரலாறு': ['சிந்து சமவெளி நாகரிகம்', 'குப்தர்கள்', 'டெல்லி சுல்தான்கள்', 'முகலாயர்கள்', 'மராத்தியர்கள்', 'தென்னிந்திய வரலாறு'],
      'இந்திய தேசிய இயக்கம்': [
        'தேசிய மறுமலர்ச்சி',
        'இந்திய தேசிய காங்கிரஸ் (INC)',
        'தலைவர்கள் எழுச்சி (காந்தி, நேரு, படேல், போஸ்)',
        'தமிழ்நாட்டின் பங்கு (வ.உ.சி, பெரியார், பாரதி)',
      ],
    },
    subTopicsMapEn: {
      'Indian History': ['Indus Valley Civilization', 'Guptas', 'Delhi Sultans', 'Mughals', 'Marathas', 'South Indian History'],
      'Indian National Movement': [
        'National Renaissance',
        'Indian National Congress (INC)',
        'Emergence of Leaders (Gandhi, Nehru, Patel, Bose)',
        'Role of Tamil Nadu (VOC, Periyar, Bharathi)',
      ],
    },
  ),
  Subject(
    id: '4',
    titleTa: 'புவியியல்',
    titleEn: 'Geography',
    subtitleTa: 'இந்தியப் புவியியல்',
    subtitleEn: 'Geography of India',
    icon: Icons.public_rounded,
    color: Colors.green,
    topicsTa: ['புவியியல் கூறுகள்'],
    topicsEn: ['Geographical Features'],
    subTopicsMapTa: {
      'புவியியல் கூறுகள்': [
        'இயற்கை அமைவு',
        'மழைப்பொழிவு & காலநிலை',
        'ஆறுகள் & நீர்நிலைகள்',
        'மண், காடுகள் & வனவிலங்குகள்',
        'போக்குவரத்து & தகவல் தொடர்பு',
        'பேரழிவு மேலாண்மை',
      ],
    },
    subTopicsMapEn: {
      'Geographical Features': [
        'Physical Features',
        'Monsoon & Climate',
        'Rivers & Water Resources',
        'Soil, Forests & Wildlife',
        'Transport & Communication',
        'Disaster Management',
      ],
    },
  ),
  Subject(
    id: '5',
    titleTa: 'அரசியலமைப்பு',
    titleEn: 'Indian Polity',
    subtitleTa: 'இந்திய அரசியல் அமைப்பு',
    subtitleEn: 'Constitution of India',
    icon: Icons.gavel_rounded,
    color: Colors.indigo,
    topicsTa: ['அரசியலமைப்பு', 'நிர்வாகம்'],
    topicsEn: ['Constitution', 'Governance'],
    subTopicsMapTa: {
      'அரசியலமைப்பு': ['முகப்புரை', 'அடிப்படை உரிமைகள் & கடமைகள்', 'மத்திய அரசு', 'மாநில அரசு', 'தேர்தல் முறை'],
      'நிர்வாகம்': ['பஞ்சாயத்து ராஜ்', 'ஊழல் எதிர்ப்பு நடவடிக்கைகள்', 'லோக் அதாலத், லோக்பால் & ஓம்புட்ஸ்மேன்', 'தகவல் அறியும் உரிமை (RTI)'],
    },
    subTopicsMapEn: {
      'Constitution': ['Preamble', 'Fundamental Rights & Duties', 'Union Government', 'State Government', 'Election System'],
      'Governance': ['Panchayati Raj', 'Anti-Corruption Measures', 'Lok Adalat, Lokpal & Ombudsman', 'Right to Information (RTI)'],
    },
  ),
  Subject(
    id: '6',
    titleTa: 'இந்தியப் பொருளாதாரம்',
    titleEn: 'Indian Economy',
    subtitleTa: 'பொருளாதாரக் கொள்கைகள்',
    subtitleEn: 'Economic Policies',
    icon: Icons.monetization_on_rounded,
    color: Colors.brown,
    topicsTa: ['பொருளாதாரம்'],
    topicsEn: ['Economy'],
    subTopicsMapTa: {
      'பொருளாதாரம்': [
        'இந்திய பொருளாதாரத்தின் இயல்புகள்',
        'ஐந்தாண்டு திட்டங்கள் & நிதி ஆயோக்',
        'நிதி ஆணையம் & GST',
        'வங்கி முறை & RBI',
        'கிராமப்புற மேம்பாடு & சமூகத் திட்டங்கள்',
      ],
    },
    subTopicsMapEn: {
      'Economy': [
        'Nature of Indian Economy',
        'Five Year Plans & NITI Aayog',
        'Finance Commission & GST',
        'Banking System & RBI',
        'Rural Development & Social Programmes',
      ],
    },
  ),
  Subject(
    id: '7',
    titleTa: 'தமிழ்நாடு (Unit 8 & 9)',
    titleEn: 'Tamil Nadu History & Development',
    subtitleTa: 'வரலாறு, பண்பாடு & நிர்வாகம்',
    subtitleEn: 'History, Culture & Administration',
    icon: Icons.location_city_rounded,
    color: Colors.purple,
    topicsTa: ['தமிழ்நாடு வரலாறு & பண்பாடு', 'தமிழக நிர்வாகம்', 'சமூகப் பிரச்சினைகள்'],
    topicsEn: ['TN History & Culture', 'TN Administration', 'Social Issues'],
    subTopicsMapTa: {
      'தமிழ்நாடு வரலாறு & பண்பாடு': [
        'தமிழ் சமுதாய வரலாறு & தொல்லியல் கண்டுபிடிப்புகள்',
        'தமிழகப் பண்பாடு & மரபு (Heritage)',
        'நீதிக்கட்சி & சுயமரியாதை இயக்கம்',
        'திராவிட இயக்கம் & சமூக சீர்திருத்தங்கள்',
      ],
      'தமிழக நிர்வாகம்': [
        'மனிதவள மேம்பாட்டுக் குறியீடு (HDI)',
        'சமூக நீதி & சமூக ஒற்றுமை',
        'தமிழக கல்வி, சுகாதாரம் & பொருளாதார வளர்ச்சி',
        'தமிழக மின் ஆளுமை (e-Governance)',
        'வளர்ச்சி நிர்வாகம் (Development Admin)',
      ],
      'சமூகப் பிரச்சினைகள்': [
        'மக்கள்தொகை வெடிப்பு',
        'வறுமை & வேலையின்மை',
        'ஊழல் & லஞ்ச ஒழிப்பு',
        'பெண்கள் மேம்பாடு',
      ],
    },
    subTopicsMapEn: {
      'TN History & Culture': [
        'History of Tamil Society & Archaeological Discoveries',
        'Tamil Culture & Heritage',
        'Justice Party & Self Respect Movement',
        'Dravidian Movement & Social Reforms',
      ],
      'TN Administration': [
        'Human Development Indicators (HDI)',
        'Social Justice & Social Harmony',
        'Education, Health & Economy in TN',
        'e-Governance in Tamil Nadu',
        'Development Administration',
      ],
      'Social Issues': [
        'Population Explosion',
        'Poverty & Unemployment',
        'Corruption & Anti-corruption',
        'Women Empowerment',
      ],
    },
  ),
  Subject(
    id: '8',
    titleTa: 'திறனறிவும் மனக்கணக்கு நுண்ணறிவும்',
    titleEn: 'Aptitude & Mental Ability',
    subtitleTa: 'கணிதம், தர்க்க அறிவு & உளவியல்',
    subtitleEn: 'Maths, Reasoning & Psychology',
    icon: Icons.calculate_rounded,
    color: Colors.pink,
    topicsTa: [
      'அடிப்படை கணிதம் (Arithmetic)',
      'வணிகக் கணிதம் (Business Math)',
      'நேரம் & அளவீடு (Time & Measurement)',
      'தர்க்க அறிவு (Logical Reasoning)',
      'புள்ளியியல் & இதர (Statistics)',
    ],
    topicsEn: [
      'Arithmetic',
      'Business Math',
      'Time & Measurement',
      'Logical Reasoning',
      'Statistics & Others',
    ],
    subTopicsMapTa: {
      'அடிப்படை கணிதம் (Arithmetic)': [
        'Simplification',
        'Percentage',
        'Ratio and Proportion',
        'Average',
        'Number System',
        'HCF and LCM',
        'Fractions and Decimals',
        'Square Root and Cube Root',
      ],
      'வணிகக் கணிதம் (Business Math)': [
        'Profit and Loss',
        'Simple Interest',
        'Compound Interest',
        'Problems on Ages',
      ],
      'நேரம் & அளவீடு (Time & Measurement)': [
        'Time and Work',
        'Pipes and Cisterns',
        'Time, Speed and Distance',
        'Mensuration',
        'Geometry',
      ],
      'தர்க்க அறிவு (Logical Reasoning)': [
        'Logical Reasoning',
        'Number Series',
        'Odd One Out',
        'Analogy',
        'Coding and Decoding',
        'Direction Sense',
        'Blood Relations',
        'Ranking and Order',
      ],
      'புள்ளியியல் & இதர (Statistics)': [
        'Data Interpretation',
        'Probability',
        'Permutations and Combinations',
        'Calendar',
        'Clock',
        'Mixed Aptitude Quiz',
      ],
    },
    subTopicsMapEn: {
      'Arithmetic': [
        'Simplification',
        'Percentage',
        'Ratio and Proportion',
        'Average',
        'Number System',
        'HCF and LCM',
        'Fractions and Decimals',
        'Square Root and Cube Root',
      ],
      'Business Math': [
        'Profit and Loss',
        'Simple Interest',
        'Compound Interest',
        'Problems on Ages',
      ],
      'Time & Measurement': [
        'Time and Work',
        'Pipes and Cisterns',
        'Time, Speed and Distance',
        'Mensuration',
        'Geometry',
      ],
      'Logical Reasoning': [
        'Logical Reasoning',
        'Number Series',
        'Odd One Out',
        'Analogy',
        'Coding and Decoding',
        'Direction Sense',
        'Blood Relations',
        'Ranking and Order',
      ],
      'Statistics & Others': [
        'Data Interpretation',
        'Probability',
        'Permutations and Combinations',
        'Calendar',
        'Clock',
        'Mixed Aptitude Quiz',
      ],
    },
  ),
  Subject(
    id: '9',
    titleTa: 'கிராம நிர்வாகம் (VAO)',
    titleEn: 'Village Administration',
    subtitleTa: 'கிராம நிர்வாக நடைமுறைகள்',
    subtitleEn: 'Village Administrative Procedures',
    icon: Icons.foundation_rounded,
    color: Colors.deepOrange,
    topicsTa: ['நில அளவை & பதிவேடுகள்', 'அரசு நிறுவனங்கள் & பணிகள்'],
    topicsEn: ['Land Records & Survey', 'Govt Institutions & Duties'],
    subTopicsMapTa: {
      'நில அளவை & பதிவேடுகள்': ['கிராம கணக்குகள் (அடங்கல், பட்டா)', 'நில அளவை முறைகள்', 'வட்டாட்சியர் & கிராம நிர்வாக அலுவலர் பணிகள்'],
      'அரசு நிறுவனங்கள் & பணிகள்': ['வருவாய்த்துறை அமைப்புகள்', 'கிராம பஞ்சாயத்து பணிகள்', 'அரசு நலத்திட்டங்கள் & சான்றிதழ்கள்'],
    },
    subTopicsMapEn: {
      'Land Records & Survey': ['Village Accounts (Adangal, Patta)', 'Land Survey Methods', 'Duties of Tahsildar & VAO'],
      'Govt Institutions & Duties': ['Revenue Department Structure', 'Village Panchayat Functions', 'Govt Schemes & Certificates'],
    },
  ),
  Subject(
    id: '10',
    titleTa: 'நடப்பு நிகழ்வுகள்',
    titleEn: 'Current Affairs',
    subtitleTa: 'தினசரி செய்திகள் & திட்டங்கள்',
    subtitleEn: 'Daily Updates & Schemes',
    icon: Icons.newspaper_rounded,
    color: Colors.teal,
    topicsTa: ['பொதுச் செய்திகள்', 'அரசு திட்டங்கள்', 'விளையாட்டு & விருதுகள்'],
    topicsEn: ['General News', 'Govt Schemes', 'Sports & Awards'],
    subTopicsMapTa: {
      'பொதுச் செய்திகள்': ['தமிழ்நாடு நிகழ்வுகள்', 'தேசிய நிகழ்வுகள்', 'சர்வதேச நிகழ்வுகள்', 'முக்கிய நபர்கள் (Personalities)'],
      'அரசு திட்டங்கள்': ['மத்திய அரசு திட்டங்கள்', 'தமிழக அரசு திட்டங்கள்', 'சமூக நலத்திட்டங்கள்'],
      'விளையாட்டு & விருதுகள்': ['விளையாட்டு செய்திகள்', 'விருதுகள் மற்றும் கௌரவங்கள்', 'புத்தகங்கள் மற்றும் ஆசிரியர்கள்'],
    },
    subTopicsMapEn: {
      'General News': ['Tamil Nadu Events', 'National Events', 'International Events', 'Important Personalities'],
      'Govt Schemes': ['Central Government Schemes', 'State Government Schemes', 'Social Welfare Schemes'],
      'Sports & Awards': ['Sports News', 'Awards and Honours', 'Books and Authors'],
    },
  ),
];
