import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<ConnectivityResult>((ref) async* {
  final connectivity = Connectivity();
  
  // Emitir el estado inicial
  final initial = await connectivity.checkConnectivity();
  yield initial.first; // Connectivity v6 returns a list, we take the first one

  // Escuchar cambios
  yield* connectivity.onConnectivityChanged.map((results) => results.first);
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider).valueOrNull;
  if (connectivity == null) return true; // Asumimos online por defecto para no asustar
  return connectivity != ConnectivityResult.none;
});
