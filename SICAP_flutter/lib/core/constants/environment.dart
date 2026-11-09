class Environment {
  static const String rtdbUrl = String.fromEnvironment('RTDB_URL');

  static bool get isConfigured => rtdbUrl.isNotEmpty;

  static void validate() {
    if (rtdbUrl.isEmpty) {
      throw Exception(
        'CRITICAL: La variable de entorno RTDB_URL no ha sido configurada. '
        'Asegúrate de compilar con --dart-define=RTDB_URL=tu_url_aqui'
      );
    }
  }
}
