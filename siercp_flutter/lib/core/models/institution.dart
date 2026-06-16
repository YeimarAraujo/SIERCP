import 'package:cloud_firestore/cloud_firestore.dart';

enum InstitutionStatus { active, suspended, pending }

enum InstitutionType { university, hospital, company, government, ngo, other }

/// Nivel del tenant en el modelo de 3 niveles
/// (JOMAR Group › SIERCP SaaS › Instituciones):
///   owner   — institución operada por la empresa dueña del SaaS (JOMAR Academy).
///   partner — institución aliada (puede destacarse en "Aliadas").
///   client  — institución cliente estándar (default).
/// Solo SUPER_ADMIN puede cambiar el tier (enforced en firestore.rules).
enum InstitutionTier { owner, partner, client }

extension InstitutionTierExt on InstitutionTier {
  String get wire => switch (this) {
        InstitutionTier.owner   => 'OWNER',
        InstitutionTier.partner => 'PARTNER',
        InstitutionTier.client  => 'CLIENT',
      };

  String get label => switch (this) {
        InstitutionTier.owner   => 'Propietaria',
        InstitutionTier.partner => 'Aliada',
        InstitutionTier.client  => 'Cliente',
      };

  static InstitutionTier fromString(String? s) => switch (s) {
        'OWNER'   => InstitutionTier.owner,
        'PARTNER' => InstitutionTier.partner,
        _         => InstitutionTier.client,
      };
}

extension InstitutionTypeExt on InstitutionType {
  String get label => switch (this) {
        InstitutionType.university => 'Universidad',
        InstitutionType.hospital   => 'Hospital / Clínica',
        InstitutionType.company    => 'Empresa',
        InstitutionType.government => 'Entidad Gubernamental',
        InstitutionType.ngo        => 'ONG / Fundación',
        InstitutionType.other      => 'Otra',
      };

  static InstitutionType fromString(String? s) => switch (s) {
        'university' => InstitutionType.university,
        'hospital'   => InstitutionType.hospital,
        'company'    => InstitutionType.company,
        'government' => InstitutionType.government,
        'ngo'        => InstitutionType.ngo,
        _            => InstitutionType.other,
      };
}

class InstitutionModel {
  final String id;
  final String name;
  final String? nit;
  final InstitutionType type;
  final InstitutionStatus status;
  final String? logoUrl;
  final String contactEmail;
  final String? phoneNumber;
  final String? address;
  final String? city;
  final String? country;

  /// UID del admin principal que creó/gestiona esta org.
  final String? primaryAdminId;

  /// Contadores en vivo (actualizados por Cloud Functions o transacciones).
  final int memberCount;
  final int activeCoursesCount;
  final int totalSessionsCount;

  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Configuración flexible por tenant (colores, límites custom, integraciones).
  final Map<String, dynamic> config;

  // ── Modelo de 3 niveles ────────────────────────────────────────────────────
  /// Nivel del tenant. Default [InstitutionTier.client]. Solo SUPER_ADMIN lo cambia.
  final InstitutionTier tier;

  /// Si aparece en la sección pública "Instituciones Aliadas". Default false.
  final bool showcase;

  /// UID responsable de facturación (Nivel 1 para OWNER).
  final String? billingOwnerUid;

  const InstitutionModel({
    required this.id,
    required this.name,
    this.nit,
    this.type = InstitutionType.other,
    this.status = InstitutionStatus.pending,
    this.logoUrl,
    required this.contactEmail,
    this.phoneNumber,
    this.address,
    this.city,
    this.country,
    this.primaryAdminId,
    this.memberCount = 0,
    this.activeCoursesCount = 0,
    this.totalSessionsCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.config = const {},
    this.tier = InstitutionTier.client,
    this.showcase = false,
    this.billingOwnerUid,
  });

  bool get isActive    => status == InstitutionStatus.active;
  bool get isSuspended => status == InstitutionStatus.suspended;
  bool get isPending   => status == InstitutionStatus.pending;

