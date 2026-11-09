#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>
// #include <HX711.h> // Eliminado: no se usa celda de carga
#include <esp_system.h>
#include <esp_mac.h>
#include <Adafruit_VL53L0X.h>

// UUIDs
#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define CHAR_TELEMETRY_UUID "12345678-1234-5678-1234-56789abcdef1"
#define CHAR_CTRL_UUID      "12345678-1234-5678-1234-56789abcdef2"

// TELEMETRÍA
struct __attribute__((packed)) TelemetryBatch {
    uint32_t timestamp;
    struct Sample { float force; float depth; } samples[5];
    uint16_t compressions;
    uint8_t bpm;
    uint8_t flags; // bit0: sensorOk, bit1: calibrated, bit2: forceOk
};

// HARDWARE
// HX711 scale; // Eliminado: no se usa celda de carga
Adafruit_VL53L0X lox = Adafruit_VL53L0X();

// BLE
BLECharacteristic* pTelemetryChar = NULL;
bool deviceConnected = false;
bool sessionActive = false;

// VARIABLES CLÍNICAS
float baselineDepth = 0;
float factoryBaseline = 0;      // referencia tomada al encender
volatile bool rezeroPending = false;
float compressionPeak = 0;      // pico de la compresión en curso
float filteredDepth = 0;

enum State { IDLE, PRESSING, HOLDING, RELEASING, RELEASED_HIGH };
float lastValley = -1;
const float RISE_MM = 6.0;
bool inCompression = false;
State state = IDLE;
bool resetPending = false;
uint32_t resetTime = 0;
uint8_t confirmCount = 0;
uint32_t lastCompressionTime = 0;

int compressionCount = 0;
unsigned long lastCompMs = 0;
float currentBPM = 0;

// ESTADO DE SENSORES
bool _sensorOk = true;
bool _forceOk = true;

// PARÁMETROS
const float DEPTH_DOWN = 15.0;
const float DEPTH_UP   = 8.0;
const uint8_t CONFIRM  = 2;
const uint32_t COOLDOWN = 180;
// Con liberación incompleta nunca se baja de DEPTH_UP: se considera terminada
// la compresión al caer a esta fracción del pico, y la app mide el residual.
const float RELEASE_RATIO = 0.6;
const uint8_t MAX_INVALID_READINGS = 15;   // ~0,5 s sin datos marca el sensor
const float MAX_REZERO_DRIFT_MM = 15.0;    // evita calibrar con el tórax oprimido
const uint8_t REZERO_SAMPLES = 10;
const uint32_t REZERO_TIMEOUT_MS = 500;

// RESET TOTAL
void resetSession() {

    compressionCount = 0;
    currentBPM = 0;
    lastCompMs = 0;

    state = IDLE;
    confirmCount = 0;

    filteredDepth = 0;

    inCompression = false;
    compressionPeak = 0;
    lastValley = -1;

    Serial.println("[SYSTEM] RESET COMPLETO SEGURO");
}
// FSM
void updateFSM(float depth, uint32_t now) {

    bool down = depth > DEPTH_DOWN;
    if (state == IDLE) compressionPeak = 0;
    if (depth > compressionPeak) compressionPeak = depth;

    float releaseAt = compressionPeak * RELEASE_RATIO;
    if (releaseAt < DEPTH_UP) releaseAt = DEPTH_UP;
    bool up = depth < releaseAt;

    switch (state) {

        case IDLE:
            if (down) { confirmCount = 1; state = PRESSING; }
        break;

        case PRESSING:
            if (down) {
                if (++confirmCount >= CONFIRM) {
                    state = HOLDING;
                    confirmCount = 0;
                }
            } else { state = IDLE; confirmCount = 0; }
        break;

        case HOLDING:
            if (up) { confirmCount = 1; state = RELEASING; }
        break;

        case RELEASING:
            if (up) {
                if (++confirmCount >= CONFIRM) {

                    if (now - lastCompressionTime > COOLDOWN) {

                        compressionCount++;

                        if (lastCompMs > 0) {
                            float bpmRaw = 60000.0 / (now - lastCompMs);
                            currentBPM = (0.7 * currentBPM) + (0.3 * bpmRaw);
                        }

                        lastCompMs = now;
                        lastCompressionTime = now;
                    }

                    // Si no volvió a cero, la siguiente compresión arranca desde aquí.
                    compressionPeak = 0;
                    state = depth > DEPTH_DOWN ? RELEASED_HIGH : IDLE;
                    confirmCount = 0;
                }
            } else { state = HOLDING; confirmCount = 0; }
        break;

        // Liberación incompleta: espera a que empiece a bajar de nuevo.
        case RELEASED_HIGH:
            if (depth < DEPTH_DOWN) {
                lastValley = -1;
                state = IDLE;
            } else if (lastValley < 0 || depth < lastValley) {
                lastValley = depth;
            } else if (depth > lastValley + RISE_MM) {
                lastValley = -1;
                confirmCount = 0;
                state = PRESSING;
            }
        break;
    }
}

