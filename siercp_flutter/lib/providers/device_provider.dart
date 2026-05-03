import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../models/maniqui.dart';

final devicesStreamProvider = StreamProvider<List<ManiquiModel>>((ref) {
  return ref.watch(firestoreServiceProvider).watchManikins();
});
