import 'package:cloud_firestore/cloud_firestore.dart';

class ManiquiModel {
  final String id;
  final String name;
  final String uuid;
  final String status;
  final DateTime? lastConnection;
  final String? apiKey;
  final String? assignedTo;
  final String? currentSessionId;

  const ManiquiModel({
    required this.id,
    required this.name,
    required this.uuid,
    required this.status,
    this.lastConnection,
    this.apiKey,
    this.assignedTo,
    this.currentSessionId,
  });

  factory ManiquiModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ManiquiModel(
      id:               doc.id,
      name:             d['name']     ?? 'Maniquí',
      uuid:             d['uuid']     ?? '',
      status:           d['status']   ?? 'desconectado',
      apiKey:           d['apiKey'],
      assignedTo:       d['assignedTo'],
      currentSessionId: d['currentSessionId'],
      lastConnection:   (d['lastConnection'] as Timestamp?)?.toDate(),
    );
  }
}