// BLE CONTROL
class ControlCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pChar) {

        String val = pChar->getValue();
        if (val.length() == 0) return;

        uint8_t cmd = val[0];

        // START
        if (cmd == 0x01) {
            resetSession();       
            rezeroPending = true;   // se atiende en loop(): I2C no va en el callback BLE
            sessionActive = true;

            resetPending = false;    
            Serial.println("[SESSION] START");
        }

        // STOP (solo detiene streaming + agenda reset)
        else if (cmd == 0x00) {
            sessionActive = false;

            resetPending = true;
            resetTime = millis() + 300;  

            Serial.println("[SESSION] STOP - RESET PENDING");
        }
    }
};

// BLE SERVER
class MyServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pS) { 
        deviceConnected = true; 
    }
    void onDisconnect(BLEServer* pS) { 
        deviceConnected = false;
        resetSession();
        BLEDevice::startAdvertising();
    }
};
void handleReset() {
    if (resetPending && millis() > resetTime) {
        resetSession();
        resetPending = false;
    }
}
// Promedia lecturas del modo continuo. Devuelve false si no hay suficientes.
bool measureBaseline(uint8_t wanted, uint32_t timeoutMs, float &result) {
    long sum = 0;
    uint8_t count = 0;
    uint32_t start = millis();
    while (count < wanted && millis() - start < timeoutMs) {
        if (lox.isRangeComplete()) {
            uint16_t r = lox.readRangeResult();
            if (r > 0 && r < 2000) { sum += r; count++; }
        }
        delay(1);
    }
    if (count * 2 < wanted) return false;
    result = sum / (float)count;
    return true;
}

// Re-cero al iniciar sesión: corrige que el tórax no vuelva al mismo punto.
void applyRezero() {
    float measured = 0;
    if (!measureBaseline(REZERO_SAMPLES, REZERO_TIMEOUT_MS, measured)) return;
    if (fabs(measured - factoryBaseline) > MAX_REZERO_DRIFT_MM) {
        Serial.println("[WARN] Re-cero descartado: el torax parece oprimido");
        return;
    }
    baselineDepth = measured;
    Serial.print("[OK] Re-cero: "); Serial.println(baselineDepth);
}

