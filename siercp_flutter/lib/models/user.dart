import 'package:cloud_firestore/cloud_firestore.dart';

// ─── UserModel ─────────────────────────────────────────────────────────────────
class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? avatarUrl;
  final String? identificacion;
  final bool isActive;
  final UserStats? stats;

  const UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.avatarUrl,
    this.identificacion,
    this.isActive = true,
    this.stats,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final res = '$f$l'.toUpperCase();
    return res.isEmpty ? 'U' : res;
  }

  bool get isAdmin      => role == 'ADMIN';
  bool get isInstructor => role == 'INSTRUCTOR';
  bool get isStudent    => role == 'ESTUDIANTE';

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final statsMap = d['stats'] as Map<String, dynamic>?;
    return UserModel(
      id:             doc.id,
      email:          d['email']         ?? '',
      firstName:      d['firstName']     ?? '',
      lastName:       d['lastName']      ?? '',
      role:           d['role']          ?? 'ESTUDIANTE',
      avatarUrl:      d['avatarUrl'],
      identificacion: d['identificacion'],
      isActive:       d['isActive']      ?? true,
      stats: statsMap != null ? UserStats.fromMap(statsMap) : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'uid':            id,
    'email':          email,
    'firstName':      firstName,
    'lastName':       lastName,
    'role':           role,
    'avatarUrl':      avatarUrl,
    'identificacion': identificacion,
    'isActive':       isActive,
    'stats': {
      'totalSessions':     stats?.totalSessions     ?? 0,
      'sessionsToday':     stats?.sessionsToday     ?? 0,
      'averageScore':      stats?.averageScore      ?? 0.0,
      'bestScore':         stats?.bestScore         ?? 0.0,
      'streakDays':        stats?.streakDays        ?? 0,
      'totalHours':        stats?.totalHours        ?? 0.0,
      'averageDepthMm':    stats?.averageDepthMm    ?? 0.0,
      'averageRatePerMin': stats?.averageRatePerMin ?? 0.0,
    },
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

// ─── UserStats ─────────────────────────────────────────────────────────────────
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
    this.totalSessions    = 0,
    this.sessionsToday    = 0,
    this.averageScore     = 0,
    this.bestScore        = 0,
    this.streakDays       = 0,
    this.totalHours       = 0,
    this.averageDepthMm   = 0,
    this.averageRatePerMin = 0,
  });

  factory UserStats.fromMap(Map<String, dynamic> m) => UserStats(
    totalSessions:     m['totalSessions']     ?? 0,
    sessionsToday:     m['sessionsToday']     ?? 0,
    averageScore:      (m['averageScore']     ?? 0).toDouble(),
    bestScore:         (m['bestScore']        ?? 0).toDouble(),
    streakDays:        m['streakDays']        ?? 0,
    totalHours:        (m['totalHours']       ?? 0).toDouble(),
    averageDepthMm:    (m['averageDepthMm']   ?? 0).toDouble(),
    averageRatePerMin: (m['averageRatePerMin'] ?? 0).toDouble(),
  );
}

// ─── AuthTokens (ya no se usarán, se mantiene para compatibilidad) ─────────────
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
