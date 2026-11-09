import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';

/// Invitación de una institución a alguien que ya tenía cuenta.
class Invitation {
  const Invitation(this.id, this.institutionId, this.institutionName, this.role);

  final String id;
  final String institutionId;
  final String institutionName;
  final String role;
}

final pendingInvitationsProvider = StreamProvider<List<Invitation>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  final db = FirebaseFirestore.instance;
  return db
      .collection(AppConstants.colMemberships)
      .where('userId', isEqualTo: user.id)
      .where('status', isEqualTo: 'invited')
      .snapshots()
      .asyncMap((snap) => Future.wait(snap.docs.map((d) async {
            final institutionId = d.data()['institutionId'] as String? ?? '';
            final institution = await db.collection(AppConstants.colInstitutions).doc(institutionId).get();
            return Invitation(
              d.id,
              institutionId,
              (institution.data()?['name'] as String?) ?? 'Una institución',
              d.data()['role'] as String? ?? '',
            );
          })));
});

/// La persona decide si entra a la institución (Ley 1581): hasta que acepte,
/// la institución no ve sus datos.
class InvitationsBanner extends ConsumerWidget {
  const InvitationsBanner({super.key});

  Future<void> _answer(BuildContext context, WidgetRef ref, Invitation invitation, bool accept) async {
    final doc = FirebaseFirestore.instance.collection(AppConstants.colMemberships).doc(invitation.id);
    try {
      if (accept) {
        await doc.update({
          'status': 'approved',
          'isActive': true,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
        final user = ref.read(currentUserProvider);
        if (user != null) await ref.read(orgContextProvider.notifier).loadForUser(user.id);
      } else {
        await doc.delete();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo responder: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitations = ref.watch(pendingInvitationsProvider).valueOrNull ?? const [];
    if (invitations.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final invitation in invitations)
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${invitation.institutionName} te invitó a unirte',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  const Text('Si aceptas, la institución y sus instructores verán tu progreso y tus sesiones.'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _answer(context, ref, invitation, false),
                        child: const Text('Rechazar'),
                      ),
                      FilledButton(
                        onPressed: () => _answer(context, ref, invitation, true),
                        child: const Text('Aceptar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
