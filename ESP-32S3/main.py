import network
import ujson
import utime
import ubinascii
from machine import I2C, Pin, UART
from hx711 import HX711

# ============================================================
<<<<<<< HEAD
# CONFIGURACION DE INTERNET Y FIREBASE
# ============================================================
WIFI_SSID     = "YeimarAraujo"
WIFI_PASSWORD = "09122005" 
FIREBASE_URL  = "https://siercp-default-rtdb.firebaseio.com/"  # <-- URL DE TU FIREBASE REALTIME DATABASE
MANIQUI_UUID  = "AA:BB:CC:DD:EE:FF"          # <-- MAC REAL (se auto-detectara abajo)
=======
# CONFIGURACION
# ============================================================
WIFI_SSID     = "YeimarAraujo"
WIFI_PASSWORD = "09122005" 
FIREBASE_URL  = "https://siercp-default-rtdb.firebaseio.com"
>>>>>>> origin/main

# Configurar WiFi
wlan = network.WLAN(network.STA_IF)
wlan.active(True)
<<<<<<< HEAD
mac_real = ubinascii.hexlify(wlan.config('mac'), ':').decode().upper()
print("\n[INFO] MAC Address REAL de este ESP32:", mac_real)
MANIQUI_UUID = mac_real  # Auto-reemplazamos con la real

def conectar_wifi():
    led_azul = Pin(2, Pin.OUT) # Asumimos Pin 2 (comun para LED integrado o externo)
    led_azul.value(0)          # Apagado mientras intenta conectar
    
    if not wlan.isconnected():
        print("\nConectando a Wi-Fi:", WIFI_SSID, "...")
        wlan.connect(WIFI_SSID, WIFI_PASSWORD)
        t = 10
        while not wlan.isconnected() and t > 0:
            utime.sleep(1)
            t -= 1
    if wlan.isconnected():
        led_azul.value(1)      # Encender LED Azul (WiFi OK)
        print("[WIFI] Conectado! IP:", wlan.ifconfig()[0])
    else:
        print("[WIFI] ADVERTENCIA: Fallo al conectar. Funcionara localmente.")

# ============================================================
# DRIVERS Y RCP
# ============================================================
try:
    from vl53l0x import VL53L0X
except ImportError:
    pass

class JQ8900:
    def __init__(self, uart):
        self.uart = uart
        utime.sleep_ms(500)
    def _cmd(self, cmd, *args):
=======
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
>>>>>>> origin/main
        buf = bytearray([0xAA, cmd, len(args)] + list(args))
        buf.append(sum(buf) & 0xFF)
        self.uart.write(bytes(buf))
        utime.sleep_ms(50)
<<<<<<< HEAD
    def play(self, track):
        self._cmd(0x07, 0x00, track)

