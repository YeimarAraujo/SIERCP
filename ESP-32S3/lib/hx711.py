import utime
from machine import Pin

# ------------------------------------------------------------
# DRIVER HX711
# BUGS CORREGIDOS:
#   1. self.gain -> self._pulsos en _read_raw()
#   2. Codigo huerfano eliminado de get_kg_promedio()
#   3. Timeout agregado en espera de datos
# ------------------------------------------------------------
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
        self._read_raw()

    def _read_raw(self):
        t = utime.ticks_ms()
        while self.dout.value() == 1:
            if utime.ticks_diff(utime.ticks_ms(), t) > 1000:
                raise OSError("HX711 no responde - revisa DT=25 SCK=26")
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

    def tare(self, times=10):
        total = 0
        for _ in range(times):
            total += self._read_raw()
            utime.sleep_ms(10)
        self.offset = total // times
        print("Tara:", self.offset)

    def calibrate(self, peso_conocido_kg, lectura_con_peso):
        self.scale = (lectura_con_peso - self.offset) / peso_conocido_kg

    def get_kg(self):
        if self.scale == 0:
            return 0.0
        raw = self._read_raw()
        return (raw - self.offset) / self.scale

    def get_kg_promedio(self, n=5):
        total = 0.0
        for _ in range(n):
            total += self.get_kg()
            utime.sleep_ms(5)
        return total / n

