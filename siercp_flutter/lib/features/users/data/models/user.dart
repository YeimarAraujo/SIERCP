import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:siercp/core/constants/constants.dart';

// ── Certificate verification ─────────────────────────────────────────────────

enum CertVerificationStatus { none, pending, approved, rejected }

extension CertVerificationStatusExt on CertVerificationStatus {
  String get name => switch (this) {
        CertVerificationStatus.none => 'NONE',
        CertVerificationStatus.pending => 'PENDING',
        CertVerificationStatus.approved => 'APPROVED',
        CertVerificationStatus.rejected => 'REJECTED',
      };

  static CertVerificationStatus fromString(String? s) => switch (s) {
        'PENDING' => CertVerificationStatus.pending,
        'APPROVED' => CertVerificationStatus.approved,
        'REJECTED' => CertVerificationStatus.rejected,
        _ => CertVerificationStatus.none,
      };
}

// ── User certificate document ─────────────────────────────────────────────────

class UserCertificate {
  final String id;
  final String userId;
  final String type; // 'PROFESIONAL' | 'SST_LICENCIA' | 'AHA' | 'OTRO'
  final String issuer;
  final String certificateNumber;
  final String issueDate;
  final String? expiryDate;
  final String fileUrl;
  final CertVerificationStatus verificationStatus;
  final String? rejectionReason;
  final DateTime? createdAt;

  const UserCertificate({
    required this.id,
    required this.userId,
    required this.type,
    required this.issuer,
    required this.certificateNumber,
    required this.issueDate,
    this.expiryDate,
    required this.fileUrl,
    this.verificationStatus = CertVerificationStatus.pending,
    this.rejectionReason,
    this.createdAt,
  });

  factory UserCertificate.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserCertificate(
      id: doc.id,
      userId: d['userId'] ?? '',
      type: d['type'] ?? 'OTRO',
      issuer: d['issuer'] ?? '',
      certificateNumber: d['certificateNumber'] ?? '',
      issueDate: d['issueDate'] ?? '',
      expiryDate: d['expiryDate'],
      fileUrl: d['fileUrl'] ?? '',
      verificationStatus:
          CertVerificationStatusExt.fromString(d['verificationStatus']),
      rejectionReason: d['rejectionReason'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

// ── UserModel ─────────────────────────────────────────────────────────────────

class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;

  /// Role string matching AppConstants role constants.
  final String role;

  final String? avatarUrl;

  /// Número de identificación (cédula, pasaporte, etc.).
  /// Mantenemos el nombre original para no romper las 18+ referencias existentes.
  /// El Firestore escribe 'identification' (canónico Web); fromFirestore lee ambos.
  final String? identificacion;

  final String? phoneNumber;
  final bool isActive;
  final DateTime? lastActive;
  final bool isOnline;
  final UserStats? stats;
  final List<String>? memberships;

  /// ID de la organización primaria. Cadena vacía si el usuario no tiene org.
  final String institutionId;

  /// Estado de ciclo de vida de la cuenta. 'PENDING' | 'ACTIVE'.
  final String accountStatus;

  /// Number of courses this user has created (enforced against role limit).
  final int coursesCreated;

  /// Certificate verification tier.
  final CertVerificationStatus certVerification;

  const UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.avatarUrl,
    this.identificacion,
    this.phoneNumber,
    this.isActive = true,
    this.lastActive,
    this.isOnline = false,
    this.stats,
    this.memberships,
    this.institutionId = '',
    this.accountStatus = 'ACTIVE',
    this.coursesCreated = 0,
    this.certVerification = CertVerificationStatus.none,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? role,
    String? avatarUrl,
    String? identificacion,
    String? phoneNumber,
    bool? isActive,
    DateTime? lastActive,
    bool? isOnline,
    UserStats? stats,
    List<String>? memberships,
    String? institutionId,
    String? accountStatus,
    int? coursesCreated,
    CertVerificationStatus? certVerification,
  }) =>
      UserModel(
        id: id ?? this.id,
        email: email ?? this.email,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        role: role ?? this.role,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        identificacion: identificacion ?? this.identificacion,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        isActive: isActive ?? this.isActive,
        lastActive: lastActive ?? this.lastActive,
        isOnline: isOnline ?? this.isOnline,
        stats: stats ?? this.stats,
        memberships: memberships ?? this.memberships,
        institutionId: institutionId ?? this.institutionId,
        accountStatus: accountStatus ?? this.accountStatus,
        coursesCreated: coursesCreated ?? this.coursesCreated,
        certVerification: certVerification ?? this.certVerification,
      );

  // ── Alias canónico (alineado con Web: field 'identification') ────────────
  // El getter permite que código futuro use `.identification` sin romper nada.
  String? get identification => identificacion;

