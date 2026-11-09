import 'dart:io';

import 'package:flutter/services.dart';

/// Abre SICAP VR (la app del simulador para gafas) y mantiene viva la sesión
/// mientras SICAP VR ocupa la pantalla. Solo Android.
class VrLauncher {
  static const _channel = MethodChannel('sicap/vr');

  /// Paquete de SICAP VR, el mismo que declara Unity al compilar.
  static const vrPackage = 'com.sicap.vr';

  static Future<bool> isInstalled() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isInstalled') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> launch() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('launch') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Servicio visible que evita que Android congele la app en segundo plano.
  static Future<void> keepAlive(bool on) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('keepAlive', {'on': on});
    } on PlatformException {
      // Sin el servicio la sesión puede pausarse, pero no se pierde.
    }
  }
}
