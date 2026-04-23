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
                print(f"[Láser] ⚠ No detectado en I2C")
        except Exception as e:
            print(f"[Láser] ✗ Error: {e}")
        
        if not self.laser_ok:
            print("[Láser] ⚠ Usando simulación basada en fuerza")
    
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
            
            for _ in range(10):
                try:
                    d = self.laser.read()
                    if d and 10 < d < 8000:
                        muestras.append(d)
                except:
                    pass
                utime.sleep_ms(50)
            
            if muestras:
                muestras.sort()
                self.distancia_base = muestras[len(muestras)//2]  # Mediana
                print(f"[Calibración] ✓ Distancia base: {self.distancia_base} mm")
            else:
                print("[Calibración] ✗ Láser sin lecturas válidas")
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
        
        # Simulación: ~1 kg ≈ 2 mm
        return fuerza_kg * 2.0
    
    def detectar_compresion(self, fuerza):
        """
        Detecta compresiones válidas por ciclo de fuerza
        Retorna: nueva_compresion_detectada
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
                self.audio.play(2)  # Pista 2: "Bien"
        
        return nueva_compresion
    
    def enviar_telemetria(self, fuerza):
        """
        Envía telemetría a Firebase (FORMATO ORIGINAL)
        Los valores son independientes de los datos reales de compresión
        """
        if not wlan.isconnected():
            return
        
        try:
            import urequests
            
            # URL de Firebase
            url = f"{FIREBASE_URL}/telemetria/{DEVICE_MAC}.json"
            
            # DATOS SIMULADOS/INDEPENDIENTES (mantiene formato original)
            ritmo_simulado = 70 + (fuerza * 0.5)  # Ritmo cardíaco "del paciente"
            oxigeno = 98.0                        # Oxígeno fijo
            presion = fuerza                      # Fuerza real (Flutter lo convierte a mm)
            temperatura = 36.5                    # Temperatura fija
            
            data = {
                "ritmo_cardiaco": round(ritmo_simulado, 1),
                "oxigeno": oxigeno,
                "presion": round(presion, 2),
                "temperatura": temperatura,
                "timestamp": {".sv": "timestamp"}
            }
            
            # Enviar a Firebase (PATCH actualiza sin borrar)
            res = urequests.patch(url, json=data, timeout=3)
            
            if res.status_code == 200:
                print(f"[Firebase] ✓ Enviado | RC:{ritmo_simulado:.1f} O2:{oxigeno} P:{presion:.1f} T:{temperatura}")
            else:
                print(f"[Firebase] ✗ Error {res.status_code}")
            
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
        
        while True:
            try:
                # Leer sensores REALES (para control interno)
                fuerza = self.leer_fuerza()
                profundidad = self.leer_profundidad(fuerza)
                
                # Detectar compresiones REALES (para audio feedback)
                nueva_comp = self.detectar_compresion(fuerza)
                
                if nueva_comp:
                    print(f"[Compresión] #{self.compresiones_detectadas} detectada | F:{fuerza:.1f}kg P:{profundidad:.1f}mm")
                
                # Enviar telemetría cada 250 ms para fluidez en la UI
                ahora = utime.ticks_ms()
                if utime.ticks_diff(ahora, self.ultima_telemetria) >= 250:
                    self.enviar_telemetria(fuerza)
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