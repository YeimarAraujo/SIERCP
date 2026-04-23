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
    """Conecta a WiFi y enciende LED azul cuando está conectado"""
    led_azul = Pin(2, Pin.OUT)
    led_azul.value(0)
    
    if not wlan.isconnected():
        print(f"\n[WiFi] Conectando a: {WIFI_SSID}...")
        wlan.connect(WIFI_SSID, WIFI_PASSWORD)
        timeout = 15
        
        while not wlan.isconnected() and timeout > 0:
            utime.sleep(1)
            timeout -= 1
            print(".", end="")
    
    if wlan.isconnected():
        led_azul.value(1)
        print(f"\n[WiFi] ✓ Conectado | IP: {wlan.ifconfig()[0]}")
        print(f"[WiFi] MAC: {DEVICE_MAC}")
        return True
    else:
        print("\n[WiFi] ✗ Error: No se pudo conectar")
        return False

# ============================================================
# DRIVER DE AUDIO JQ8900
# ============================================================
class JQ8900:
    """Driver para módulo de audio JQ8900"""
    def __init__(self, uart):
        self.uart = uart
        utime.sleep_ms(500)
        self._cmd(0x09, 0x01)  # Seleccionar tarjeta SD
        utime.sleep_ms(200)
        self._cmd(0x13, 30)    # Volumen máximo (30)
    
    def _cmd(self, cmd, *args):
        """Envía comando al JQ8900"""
        buf = bytearray([0xAA, cmd, len(args)] + list(args))
        buf.append(sum(buf) & 0xFF)
        self.uart.write(bytes(buf))
        utime.sleep_ms(50)
    
    def play(self, track):
        """Reproduce pista específica (1-255)"""
        self._cmd(0x07, 0x00, track)

