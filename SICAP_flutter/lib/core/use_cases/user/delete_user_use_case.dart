import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:siercp/core/constants/constants.dart';

class DeleteUserUseCase {
  const DeleteUserUseCase();

  Future<void> execute(String userId) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // 1. Soft-delete: desactivar el documento del usuario
    batch.update(db.collection(AppConstants.colUsers).doc(userId), {
      'isActive':      false,
      'accountStatus': 'deleted',
      'updatedAt':     FieldValue.serverTimestamp(),
    });

    // 2. Desactivar todas las memberships activas del usuario
    final membershipsSnap = await db
        .collection(AppConstants.colMemberships)
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in membershipsSnap.docs) {
      batch.update(doc.reference, {
        'isActive':  false,
        'status':    'deleted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    // TODO: Llamar Cloud Function deleteAuthUser para eliminar de Firebase Auth
  }
}
