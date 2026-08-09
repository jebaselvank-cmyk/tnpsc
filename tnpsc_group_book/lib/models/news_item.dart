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
      titleEn: data['titleEn'] ?? '',
      titleTa: data['titleTa'] ?? '',
      contentEn: data['contentEn'] ?? '',
      contentTa: data['contentTa'] ?? '',
      category: data['category'] ?? 'General',
      date: data['date'] ?? '',
      timestamp: data['timestamp'] != null 
          ? (data['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
    );
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
