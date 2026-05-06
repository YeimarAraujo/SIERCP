import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/features/guides/data/models/guide.dart';
import 'package:siercp/features/guides/data/guide_service.dart';
import 'package:siercp/features/devices/data/device_service.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/devices/data/ble_service.dart';

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

final deviceConnectionProvider = Provider<DeviceStatus>((ref) {
  final ble = ref.watch(bleServiceProvider);
  return DeviceStatus(
    isConnected: ble.isConnected,
    macAddress: ble.connectedDevice?.remoteId.str,
  );
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
