import network
import ujson
import utime
import ubinascii
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
        timeout = 15

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
# CONSTANTES AHA 2025
# ============================================================
# Profundidad adulto
AHA_MIN_DEPTH_MM     = 50.0   # 5 cm minimo
AHA_MAX_DEPTH_MM     = 60.0   # 6 cm maximo
# Frecuencia
AHA_MIN_RATE_CPM     = 100
AHA_MAX_RATE_CPM     = 120
# Pausa maxima sin compresiones
AHA_MAX_PAUSE_SEC    = 10.0
# Recoil: fuerza residual maxima para considerar descompresion completa
AHA_RECOIL_THRESHOLD = 0.5    # kg
# Umbrales de deteccion de compresion
UMBRAL_INICIO_KG     = 1.5    # kg para iniciar compresion
UMBRAL_FIN_KG        = 0.5    # kg para fin de compresion
# Intervalo de telemetria
TELEMETRIA_MS        = 100    # 10 updates/seg


# ============================================================
# SISTEMA RCP — AHA 2025
# ============================================================
class SistemaRCP:
    """Sistema de monitoreo de RCP con precision clinica AHA 2025"""

    def __init__(self):
        print("\n" + "=" * 50)
        print("   SIERCP — Sistema RCP AHA 2025")
        print("=" * 50)

        # Audio JQ8900
        self._init_audio()

        # Sensor de Fuerza HX711
        self._init_fuerza()

        # Sensor Laser VL53L0X (OBLIGATORIO)
        self._init_laser()

        # Variables de control de compresiones
        self.en_compresion = False
        self.pico_fuerza = 0.0
        self.pico_profundidad = 0.0
        self.compresiones_totales = 0
        self.compresiones_correctas = 0
        self.recoil_correctos = 0

        # Ventana deslizante para CPM (ultimas 10 compresiones)
        self._ts_compresiones = []    # timestamps en ms
        self._MAX_WINDOW = 10

        # Deteccion de pausas
        self.ultima_compresion_ts = 0
        self.pausas_count = 0
        self.max_pausa_seg = 0.0

        # Acumuladores para promedios
        self._sum_profundidad = 0.0
        self._sum_fuerza = 0.0

        # Telemetria
        self.ultima_telemetria = 0

        # Estado actual (se actualiza en cada iteracion)
        self.frecuencia_cpm = 0
        self.profundidad_actual = 0.0
        self.fuerza_actual = 0.0
        self.calidad_pct = 0.0
        self.recoil_ok = False
        self.compresion_correcta = False

        print("\n" + "=" * 50)
        print("   [OK] Sistema inicializado")
        print("=" * 50 + "\n")

    def _init_audio(self):
        """Inicializa modulo de audio"""
        try:
            uart = UART(2, baudrate=9600, tx=Pin(16), rx=Pin(15))
            self.audio = JQ8900(uart)
            print("[Audio] OK - JQ8900 (TX:16, RX:15)")
        except Exception as e:
            print("[Audio] WARN: {}".format(e))
            self.audio = None

    def _init_fuerza(self):
        """Inicializa sensor de fuerza HX711"""
        self.fuerza_ok = False
        try:
            self.celda = HX711(4, 5)  # DT=4, SCK=5
            self.fuerza_ok = True
            if self.celda.is_calibrated:
                print("[Fuerza] OK - HX711 calibrado (scale={:.2f})".format(
                    self.celda.scale))
            else:
                print("[Fuerza] WARN - HX711 SIN CALIBRAR")
                print("         Ejecutar: sistema.calibrar_fuerza()")
        except Exception as e:
            print("[Fuerza] ERROR: {}".format(e))

    def _init_laser(self):
        """Inicializa sensor laser VL53L0X (OBLIGATORIO para sesion)"""
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
                print("[Laser] ERROR - No detectado en I2C")
                print("[Laser] Dispositivos I2C: {}".format(
                    ['0x{:02X}'.format(d) for d in dispositivos]))
        except Exception as e:
            print("[Laser] ERROR: {}".format(e))

        if not self.laser_ok:
            print("\n" + "!" * 50)
            print("  SENSOR VL53L0X NO DISPONIBLE")
            print("  No se puede iniciar sesion de entrenamiento")
            print("  Revisar conexiones I2C del sensor laser")
            print("!" * 50 + "\n")

    def calibrar_fuerza(self):
        """Calibracion interactiva de la celda de carga"""
        if not self.fuerza_ok:
            print("[ERROR] Celda de carga no inicializada")
            return False
        return self.celda.calibrate_interactive()

    def calibrar(self):
        """Calibra todos los sensores antes de iniciar sesion"""
        print("\n[Calibracion] Iniciando...")

        # Verificar sensor laser OBLIGATORIO
        if not self.laser_ok:
            print("[Calibracion] FALLO: Sensor laser no disponible")
            return False

        # Calibrar celda de carga (tara)
        if self.fuerza_ok:
            try:
                print("[Calibracion] Tarando celda... (no presionar)")
                self.celda.tare(20)
            except Exception as e:
                print("[Calibracion] ERROR en tara: {}".format(e))

        # Usaremos el modo single-shot (ping) por defecto para max estabilidad
        pass

        # Calibrar distancia base del laser (30 muestras con IQR)
        print("[Calibracion] Midiendo distancia base... (no presionar)")
        base = self.laser.calibrate_base(30)
        if base is None:
            print("[Calibracion] FALLO: Laser sin lecturas validas")
            return False
        self.distancia_base = base
        print("[Calibracion] Distancia base: {} mm".format(base))

        print("[Calibracion] OK - Completada\n")
        return True

    def leer_fuerza(self):
        """Lee fuerza actual en kg (con filtro EMA)"""
        if not self.fuerza_ok:
            return 0.0
        try:
            return self.celda.get_kg()
        except:
            return 0.0

    def leer_profundidad(self):
        """Lee profundidad de compresion en mm desde laser"""
        if not self.laser_ok:
            return 0.0
        try:
            d = self.laser.read()
            if d and d < 8000:
                prof = self.distancia_base - d
                return max(0.0, float(prof))
        except:
            pass
        return 0.0

    def _calcular_cpm(self):
        """Calcula frecuencia CPM con ventana deslizante"""
        n = len(self._ts_compresiones)
        if n < 2:
            return 0
        # Usar ventana de ultimas _MAX_WINDOW compresiones
        window = self._ts_compresiones[-self._MAX_WINDOW:]
        span = window[-1] - window[0]
        if span <= 0:
            return 0
        return round((len(window) - 1) / (span / 60000.0))

    def _detectar_pausa(self, ahora_ms):
        """Detecta pausas > 10 segundos entre compresiones"""
        if self.ultima_compresion_ts > 0 and self.compresiones_totales > 0:
            pausa_seg = utime.ticks_diff(ahora_ms, self.ultima_compresion_ts) / 1000.0
            if pausa_seg > self.max_pausa_seg:
                self.max_pausa_seg = pausa_seg
            if pausa_seg >= AHA_MAX_PAUSE_SEC:
                # Solo contar una vez por pausa
                return True
        return False

    def procesar_compresion(self, fuerza, profundidad):
        """
        Detecta ciclos de compresion y evalua segun AHA 2025.
        Retorna True si se detecto una nueva compresion completada.
        """
        ahora = utime.ticks_ms()
        nueva_compresion = False

        # Estado actual de recoil
        self.recoil_ok = (not self.en_compresion and
                          fuerza < AHA_RECOIL_THRESHOLD)

        # INICIO de compresion: fuerza supera umbral
        if fuerza >= UMBRAL_INICIO_KG and not self.en_compresion:
            self.en_compresion = True
            self.pico_fuerza = fuerza
            self.pico_profundidad = profundidad

        # DURANTE compresion: rastrear pico
        elif self.en_compresion:
            if fuerza > self.pico_fuerza:
                self.pico_fuerza = fuerza
            if profundidad > self.pico_profundidad:
                self.pico_profundidad = profundidad

        # FIN de compresion: fuerza baja del umbral
        elif fuerza <= UMBRAL_FIN_KG and self.en_compresion:
            self.en_compresion = False
            self.compresiones_totales += 1

            # Evaluar profundidad de ESTA compresion usando el PICO
            prof_ok = (AHA_MIN_DEPTH_MM <= self.pico_profundidad <= AHA_MAX_DEPTH_MM)
            recoil_ok = (fuerza < AHA_RECOIL_THRESHOLD)

            if prof_ok:
                self.compresiones_correctas += 1
            if recoil_ok:
                self.recoil_correctos += 1

            self.compresion_correcta = prof_ok and recoil_ok

            # Acumuladores
            self._sum_profundidad += self.pico_profundidad
            self._sum_fuerza += self.pico_fuerza

            # Timestamp para calculo de CPM
            self._ts_compresiones.append(ahora)
            # Mantener ventana maxima
            if len(self._ts_compresiones) > self._MAX_WINDOW * 2:
                self._ts_compresiones = self._ts_compresiones[-self._MAX_WINDOW:]

            # Detectar pausas
            if self.ultima_compresion_ts > 0:
                pausa = utime.ticks_diff(ahora, self.ultima_compresion_ts) / 1000.0
                if pausa > self.max_pausa_seg:
                    self.max_pausa_seg = pausa
                if pausa >= AHA_MAX_PAUSE_SEC:
                    self.pausas_count += 1

            self.ultima_compresion_ts = ahora
            self.pico_fuerza = 0.0
            self.pico_profundidad = 0.0
            nueva_compresion = True

            # Audio feedback cada 5 compresiones
            if self.audio and self.compresiones_totales % 5 == 0:
                if not prof_ok:
                    self.audio.play(3)  # Pista 3: "Mas profundo"
                elif not recoil_ok:
                    self.audio.play(4)  # Pista 4: "Descomprime"
                else:
                    self.audio.play(2)  # Pista 2: "Bien"

        return nueva_compresion

    def _calcular_calidad(self):
        """Calcula porcentaje de calidad global"""
        if self.compresiones_totales == 0:
            return 0.0
        return (self.compresiones_correctas / self.compresiones_totales) * 100.0

    def enviar_telemetria(self, fuerza, profundidad):
        """
        Envia telemetria completa a Firebase RTDB.
        El ESP32 envia TODOS los datos calculados — Flutter solo muestra.
        """
        if not wlan.isconnected():
            return

        try:
            import urequests

            url = "{}/telemetria/{}.json".format(FIREBASE_URL, DEVICE_MAC)

            # Frecuencia actual
            cpm = self._calcular_cpm()
            self.frecuencia_cpm = cpm

            # Calidad acumulada
            self.calidad_pct = self._calcular_calidad()

            # Promedios
            avg_prof = (self._sum_profundidad / self.compresiones_totales
                        if self.compresiones_totales > 0 else 0.0)
            avg_fuerza = (self._sum_fuerza / self.compresiones_totales
                          if self.compresiones_totales > 0 else 0.0)

            # Recoil porcentaje
            recoil_pct = (self.recoil_correctos / self.compresiones_totales * 100.0
                          if self.compresiones_totales > 0 else 0.0)

            data = {
                # Datos instantaneos
                "fuerza_kg": round(fuerza, 2),
                "profundidad_mm": round(profundidad, 1),
                "frecuencia_cpm": cpm,
                # Contadores
                "compresiones": self.compresiones_totales,
                "compresiones_correctas": self.compresiones_correctas,
                # Estado
                "recoil_ok": self.recoil_ok,
                "en_compresion": self.en_compresion,
                "compresion_correcta": self.compresion_correcta,
                # Metricas acumuladas
                "calidad_pct": round(self.calidad_pct, 1),
                "recoil_pct": round(recoil_pct, 1),
                "avg_profundidad_mm": round(avg_prof, 1),
                "avg_fuerza_kg": round(avg_fuerza, 2),
                "pausas": self.pausas_count,
                "max_pausa_seg": round(self.max_pausa_seg, 1),
                # Sistema
                "sensor_ok": self.laser_ok and self.fuerza_ok,
                "calibrado": self.celda.is_calibrated if self.fuerza_ok else False,
                "timestamp": {".sv": "timestamp"},
            }

            headers = {"Content-Type": "application/json"}
            body = ujson.dumps(data)
            res = urequests.request("PATCH", url, data=body,
                                    headers=headers, timeout=3)

            if res.status_code == 200:
                print("[Tel] F:{:.1f}kg D:{:.0f}mm R:{}cpm C:{} Q:{:.0f}%".format(
                    fuerza, profundidad, cpm,
                    self.compresiones_totales,
                    self.calidad_pct))
            else:
                print("[Tel] ERR {}".format(res.status_code))

            res.close()

        except ImportError:
            print("[Tel] ERROR - urequests no instalado")
        except Exception as e:
            print("[Tel] ERROR: {}".format(e))

    def iniciar(self):
        """Inicia el loop principal del sistema"""

        # VERIFICACION OBLIGATORIA: Sensor laser
        if not self.laser_ok:
            print("\n" + "!" * 50)
            print("  ERROR: SENSOR DE PROFUNDIDAD NO DISPONIBLE")
            print("  El sensor VL53L0X es requerido para")
            print("  entrenamiento valido segun AHA 2025.")
            print("  Revisar conexiones I2C del sensor laser.")
            print("!" * 50 + "\n")

            # Enviar estado de error a Firebase
            if wlan.isconnected():
                try:
                    import urequests
                    url = "{}/telemetria/{}.json".format(FIREBASE_URL, DEVICE_MAC)
                    data = {
                        "sensor_ok": False,
                        "error": "VL53L0X no disponible",
                        "timestamp": {".sv": "timestamp"},
                    }
                    headers = {"Content-Type": "application/json"}
                    body = ujson.dumps(data)
                    res = urequests.request("PATCH", url, data=body,
                                            headers=headers, timeout=3)
                    res.close()
                except:
                    pass
            return  # NO iniciar sesion

        # Calibrar sensores
        if not self.calibrar():
            print("[ERROR] Calibracion fallida - no se puede iniciar")
            return

        print("\n" + "=" * 50)
        print("   SISTEMA ACTIVO — Esperando compresiones...")
        print("   AHA 2025: Prof 50-60mm | Frec 100-120cpm")
        print("=" * 50 + "\n")

        while True:
            try:
                # Leer sensores
                fuerza = self.leer_fuerza()
                profundidad = self.leer_profundidad()

                # Actualizar valores actuales
                self.fuerza_actual = fuerza
                self.profundidad_actual = profundidad

                # Procesar compresion
                nueva_comp = self.procesar_compresion(fuerza, profundidad)

                if nueva_comp:
                    # Evaluar y mostrar
                    prof_ok = AHA_MIN_DEPTH_MM <= profundidad <= AHA_MAX_DEPTH_MM
                    cpm = self._calcular_cpm()
                    rate_ok = AHA_MIN_RATE_CPM <= cpm <= AHA_MAX_RATE_CPM

                    estado = "OK" if (prof_ok and self.recoil_ok) else "CORREGIR"
                    print("[C#{}] F:{:.1f}kg D:{:.0f}mm R:{}cpm [{}]".format(
                        self.compresiones_totales,
                        fuerza, profundidad, cpm, estado))

                # Telemetria cada 200ms
                ahora = utime.ticks_ms()
                if utime.ticks_diff(ahora, self.ultima_telemetria) >= TELEMETRIA_MS:
                    self.enviar_telemetria(fuerza, profundidad)
                    self.ultima_telemetria = ahora

                    # Reconectar WiFi si se perdio
                    if not wlan.isconnected():
                        print("[WiFi] Reconectando...")
                        conectar_wifi()
                utime.sleep_ms(10)  # 100 lecturas/segundo

            except KeyboardInterrupt:
                print("\n\n[Sistema] Detenido por usuario")
                if self.laser_ok:
                    try:
                        self.laser.stop_continuous()
                    except:
                        pass
                break
            except Exception as e:
                print("[Error] {}".format(e))
                utime.sleep(1)

# ============================================================
# MAIN
# ============================================================
if __name__ == "__main__":
    print("\n" + "=" * 50)
    print("   SIERCP — Sistema de RCP Inteligente")
    print("   Estandares AHA 2025")
    print("=" * 50)

    # Conectar WiFi
    conectar_wifi()

    # Iniciar sistema
    sistema = SistemaRCP()
    sistema.iniciar()