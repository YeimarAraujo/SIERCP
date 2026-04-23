# -*- coding: utf-8 -*-
"""
BLE Simple Peripheral - UART over Bluetooth LE
Implementación para ESP32 en MicroPython

Basado en el Nordic UART Service (NUS)
Compatible con apps como nRF Connect, Serial Bluetooth Terminal, etc.
"""
import bluetooth
import struct
import ubinascii
from micropython import const

# UUIDs del servicio UART Nordic (NUS - Nordic UART Service)
_UART_UUID = bluetooth.UUID("6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
_UART_TX = bluetooth.UUID("6E400003-B5A3-F393-E0A9-E50E24DCCA9E")  # TX desde perspectiva del periférico
_UART_RX = bluetooth.UUID("6E400002-B5A3-F393-E0A9-E50E24DCCA9E")  # RX desde perspectiva del periférico

# Flags para características
_FLAG_READ = const(0x0002)
_FLAG_WRITE = const(0x0008)
_FLAG_NOTIFY = const(0x0010)
_FLAG_WRITE_NO_RESPONSE = const(0x0004)

# Eventos BLE
_IRQ_CENTRAL_CONNECT = const(1)
_IRQ_CENTRAL_DISCONNECT = const(2)
_IRQ_GATTS_WRITE = const(3)
_IRQ_MTU_EXCHANGED = const(21)

# Configuración
MAX_BUFFER_SIZE = const(512)
DEFAULT_MTU = const(20)  # MTU mínimo garantizado


class BLESimplePeripheral:
    """
    Periférico BLE simple que implementa UART sobre Bluetooth
    
    Uso:
        ble = bluetooth.BLE()
        sp = BLESimplePeripheral(ble, name="ESP32")
        
        # Enviar datos
        if sp.is_connected():
            sp.send("Hola mundo\\n")
        
        # Recibir datos
        def on_rx(data):
            print("Recibido:", data)
        sp.on_write(on_rx)
    """
    
    def __init__(self, ble, name="ESP32", rxbuf=MAX_BUFFER_SIZE):
        """
        Inicializa el periférico BLE
        
        Args:
            ble: Instancia de bluetooth.BLE()
            name: Nombre visible del dispositivo
            rxbuf: Tamaño del buffer de recepción
        """
        self._ble = ble
        self._ble.active(True)
        self._ble.irq(self._irq)
        
        # Registrar servicio UART
        self._register_services()
        
        # Estado de conexión
        self._connections = set()
        self._write_callback = None
        self._payload = None
        self._mtu = DEFAULT_MTU
        
        # Buffer de recepción
        self._rx_buffer = bytearray(rxbuf)
        self._rx_pos = 0
        
        # Iniciar advertising
        self._advertise(name)
        
        print(f"[BLE] Periférico '{name}' iniciado")
        print(f"[BLE] TX UUID: {_UART_TX}")
        print(f"[BLE] RX UUID: {_UART_RX}")
    
    def _register_services(self):
        """Registra el servicio UART BLE"""
        # Definir servicio UART con características TX y RX
        UART_SERVICE = (
            _UART_UUID,
            (
                (_UART_TX, _FLAG_NOTIFY | _FLAG_READ),  # TX: servidor -> cliente (notificaciones)
                (_UART_RX, _FLAG_WRITE | _FLAG_WRITE_NO_RESPONSE),  # RX: cliente -> servidor (escritura)
            ),
        )
        
        # Registrar servicios
        services = (UART_SERVICE,)
        ((self._tx_handle, self._rx_handle),) = self._ble.gatts_register_services(services)
    
    def _irq(self, event, data):
        """
        Manejador de interrupciones BLE
        
        Eventos:
        - Conexión/desconexión
        - Escritura en característica RX
        - Intercambio de MTU
        """
        if event == _IRQ_CENTRAL_CONNECT:
            # Cliente conectado
            conn_handle, _, _ = data
            self._connections.add(conn_handle)
            print(f"[BLE] Cliente conectado (handle={conn_handle})")
        
        elif event == _IRQ_CENTRAL_DISCONNECT:
            # Cliente desconectado
            conn_handle, _, _ = data
            if conn_handle in self._connections:
                self._connections.remove(conn_handle)
            print(f"[BLE] Cliente desconectado (handle={conn_handle})")
            # Reiniciar advertising
            self._advertise()
        
        elif event == _IRQ_GATTS_WRITE:
            # Datos recibidos del cliente
            conn_handle, value_handle = data
            
            if value_handle == self._rx_handle:
                # Leer datos escritos
                value = self._ble.gatts_read(self._rx_handle)
                
                # Llamar callback si está definido
                if self._write_callback:
                    try:
                        self._write_callback(value)
                    except Exception as e:
                        print(f"[BLE] Error en callback: {e}")
                else:
                    # Si no hay callback, almacenar en buffer
                    self._buffer_rx(value)
        
        elif event == _IRQ_MTU_EXCHANGED:
            # MTU negociado
            conn_handle, mtu = data
            self._mtu = mtu - 3  # Restar overhead del protocolo
            print(f"[BLE] MTU negociado: {self._mtu} bytes")
    
    def _advertise(self, name="ESP32"):
        """
        Inicia advertising BLE para que el dispositivo sea visible
        
        Args:
            name: Nombre del dispositivo
        """
        # Payload de advertising
        adv_data = bytearray()
        
        # Flags (General Discoverable + BR/EDR Not Supported)
        adv_data.extend(struct.pack("BB", 2, 0x01))  # Length, AD Type
        adv_data.extend(struct.pack("B", 0x06))      # Flags
        
        # Complete Local Name
        name_bytes = name.encode()
        adv_data.extend(struct.pack("BB", len(name_bytes) + 1, 0x09))
        adv_data.extend(name_bytes)
        
        # Service UUID (UART Service)
        uuid_bytes = bytes(reversed(_UART_UUID.bytes))  # Little-endian
        adv_data.extend(struct.pack("BB", len(uuid_bytes) + 1, 0x07))
        adv_data.extend(uuid_bytes)
        
        # Iniciar advertising
        self._ble.gap_advertise(
            100000,  # Intervalo en microsegundos (100ms)
            adv_data=adv_data,
            resp_data=None,
            connectable=True
        )
        print(f"[BLE] Advertising como '{name}'")
    
    def _buffer_rx(self, data):
        """Almacena datos recibidos en buffer interno"""
        for byte in data:
            if self._rx_pos < len(self._rx_buffer):
                self._rx_buffer[self._rx_pos] = byte
                self._rx_pos += 1
    
    def send(self, data):
        """
        Envía datos al cliente conectado
        
        Args:
            data: String o bytes a enviar
            
        Returns:
            True si se envió correctamente, False si no hay conexión
        """
        if not self.is_connected():
            return False
        
        # Convertir a bytes si es necesario
        if isinstance(data, str):
            data = data.encode()
        
        try:
            # Enviar en chunks del tamaño del MTU
            for i in range(0, len(data), self._mtu):
                chunk = data[i:i + self._mtu]
                
                # Notificar a todos los clientes conectados
                for conn_handle in self._connections:
                    self._ble.gatts_notify(conn_handle, self._tx_handle, chunk)
            
            return True
            
        except Exception as e:
            print(f"[BLE] Error enviando: {e}")
            return False
    
    def read(self, max_bytes=None):
        """
        Lee datos del buffer de recepción
        
        Args:
            max_bytes: Máximo número de bytes a leer (None = todo)
            
        Returns:
            bytes: Datos leídos
        """
        if max_bytes is None:
            max_bytes = self._rx_pos
        
        data = bytes(self._rx_buffer[:min(max_bytes, self._rx_pos)])
        
        # Limpiar buffer leído
        self._rx_pos = 0
        
        return data
    
    def on_write(self, callback):
        """
        Registra callback para cuando se reciben datos
        
        Args:
            callback: Función que recibe bytes como argumento
                      Ejemplo: def on_rx(data): print(data)
        """
        self._write_callback = callback
    
    def is_connected(self):
        """
        Verifica si hay al menos un cliente conectado
        
        Returns:
            bool: True si hay conexión activa
        """
        return len(self._connections) > 0
    
    def disconnect(self):
        """Desconecta todos los clientes"""
        for conn_handle in self._connections.copy():
            try:
                self._ble.gap_disconnect(conn_handle)
            except:
                pass
        self._connections.clear()
    
    def stop(self):
        """Detiene el periférico BLE"""
        self.disconnect()
        self._ble.gap_advertise(None)  # Detener advertising
        self._ble.active(False)
        print("[BLE] Periférico detenido")
    
    def get_connections_count(self):
        """Retorna el número de clientes conectados"""
        return len(self._connections)
    
    def get_mtu(self):
        """Retorna el MTU actual"""
        return self._mtu


# ============================================================
# EJEMPLO DE USO
# ============================================================
def demo():
    """Ejemplo simple de uso"""
    import utime
    
    # Inicializar BLE
    ble = bluetooth.BLE()
    sp = BLESimplePeripheral(ble, name="ESP32-DEMO")
    
    # Callback para datos recibidos
    def on_receive(data):
        print(f"Recibido: {data.decode('utf-8', 'ignore')}")
        # Echo back
        sp.send(f"Echo: {data.decode('utf-8', 'ignore')}\n")
    
    sp.on_write(on_receive)
    
    print("\nEsperando conexión BLE...")
    print("Conecta con app móvil (nRF Connect, Serial Bluetooth Terminal, etc.)")
    
    counter = 0
    while True:
        if sp.is_connected():
            # Enviar contador cada segundo
            sp.send(f"Contador: {counter}\n")
            counter += 1
        
        utime.sleep(1)


if __name__ == "__main__":
    demo()