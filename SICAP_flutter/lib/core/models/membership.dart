import 'package:cloud_firestore/cloud_firestore.dart';

enum MembershipStatus { pending, approved, rejected, suspended }

enum PlanType {
  pyme,         // Corporativo: 15 users, 1 sede, 3 cursos, 50 certs/mes
  business,     // Corporativo: 50 users, 2 sedes, 10 cursos, 200 certs/mes
  corporate,    // Corporativo: 200 users, 5 sedes, ilimitado
  enterprise,   // Corporativo: ilimitado, multi-sede, soporte dedicado
  sstConLicencia,   // Profesional SST con licencia vigente
  sstSinLicencia,   // Profesional SST sin licencia
  credits,      // Por créditos de sesiones / certificados
}

class PlanLimits {
  final int maxUsers;           // -1 = ilimitado
  final int maxSeats;           // Número de sedes
  final int maxActiveCourses;   // -1 = ilimitado
  final int maxCertificatesPerMonth; // -1 = ilimitado
  final int maxManikins;        // Maniquíes incluidos en el plan
  final bool canUseLiveSessions;
  final bool canRecordSessions;
  final bool canUseMultiSite;
  final bool canUseApi;
  final bool canUseBiReports;
  final int historyMonths;      // -1 = ilimitado
  final bool requiresSstLicense;

  const PlanLimits({
    required this.maxUsers,
    required this.maxSeats,
    required this.maxActiveCourses,
    required this.maxCertificatesPerMonth,
    required this.maxManikins,
    required this.canUseLiveSessions,
    required this.canRecordSessions,
    required this.canUseMultiSite,
    required this.canUseApi,
    required this.canUseBiReports,
    required this.historyMonths,
    required this.requiresSstLicense,
  });

  static PlanLimits forPlan(PlanType plan) {
    switch (plan) {
      case PlanType.pyme:
        return const PlanLimits(
          maxUsers: 15, maxSeats: 1, maxActiveCourses: 3,
          maxCertificatesPerMonth: 50, maxManikins: 1,
          canUseLiveSessions: false, canRecordSessions: false,
          canUseMultiSite: false, canUseApi: false, canUseBiReports: false,
          historyMonths: 6, requiresSstLicense: false,
        );
      case PlanType.business:
        return const PlanLimits(
          maxUsers: 50, maxSeats: 2, maxActiveCourses: 10,
          maxCertificatesPerMonth: 200, maxManikins: 2,
          canUseLiveSessions: true, canRecordSessions: false,
          canUseMultiSite: false, canUseApi: false, canUseBiReports: false,
          historyMonths: 24, requiresSstLicense: false,
        );
      case PlanType.corporate:
        return const PlanLimits(
          maxUsers: 200, maxSeats: 5, maxActiveCourses: -1,
          maxCertificatesPerMonth: -1, maxManikins: 4,
          canUseLiveSessions: true, canRecordSessions: true,
          canUseMultiSite: true, canUseApi: false, canUseBiReports: true,
          historyMonths: -1, requiresSstLicense: false,
        );
      case PlanType.enterprise:
        return const PlanLimits(
          maxUsers: -1, maxSeats: -1, maxActiveCourses: -1,
          maxCertificatesPerMonth: -1, maxManikins: 8,
          canUseLiveSessions: true, canRecordSessions: true,
          canUseMultiSite: true, canUseApi: true, canUseBiReports: true,
          historyMonths: -1, requiresSstLicense: false,
        );
      case PlanType.sstConLicencia:
        return const PlanLimits(
          maxUsers: 1, maxSeats: 1, maxActiveCourses: -1,
          maxCertificatesPerMonth: -1, maxManikins: 0,
          canUseLiveSessions: false, canRecordSessions: false,
          canUseMultiSite: false, canUseApi: false, canUseBiReports: false,
          historyMonths: -1, requiresSstLicense: true,
        );
      case PlanType.sstSinLicencia:
        return const PlanLimits(
          maxUsers: 1, maxSeats: 1, maxActiveCourses: -1,
          maxCertificatesPerMonth: -1, maxManikins: 0,
          canUseLiveSessions: false, canRecordSessions: false,
          canUseMultiSite: false, canUseApi: false, canUseBiReports: false,
          historyMonths: -1, requiresSstLicense: false,
        );
      case PlanType.credits:
        return const PlanLimits(
          maxUsers: 1, maxSeats: 1, maxActiveCourses: -1,
          maxCertificatesPerMonth: -1, maxManikins: 0,
          canUseLiveSessions: false, canRecordSessions: false,
          canUseMultiSite: false, canUseApi: false, canUseBiReports: false,
          historyMonths: 12, requiresSstLicense: false,
        );
    }
  }
}

class MembershipModel {
  final String id;
  final String userId;
  final String institutionId;
  final String role; // 'SUPER_ADMIN' | 'ADMIN' | 'INSTRUCTOR' | 'USUARIO_SST' | 'USUARIO_PROFESIONAL' | 'USUARIO'
  final MembershipStatus status;
  final bool isActive;
  final String? approvedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Plan fields
  final PlanType planType;
  final DateTime? planExpiresAt;
  final int creditBalance; // Remaining credits (for PlanType.credits)

  // SST license validation
  final String? sstLicenseNumber;
  final bool sstLicenseVerified;
  final DateTime? sstLicenseExpiresAt;

