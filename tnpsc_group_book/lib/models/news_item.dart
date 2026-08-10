import 'package:cloud_firestore/cloud_firestore.dart';

class NewsItem {
  final String id;
  final String titleEn;
  final String titleTa;
  final String contentEn;
  final String contentTa;
  final String category;
  final String date;
  final DateTime timestamp;

  NewsItem({
    required this.id,
    required this.titleEn,
    required this.titleTa,
    required this.contentEn,
    required this.contentTa,
    required this.category,
    required this.date,
    required this.timestamp,
  });

  factory NewsItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NewsItem(
      id: doc.id,
      titleEn: _parseContent(data['titleEn']),
      titleTa: _parseContent(data['titleTa']),
      contentEn: _parseContent(data['contentEn']),
      contentTa: _parseContent(data['contentTa']),
      category: _parseContent(data['category'] ?? 'General'),
      date: _parseContent(data['date']),
      timestamp: data['timestamp'] != null 
          ? (data['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  static String _parseContent(dynamic content) {
    if (content == null) return '';
    if (content is String) return content;
    if (content is List) {
      return content.map((e) => e.toString()).join('\n');
    }
    return content.toString();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'titleEn': titleEn,
      'titleTa': titleTa,
      'contentEn': contentEn,
      'contentTa': contentTa,
      'category': category,
      'date': date,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