class SistemaRCP:
    def __init__(self):
        print("\nInicializando Sensores...")
        
        # Audio
        uart = UART(2, baudrate=9600, tx=Pin(16), rx=Pin(15))
        self.audio = JQ8900(uart)
        # Cambio a Tarjeta SD y volumen al maximo
        self.audio._cmd(0x09, 0x01) # Seleccionar SD (por si tu modulo es solo-SD)
        utime.sleep_ms(200)
        self.audio._cmd(0x13, 30)   # Volumen maximo (30)
        print("JQ8900 (Audio) -> OK")

        # Fuerza (HX711 en pines 4 y 5 seguros para S3)
        self.fuerza_ok = False
        try:
            self.celda = HX711(4, 5)
            self.fuerza_ok = True
            print("HX711 (Fuerza) -> OK")
        except Exception as e:
            print("HX711 -> FALLO:", e)

        # Laser (I2C en 17 y 18)
        self.laser_ok = False
        self.distancia_base = 200
        try:
            self.i2c = I2C(1, sda=Pin(17), scl=Pin(18), freq=100000)
            if 0x29 in self.i2c.scan():
                self.laser = VL53L0X(self.i2c)
                self.laser_ok = True
                print("VL53L0X (Laser) ->  OK")
            else:
                print("VL53L0X -> No detectado en I2C (revisa cables)")
        except Exception as e:
            print("VL53L0X -> FALLO:", e)

        if not self.laser_ok:
            print("\n[!] AVISO: Laser VL53L0X no disponible.")
            print("[!] Se simulara la profundidad usando la fuerza de compresion.")

        self.ultima_telemetria = 0

    def enviar_telemetria(self, hr, ox, pres, temp):
        if not wlan.isconnected(): return
        try:
            import urequests
            url = FIREBASE_URL + "/telemetria/" + MANIQUI_UUID + ".json"
            data = {
                "ritmo_cardiaco": hr,
                "oxigeno": ox,
                "presion": pres,
                "temperatura": temp,
                "timestamp": {".sv": "timestamp"}
            }
            # PATCH actualiza los datos en vez de duplicarlos/sobreescribir el historial entero
            res = urequests.patch(url, json=data, timeout=3)
            print("[Firebase] Enviado OK:", res.text)
            res.close()
        except ImportError:
            pass # No hay urequests instalado
        except Exception as e:
            print("[Firebase] Fallo envio:", e)

    def calibrar(self):
        print("\nCalibrando sensores...")
        if self.fuerza_ok:
            try:
                self.celda.tare(10)
            except: pass
            
        if self.laser_ok:
            muestras = []
=======
    
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
            
>>>>>>> origin/main
            for _ in range(10):
                try:
                    d = self.laser.read()
                    if d and 10 < d < 8000:
                        muestras.append(d)
                except:
                    pass
                utime.sleep_ms(50)
<<<<<<< HEAD
            if muestras:
                muestras.sort()
                self.distancia_base = muestras[len(muestras)//2]
            else:
                print("Laser dio valores nulos o 0, asumiendo error y simulando profundidad.")
                self.laser_ok = False

    def leer_profundidad(self, fuerza_kg):
=======
            
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
>>>>>>> origin/main
        if self.laser_ok:
            try:
                d = self.laser.read()
                if d and d < 8000:
<<<<<<< HEAD
                    return max(0, self.distancia_base - d)
            except: pass
        # Simulacion: Si el laser falla, estimamos que 1kg = 2mm (ej: 25kg = 50mm)
        return fuerza_kg * 2.0

    def iniciar(self):
        self.calibrar()
        print("\n= SISTEMA LISTO = Esperando compresiones...")
        
        while True:
            # Leer Sensores
            fuerza = 0
            if self.fuerza_ok:
                try: fuerza = self.celda.get_kg()
                except: pass
            fuerza = max(0, fuerza)
            
            prof = self.leer_profundidad(fuerza)
            
            # Subir a internet cada 1 segundo (solo si hay Wifi y hay datos)
            ahora = utime.ticks_ms()
            if utime.ticks_diff(ahora, self.ultima_telemetria) > 1000:
                print("Estado -> Fuerza: {:.1f} kg | Profundidad: {:.1f} mm".format(fuerza, prof))
                
                # Valores simulados mezclados con sensor real
                ritmo_simulado = 70 + (fuerza * 0.5)
                presion_estimada = fuerza * 1.5 
                
                self.enviar_telemetria(ritmo_simulado, 98.0, presion_estimada, 36.5)
                self.ultima_telemetria = ahora
                
            utime.sleep_ms(50)
=======
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
>>>>>>> origin/main

# ============================================================
# MAIN
# ============================================================
if __name__ == "__main__":
<<<<<<< HEAD
    conectar_wifi()
    sistema = SistemaRCP()
    sistema.iniciar()
=======
    print("\n" + "="*50)
    print("   SIERCP - Sistema de RCP Inteligente")
    print("="*50)
    
    # Conectar WiFi
    conectar_wifi()
    
    # Iniciar sistema
    sistema = SistemaRCP()
    sistema.iniciar()
>>>>>>> origin/main
