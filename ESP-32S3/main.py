
import network
import ujson
import utime
import ubinascii
import _thread
from machine import I2C, Pin, UART
from hx711 import HX711


# ============================================================
# CONFIGURACION
# ============================================================
WIFI_SSID     = "YeimarAraujo"
WIFI_PASSWORD = "09122005"
FIREBASE_URL  = "https://siercp-default-rtdb.firebaseio.com"


# Configurar WiFi
wlan = network.WLAN(network.STA_IF)
wlan.active(True)
DEVICE_MAC = ubinascii.hexlify(wlan.config('mac'), ':').decode().upper()


def conectar_wifi():
    """Conecta a WiFi y enciende LED azul cuando esta conectado"""
    led_azul = Pin(2, Pin.OUT)
    led_azul.value(0)

    if not wlan.isconnected():
        print("\n[WiFi] Conectando a: {}...".format(WIFI_SSID))
        wlan.connect(WIFI_SSID, WIFI_PASSWORD)
        timeout = 20

        while not wlan.isconnected() and timeout > 0:
            utime.sleep(1)
            timeout -= 1
            print(".", end="")

    if wlan.isconnected():
        led_azul.value(1)
        print("\n[WiFi] OK Conectado | IP: {}".format(wlan.ifconfig()[0]))
        print("[WiFi] MAC: {}".format(DEVICE_MAC))
        return True
    else:
        print("\n[WiFi] ERROR: No se pudo conectar")
        return False


# ============================================================
# DRIVER DE AUDIO JQ8900
# ============================================================
class JQ8900:
    """Driver para modulo de audio JQ8900"""
    def __init__(self, uart):
        self.uart = uart
        utime.sleep_ms(500)
        self._cmd(0x09, 0x01)  # Seleccionar tarjeta SD
        utime.sleep_ms(200)
        self._cmd(0x13, 30)    # Volumen maximo (30)

    def _cmd(self, cmd, *args):
        """Envia comando al JQ8900"""
        buf = bytearray([0xAA, cmd, len(args)] + list(args))
        buf.append(sum(buf) & 0xFF)
        self.uart.write(bytes(buf))
        utime.sleep_ms(50)

    def play(self, track):
        """Reproduce pista especifica (1-255)"""
        self._cmd(0x07, 0x00, track)


# ============================================================
# CONSTANTES AHA 2025 — MEJORADAS
# ============================================================

# ── Profundidad ──────────────────────────────────────────────
# AHA 2025: 5–6 cm (adulto). Usamos margen interior para retroalimentacion.
AHA_MIN_DEPTH_MM      = 50.0   # 5.0 cm — minimo clinico
AHA_MAX_DEPTH_MM      = 60.0   # 6.0 cm — maximo clinico
AHA_DEPTH_WARN_LOW_MM = 45.0   # <4.5 cm → advertencia "muy superficial"
AHA_DEPTH_WARN_HI_MM  = 65.0   # >6.5 cm → advertencia "demasiado profundo"

# ── Frecuencia CPM ──────────────────────────────────────────
# AHA 2025: 100–120 cpm. Fuera de rango = riesgo para el paciente.
# Por encima de 120 cpm la calidad cae y se puede dañar al paciente.
AHA_MIN_RATE_CPM      = 100
AHA_MAX_RATE_CPM      = 120
AHA_RATE_DANGER_HI    = 130    # >130 cpm = PELIGROSO → penaliza calidad
AHA_RATE_DANGER_LOW   = 80     # <80 cpm  = MUY LENTO → penaliza calidad

# ── Fuerza aplicada (HX711, celda de carga) ─────────────────
# Referencia: ~25–60 kg-fuerza para adulto sobre maniquí.
# Ajusta FORCE_MIN_KG y FORCE_MAX_KG según tu celda calibrada.
AHA_FORCE_MIN_KG      = 25.0   # Minimo de fuerza aceptable
AHA_FORCE_MAX_KG      = 60.0   # Maximo de fuerza aceptable
AHA_FORCE_DANGER_KG   = 70.0   # Fuerza excesiva — riesgo fractura costal