  String get statusLabel => switch (status) {
        InstitutionStatus.active    => 'Activa',
        InstitutionStatus.suspended => 'Suspendida',
        InstitutionStatus.pending   => 'Pendiente',
      };

  factory InstitutionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return InstitutionModel(
      id:                 doc.id,
      name:               d['name'] ?? '',
      nit:                d['nit'],
      type:               InstitutionTypeExt.fromString(d['type']),
      status:             _parseStatus(d['status']),
      logoUrl:            d['logoUrl'],
      contactEmail:       d['contactEmail'] ?? '',
      phoneNumber:        d['phoneNumber'],
      address:            d['address'],
      city:               d['city'],
      country:            d['country'],
      primaryAdminId:     d['primaryAdminId'],
      memberCount:        (d['memberCount'] as num?)?.toInt() ?? 0,
      activeCoursesCount: (d['activeCoursesCount'] as num?)?.toInt() ?? 0,
      totalSessionsCount: (d['totalSessionsCount'] as num?)?.toInt() ?? 0,
      createdAt:  (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:  (d['updatedAt'] as Timestamp?)?.toDate(),
      config:     (d['config'] as Map<String, dynamic>?) ?? {},
      tier:       InstitutionTierExt.fromString(d['tier']),
      showcase:   d['showcase'] as bool? ?? false,
      billingOwnerUid: d['billingOwnerUid'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name':               name,
        'nit':                nit,
        'type':               type.name,
        'status':             status.name,
        'logoUrl':            logoUrl,
        'contactEmail':       contactEmail,
        'phoneNumber':        phoneNumber,
        'address':            address,
        'city':               city,
        'country':            country,
        'primaryAdminId':     primaryAdminId,
        'memberCount':        memberCount,
        'activeCoursesCount': activeCoursesCount,
        'totalSessionsCount': totalSessionsCount,
        'createdAt':          Timestamp.fromDate(createdAt),
        'updatedAt':          FieldValue.serverTimestamp(),
        'config':             config,
        'tier':               tier.wire,
        'showcase':           showcase,
        'billingOwnerUid':    billingOwnerUid,
      };

  InstitutionModel copyWith({
    String? name,
    String? nit,
    InstitutionType? type,
    InstitutionStatus? status,
    String? logoUrl,
    String? contactEmail,
    String? phoneNumber,
    String? address,
    String? city,
    String? country,
    String? primaryAdminId,
    int? memberCount,
    int? activeCoursesCount,
    int? totalSessionsCount,
    Map<String, dynamic>? config,
    InstitutionTier? tier,
    bool? showcase,
    String? billingOwnerUid,
  }) =>
      InstitutionModel(
        id:                 id,
        name:               name ?? this.name,
        nit:                nit ?? this.nit,
        type:               type ?? this.type,
        status:             status ?? this.status,
        logoUrl:            logoUrl ?? this.logoUrl,
        contactEmail:       contactEmail ?? this.contactEmail,
        phoneNumber:        phoneNumber ?? this.phoneNumber,
        address:            address ?? this.address,
        city:               city ?? this.city,
        country:            country ?? this.country,
        primaryAdminId:     primaryAdminId ?? this.primaryAdminId,
        memberCount:        memberCount ?? this.memberCount,
        activeCoursesCount: activeCoursesCount ?? this.activeCoursesCount,
        totalSessionsCount: totalSessionsCount ?? this.totalSessionsCount,
        createdAt:          createdAt,
        updatedAt:          DateTime.now(),
        config:             config ?? this.config,
        tier:               tier ?? this.tier,
        showcase:           showcase ?? this.showcase,
        billingOwnerUid:    billingOwnerUid ?? this.billingOwnerUid,
      );

  static InstitutionStatus _parseStatus(String? s) => switch (s) {
        'active'    => InstitutionStatus.active,
        'suspended' => InstitutionStatus.suspended,
        _           => InstitutionStatus.pending,
      };
}
