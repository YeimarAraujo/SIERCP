#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>
#include <HX711.h>
#include <Adafruit_VL53L0X.h>

// UUIDs Estándar del Proyecto
#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define CHAR_TELEMETRY_UUID "12345678-1234-5678-1234-56789abcdef1"

// Estructura de Telemetría (44 bytes)
struct __attribute__((packed)) TelemetryBatch {
    uint32_t timestamp;
    struct Sample { float force; float depth; } samples[5];
};

// Sensores y Estado
HX711 scale;
Adafruit_VL53L0X lox = Adafruit_VL53L0X();
bool deviceConnected = false;
BLECharacteristic* pTelemetryChar = NULL;

// Variables de Filtrado y Calibración
float baselineDepth = 0;
float filteredDepth = 0;
float filteredForce = 0;
const float EMA_ALPHA = 0.3; // Factor de suavizado (0.1 muy suave, 0.9 muy ruidoso)

// Lógica de Compresiones (Máquina de Estados básica para diagnóstico)
int compressionCount = 0;
bool inCompression = false;

class MyServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) { 
        deviceConnected = true; 
        printf(">>> CLINICAL MONITOR: CONECTADO\n"); 
    }
    void onDisconnect(BLEServer* pServer) { 
        deviceConnected = false; 
        printf(">>> CLINICAL MONITOR: DESCONECTADO\n"); 
        BLEDevice::startAdvertising(); 
    }
};

void setup() {
    Serial.begin(115200);
    pinMode(2, OUTPUT);
    printf("\n--- SIERCP PROFESSIONAL FIRMWARE V2.0 ---\n");
    
    // 1. Inicializar I2C y Láser
    Wire.begin(17, 18);
    if (lox.begin()) {
        lox.setMeasurementTimingBudgetMicroSeconds(20000); // 20ms para alta velocidad
        lox.startRangeContinuous();
        printf("[OK] VL53L0X: Modo Alta Velocidad activado\n");
    }

    // 2. Inicializar Celda de Carga
    scale.begin(4, 5);
    scale.set_scale(2280.f); // Ajustar según calibración física
    if (scale.wait_ready_timeout(1000)) {
        scale.tare();
        printf("[OK] HX711: Tara completada\n");
    }

    // 3. Calibración de Punto Cero (Promedio de 20 muestras)
    printf("Calibrando superficie... No tocar el maniquí.\n");
    long sum = 0;
    for(int i=0; i<20; i++) { sum += lox.readRange(); delay(30); }
    baselineDepth = (float)sum / 20.0f;
    filteredDepth = 0;
    printf("[OK] Baseline establecida: %.2f mm\n", baselineDepth);

    // 4. Configuración BLE Profesional
    BLEDevice::init("SIERCP_MANIQUI");
    BLEDevice::setMTU(512); 
    BLEServer *pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    BLEService *pService = pServer->createService(SERVICE_UUID);
    pTelemetryChar = pService->createCharacteristic(
        CHAR_TELEMETRY_UUID, 
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pTelemetryChar->addDescriptor(new BLE2902());
    pService->start();

    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->start();
    
    printf("--- SISTEMA PROFESIONAL LISTO ---\n");
}

void loop() {
    if (deviceConnected) {
        TelemetryBatch batch;
        batch.timestamp = millis();

        for(int i=0; i<5; i++) {
            // A. Lectura Raw
            float rawForce = scale.is_ready() ? scale.get_units(1) : 0;
            if(rawForce < 0) rawForce = 0;

            uint16_t range = lox.readRange();
            float rawDepth = (range < 8000) ? (baselineDepth - (float)range) : 0;
            if(rawDepth < 0) rawDepth = 0;

            // B. Filtrado EMA (Suavizado de señal)
            filteredDepth = (EMA_ALPHA * rawDepth) + ((1.0 - EMA_ALPHA) * filteredDepth);
            filteredForce = (EMA_ALPHA * rawForce) + ((1.0 - EMA_ALPHA) * filteredForce);

            // C. Lógica de Conteo (Detección de flanco de bajada)
            if (!inCompression && filteredDepth > 15.0) {
                inCompression = true;
            } else if (inCompression && filteredDepth < 8.0) {
                inCompression = false;
                compressionCount++;
                printf("Compresión detectada! Total: %d\n", compressionCount);
            }

            batch.samples[i].force = filteredForce;
            batch.samples[i].depth = filteredDepth;
            
            delay(15); // Estabilidad de muestreo
        }

        pTelemetryChar->setValue((uint8_t*)&batch, sizeof(TelemetryBatch));
        pTelemetryChar->notify();
        digitalWrite(2, HIGH);
    } else {
        digitalWrite(2, (millis() / 500) % 2); // Parpadeo de espera
        if (compressionCount > 0) compressionCount = 0; // Reset al desconectar
        delay(10);
    }
}