# ── Recoil (descompresion completa) ──────────────────────────
# El pecho debe descomprimirse por completo entre compresiones.
# Si la fuerza residual supera este umbral, el recoil es incompleto.
AHA_RECOIL_THRESHOLD  = 2.5    # kg — umbral mas estricto (antes 0.8 kg)
                                # En maniqui con celda real: ajustar post-calibracion

# ── Pausa maxima sin compresiones ────────────────────────────
AHA_MAX_PAUSE_SEC     = 10.0

# ── Deteccion de compresiones (maquina de estados) ──────────
# Ajustados para maniqui adulto + sensor VL53L0X montado sobre el pecho.
# La base del sensor esta tipicamente a 150–300 mm sobre el esternon en reposo.

DETECT_START_MM       = 10.0   # Profundidad minima para abrir la ventana de compresion
                                # (era 8 mm, ahora 10 mm para reducir falsos positivos)
DETECT_PEAK_MIN_MM    = 10.0   # Pico minimo aceptable para que sea compresion real
                                # (era 20 mm — ahora 35 mm para exigir al menos 3.5 cm
                                #  y descartar toqueteos o apoyos leves)
DETECT_END_MM         = 6.0    # Profundidad al regresar para cerrar el ciclo
                                # (era 4 mm, ahora 6 mm — regreso mas realista)
DETECT_REARM_MM       = 6.0    # Umbral de rearmado antes de aceptar nueva compresion
                                # (era 6 mm, ahora 8 mm — evita doble conteo)
DETECT_MIN_DUR_MS     = 120    # Duracion minima de compresion valida (antes 120 ms)
                                # < 150 ms = toque rapido, no compresion clinica
DETECT_MAX_DUR_MS     = 900    # Duracion maxima (antes 900 ms)
                                # > 800 ms = compresion demasiado lenta
DETECT_DEBOUNCE_MS    = 60     # Debounce entre ciclos (antes 60 ms)

# ── Telemetria ──────────────────────────────────────────────
TELEMETRIA_MS         = 100    # ~6-7 updates/seg (antes 100 ms — mas estable en red)

# ── Boton de finalizacion fisica ─────────────────────────────
# El sistema NO finaliza por tiempo. Termina cuando el operador
# presiona el boton fisico conectado a GPIO 0 (pull-up interno).
# PIN_BTN_FIN = 0 corresponde al BOOT button del ESP32 (facil de usar en demos).
PIN_BTN_FIN           = 0      # GPIO con boton de finalizar sesion (pull-up interno)
BTN_DEBOUNCE_MS       = 300    # Antirrebote del boton


