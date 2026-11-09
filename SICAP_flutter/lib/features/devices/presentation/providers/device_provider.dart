import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/features/devices/data/models/maniqui.dart';

final devicesStreamProvider = StreamProvider<List<ManiquiModel>>((ref) {
  return ref.watch(firestoreServiceProvider).watchManikins();
});
