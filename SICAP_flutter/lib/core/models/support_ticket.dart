import 'package:cloud_firestore/cloud_firestore.dart';

enum TicketStatus { open, inProgress, resolved, closed }

extension TicketStatusExt on TicketStatus {
  String get name => switch (this) {
        TicketStatus.open       => 'open',
        TicketStatus.inProgress => 'inProgress',
        TicketStatus.resolved   => 'resolved',
        TicketStatus.closed     => 'closed',
      };

  String get label => switch (this) {
        TicketStatus.open       => 'Abierto',
        TicketStatus.inProgress => 'En progreso',
        TicketStatus.resolved   => 'Resuelto',
        TicketStatus.closed     => 'Cerrado',
      };

  static TicketStatus fromString(String? s) => switch (s) {
        'inProgress' => TicketStatus.inProgress,
        'resolved'   => TicketStatus.resolved,
        'closed'     => TicketStatus.closed,
        _            => TicketStatus.open,
      };
}

enum TicketCategory { doubt, technicalIssue, certRequest, billing, other }

extension TicketCategoryExt on TicketCategory {
  String get name => switch (this) {
        TicketCategory.doubt          => 'doubt',
        TicketCategory.technicalIssue => 'technicalIssue',
        TicketCategory.certRequest    => 'certRequest',
        TicketCategory.billing        => 'billing',
        TicketCategory.other          => 'other',
      };

  String get label => switch (this) {
        TicketCategory.doubt          => 'Duda',
        TicketCategory.technicalIssue => 'Problema técnico',
        TicketCategory.certRequest    => 'Certificación',
        TicketCategory.billing        => 'Facturación',
        TicketCategory.other          => 'Otro',
      };

  static TicketCategory fromString(String? s) => switch (s) {
        'technicalIssue' => TicketCategory.technicalIssue,
        'certRequest'    => TicketCategory.certRequest,
        'billing'        => TicketCategory.billing,
        'doubt'          => TicketCategory.doubt,
        _                => TicketCategory.other,
      };
}

class SupportTicket {
  final String id;
  final String? userId;
  final String name;
  final String email;
  final TicketCategory category;
  final String subject;
  final String message;
  final TicketStatus status;
  final String? response;
  final String? respondedBy;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const SupportTicket({
    required this.id,
    this.userId,
    required this.name,
    required this.email,
    this.category = TicketCategory.other,
    required this.subject,
    required this.message,
    this.status = TicketStatus.open,
    this.response,
    this.respondedBy,
    required this.createdAt,
    this.respondedAt,
  });

  factory SupportTicket.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SupportTicket(
      id:          doc.id,
      userId:      d['userId'],
      name:        d['name'] ?? '',
      email:       d['email'] ?? '',
      category:    TicketCategoryExt.fromString(d['category']),
      subject:     d['subject'] ?? '',
      message:     d['message'] ?? '',
      status:      TicketStatusExt.fromString(d['status']),
      response:    d['response'],
      respondedBy: d['respondedBy'],
      createdAt:   (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (d['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId':      userId,
        'name':        name,
        'email':       email,
        'category':    category.name,
        'subject':     subject,
        'message':     message,
        'status':      status.name,
        'response':    response,
        'respondedBy': respondedBy,
        'createdAt':   Timestamp.fromDate(createdAt),
        'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
        'updatedAt':   FieldValue.serverTimestamp(),
      };

  SupportTicket copyWith({
    TicketStatus? status,
    String? response,
    String? respondedBy,
    DateTime? respondedAt,
  }) => SupportTicket(
        id:          id,
        userId:      userId,
        name:        name,
        email:       email,
        category:    category,
        subject:     subject,
        message:     message,
        status:      status ?? this.status,
        response:    response ?? this.response,
        respondedBy: respondedBy ?? this.respondedBy,
        createdAt:   createdAt,
        respondedAt: respondedAt ?? this.respondedAt,
      );
}