  // Usage counters (reset monthly for certs; live values for users/courses)
  final int usageCurrentUsers;
  final int usageCurrentCourses;
  final int usageCertificatesThisMonth;
  final DateTime? usagePeriodStart; // When the current cert-count period started

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
    this.planType = PlanType.pyme,
    this.planExpiresAt,
    this.creditBalance = 0,
    this.sstLicenseNumber,
    this.sstLicenseVerified = false,
    this.sstLicenseExpiresAt,
    this.usageCurrentUsers = 0,
    this.usageCurrentCourses = 0,
    this.usageCertificatesThisMonth = 0,
    this.usagePeriodStart,
  });

  PlanLimits get limits => PlanLimits.forPlan(planType);

  bool get isPlanActive {
    if (!isActive || status != MembershipStatus.approved) return false;
    if (planExpiresAt != null && DateTime.now().isAfter(planExpiresAt!)) return false;
    return true;
  }

  bool get canAddUser {
    final l = limits;
    return l.maxUsers == -1 || usageCurrentUsers < l.maxUsers;
  }

  bool get canAddCourse {
    final l = limits;
    return l.maxActiveCourses == -1 || usageCurrentCourses < l.maxActiveCourses;
  }

  bool get canIssueCertificate {
    if (planType == PlanType.credits) return creditBalance > 0;
    final l = limits;
    return l.maxCertificatesPerMonth == -1 ||
        usageCertificatesThisMonth < l.maxCertificatesPerMonth;
  }

  bool get hasSstLicenseAccess {
    if (!limits.requiresSstLicense) return true;
    if (!sstLicenseVerified) return false;
    if (sstLicenseExpiresAt != null && DateTime.now().isAfter(sstLicenseExpiresAt!)) return false;
    return true;
  }

  factory MembershipModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MembershipModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      institutionId: d['institutionId'] ?? '',
      role: d['role'] ?? 'USUARIO',
      status: _parseStatus(d['status']),
      isActive: d['isActive'] ?? true,
      approvedBy: d['approvedBy'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      planType: _parsePlanType(d['planType']),
      planExpiresAt: (d['planExpiresAt'] as Timestamp?)?.toDate(),
      creditBalance: d['creditBalance'] ?? 0,
      sstLicenseNumber: d['sstLicenseNumber'],
      sstLicenseVerified: d['sstLicenseVerified'] ?? false,
      sstLicenseExpiresAt: (d['sstLicenseExpiresAt'] as Timestamp?)?.toDate(),
      usageCurrentUsers: d['usageCurrentUsers'] ?? 0,
      usageCurrentCourses: d['usageCurrentCourses'] ?? 0,
      usageCertificatesThisMonth: d['usageCertificatesThisMonth'] ?? 0,
      usagePeriodStart: (d['usagePeriodStart'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'institutionId': institutionId,
    'role': role,
    'status': status.name,
    'isActive': isActive,
    'approvedBy': approvedBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': FieldValue.serverTimestamp(),
    'planType': planType.name,
    'planExpiresAt': planExpiresAt != null ? Timestamp.fromDate(planExpiresAt!) : null,
    'creditBalance': creditBalance,
    'sstLicenseNumber': sstLicenseNumber,
    'sstLicenseVerified': sstLicenseVerified,
    'sstLicenseExpiresAt': sstLicenseExpiresAt != null ? Timestamp.fromDate(sstLicenseExpiresAt!) : null,
    'usageCurrentUsers': usageCurrentUsers,
    'usageCurrentCourses': usageCurrentCourses,
    'usageCertificatesThisMonth': usageCertificatesThisMonth,
    'usagePeriodStart': usagePeriodStart != null ? Timestamp.fromDate(usagePeriodStart!) : null,
  };

  static MembershipStatus _parseStatus(String? s) {
    switch (s) {
      case 'approved':  return MembershipStatus.approved;
      case 'rejected':  return MembershipStatus.rejected;
      case 'suspended': return MembershipStatus.suspended;
      default:          return MembershipStatus.pending;
    }
  }

  static PlanType _parsePlanType(String? s) {
    switch (s) {
      case 'business':        return PlanType.business;
      case 'corporate':       return PlanType.corporate;
      case 'enterprise':      return PlanType.enterprise;
      case 'sstConLicencia':  return PlanType.sstConLicencia;
      case 'sstSinLicencia':  return PlanType.sstSinLicencia;
      case 'credits':         return PlanType.credits;
      default:                return PlanType.pyme;
    }
  }

  MembershipModel copyWith({
    MembershipStatus? status,
    bool? isActive,
    String? approvedBy,
    PlanType? planType,
    DateTime? planExpiresAt,
    int? creditBalance,
    String? sstLicenseNumber,
    bool? sstLicenseVerified,
    DateTime? sstLicenseExpiresAt,
    int? usageCurrentUsers,
    int? usageCurrentCourses,
    int? usageCertificatesThisMonth,
    DateTime? usagePeriodStart,
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
    planType: planType ?? this.planType,
    planExpiresAt: planExpiresAt ?? this.planExpiresAt,
    creditBalance: creditBalance ?? this.creditBalance,
    sstLicenseNumber: sstLicenseNumber ?? this.sstLicenseNumber,
    sstLicenseVerified: sstLicenseVerified ?? this.sstLicenseVerified,
    sstLicenseExpiresAt: sstLicenseExpiresAt ?? this.sstLicenseExpiresAt,
    usageCurrentUsers: usageCurrentUsers ?? this.usageCurrentUsers,
    usageCurrentCourses: usageCurrentCourses ?? this.usageCurrentCourses,
    usageCertificatesThisMonth: usageCertificatesThisMonth ?? this.usageCertificatesThisMonth,
    usagePeriodStart: usagePeriodStart ?? this.usagePeriodStart,
  );
}
