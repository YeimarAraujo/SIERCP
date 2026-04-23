import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/guide.dart';
import '../services/guide_service.dart';
import '../services/device_service.dart';
import 'auth_provider.dart';

// ─── Guías por curso (Stream en tiempo real) ──────────────────────────────────
final courseGuidesProvider =
    StreamProvider.family<List<GuideModel>, String>((ref, courseId) {
  return ref.read(guideServiceProvider).streamGuidesByCourse(courseId);
});

// ─── Progreso de guías del usuario actual (Stream) ────────────────────────────
final userGuideProgressProvider =
    StreamProvider.family<Map<String, GuideProgress>, String>((ref, userId) {
  return ref.read(guideServiceProvider).streamUserGuideProgress(userId);
});

// ─── Resumen de progreso de guías en un curso ─────────────────────────────────
// Clave: 'userId|courseId'
final courseGuideProgressProvider =
    FutureProvider.family<GuideProgressSummary, String>((ref, key) async {
  final parts = key.split('|');
  if (parts.length < 2) return const GuideProgressSummary();
  final userId   = parts[0];
  final courseId = parts[1];
  return ref
      .read(guideServiceProvider)
      .getCourseGuideProgressSummary(userId, courseId);
});

// ─── Categoría seleccionada para filtro ───────────────────────────────────────
final selectedGuideCategoryProvider =
    StateProvider<GuideCategory?>((ref) => null);

// ─── Progreso de carga de PDF ─────────────────────────────────────────────────
final guideUploadProgressProvider = StateProvider<double>((ref) => 0.0);

// ─── Estado del dispositivo (Stream en tiempo real desde RTDB) ────────────────
final deviceConnectionProvider = StreamProvider<DeviceStatus>((ref) {
  return ref.read(deviceServiceProvider).streamConnectionStatus();
});

// ─── Lista de dispositivos disponibles ───────────────────────────────────────
final availableDevicesProvider = StreamProvider<List<DeviceInfo>>((ref) {
  return ref.read(deviceServiceProvider).streamAvailableDevices();
});

// ─── Telemetría de un dispositivo específico (family por MAC) ─────────────────
final deviceTelemetryProvider =
    StreamProvider.family<DeviceInfo?, String>((ref, macAddress) {
  return ref.read(deviceServiceProvider).streamDevice(macAddress);
});

// ─── MAC seleccionada para la sesión ─────────────────────────────────────────
final selectedDeviceMacProvider = StateProvider<String?>((ref) => null);

// ─── Guías del usuario actual (combinado) ────────────────────────────────────
final myGuideProgressProvider =
    StreamProvider<Map<String, GuideProgress>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.read(guideServiceProvider).streamUserGuideProgress(user.id);
});