  // ── Display helpers ──────────────────────────────────────────────────────

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final res = '$f$l'.toUpperCase();
    return res.isEmpty ? 'U' : res;
  }

  String get roleLabel => switch (role) {
        AppConstants.roleSuperAdmin => 'Super Administrador',
        AppConstants.roleAdmin => 'Administrador',
        AppConstants.roleInstructor => 'Instructor',
        AppConstants.roleUsuarioSST => 'Usuario SST',
        AppConstants.roleUsuarioProfesional => 'Usuario Profesional',
        _ => 'Usuario',
      };

  // ── Role checks ──────────────────────────────────────────────────────────

  bool get isSuperAdmin => role == AppConstants.roleSuperAdmin;
  bool get isAdmin =>
      role == AppConstants.roleAdmin || role == AppConstants.roleSuperAdmin;
  bool get isInstructor =>
      role == AppConstants.roleInstructor ||
      role == AppConstants.roleAdmin ||
      role == AppConstants.roleSuperAdmin;

  bool get isUsuario =>
      role == AppConstants.roleUsuario ||
      role == AppConstants.roleUsuarioProfesional ||
      role == AppConstants.roleUsuarioSST;

  bool get isUsuarioPro => role == AppConstants.roleUsuarioProfesional;
  bool get isUsuarioSST => role == AppConstants.roleUsuarioSST;

  /// @deprecated Use [isUsuario].
  bool get isStudent => isUsuario;

  // ── Business rules ───────────────────────────────────────────────────────

  int get courseLimit => switch (role) {
        AppConstants.roleUsuario => AppConstants.courseLimitUsuario,
        AppConstants.roleUsuarioProfesional =>
          AppConstants.courseLimitUsuarioPro,
        _ => 999999, // admin/instructor/sst: plan-controlled
      };

  bool get canCreateMoreCourses => coursesCreated < courseLimit;

  bool get mustPayToCertify => role == AppConstants.roleUsuarioProfesional;

  // ── Serialization ────────────────────────────────────────────────────────

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final statsMap = d['stats'] as Map<String, dynamic>?;
    return UserModel(
      id: doc.id,
      email: d['email'] ?? '',
      firstName: d['firstName'] ?? '',
      lastName: d['lastName'] ?? '',
      role: d['role'] ?? AppConstants.roleUsuario,
      avatarUrl: d['avatarUrl'],
      // Lee 'identification' (canónico Web) primero; si no existe lee 'identificacion' (legado Flutter).
      identificacion: (d['identification'] ?? d['identificacion']) as String?,
      phoneNumber: d['phoneNumber'],
      isActive: d['isActive'] ?? true,
      lastActive: (d['lastActive'] as Timestamp?)?.toDate(),
      isOnline: d['isOnline'] ?? false,
      stats: statsMap != null ? UserStats.fromMap(statsMap) : null,
      memberships:
          (d['memberships'] as List?)?.map((e) => e.toString()).toList(),
      institutionId: d['institutionId'] as String? ?? '',
      accountStatus: d['status'] as String? ?? 'ACTIVE',
      coursesCreated: (d['coursesCreated'] as num?)?.toInt() ?? 0,
      certVerification:
          CertVerificationStatusExt.fromString(d['certVerification']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': id,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
        'avatarUrl': avatarUrl,
        // Escribe 'identification' (canónico) para que Web también lo lea.
        'identification': identificacion,
        'phoneNumber': phoneNumber,
        'isActive': isActive,
        'status': accountStatus,
        'institutionId': institutionId,
        'lastActive':
            lastActive != null ? Timestamp.fromDate(lastActive!) : null,
        'isOnline': isOnline,
        'stats': {
          'totalSessions': stats?.totalSessions ?? 0,
          'sessionsToday': stats?.sessionsToday ?? 0,
          'averageScore': stats?.averageScore ?? 0.0,
          'bestScore': stats?.bestScore ?? 0.0,
          'streakDays': stats?.streakDays ?? 0,
          'totalHours': stats?.totalHours ?? 0.0,
          'averageDepthMm': stats?.averageDepthMm ?? 0.0,
          'averageRatePerMin': stats?.averageRatePerMin ?? 0.0,
        },
        'memberships': memberships,
        'coursesCreated': coursesCreated,
        'certVerification': certVerification.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

// ── UserStats ────────────────────────────────────────────────────────────────

class UserStats {
  final int totalSessions;
  final int sessionsToday;
  final double averageScore;
  final double bestScore;
  final int streakDays;
  final double totalHours;
  final double averageDepthMm;
  final double averageRatePerMin;

  const UserStats({
    this.totalSessions = 0,
    this.sessionsToday = 0,
    this.averageScore = 0,
    this.bestScore = 0,
    this.streakDays = 0,
    this.totalHours = 0,
    this.averageDepthMm = 0,
    this.averageRatePerMin = 0,
  });

  factory UserStats.fromMap(Map<String, dynamic> m) => UserStats(
        totalSessions: m['totalSessions'] ?? 0,
        sessionsToday: m['sessionsToday'] ?? 0,
        averageScore: (m['averageScore'] ?? 0).toDouble(),
        bestScore: (m['bestScore'] ?? 0).toDouble(),
        streakDays: m['streakDays'] ?? 0,
        totalHours: (m['totalHours'] ?? 0).toDouble(),
        averageDepthMm: (m['averageDepthMm'] ?? 0).toDouble(),
        averageRatePerMin: (m['averageRatePerMin'] ?? 0).toDouble(),
      );
}

// ── AuthTokens ────────────────────────────────────────────────────────────────

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final bool isAuthenticated;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.isAuthenticated = true,
  });

  factory AuthTokens.empty() => const AuthTokens(
        accessToken: '',
        refreshToken: '',
        isAuthenticated: false,
      );
}
