import 'package:cloud_firestore/cloud_firestore.dart';

enum LogType { product, transaction, supplier, system }

class ActivityLog {
  final String? id;
  final String action;
  final String details;
  final DateTime timestamp;
  final LogType type;
  final Map<String, dynamic>? extraData;

  ActivityLog({
    this.id,
    required this.action,
    required this.details,
    required this.timestamp,
    required this.type,
    this.extraData,
  });

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.name,
      if (extraData != null) 'extraData': extraData,
    };
  }

  factory ActivityLog.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ActivityLog(
      id: doc.id,
      action: data['action'] ?? '',
      details: data['details'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: LogType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => LogType.system,
      ),
      extraData: data['extraData'],
    );
  }
}
