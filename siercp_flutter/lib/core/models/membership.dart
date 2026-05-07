import 'package:cloud_firestore/cloud_firestore.dart';

enum MembershipStatus { pending, approved, rejected, suspended }

class MembershipModel {
  final String id;
  final String userId;
  final String institutionId;
  final String role; // 'ADMIN', 'INSTRUCTOR', 'ESTUDIANTE'
  final MembershipStatus status;
  final bool isActive;
  final String? approvedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MembershipModel({
    required this.id,
    required this.userId,
    required this.institutionId,
    required this.role,
    this.status = MembershipStatus.pending,
    this.isActive = true,
    this.approvedBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory MembershipModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MembershipModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      institutionId: d['institutionId'] ?? '',
      role: d['role'] ?? 'ESTUDIANTE',
      status: _parseStatus(d['status']),
      isActive: d['isActive'] ?? true,
      approvedBy: d['approvedBy'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'institutionId': institutionId,
    'role': role,
    'status': status.toString().split('.').last,
    'isActive': isActive,
    'approvedBy': approvedBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static MembershipStatus _parseStatus(String? s) {
    switch (s) {
      case 'approved': return MembershipStatus.approved;
      case 'rejected': return MembershipStatus.rejected;
      case 'suspended': return MembershipStatus.suspended;
      default: return MembershipStatus.pending;
    }
  }

  MembershipModel copyWith({
    MembershipStatus? status,
    bool? isActive,
    String? approvedBy,
  }) => MembershipModel(
    id: id,
    userId: userId,
    institutionId: institutionId,
    role: role,
    status: status ?? this.status,
    isActive: isActive ?? this.isActive,
    approvedBy: approvedBy ?? this.approvedBy,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