# ============================================================
# SISTEMA RCP
# ============================================================
class SistemaRCP:
    """Sistema de monitoreo de RCP con sensores y telemetría"""
    
    def __init__(self):
        print("\n" + "="*50)
        print("   SISTEMA RCP - Inicializando...")
        print("="*50)
        
        # Audio JQ8900
        self._init_audio()
        
        # Sensor de Fuerza HX711
        self._init_fuerza()
        
        # Sensor Láser VL53L0X
        self._init_laser()
        
        # Variables de control
        self.ultima_telemetria = 0
        self.compresiones_detectadas = 0
        self.ultima_compresion = 0
        self.timestamps_compresiones = []
        self.en_compresion = False
        self.pico_fuerza = 0.0
        
        print("\n" + "="*50)
        print("   ✓ Sistema inicializado correctamente")
        print("="*50 + "\n")
    
    def _init_audio(self):
        """Inicializa módulo de audio"""
        try:
            uart = UART(2, baudrate=9600, tx=Pin(16), rx=Pin(15))
            self.audio = JQ8900(uart)
            print("[Audio] ✓ JQ8900 OK (Pines TX:16, RX:15)")
        except Exception as e:
            print(f"[Audio] ✗ Error: {e}")
            self.audio = None
    
    def _init_fuerza(self):
        """Inicializa sensor de fuerza HX711"""
        self.fuerza_ok = False
        try:
            self.celda = HX711(4, 5)  # DT=4, SCK=5
            self.fuerza_ok = True
            print("[Fuerza] ✓ HX711 OK (Pines DT:4, SCK:5)")
        except Exception as e:
            print(f"[Fuerza] ✗ Error: {e}")
    
    def _init_laser(self):
        """Inicializa sensor láser VL53L0X"""
        self.laser_ok = False
        self.distancia_base = 200  # mm (distancia sin compresión)
        
        try:
            self.i2c = I2C(1, sda=Pin(17), scl=Pin(18), freq=100000)
            dispositivos = self.i2c.scan()
            
            if 0x29 in dispositivos:
                from vl53l0x import VL53L0X
                self.laser = VL53L0X(self.i2c)
                self.laser_ok = True
                print("[Láser] ✓ VL53L0X OK (I2C SDA:17, SCL:18)")
            else:
                print(f"[Láser] ⚠ No detectado en I2C (encontrados: {[hex(d) for d in dispositivos]})")
        except Exception as e:
            print(f"[Láser] ✗ Error: {e}")
        
        if not self.laser_ok:
            print("[Láser] ⚠ Usando simulación: 1kg ≈ 2mm profundidad")
    
    def calibrar(self):
        """Calibra los sensores antes de iniciar"""
        print("\n[Calibración] Iniciando...")
        
        # Calibrar celda de carga (tarar)
        if self.fuerza_ok:
            try:
                print("[Calibración] Tarando celda... (no presionar)")
                self.celda.tare(10)
                print("[Calibración] ✓ Celda tarada")
            except Exception as e:
                print(f"[Calibración] ✗ Error en tara: {e}")
        
        # Calibrar láser (medir distancia base)
        if self.laser_ok:
            print("[Calibración] Midiendo distancia base...")
            muestras = []
            
            for i in range(10):
                try:
                    d = self.laser.read()
                    if d and 10 < d < 8000:
                        muestras.append(d)
                        print(f"  Muestra {i+1}/10: {d} mm")
                except:
                    pass
                utime.sleep_ms(100)
            
            if muestras:
                muestras.sort()
                self.distancia_base = muestras[len(muestras)//2]  # Mediana
                print(f"[Calibración] ✓ Distancia base: {self.distancia_base} mm")
            else:
                print("[Calibración] ✗ Láser sin lecturas válidas, usando simulación")
                self.laser_ok = False
        
        print("[Calibración] ✓ Completada\n")
    
    def leer_fuerza(self):
        """Lee la fuerza actual en kg"""
        if not self.fuerza_ok:
            return 0.0
        try:
            return max(0.0, self.celda.get_kg())
        except:
            return 0.0
    
    def leer_profundidad(self, fuerza_kg):
        """Lee o estima la profundidad de compresión en mm"""
        if self.laser_ok:
            try:
                d = self.laser.read()
                if d and d < 8000:
                    prof = self.distancia_base - d
                    return max(0.0, prof)
            except:
                pass
        
        # Simulación: ~1 kg ≈ 2 mm (ajustar según tu celda)
        return fuerza_kg * 2.0
    
    def detectar_compresion(self, fuerza, profundidad):
        """
        Detecta compresiones válidas por ciclo de fuerza
        Retorna: (nueva_compresion_detectada, ritmo_cpm)
        """
        UMBRAL_INICIO = 4.0   # kg para iniciar compresión
        UMBRAL_FIN = 2.0      # kg para fin de compresión
        
        nueva_compresion = False
        ahora = utime.ticks_ms()
        
        # Detectar inicio de compresión
        if fuerza >= UMBRAL_INICIO and not self.en_compresion:
            self.en_compresion = True
            self.pico_fuerza = fuerza
        
        # Actualizar pico durante compresión
        elif fuerza > self.pico_fuerza and self.en_compresion:
            self.pico_fuerza = fuerza
        
        # Detectar fin de compresión
        elif fuerza <= UMBRAL_FIN and self.en_compresion:
            self.en_compresion = False
            self.compresiones_detectadas += 1
            self.timestamps_compresiones.append(ahora)
            self.ultima_compresion = ahora
            self.pico_fuerza = 0.0
            nueva_compresion = True
            
            # Reproducir audio cada 5 compresiones
            if self.audio and self.compresiones_detectadas % 5 == 0:
                if profundidad < 50:
                    self.audio.play(1)  # "Más profundo"
                else:
                    self.audio.play(2)  # "Bien"
        
        # Calcular ritmo real (CPM)
        ritmo_cpm = self._calcular_ritmo()
        
        return nueva_compresion, ritmo_cpm
    
    def _calcular_ritmo(self):
        """Calcula el ritmo real en compresiones por minuto"""
        # Limpiar timestamps antiguos (> 10 segundos)
        ahora = utime.ticks_ms()
        self.timestamps_compresiones = [
            t for t in self.timestamps_compresiones 
            if utime.ticks_diff(ahora, t) < 10000
        ]
        
        if len(self.timestamps_compresiones) < 2:
            return 0
        
        # Calcular CPM basado en ventana de tiempo
        span = utime.ticks_diff(
            self.timestamps_compresiones[-1], 
            self.timestamps_compresiones[0]
        )
        
        if span > 0:
            num_comp = len(self.timestamps_compresiones) - 1
            cpm = int((num_comp / (span / 60000.0)))
            return cpm
        
        return 0
    
    def enviar_telemetria(self, fuerza, profundidad, ritmo_cpm):
        """Envía datos a Firebase"""
        if not wlan.isconnected():
            return
        
        try:
            import urequests
            
            # URL de Firebase
            url = f"{FIREBASE_URL}/telemetria/{DEVICE_MAC}.json"
            
            # Datos a enviar según modelo DeviceInfo en Flutter
            data = {
                "ritmo_cardiaco": ritmo_cpm,
                "oxigeno": 98.0,          # Simulado o leer de sensor real si se añade
                "presion": round(fuerza, 2),
                "temperatura": 36.5,      # Simulado o leer de sensor real si se añade
                "timestamp": {".sv": "timestamp"}
            }
            
            # Enviar a Firebase (PATCH actualiza sin borrar)
            res = urequests.patch(url, json=data, timeout=3)
            
            if res.status_code == 200:
                print(f"[Firebase] ✓ Enviado | F:{fuerza:.1f}kg P:{profundidad:.1f}mm R:{ritmo_cpm}cpm")
            else:
                print(f"[Firebase] ✗ Error {res.status_code}: {res.text}")
            
            res.close()
            
        except ImportError:
            print("[Firebase] ✗ urequests no instalado")
        except Exception as e:
            print(f"[Firebase] ✗ Error: {e}")
    
    def iniciar(self):
        """Inicia el loop principal del sistema"""
        self.calibrar()
        
        print("\n" + "="*50)
        print("   🚀 SISTEMA ACTIVO - Esperando compresiones...")
        print("="*50 + "\n")
        
        contador_loop = 0
        
        while True:
            try:
                # Leer sensores
                fuerza = self.leer_fuerza()
                profundidad = self.leer_profundidad(fuerza)
                
                # Detectar compresiones
                nueva_comp, ritmo_cpm = self.detectar_compresion(fuerza, profundidad)
                
                # Mostrar info cada 20 loops (~1 segundo)
                contador_loop += 1
                if contador_loop >= 20:
                    print(f"[Loop] F:{fuerza:5.1f}kg | P:{profundidad:5.1f}mm | R:{ritmo_cpm:3d}cpm | C:{self.compresiones_detectadas}")
                    contador_loop = 0
                
                # Enviar telemetría cada 250 ms (4 Hz) para mayor fluidez en UI
                ahora = utime.ticks_ms()
                if utime.ticks_diff(ahora, self.ultima_telemetria) >= 250:
                    self.enviar_telemetria(fuerza, profundidad, ritmo_cpm)
                    self.ultima_telemetria = ahora
                
                utime.sleep_ms(50)  # 20 lecturas por segundo
                
            except KeyboardInterrupt:
                print("\n\n[Sistema] Detenido por usuario")
                break
            except Exception as e:
                print(f"[Error] {e}")
                utime.sleep(1)

# ============================================================
# MAIN
# ============================================================
if __name__ == "__main__":
    print("\n" + "="*50)
    print("   SIERCP - Sistema de RCP Inteligente")
    print("="*50)
    
    # Conectar WiFi
    conectar_wifi()
    
    # Iniciar sistema
    sistema = SistemaRCP()
    sistema.iniciar()