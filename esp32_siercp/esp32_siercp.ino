#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>
#include <HX711.h>
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
};

// HARDWARE
HX711 scale;
Adafruit_VL53L0X lox = Adafruit_VL53L0X();

// BLE
BLECharacteristic* pTelemetryChar = NULL;
bool deviceConnected = false;
bool sessionActive = false;

// VARIABLES CLÍNICAS
float baselineDepth = 0;
float filteredDepth = 0;
float filteredForce = 0;

enum State { IDLE, PRESSING, HOLDING, RELEASING };
bool inCompression = false;
State state = IDLE;
bool resetPending = false;
uint32_t resetTime = 0;
uint8_t confirmCount = 0;
uint32_t lastCompressionTime = 0;

int compressionCount = 0;
unsigned long lastCompMs = 0;
float currentBPM = 0;

// PARÁMETROS
const float DEPTH_DOWN = 15.0;
const float DEPTH_UP   = 8.0;
const uint8_t CONFIRM  = 2;
const uint32_t COOLDOWN = 180;

// RESET TOTAL
void resetSession() {

    compressionCount = 0;
    currentBPM = 0;
    lastCompMs = 0;

    state = IDLE;
    confirmCount = 0;

    filteredDepth = 0;
    filteredForce = 0;

    inCompression = false;

    Serial.println("[SYSTEM] RESET COMPLETO SEGURO");
}
// FSM
void updateFSM(float depth, uint32_t now) {

    bool down = depth > DEPTH_DOWN;
    bool up   = depth < DEPTH_UP;

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

                    state = IDLE;
                    confirmCount = 0;
                }
            } else { state = HOLDING; confirmCount = 0; }
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
            resetSession();          // limpia estado base
            sessionActive = true;

            resetPending = false;    // cancela resets pendientes
            Serial.println("[SESSION] START");
        }

        // STOP (solo detiene streaming + agenda reset)
        else if (cmd == 0x00) {
            sessionActive = false;

            resetPending = true;
            resetTime = millis() + 300;  // delay seguro

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
void setup() {
    Serial.begin(115200);
    pinMode(2, OUTPUT);

    Wire.begin(17, 18);
    lox.begin();
    lox.startRangeContinuous();

    scale.begin(4, 5);
    scale.set_scale(2280.f);
    scale.tare();

    // Calibración inicial
    long sum = 0;
    for(int i=0;i<20;i++){ sum += lox.readRange(); delay(20); }
    baselineDepth = sum / 20.0;

    // BLE
    BLEDevice::init("SIERCP_PRO");
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

    static float f = 0;
    static float d = 0;

    // ───── LECTURA + FSM ─────

    handleReset();  

    if (deviceConnected && sessionActive && now - lastSample >= SAMPLE_INTERVAL) {
        lastSample = now;

        float rawForce = scale.is_ready() ? scale.get_units(1) : 0;
        if (rawForce < 0) rawForce = 0;

        uint16_t range = lox.readRange();
        float rawDepth = (baselineDepth - (float)range);
        if (rawDepth < 0) rawDepth = 0;

        // FILTRO
        filteredDepth = (0.5 * rawDepth) + (0.5 * filteredDepth);
        filteredForce = (0.4 * rawForce) + (0.6 * filteredForce);

        d = filteredDepth;
        f = filteredForce;

        updateFSM(d, now);
    }

    // ───── ENVÍO BLE ─────
    if (deviceConnected && sessionActive && now - lastBLE >= BLE_INTERVAL) {
        lastBLE = now;

        TelemetryBatch batch;
        batch.timestamp = now;

        for(int i=0;i<5;i++){
            batch.samples[i].force = f;
            batch.samples[i].depth = d;
        }

        batch.compressions = compressionCount;
        batch.bpm = (now - lastCompMs > 3000) ? 0 : (uint8_t)currentBPM;

        pTelemetryChar->setValue((uint8_t*)&batch, sizeof(batch));
        pTelemetryChar->notify();
    }

    // LED
    digitalWrite(2, sessionActive ? HIGH : (now/500)%2);
}