import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:siercp/features/session/presentation/providers/ble_session_provider.dart';
import 'package:siercp/features/guides/presentation/providers/guide_provider.dart';
import 'package:siercp/features/devices/data/ble_service.dart';
import 'package:siercp/core/theme/theme.dart';

class DeviceSelectionScreen extends ConsumerStatefulWidget {
  const DeviceSelectionScreen({super.key});

  @override
  ConsumerState<DeviceSelectionScreen> createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends ConsumerState<DeviceSelectionScreen> {
  bool _isScanning = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _checkLocationAndScan();
  }

  Future<void> _checkLocationAndScan() async {
    // Solicitar permisos silenciosamente al entrar a la pantalla.
    // El sistema operativo mostrará el diálogo de permisos solo si es la
    // primera vez; en siguientes ejecuciones simplemente usará el estado guardado.
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    }
    _startScan();
  }

  Future<void> _startScan() async {
    if (!mounted) return;
    setState(() => _isScanning = true);

    try {
      // Encender Bluetooth si está apagado (Android)
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState == BluetoothAdapterState.off) {
        await FlutterBluePlus.turnOn();
        // Esperar breve momento para que el adaptador encienda
        await Future.delayed(const Duration(milliseconds: 500));
      }

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withServices: [Guid("12345678-1234-5678-1234-56789abcdef0")],
        androidUsesFineLocation: false,
      );
    } catch (_) {
      // Fallo silencioso — la pantalla mostrará el estado vacío de escaneo
      // y el usuario puede reintentar con el botón de refrescar.
    }

    if (mounted) setState(() => _isScanning = false);
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _isConnecting = true);
    final bleService = ref.read(bleServiceProvider);
    
    // Detenemos el escaneo antes de conectar
    await FlutterBluePlus.stopScan();
    
    try {
      await bleService.connectToDevice(device);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maniquí conectado exitosamente'), backgroundColor: AppColors.green),
        );
        context.pop(); // Volvemos a la pantalla anterior
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al conectar: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Escáner Bluetooth SIERCP'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isScanning 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand))
                : const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _startScan,
          )
        ],
      ),
      body: _isConnecting 
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.brand),
                SizedBox(height: 16),
                Text("Estableciendo conexión BLE de baja latencia...", style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600))
              ],
            ),
          )
        : Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bluetooth_searching_rounded, size: 24, color: AppColors.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Buscando maniquíes cercanos. Asegúrate de que el ESP32 esté encendido y cerca de tu dispositivo.',
                    style: TextStyle(color: textP, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: FlutterBluePlus.scanResults,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error de escaneo: ${snapshot.error}', style: const TextStyle(color: AppColors.red)));
                }

                final results = snapshot.data ?? [];
                
                if (results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bluetooth_disabled_rounded, size: 64, color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('No se encontraron dispositivos', style: TextStyle(color: textS, fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final r = results[index];
                    final device = r.device;
                    final name = device.platformName.isNotEmpty ? device.platformName : 'Dispositivo Desconocido';
                    
                    // Filtrar dispositivos sin nombre para limpiar la UI (opcional)
                    // if (name == 'Dispositivo Desconocido') return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                          child: const Icon(Icons.bluetooth, color: AppColors.brand),
                        ),
                        title: Text(name, style: TextStyle(color: textP, fontWeight: FontWeight.bold)),
                        subtitle: Text('${device.remoteId.str} • RSSI: ${r.rssi} dBm', style: TextStyle(color: textS, fontSize: 11)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () => _connectToDevice(device),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: const Size(0, 32),
                              ),
                              child: const Text('Conectar', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Botón de Simulación
          Padding(
            padding: const EdgeInsets.all(20),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.science_outlined, size: 16),
              label: const Text('Continuar sin maniquí (modo simulación)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                foregroundColor: textS,
                side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
              ),
              onPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }
}