void setup() {
    Serial.begin(115200);
    pinMode(2, OUTPUT);

    Wire.begin(17, 18);

    // ── Inicializar VL53L0X (sensor de profundidad) ──
    if (!lox.begin()) {
        Serial.println("[ERROR] VL53L0X no detectado! Verificar cableado I2C (SDA=17, SCL=18)");
        _sensorOk = false;
    } else {
        lox.startRangeContinuous();
        Serial.println("[OK] VL53L0X inicializado");

        // Calibración inicial
        float measured = 0;
        if (measureBaseline(20, 2000, measured)) {
            baselineDepth = measured;
            factoryBaseline = measured;
            Serial.print("[OK] Baseline Depth: "); Serial.println(baselineDepth);
        } else {
            Serial.println("[ERROR] VL53L0X lecturas inválidas");
            _sensorOk = false;
            baselineDepth = 0;
        }
    }

    // HX711 eliminado físicamente — force siempre 0, sensorOk solo depende del VL53L0X
    _forceOk = true;
    

    // BLE
     uint64_t chipid = ESP.getEfuseMac();

    char bleName[20];
    sprintf(bleName, "SICAP-MAN%04X", (uint16_t)(chipid & 0xFFFF));

    Serial.println(bleName);

    BLEDevice::init(bleName);
    BLEServer *pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    BLEService *pService = pServer->createService(SERVICE_UUID);

    pTelemetryChar = pService->createCharacteristic(
        CHAR_TELEMETRY_UUID, BLECharacteristic::PROPERTY_NOTIFY
    );
    pTelemetryChar->addDescriptor(new BLE2902());

    BLECharacteristic* pCtrlChar = pService->createCharacteristic(
        CHAR_CTRL_UUID, BLECharacteristic::PROPERTY_WRITE
    );
    pCtrlChar->setCallbacks(new ControlCallbacks());

    pService->start();
    BLEDevice::getAdvertising()->addServiceUUID(SERVICE_UUID);
    BLEDevice::startAdvertising();

    Serial.println("SYSTEM READY");
}

void loop() {

    static uint32_t lastSample = 0;
    static uint32_t lastBLE = 0;

    const uint32_t SAMPLE_INTERVAL = 10; // 100Hz
    const uint32_t BLE_INTERVAL = 50;    // 20Hz

    uint32_t now = millis();

    static float d = 0;
    static float pending[5];        // lecturas nuevas desde el último paquete
    static uint8_t pendingCount = 0;
    static uint8_t invalidReadings = 0;

    // ───── LECTURA + FSM ─────

    handleReset();

    if (rezeroPending && sessionActive) {
        rezeroPending = false;
        applyRezero();
        filteredDepth = 0;
        d = 0;
        pendingCount = 0;
    }

    // El sensor entrega datos a su propio ritmo (~30 Hz por defecto): se procesa
    // cada medición completa, sin bloquear el loop ni el envío BLE.
    if (deviceConnected && sessionActive && now - lastSample >= SAMPLE_INTERVAL && lox.isRangeComplete()) {
        lastSample = now;

        uint16_t range = lox.readRangeResult();
        if (range > 0 && range < 2000) {
            invalidReadings = 0;
            _sensorOk = true;

            float rawDepth = baselineDepth - (float)range;
            if (rawDepth < 0) rawDepth = 0;

            // FILTRO
            filteredDepth = (0.5 * rawDepth) + (0.5 * filteredDepth);
            d = filteredDepth;

            updateFSM(d, now);

            if (pendingCount < 5) pending[pendingCount++] = d;
        } else if (invalidReadings < MAX_INVALID_READINGS) {
            // Una lectura mala conserva el último valor: 0 mm sería una liberación falsa.
            if (++invalidReadings == MAX_INVALID_READINGS) {
                _sensorOk = false;
                Serial.println("[WARN] Sensor sin lecturas validas");
            }
        }
    }


    // ───── ENVÍO BLE ─────
    if (deviceConnected && sessionActive && now - lastBLE >= BLE_INTERVAL) {
        lastBLE = now;

        TelemetryBatch batch;
        batch.timestamp = now;

        // Primero las lecturas reales; el resto repite la última para no retroceder.
        for(int i=0;i<5;i++){
            batch.samples[i].force = 0;
            batch.samples[i].depth = i < pendingCount ? pending[i] : d;
        }
        pendingCount = 0;

        batch.compressions = compressionCount;
        batch.bpm = (now - lastCompMs > 3000) ? 0 : (uint8_t)currentBPM;
        batch.flags = (_sensorOk ? 0x01 : 0) | 0x02 | 0x04;

        pTelemetryChar->setValue((uint8_t*)&batch, sizeof(batch));
        pTelemetryChar->notify();
    }

    // LED
    digitalWrite(2, sessionActive ? HIGH : (now/500)%2);
}