import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/guide.dart';
import '../services/guide_service.dart';
import '../services/device_service.dart';
import 'auth_provider.dart';

final courseGuidesProvider =
    StreamProvider.family<List<GuideModel>, String>((ref, courseId) {
  return ref.read(guideServiceProvider).streamGuidesByCourse(courseId);
});

final userGuideProgressProvider =
    StreamProvider.family<Map<String, GuideProgress>, String>((ref, userId) {
  return ref.read(guideServiceProvider).streamUserGuideProgress(userId);
});
final courseGuideProgressProvider =
    FutureProvider.family<GuideProgressSummary, String>((ref, key) async {
  final parts = key.split('|');
  if (parts.length < 2) return const GuideProgressSummary();
  final userId = parts[0];
  final courseId = parts[1];
  return ref
      .read(guideServiceProvider)
      .getCourseGuideProgressSummary(userId, courseId);
});

final selectedGuideCategoryProvider =
    StateProvider<GuideCategory?>((ref) => null);

final guideUploadProgressProvider = StateProvider<double>((ref) => 0.0);

final deviceConnectionProvider = StreamProvider<DeviceStatus>((ref) {
  return ref.read(deviceServiceProvider).streamConnectionStatus();
});
final availableDevicesProvider = StreamProvider<List<DeviceInfo>>((ref) {
  return ref.read(deviceServiceProvider).streamAvailableDevices();
});

final deviceTelemetryProvider =
    StreamProvider.family<DeviceInfo?, String>((ref, macAddress) {
  return ref.read(deviceServiceProvider).streamDevice(macAddress);
});
final selectedDeviceMacProvider = StateProvider<String?>((ref) => null);

final myGuideProgressProvider =
    StreamProvider<Map<String, GuideProgress>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.read(guideServiceProvider).streamUserGuideProgress(user.id);
});