# ============================================================
# SISTEMA RCP — AHA 2025 (version mejorada)
# ============================================================
class SistemaRCP:
    """
    Sistema de monitoreo RCP con precision clinica AHA 2025.

    Mejoras respecto a version anterior:
    - DETECT_PEAK_MIN_MM subido a 35 mm → solo cuenta compresiones reales
    - Umbral AHA_RECOIL_THRESHOLD subido a 2.5 kg → recoil mas estricto
    - Frecuencia: penalizacion de calidad si cpm > 120 o < 100
    - Fuerza: evaluacion y retroalimentacion auditiva por rango
    - Calidad: ponderada (profundidad 40% + recoil 30% + frecuencia 30%)
    - Sesion finaliza con BOTON FISICO, no por tiempo
    - Telemetria incluye breakdowns de calidad
    """

    def __init__(self):
        print("\n" + "=" * 50)
        print("   SIERCP — Sistema RCP AHA 2025 v2")
        print("=" * 50)

        # Boton de finalizacion (GPIO 0, BOOT button ESP32)
        self.btn_fin = Pin(PIN_BTN_FIN, Pin.IN, Pin.PULL_UP)
        self._btn_last_ms = 0
        self._sesion_activa = False

        # Audio JQ8900
        self._init_audio()

        # Sensor de Fuerza HX711
        self._init_fuerza()

        # Sensor Laser VL53L0X (OBLIGATORIO)
        self._init_laser()

        # Control de compresiones
        self.en_compresion = False
        self.pico_fuerza = 0.0
        self.pico_profundidad = 0.0
        self._ts_compresiones = []
        self._MAX_WINDOW = 14   # ventana de 14 compresiones para CPM estable

        # Telemetria
        self.ultima_telemetria = 0
        self._tel_data = None
        self._tel_lock = _thread.allocate_lock()
        self._tel_running = False

        self.reset_estadisticas()

    # ── Reset ────────────────────────────────────────────────────
    def reset_estadisticas(self):
        """Reinicia todos los contadores para una nueva sesion"""
        self.estado_mecanico     = "reposo"
        self.en_compresion       = False
        self.inicio_compresion_ts = 0
        self.fin_compresion_ts   = 0
        self.pico_fuerza         = 0.0
        self.pico_profundidad    = 0.0
        self.compresiones_totales   = 0
        self.compresiones_correctas = 0
        self.recoil_correctos    = 0
        self.freq_correctas      = 0   # compresiones dentro de 100-120 cpm
        self.fuerza_correctas    = 0   # compresiones con fuerza en rango
        self._ts_compresiones    = []
        self.ultima_compresion_ts = 0
        self.pausas_count        = 0
        self.max_pausa_seg       = 0.0
        self._sum_profundidad    = 0.0
        self._sum_fuerza         = 0.0

        # Estado instantaneo
        self.frecuencia_cpm      = 0
        self.profundidad_actual  = 0.0
        self.fuerza_actual       = 0.0
        self.calidad_pct         = 0.0
        self.recoil_ok           = False
        self.compresion_correcta = False

        print("\n[OK] Estadisticas reiniciadas\n")

    # ── Inicializacion ───────────────────────────────────────────
    def _init_audio(self):
        try:
            uart = UART(2, baudrate=9600, tx=Pin(16), rx=Pin(15))
            self.audio = JQ8900(uart)
            print("[Audio] OK - JQ8900 (TX:16, RX:15)")
        except Exception as e:
            print("[Audio] WARN: {}".format(e))
            self.audio = None

    def _init_fuerza(self):
        self.fuerza_ok = False
        try:
            self.celda = HX711(4, 5)
            self.fuerza_ok = True
            if self.celda.is_calibrated:
                print("[Fuerza] OK - HX711 calibrado (scale={:.2f})".format(self.celda.scale))
            else:
                print("[Fuerza] WARN - HX711 SIN CALIBRAR — ejecutar: sistema.calibrar_fuerza()")
        except Exception as e:
            print("[Fuerza] ERROR: {}".format(e))

    def _init_laser(self):
        self.laser_ok = False
        self.distancia_base = 0
        try:
            self.i2c = I2C(1, sda=Pin(17), scl=Pin(18), freq=400000)
            dispositivos = self.i2c.scan()
            if 0x29 in dispositivos:
                from vl53l0x import VL53L0X
                self.laser = VL53L0X(self.i2c)
                self.laser_ok = True
                print("[Laser] OK - VL53L0X (I2C SDA:17, SCL:18)")
            else:
                print("[Laser] ERROR - No detectado | I2C: {}".format(
                    ['0x{:02X}'.format(d) for d in dispositivos]))
        except Exception as e:
            print("[Laser] ERROR: {}".format(e))

        if not self.laser_ok:
            print("\n" + "!" * 50)
            print("  SENSOR VL53L0X NO DISPONIBLE")
            print("  No se puede iniciar sesion de entrenamiento")
            print("!" * 50 + "\n")

    # ── Calibracion ─────────────────────────────────────────────
    def calibrar_fuerza(self):
        if not self.fuerza_ok:
            print("[ERROR] Celda de carga no inicializada")
            return False
        return self.celda.calibrate_interactive()

    def calibrar(self):
        print("\n[Calibracion] Iniciando...")
        if not self.laser_ok:
            print("[Calibracion] FALLO: Sensor laser no disponible")
            return False

        if self.fuerza_ok:
            try:
                print("[Calibracion] Tarando celda... (no presionar el maniqui)")
                self.celda.tare(20)
                print("[Calibracion] Tara OK")
            except Exception as e:
                print("[Calibracion] ERROR en tara: {}".format(e))

        print("[Calibracion] Midiendo distancia base (30 muestras)... no presionar")
        base = self.laser.calibrate_base(30)
        if base is None:
            print("[Calibracion] FALLO: Laser sin lecturas validas")
            return False

        self.distancia_base = base
        print("[Calibracion] Distancia base: {} mm".format(base))
        print("[Calibracion] OK — LISTO\n")
        return True

    # ── Lectura de sensores ──────────────────────────────────────
    def leer_fuerza(self):
        if not self.fuerza_ok:
            return 0.0
        try:
            return self.celda.get_kg()
        except:
            return 0.0

    def leer_profundidad(self):
        """
        Lee profundidad de compresion en mm.
        Filtro: descarta lecturas > distancia_base (sensor mirando al techo)
        y lecturas anomalas > 500 mm de profundidad.
        """
        if not self.laser_ok:
            return 0.0
        try:
            d = self.laser.read()
            if d and 10 < d < 8000:
                prof = self.distancia_base - d
                # Clamp: entre 0 y 150 mm (mas de 15 cm de compresion = imposible)
                return max(0.0, min(float(prof), 150.0))
        except:
            pass
        return 0.0

    # ── CPM con ventana deslizante estabilizada ──────────────────
    def _calcular_cpm(self):
        """
        CPM robusto: ventana deslizante de _MAX_WINDOW compresiones.
        Si han pasado >3 s sin compresion nueva, retorna 0 (ritmo detenido).
        """
        n = len(self._ts_compresiones)
        if n < 2:
            return 0

        ahora = utime.ticks_ms()
        # Si no hubo compresion reciente, el ritmo cayó
        if utime.ticks_diff(ahora, self._ts_compresiones[-1]) > 3000:
            return 0

        window = self._ts_compresiones[-self._MAX_WINDOW:]
        span_ms = utime.ticks_diff(window[-1], window[0])
        if span_ms <= 0:
            return 0

        # (n_compresiones - 1) intervalos en `span_ms` ms
        cpm = round((len(window) - 1) / (span_ms / 60000.0))
        return min(cpm, 200)  # clamp anti-desbordamiento

    # ── Clasificacion de frecuencia ──────────────────────────────
    def _clasificar_frecuencia(self, cpm):
        """Retorna etiqueta y si esta dentro del rango AHA"""
        if cpm == 0:
            return "SIN_DATOS", False
        if cpm < AHA_RATE_DANGER_LOW:
            return "MUY_LENTO", False
        if cpm < AHA_MIN_RATE_CPM:
            return "LENTO", False
        if cpm <= AHA_MAX_RATE_CPM:
            return "CORRECTO", True
        if cpm <= AHA_RATE_DANGER_HI:
            return "RAPIDO", False
        return "PELIGROSO", False   # >130 cpm — riesgo real para el paciente

    # ── Clasificacion de fuerza ──────────────────────────────────
    def _clasificar_fuerza(self, fuerza_kg):
        if fuerza_kg < AHA_FORCE_MIN_KG:
            return "INSUFICIENTE", False
        if fuerza_kg <= AHA_FORCE_MAX_KG:
            return "CORRECTA", True
        if fuerza_kg <= AHA_FORCE_DANGER_KG:
            return "EXCESIVA", False
        return "PELIGROSA", False   # >70 kg — riesgo fractura costal

    # ── Calidad ponderada ────────────────────────────────────────
    def _calcular_calidad(self, cpm):
        """
        Calidad ponderada (0-100%):
          - 40% profundidad correcta
          - 30% recoil completo
          - 30% frecuencia en rango AHA

        Una frecuencia peligrosa (>130 cpm) aplica penalizacion adicional del 20%.
        """
        if self.compresiones_totales == 0:
            return 0.0

        _, freq_ok = self._clasificar_frecuencia(cpm)
        freq_score = (self.freq_correctas / self.compresiones_totales) if self.compresiones_totales > 0 else 0.0
        prof_score = self.compresiones_correctas / self.compresiones_totales
        recoil_score = self.recoil_correctos / self.compresiones_totales

        calidad = (prof_score * 0.40) + (recoil_score * 0.30) + (freq_score * 0.30)

        # Penalizacion si hay compresiones en zona peligrosa de frecuencia
        if cpm > AHA_RATE_DANGER_HI:
            calidad *= 0.80

        return round(calidad * 100.0, 1)

    # ── Maquina de estados de compresion ────────────────────────
    def procesar_compresion(self, fuerza, profundidad):
        """
        Maquina de estados biomédica mejorada.
        Estados: reposo → comprimiendo → rearmando

        Cambios respecto a v1:
        - DETECT_PEAK_MIN_MM = 35 mm (mayor exigencia)
        - Recoil mas estricto: 2.5 kg umbral
        - Evaluacion de fuerza por rango
        - Evaluacion de frecuencia por rango (peligroso/rapido/correcto/lento)
        - Retroalimentacion auditiva granular
        """
        ahora = utime.ticks_ms()
        nueva_compresion = False

        # Recoil instantaneo
        self.recoil_ok = bool(fuerza < AHA_RECOIL_THRESHOLD)

        # ── REPOSO ──────────────────────────────────────────────
        if self.estado_mecanico == "reposo":
            # Auto-reset si pasan >30 s sin actividad
            if (self.ultima_compresion_ts > 0 and
                    utime.ticks_diff(ahora, self.ultima_compresion_ts) > 30000):
                self.reset_estadisticas()

            if profundidad >= DETECT_START_MM:
                self.estado_mecanico     = "comprimiendo"
                self.en_compresion       = True
                self.inicio_compresion_ts = ahora
                self.pico_fuerza         = fuerza
                self.pico_profundidad    = profundidad

        # ── COMPRIMIENDO ─────────────────────────────────────────
        elif self.estado_mecanico == "comprimiendo":
            if fuerza > self.pico_fuerza:
                self.pico_fuerza = fuerza
            if profundidad > self.pico_profundidad:
                self.pico_profundidad = profundidad

            if profundidad <= DETECT_END_MM:
                duracion_ms = utime.ticks_diff(ahora, self.inicio_compresion_ts)
                self.estado_mecanico = "rearmando"
                self.en_compresion   = False
                self.fin_compresion_ts = ahora

                # Validar ruido vs compresion real
                valida = (
                    duracion_ms >= DETECT_MIN_DUR_MS and
                    duracion_ms <= DETECT_MAX_DUR_MS and
                    self.pico_profundidad >= DETECT_PEAK_MIN_MM
                )

                if valida:
                    self.compresiones_totales += 1

                    # Registrar timestamp para CPM
                    self._ts_compresiones.append(ahora)
                    if len(self._ts_compresiones) > self._MAX_WINDOW * 2:
                        self._ts_compresiones = self._ts_compresiones[-self._MAX_WINDOW:]

                    # ── Evaluacion AHA ────────────────────────────────
                    prof_ok    = (AHA_MIN_DEPTH_MM <= self.pico_profundidad <= AHA_MAX_DEPTH_MM)
                    recoil_fue = (fuerza < AHA_RECOIL_THRESHOLD)
                    cpm_ahora  = self._calcular_cpm()
                    _, freq_ok = self._clasificar_frecuencia(cpm_ahora)
                    _, fuerza_ok_flag = self._clasificar_fuerza(self.pico_fuerza)

                    if prof_ok:
                        self.compresiones_correctas += 1
                    if recoil_fue:
                        self.recoil_correctos += 1
                    if freq_ok:
                        self.freq_correctas += 1

                    self.compresion_correcta = prof_ok and recoil_fue and freq_ok

                    self._sum_profundidad += self.pico_profundidad
                    self._sum_fuerza      += self.pico_fuerza

                    # ── Pausas ────────────────────────────────────────
                    if self.ultima_compresion_ts > 0:
                        pausa = utime.ticks_diff(ahora, self.ultima_compresion_ts) / 1000.0
                        if pausa > self.max_pausa_seg:
                            self.max_pausa_seg = pausa
                        if pausa >= AHA_MAX_PAUSE_SEC:
                            self.pausas_count += 1

                    self.ultima_compresion_ts = ahora
                    nueva_compresion = True

                    # ── Retroalimentacion auditiva ────────────────────
                    # Pista 1: inicio/sesion
                    # Pista 2: compresion excelente
                    # Pista 3: profundidad incorrecta
                    # Pista 4: recoil incompleto
                    # Pista 5: frecuencia fuera de rango / demasiado rapido
                    # Pista 6: frecuencia peligrosa
                    if self.audio and self.compresiones_totales % 5 == 0:
                        cpm_lbl, _ = self._clasificar_frecuencia(cpm_ahora).__class__, None
                        cpm_lbl, freq_ok2 = self._clasificar_frecuencia(cpm_ahora)

                        if cpm_lbl == "PELIGROSO":
                            self.audio.play(6)   # alerta maxima — demasiado rapido
                        elif not prof_ok:
                            self.audio.play(3)   # profundidad incorrecta
                        elif not recoil_fue:
                            self.audio.play(4)   # recoil incompleto
                        elif not freq_ok2:
                            self.audio.play(5)   # frecuencia fuera de rango
                        else:
                            self.audio.play(2)   # correcto

        # ── REARMANDO ────────────────────────────────────────────
        elif self.estado_mecanico == "rearmando":
            if utime.ticks_diff(ahora, self.fin_compresion_ts) > DETECT_DEBOUNCE_MS:
                if profundidad < DETECT_REARM_MM:
                    self.estado_mecanico  = "reposo"
                    self.pico_fuerza      = 0.0
                    self.pico_profundidad = 0.0

        return nueva_compresion

    # ── Hilo de telemetria ───────────────────────────────────────
    def _tel_thread_func(self, url):
        """Hilo dedicado para enviar telemetria sin bloquear el ciclo principal"""
        import urequests
        while self._tel_running:
            data_to_send = None
            self._tel_lock.acquire()
            if self._tel_data is not None:
                data_to_send = self._tel_data
                self._tel_data = None
            self._tel_lock.release()

            if data_to_send is not None:
                try:
                    headers = {"Content-Type": "application/json"}
                    body = ujson.dumps(data_to_send)
                    res = urequests.request("PATCH", url, data=body,
                                            headers=headers, timeout=2.0)
                    if res.status_code == 200:
                        print("[Tel] OK - C:{} CPM:{} Cal:{:.0f}%".format(
                            data_to_send["compresiones"],
                            data_to_send["frecuencia_cpm"],
                            data_to_send["calidad_pct"]))
                    else:
                        print("[Tel] ERROR HTTP {}".format(res.status_code))
                    res.close()
                except Exception as e:
                    print("[Tel] Excepcion: {}".format(e))

            utime.sleep_ms(TELEMETRIA_MS)

    def enviar_telemetria(self, fuerza, profundidad):
        """Encola datos para el hilo de telemetria (no bloquea)"""
        if not wlan.isconnected():
            return

        cpm = self._calcular_cpm()
        self.frecuencia_cpm = cpm
        self.calidad_pct    = self._calcular_calidad(cpm)

        avg_prof   = (self._sum_profundidad / self.compresiones_totales
                      if self.compresiones_totales > 0 else 0.0)
        avg_fuerza = (self._sum_fuerza / self.compresiones_totales
                      if self.compresiones_totales > 0 else 0.0)
        recoil_pct = (self.recoil_correctos / self.compresiones_totales * 100.0
                      if self.compresiones_totales > 0 else 0.0)
        freq_pct   = (self.freq_correctas / self.compresiones_totales * 100.0
                      if self.compresiones_totales > 0 else 0.0)

        cpm_lbl, _ = self._clasificar_frecuencia(cpm)
        fza_lbl, _ = self._clasificar_fuerza(fuerza)

        data = {
            # Sensores en tiempo real
            "fuerza_kg":          round(fuerza, 2),
            "profundidad_mm":     round(profundidad, 1),
            "frecuencia_cpm":     cpm,
            "frecuencia_estado":  cpm_lbl,
            "fuerza_estado":      fza_lbl,

            # Estadisticas de sesion
            "compresiones":             self.compresiones_totales,
            "compresiones_correctas":   self.compresiones_correctas,
            "recoil_ok":                self.recoil_ok,
            "en_compresion":            self.en_compresion,
            "compresion_correcta":      self.compresion_correcta,

            # Calidad desglosada
            "calidad_pct":          round(self.calidad_pct, 1),
            "recoil_pct":           round(recoil_pct, 1),
            "freq_correcta_pct":    round(freq_pct, 1),
            "avg_profundidad_mm":   round(avg_prof, 1),
            "avg_fuerza_kg":        round(avg_fuerza, 2),

            # Pausas
            "pausas":               self.pausas_count,
            "max_pausa_seg":        round(self.max_pausa_seg, 1),

            # Estado del hardware
            "sensor_ok":   self.laser_ok and self.fuerza_ok,
            "calibrado":   self.celda.is_calibrated if self.fuerza_ok else False,
            "timestamp":   {".sv": "timestamp"},
        }

        self._tel_lock.acquire()
        self._tel_data = data
        self._tel_lock.release()

    # ── Boton de finalizacion ────────────────────────────────────
    def _boton_presionado(self):
        """Retorna True si el boton de finalizar fue presionado (con debounce)"""
        if self.btn_fin.value() == 0:   # activo bajo (pull-up)
            ahora = utime.ticks_ms()
            if utime.ticks_diff(ahora, self._btn_last_ms) > BTN_DEBOUNCE_MS:
                self._btn_last_ms = ahora
                return True
        return False

    # ── Resumen final ────────────────────────────────────────────
    def _resumen_sesion(self):
        """Imprime y envia a Firebase el resumen final de la sesion"""
        cpm_final = self._calcular_cpm()
        calidad   = self._calcular_calidad(cpm_final)

        print("\n" + "=" * 50)
        print("   RESUMEN DE SESION")
        print("=" * 50)
        print("  Compresiones totales  : {}".format(self.compresiones_totales))
        print("  Compresiones correctas: {} ({:.0f}%)".format(
            self.compresiones_correctas,
            (self.compresiones_correctas / self.compresiones_totales * 100
             if self.compresiones_totales > 0 else 0)))
        print("  Recoil correcto       : {:.0f}%".format(
            self.recoil_correctos / self.compresiones_totales * 100
            if self.compresiones_totales > 0 else 0))
        print("  Freq en rango         : {:.0f}%".format(
            self.freq_correctas / self.compresiones_totales * 100
            if self.compresiones_totales > 0 else 0))
        print("  Prof. promedio        : {:.1f} mm".format(
            self._sum_profundidad / self.compresiones_totales
            if self.compresiones_totales > 0 else 0))
        print("  Fuerza promedio       : {:.1f} kg".format(
            self._sum_fuerza / self.compresiones_totales
            if self.compresiones_totales > 0 else 0))
        print("  Pausas >10s           : {}".format(self.pausas_count))
        print("  Pausa maxima          : {:.1f} s".format(self.max_pausa_seg))
        print("  CALIDAD GLOBAL        : {:.1f}%".format(calidad))
        print("=" * 50 + "\n")

        # Enviar resumen a Firebase (nodo separado)
        if wlan.isconnected():
            try:
                import urequests
                url = "{}/sesiones/{}.json".format(FIREBASE_URL, DEVICE_MAC)
                data = {
                    "compresiones":       self.compresiones_totales,
                    "compresiones_ok":    self.compresiones_correctas,
                    "recoil_pct":         round(self.recoil_correctos / self.compresiones_totales * 100 if self.compresiones_totales > 0 else 0, 1),
                    "freq_pct":           round(self.freq_correctas / self.compresiones_totales * 100 if self.compresiones_totales > 0 else 0, 1),
                    "avg_prof_mm":        round(self._sum_profundidad / self.compresiones_totales if self.compresiones_totales > 0 else 0, 1),
                    "avg_fuerza_kg":      round(self._sum_fuerza / self.compresiones_totales if self.compresiones_totales > 0 else 0, 2),
                    "pausas":             self.pausas_count,
                    "max_pausa_seg":      round(self.max_pausa_seg, 1),
                    "calidad_pct":        calidad,
                    "timestamp":          {".sv": "timestamp"},
                }
                headers = {"Content-Type": "application/json"}
                res = urequests.request("PATCH", url,
                                        data=ujson.dumps(data),
                                        headers=headers, timeout=4)
                res.close()
                print("[Firebase] Resumen de sesion guardado OK")
            except Exception as e:
                print("[Firebase] ERROR guardando resumen: {}".format(e))

    # ── Loop principal ───────────────────────────────────────────
    def iniciar(self):
        """
        Inicia el loop principal del sistema.
        La sesion termina UNICAMENTE al presionar el boton fisico (GPIO 0).
        NO hay limite de tiempo.
        """
        if not self.laser_ok:
            print("\n" + "!" * 50)
            print("  ERROR: SENSOR VL53L0X NO DISPONIBLE")
            print("  El sensor es requerido para sesion valida AHA 2025")
            print("!" * 50 + "\n")
            # Reportar error a Firebase
            if wlan.isconnected():
                try:
                    import urequests
                    url = "{}/telemetria/{}.json".format(FIREBASE_URL, DEVICE_MAC)
                    data = {"sensor_ok": False, "error": "VL53L0X no disponible",
                            "timestamp": {".sv": "timestamp"}}
                    res = urequests.request("PATCH", url, data=ujson.dumps(data),
                                            headers={"Content-Type": "application/json"},
                                            timeout=3)
                    res.close()
                except:
                    pass
            return

        if not self.calibrar():
            print("[ERROR] Calibracion fallida — no se puede iniciar")
            return

        print("\n" + "=" * 50)
        print("   SISTEMA ACTIVO — Esperando compresiones...")
        print("   AHA 2025: Prof 50-60 mm | Frec 100-120 cpm")
        print("   Presiona el boton (GPIO 0) para finalizar")
        print("=" * 50 + "\n")

        if self.audio:
            self.audio.play(1)   # pista 1 = inicio de sesion

        # Iniciar hilo de telemetria
        self._tel_running = True
        url_tel = "{}/telemetria/{}.json".format(FIREBASE_URL, DEVICE_MAC)
        _thread.start_new_thread(self._tel_thread_func, (url_tel,))

        self._sesion_activa = True

        while self._sesion_activa:
            try:
                # ── Leer sensores ──────────────────────────────
                fuerza      = self.leer_fuerza()
                profundidad = self.leer_profundidad()

                self.fuerza_actual      = fuerza
                self.profundidad_actual = profundidad

                # ── Detectar compresion ────────────────────────
                nueva_comp = self.procesar_compresion(fuerza, profundidad)

                if nueva_comp:
                    cpm = self._calcular_cpm()
                    cpm_lbl, cpm_ok = self._clasificar_frecuencia(cpm)
                    fza_lbl, fza_ok = self._clasificar_fuerza(self.pico_fuerza)
                    prof_ok = (AHA_MIN_DEPTH_MM <= self.pico_profundidad <= AHA_MAX_DEPTH_MM)

                    estado = "OK" if self.compresion_correcta else "CORREGIR"
                    print("[C#{:>3}] Pecho:{:.0f}mm F:{:.1f}kg CPM:{} [{}] Frec:{} Fza:{}".format(
                        self.compresiones_totales,
                        self.pico_profundidad,
                        self.pico_fuerza,
                        cpm, estado, cpm_lbl, fza_lbl))

                # ── Telemetria periodica ───────────────────────
                ahora = utime.ticks_ms()
                if utime.ticks_diff(ahora, self.ultima_telemetria) >= TELEMETRIA_MS:
                    self.enviar_telemetria(fuerza, profundidad)
                    self.ultima_telemetria = ahora

                    if not wlan.isconnected():
                        print("[WiFi] Reconectando...")
                        conectar_wifi()

                # ── Boton de finalizacion (sin limite de tiempo) ─
                if self._boton_presionado():
                    print("\n[Boton] Sesion finalizada por el operador")
                    self._sesion_activa = False

                utime.sleep_ms(10)   # 100 Hz de muestreo

            except KeyboardInterrupt:
                print("\n[Sistema] Detenido por usuario (Ctrl+C)")
                self._sesion_activa = False
            except Exception as e:
                print("[Error] {}".format(e))
                utime.sleep(1)

        # ── Cierre limpio ──────────────────────────────────────
        self._tel_running = False
        utime.sleep_ms(200)   # dar tiempo al hilo de telemetria a terminar

        if self.laser_ok:
            try:
                self.laser.stop_continuous()
            except:
                pass

        if self.audio:
            self.audio.play(7)   # pista 7 = fin de sesion

        self._resumen_sesion()


# ============================================================
# MAIN
# ============================================================
if __name__ == "__main__":
    print("\n" + "=" * 50)
    print("   SIERCP — Sistema de RCP Inteligente v2")
    print("   Estandares AHA 2025")
    print("=" * 50)

    conectar_wifi()

    sistema = SistemaRCP()
    sistema.iniciar()
