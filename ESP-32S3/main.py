import network
import ujson
import utime
import ubinascii
from machine import I2C, Pin, UART
from hx711 import HX711

# ============================================================
# CONFIGURACION DE INTERNET Y FIREBASE
# ============================================================
WIFI_SSID     = "YeimarAraujo"
WIFI_PASSWORD = "09122005" 
FIREBASE_URL  = "https://siercp-default-rtdb.firebaseio.com/"  # <-- URL DE TU FIREBASE REALTIME DATABASE
MANIQUI_UUID  = "AA:BB:CC:DD:EE:FF"          # <-- MAC REAL (se auto-detectara abajo)

# Configurar WiFi
wlan = network.WLAN(network.STA_IF)
wlan.active(True)
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
        buf = bytearray([0xAA, cmd, len(args)] + list(args))
        buf.append(sum(buf) & 0xFF)
        self.uart.write(bytes(buf))
        utime.sleep_ms(50)
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
                self.distancia_base = muestras[len(muestras)//2]
            else:
                print("Laser dio valores nulos o 0, asumiendo error y simulando profundidad.")
                self.laser_ok = False

    def leer_profundidad(self, fuerza_kg):
        if self.laser_ok:
            try:
                d = self.laser.read()
                if d and d < 8000:
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

# ============================================================
# MAIN
# ============================================================
if __name__ == "__main__":
    conectar_wifi()
    sistema = SistemaRCP()
    sistema.iniciar()
