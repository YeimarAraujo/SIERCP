import utime
import ujson
from machine import Pin

# ------------------------------------------------------------
# DRIVER HX711 — PRECISION CLINICA AHA 2025
#
# Caracteristicas:
#   - Tara robusta con descarte de outliers (IQR)
#   - Calibracion interactiva con persistencia en archivo
#   - Filtro EMA (Exponential Moving Average) integrado
#   - Lectura rapida sin delays innecesarios
# ------------------------------------------------------------

_CALIBRATION_FILE = "calibration.json"

class HX711:
    def __init__(self, dout, sck, gain=128):
        self.dout = Pin(dout, Pin.IN)
        self.sck  = Pin(sck, Pin.OUT)
        self.sck.value(0)
        if gain == 128:
            self._pulsos = 1
        elif gain == 64:
            self._pulsos = 3
        else:
            self._pulsos = 2
        self.offset = 0
        self.scale  = 1.0
        self._ema = 0.0
        self._ema_init = False
        self._ema_alpha = 1.0  # Sin lag para no perder el pico de compresion
        self._read_raw()
        # Intentar cargar calibracion previa
        self._load_calibration()

    def _read_raw(self):
        """Lee un valor raw de 24 bits del HX711"""
        t = utime.ticks_ms()
        while self.dout.value() == 1:
            if utime.ticks_diff(utime.ticks_ms(), t) > 1000:
                raise OSError("HX711 no responde")
        val = 0
        for _ in range(24):
            self.sck.value(1)
            val = (val << 1) | self.dout.value()
            self.sck.value(0)
        for _ in range(self._pulsos):
            self.sck.value(1)
            self.sck.value(0)
        if val & 0x800000:
            val -= 0x1000000
        return val

    def tare(self, times=20):
        """Tara robusta: descarta outliers con IQR antes de promediar"""
        readings = []
        for _ in range(times):
            try:
                readings.append(self._read_raw())
            except OSError:
                pass
            utime.sleep_ms(10)

        if len(readings) < 5:
            raise OSError("HX711: pocas lecturas validas para tara")

        # Descarte IQR
        readings.sort()
        n = len(readings)
        q1 = readings[n // 4]
        q3 = readings[3 * n // 4]
        iqr = q3 - q1
        lo = q1 - iqr
        hi = q3 + iqr
        filtered = [r for r in readings if lo <= r <= hi]

        if not filtered:
            filtered = readings  # fallback

        self.offset = sum(filtered) // len(filtered)
        self._ema = 0.0
        self._ema_init = False
        print("[HX711] Tara OK: {} ({} muestras, {} tras IQR)".format(
            self.offset, len(readings), len(filtered)))

    def calibrate(self, peso_conocido_kg):
        """
        Calibracion con peso conocido.
        Debe llamarse DESPUES de tare() y CON el peso sobre la celda.
        """
        readings = []
        print("[HX711] Leyendo {} muestras con peso...".format(20))
        for _ in range(20):
            try:
                readings.append(self._read_raw())
            except OSError:
                pass
            utime.sleep_ms(10)

        if len(readings) < 5:
            raise OSError("HX711: pocas lecturas para calibrar")

        # IQR
        readings.sort()
        n = len(readings)
        q1 = readings[n // 4]
        q3 = readings[3 * n // 4]
        iqr = q3 - q1
        lo = q1 - iqr
        hi = q3 + iqr
        filtered = [r for r in readings if lo <= r <= hi]
        if not filtered:
            filtered = readings

        avg_raw = sum(filtered) / len(filtered)
        diff = avg_raw - self.offset

        if abs(diff) < 100:
            raise ValueError("Diferencia muy pequena - peso no detectado")

        self.scale = diff / peso_conocido_kg
        self._save_calibration()
        print("[HX711] Calibrado: scale={:.2f} (peso={} kg)".format(
            self.scale, peso_conocido_kg))

    def _save_calibration(self):
        """Guarda offset y scale en archivo"""
        try:
            data = {"offset": self.offset, "scale": self.scale}
            with open(_CALIBRATION_FILE, "w") as f:
                ujson.dump(data, f)
            print("[HX711] Calibracion guardada")
        except Exception as e:
            print("[HX711] Error guardando calibracion: {}".format(e))

    def _load_calibration(self):
        """Carga calibracion previa si existe"""
        try:
            with open(_CALIBRATION_FILE, "r") as f:
                data = ujson.load(f)
            self.offset = data.get("offset", 0)
            self.scale = data.get("scale", 1.0)
            if self.scale != 1.0:
                print("[HX711] Calibracion cargada: offset={} scale={:.2f}".format(
                    self.offset, self.scale))
            else:
                print("[HX711] WARN: Sin calibracion previa (scale=1.0)")
        except (OSError, ValueError):
            print("[HX711] Sin archivo de calibracion - usar calibrate()")

    @property
    def is_calibrated(self):
        """Retorna True si el sensor tiene una calibracion real"""
        return self.scale != 1.0 and self.scale != 0.0

    def get_kg(self):
        """Lee fuerza en kg (con filtro EMA)"""
        if self.scale == 0:
            return 0.0

        # Non-blocking check: si no hay dato nuevo, retornar el ultimo conocido
        if self.dout.value() == 1 and self._ema_init:
            return max(0.0, self._ema)

        try:
            raw = self._read_raw()
        except OSError:
            return max(0.0, self._ema) if self._ema_init else 0.0
            
        kg = (raw - self.offset) / self.scale

        # Filtro EMA
        if not self._ema_init:
            self._ema = kg
            self._ema_init = True
        else:
            self._ema = self._ema_alpha * kg + (1.0 - self._ema_alpha) * self._ema

        return max(0.0, self._ema)

    def get_kg_raw(self):
        """Lee fuerza en kg SIN filtro EMA (para diagnostico)"""
        if self.scale == 0:
            return 0.0
        raw = self._read_raw()
        return max(0.0, (raw - self.offset) / self.scale)

    def get_kg_promedio(self, n=5):
        """Promedio de N lecturas (sin filtro EMA)"""
        total = 0.0
        count = 0
        for _ in range(n):
            try:
                total += self.get_kg_raw()
                count += 1
            except OSError:
                pass
            utime.sleep_ms(5)
        return total / count if count > 0 else 0.0

    def calibrate_interactive(self):
        """
        Modo de calibracion interactivo por consola serial.
        Guia al usuario paso a paso.
        """
        print("\n" + "=" * 50)
        print("  CALIBRACION DE CELDA DE CARGA HX711")
        print("=" * 50)

        # Paso 1: Tara
        print("\n[Paso 1] Retire todo peso de la celda de carga.")
        print("         Presione Enter cuando este lista...")
        input()
        print("Tarando...")
        self.tare(20)
        print("Tara completada: offset = {}".format(self.offset))

        # Paso 2: Peso conocido
        print("\n[Paso 2] Coloque un peso CONOCIDO sobre la celda.")
        peso = input("         Ingrese el peso en kg (ej: 5): ")
        try:
            peso_kg = float(peso)
        except ValueError:
            print("ERROR: valor invalido")
            return False

        if peso_kg <= 0:
            print("ERROR: peso debe ser positivo")
            return False

        print("Calibrando con {} kg...".format(peso_kg))
        self.calibrate(peso_kg)

        # Paso 3: Verificacion
        print("\n[Paso 3] Verificacion...")
        for i in range(5):
            kg = self.get_kg_raw()
            print("  Lectura {}: {:.2f} kg".format(i + 1, kg))
            utime.sleep_ms(200)

        print("\n[OK] Calibracion completa y guardada.")
        print("     Factor: scale = {:.2f}".format(self.scale))
        print("=" * 50 + "\n")
        return True
