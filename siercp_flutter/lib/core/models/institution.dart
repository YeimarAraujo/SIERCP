import 'package:cloud_firestore/cloud_firestore.dart';

enum InstitutionStatus { active, suspended, pending }

class InstitutionModel {
  final String id;
  final String name;
  final String? nit;
  final String type; // e.g., 'university', 'hospital', 'company'
  final InstitutionStatus status;
  final String? logoUrl;
  final String contactEmail;
  final String? address;
  final DateTime createdAt;
  final Map<String, dynamic> config; // Flexible config for tenant-specific settings

  const InstitutionModel({
    required this.id,
    required this.name,
    this.nit,
    required this.type,
    this.status = InstitutionStatus.pending,
    this.logoUrl,
    required this.contactEmail,
    this.address,
    required this.createdAt,
    this.config = const {},
  });

  factory InstitutionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return InstitutionModel(
      id: doc.id,
      name: d['name'] ?? '',
      nit: d['nit'],
      type: d['type'] ?? 'other',
      status: _parseStatus(d['status']),
      logoUrl: d['logoUrl'],
      contactEmail: d['contactEmail'] ?? '',
      address: d['address'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      config: d['config'] ?? {},
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'nit': nit,
    'type': type,
    'status': status.toString().split('.').last,
    'logoUrl': logoUrl,
    'contactEmail': contactEmail,
    'address': address,
    'createdAt': Timestamp.fromDate(createdAt),
    'config': config,
  };

  static InstitutionStatus _parseStatus(String? s) {
    switch (s) {
      case 'active': return InstitutionStatus.active;
      case 'suspended': return InstitutionStatus.suspended;
      default: return InstitutionStatus.pending;
    }
  }
}
