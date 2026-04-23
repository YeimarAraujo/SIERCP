// ─── BLE Service (LEGACY) ──────────────────────────────────────────────────────
// Este servicio ya NO se utiliza.
// La telemetría del maniquí ESP32 se recibe directamente desde Firebase
// Realtime Database a través de DeviceService.
// Se mantiene este archivo solo como referencia histórica.
//
// El ESP32 envía datos WiFi → Firebase RTDB → DeviceService → SessionProvider
// NO se requiere conexión Bluetooth entre el teléfono y el maniquí.
