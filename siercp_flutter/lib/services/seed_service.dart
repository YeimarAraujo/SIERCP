import 'package:cloud_firestore/cloud_firestore.dart';

class SeedService {
  static Future<void> seedScenarios() async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    final scenarios = [
      {
        'id': 'adult',
        'title': 'Adulto',
        'description': 'RCP estándar para adulto según guías AHA 2020.',
        'audioIntroText':
            'Paciente adulto sin respuesta. Inicie RCP inmediatamente.',
        'patientAge': 'Adulto (>8 años)',
        'patientType': 'adult',
        'category': 'cardiac',
        'difficulty': 'medium',
        'locked': false,
        'isNew': false,
        'orderIndex': 0,
        'ahaGuidelines': {
          'minDepthMm': 50.0,
          'maxDepthMm': 60.0,
          'minRatePerMin': 100,
          'maxRatePerMin': 120,
          'maxPauseSeconds': 10.0,
          'compressionRatio': '30:2',
        },
      },
      {
        'id': 'pediatric_child',
        'title': 'Niño (1–8 años)',
        'description': 'RCP pediátrico para niños entre 1 y 8 años.',
        'audioIntroText':
            'Niño de 5 años sin respuesta. Aplique protocolo pediátrico.',
        'patientAge': 'Niño (1–8 años)',
        'patientType': 'pediatric_child',
        'category': 'pediatric',
        'difficulty': 'hard',
        'locked': false,
        'isNew': false,
        'orderIndex': 1,
        'ahaGuidelines': {
          'minDepthMm': 50.0,
          'maxDepthMm': 60.0,
          'minRatePerMin': 100,
          'maxRatePerMin': 120,
          'maxPauseSeconds': 10.0,
          'compressionRatio': '30:2',
        },
      },
      {
        'id': 'pediatric_infant',
        'title': 'Lactante (<1 año)',
        'description': 'RCP pediátrico para lactantes menores de 1 año.',
        'audioIntroText':
            'Lactante de 6 meses sin respuesta. Use técnica de dos dedos.',
        'patientAge': 'Lactante (<1 año)',
        'patientType': 'pediatric_infant',
        'category': 'pediatric',
        'difficulty': 'hard',
        'locked': false,
        'isNew': false,
        'orderIndex': 2,
        'ahaGuidelines': {
          'minDepthMm': 40.0,
          'maxDepthMm': 50.0,
          'minRatePerMin': 100,
          'maxRatePerMin': 120,
          'maxPauseSeconds': 10.0,
          'compressionRatio': '30:2',
        },
      },
    ];

    for (final s in scenarios) {
      final ref = db.collection('scenarios').doc(s['id'] as String);
      batch.set(ref, {
        ...s,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    print('[SeedService] Escenarios creados correctamente en Firestore.');
  }
}
