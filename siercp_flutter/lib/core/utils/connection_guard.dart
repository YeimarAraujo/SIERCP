import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/features/devices/data/ble_service.dart';
import 'package:siercp/core/theme/theme.dart';

class ConnectionGuard {
  static bool checkConnection(BuildContext context, WidgetRef ref) {
    final bleService = ref.read(bleServiceProvider);
    
    if (!bleService.isConnected) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: const Row(
            children: [
              Icon(Icons.bluetooth_disabled_rounded, color: AppColors.red),
              SizedBox(width: 10),
              Text('Maniquí desconectado'),
            ],
          ),
          content: const Text(
            'Para iniciar una sesión de práctica, es necesario que el maniquí esté conectado vía Bluetooth.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/session/device-select');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
              ),
              child: const Text('Conectar ahora'),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }
}
