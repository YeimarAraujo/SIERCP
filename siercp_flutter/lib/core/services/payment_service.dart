import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final paymentServiceProvider = Provider<PaymentService>((ref) => PaymentService());

// ── Enums ─────────────────────────────────────────────────────────────────────

enum PlanType {
  pyme,
  business,
  corporate,
  enterprise,
  sstSinLicencia,
  sstConLicencia;

  /// Human-readable label in Spanish.
  String get label => switch (this) {
        PlanType.pyme => 'Pyme',
        PlanType.business => 'Business',
        PlanType.corporate => 'Corporativo',
        PlanType.enterprise => 'Enterprise',
        PlanType.sstSinLicencia => 'SST sin licencia',
        PlanType.sstConLicencia => 'SST con licencia',
      };
}

enum TransactionStatus {
  pending,
  approved,
  declined,
  voided,
  error,
  unknown;

  static TransactionStatus fromString(String? raw) => switch (raw?.toUpperCase()) {
        'PENDING' => TransactionStatus.pending,
        'APPROVED' => TransactionStatus.approved,
        'DECLINED' => TransactionStatus.declined,
        'VOIDED' => TransactionStatus.voided,
        'ERROR' => TransactionStatus.error,
        _ => TransactionStatus.unknown,
      };

  bool get isTerminal =>
      this == TransactionStatus.approved ||
      this == TransactionStatus.declined ||
      this == TransactionStatus.voided ||
      this == TransactionStatus.error;

  bool get isSuccessful => this == TransactionStatus.approved;
}

// ── Model ─────────────────────────────────────────────────────────────────────

class WompiTransaction {
  final String transactionId;
  final String redirectUrl;
  final int amountCents;
  final String? courseTitle;

  const WompiTransaction({
    required this.transactionId,
    required this.redirectUrl,
    required this.amountCents,
    this.courseTitle,
  });

  /// Formatted amount in COP (e.g. "$350.000").
  String get formattedAmount {
    final amount = amountCents ~/ 100;
    return '\$${_formatNumber(amount)} COP';
  }

  static String _formatNumber(int n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}

// ── Service ───────────────────────────────────────────────────────────────────
//
// SECURITY — all payment amounts are resolved server-side (Cloud Function or
// SIERCP-WEB). The client sends NO price, NO amount. The server looks up the
// canonical price from Firestore and uses that for the Wompi payment link.
//
// Flow:
//   1. Client calls initiatePlanPayment / initiateCoursePayment.
//   2. Cloud Function validates auth, resolves price, creates Wompi payment link.
//   3. Client opens redirectUrl via system browser (url_launcher).
//   4. User pays on Wompi's hosted page.
//   5. Wompi calls the webhook (SIERCP-WEB).
//   6. Webhook activates the plan or creates the enrollment in Firestore.
//   7. Client watches transactions/{transactionId} for status APPROVED.
//
class PaymentService {
  final FirebaseFunctions _fn = FirebaseFunctions.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Plan subscription ──────────────────────────────────────────────────────

  /// Initiates a monthly plan subscription payment for an institution.
  ///
  /// The Cloud Function validates that the caller is ADMIN of [institutionId]
  /// and resolves the price server-side. Returns a [WompiTransaction] whose
  /// [redirectUrl] must be opened via [openPaymentUrl].
  Future<WompiTransaction> initiatePlanPayment({
    required PlanType plan,
    required String institutionId,
  }) async {
    try {
      final result = await _fn
          .httpsCallable('createWompiPlanTransaction')
          .call<Map<Object?, Object?>>({
        'planType': plan.name,
        'institutionId': institutionId,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return WompiTransaction(
        transactionId: data['transactionId'] as String,
        redirectUrl: data['redirectUrl'] as String,
        amountCents: (data['amountCents'] as num).toInt(),
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PaymentService] initiatePlanPayment error: ${e.code} ${e.message}');
      throw _mapFunctionError(e);
    }
  }

  // ── Course enrollment ──────────────────────────────────────────────────────

  /// Initiates a course enrollment payment.
  ///
  /// The Cloud Function resolves the price from Firestore (cohort → template →
  /// slug). Returns a [WompiTransaction] whose [redirectUrl] must be opened
  /// via [openPaymentUrl].
  Future<WompiTransaction> initiateCoursePayment({
    required String cursoSlug,
    String? cohortId,
    String? templateId,
    String? institutionId,
  }) async {
    try {
      final result = await _fn
          .httpsCallable('createWompiCourseTransaction')
          .call<Map<Object?, Object?>>({
        'cursoSlug': cursoSlug,
        if (cohortId != null) 'cohortId': cohortId,
        if (templateId != null) 'templateId': templateId,
        if (institutionId != null) 'institutionId': institutionId,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return WompiTransaction(
        transactionId: data['transactionId'] as String,
        redirectUrl: data['redirectUrl'] as String,
        amountCents: (data['amountCents'] as num).toInt(),
        courseTitle: data['courseTitle'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PaymentService] initiateCoursePayment error: ${e.code} ${e.message}');
      throw _mapFunctionError(e);
    }
  }

  // ── Open payment URL ───────────────────────────────────────────────────────

  /// Opens the Wompi hosted checkout page in the system browser.
  Future<void> openPaymentUrl(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw Exception('No se pudo abrir el enlace de pago. Intenta de nuevo.');
    }
  }

  // ── Transaction status stream ──────────────────────────────────────────────

  /// Streams the [TransactionStatus] of a pending transaction.
  ///
  /// Use this after calling [openPaymentUrl] to reactively detect when Wompi
  /// confirms the payment (APPROVED, DECLINED, etc.).
  Stream<TransactionStatus> watchTransactionStatus(String transactionId) {
    return _db
        .collection('transactions')
        .doc(transactionId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return TransactionStatus.unknown;
      final status = snap.data()?['status'] as String?;
      return TransactionStatus.fromString(status);
    });
  }

  /// One-shot read of a transaction's current status.
  Future<TransactionStatus> getTransactionStatus(String transactionId) async {
    final snap = await _db.collection('transactions').doc(transactionId).get();
    if (!snap.exists) return TransactionStatus.unknown;
    return TransactionStatus.fromString(snap.data()?['status'] as String?);
  }

  // ── Error mapping ──────────────────────────────────────────────────────────

  Exception _mapFunctionError(FirebaseFunctionsException e) {
    return switch (e.code) {
      'unauthenticated' => Exception('Debes iniciar sesión para realizar un pago.'),
      'permission-denied' =>
        Exception('No tienes permiso para gestionar esta suscripción.'),
      'not-found' => Exception('Curso o plan no encontrado. Verifica los datos e intenta de nuevo.'),
      'already-exists' => Exception('Ya tienes una inscripción activa para este curso.'),
      'invalid-argument' => Exception('Datos de pago inválidos: ${e.message}'),
      'resource-exhausted' => Exception('Demasiados intentos. Espera un momento e intenta de nuevo.'),
      'internal' => Exception('Error en el servidor de pagos. Intenta más tarde.'),
      _ => Exception('Error de pago: ${e.message}'),
    };
  }
}
