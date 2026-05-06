import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/theme.dart';
import '../models/maniqui.dart';
import '../widgets/section_label.dart';

// Stream en tiempo real para escuchar dispositivos conectados (latidos/pings)
final rtdbDevicesProvider = StreamProvider<List<ManiquiModel>>((ref) {
  return FirebaseDatabase.instance.ref('devices').onValue.map((event) {
    if (event.snapshot.value == null) return [];
    
    final data = Map<String, dynamic>.from(event.snapshot.value as Map);
    return data.entries.map((e) {
      final val = Map<String, dynamic>.from(e.value as Map);
      final lastMs = val['last_seen'] as int?;
      
      DateTime? lastConnection;
      if (lastMs != null) {
        lastConnection = DateTime.fromMillisecondsSinceEpoch(lastMs);
      }
      
      bool isOnline = false;
      if (lastConnection != null) {
        isOnline = DateTime.now().difference(lastConnection).inSeconds < 20;
      }
      
      return ManiquiModel(
        id: e.key,
        name: val['name']?.toString() ?? 'SIERCP ESP32',
        uuid: e.key,
        status: isOnline ? 'Conectado' : 'Desconectado',
        lastConnection: lastConnection,
      );
    }).toList();
  });
});

class DeviceStatusScreen extends ConsumerWidget {
  const DeviceStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maniquisAsync = ref.watch(rtdbDevicesProvider);
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    final cardBg = theme.colorScheme.surface;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final border = theme.dividerTheme.color ?? AppColors.cardBorder;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Estado de Maniquíes', 
          style: TextStyle(color: textP, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textP, size: 20),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(rtdbDevicesProvider),
        color: AppColors.brand,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const SectionLabel('Dispositivos Conectados'),
              const SizedBox(height: 20),
              Expanded(
                child: maniquisAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
                  error: (e, st) => Center(child: Text('Error al cargar datos:\n$e', style: TextStyle(color: AppColors.red))),
                  data: (maniquis) {
                    if (maniquis.isEmpty) {
                      return const Center(child: Text('Ningún maniquí registrado.', style: TextStyle(color: AppColors.textSecondary)));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: maniquis.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final m = maniquis[index];
                        final isOnline = m.status.toLowerCase() == 'disponible' || m.status.toLowerCase() == 'conectado';
                        final statColor = isOnline ? AppColors.green : AppColors.brand;
                        
                        String lastSeen = 'Recientemente';
                        if (m.lastConnection != null) {
                          final diff = DateTime.now().difference(m.lastConnection!);
                          if (diff.inSeconds < 20) {
                            lastSeen = 'Ahorita (En vivo)';
                          } else if (diff.inMinutes < 60) {
                            lastSeen = 'Hace ${diff.inMinutes} min';
                          } else {
                            lastSeen = 'Hace ${diff.inHours} horas';
                          }
                        }

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            border: Border.all(color: border, width: 0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.bluetooth_connected, color: statColor, size: 28),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.name, style: TextStyle(color: textP, fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(m.uuid, style: TextStyle(color: textS, fontSize: 10, fontFamily: 'SpaceMono')),
                                    const SizedBox(height: 2),
                                    Text('Visto: $lastSeen', style: TextStyle(color: textS, fontSize: 10)),
                                  ],
                                ),
                              ),
                              Text(m.status.toUpperCase(), style: TextStyle(color: statColor, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

