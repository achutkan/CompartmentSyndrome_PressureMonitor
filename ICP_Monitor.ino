#include "config.h"
#include "sensor.h"
#include "battery.h"
#include "filter.h"
#include "esp_pm.h"
#include "esp_system.h"
#include "esp_sleep.h"

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define LED_BUILTIN 15
#define DEEP_SLEEP_SECONDS 55  // sleep 55s so wake + connect + send fits in 60s window

// Zero offset — stored in RTC memory so it survives deep sleep
RTC_DATA_ATTR float zeroOffsetMmhg = 0.0;
RTC_DATA_ATTR int   bootCount = 0;

// Runtime state
volatile bool zeroRequested   = false;
volatile bool clientConnected = false;
volatile bool dataSent        = false;

BLECharacteristic *pCharacteristic;
BLECharacteristic *pCmdCharacteristic;

class CmdCallbacks : public BLECharacteristicCallbacks 
{
    void onWrite(BLECharacteristic *pChar) 
    {
        String val = pChar->getValue();
        if (val == "ZERO") 
        {
            zeroRequested = true;
            Serial.println("Zero command received via BLE");
        }
    }
};

class ServerCallbacks : public BLEServerCallbacks 
{
    void onConnect(BLEServer* pServer) 
    {
        clientConnected = true;
        Serial.println("BLE client connected");
    }
    void onDisconnect(BLEServer* pServer) 
    {
        clientConnected = false;
        Serial.println("BLE client disconnected");
    }
};

void sendBLE(float pressure, float temp, int bat) 
{
    if (!clientConnected) return;
    char buf[64];
    snprintf(buf, sizeof(buf), "%.2f,%.2f,%d", pressure, temp, bat);
    pCharacteristic->setValue(buf);
    pCharacteristic->notify();
    dataSent = true;
    Serial.printf("Sent: %s\n", buf);
}

void setup() 
{
    Serial.begin(115200);
    delay(500);

    bootCount++;
    Serial.printf("\n=== ICP Monitor | Boot #%d ===\n", bootCount);
    Serial.printf("Reset reason: %d\n", esp_reset_reason());

    pinMode(LED_BUILTIN, OUTPUT);
    digitalWrite(LED_BUILTIN, HIGH);

    // Read sensor
    sensorInit();
    filterInit();

    float pressure_psi = 0, temp_c = 0;
    float pressureMmhg = 0;
    bool  sensorOk = false;

    delay(200);  // let I2C bus settle before first read
    SensorResult result = sensorRead(pressure_psi, temp_c);
    Serial.printf("[Sensor] result=%d\n", result);

    if (result == SENSOR_OK) 
    {
        float rawMmhg = psiToMmhg(pressure_psi);

        if (zeroRequested) 
        {
            zeroOffsetMmhg = rawMmhg;
            zeroRequested  = false;
            Serial.printf("Zeroed. Offset = %.1f mmHg\n", zeroOffsetMmhg);
        }

        pressureMmhg = filterSample(rawMmhg - zeroOffsetMmhg);
        sensorOk = true;
    }

    // Read battery
    batteryInit();
    delay(100);
    float voltage    = readBatteryVoltage();
    int   batPercent = batteryPercent(voltage);

    Serial.printf("P: %.1f mmHg | T: %.1f C | Bat: %d%% | %s\n",
        pressureMmhg, temp_c, batPercent,
        sensorOk ? "OK" : "ERROR");

    // ── Init BLE ──
    delay(200);  // settle before BLE spike
    BLEDevice::init("ICP_Monitor");
    BLEDevice::setPower(ESP_PWR_LVL_N12);

    BLEServer *server = BLEDevice::createServer();
    server->setCallbacks(new ServerCallbacks());

    BLEService *service = server->createService(
        BLEUUID("12345678-1234-1234-1234-123456789abc"), 32);

    pCharacteristic = service->createCharacteristic(
        "abcd1234-5678-90ab-cdef-123456789abd",
        BLECharacteristic::PROPERTY_NOTIFY);
    pCharacteristic->addDescriptor(new BLE2902());

    pCmdCharacteristic = service->createCharacteristic(
        "abcd1234-5678-90ab-cdef-123456789abe",
        BLECharacteristic::PROPERTY_WRITE);
    pCmdCharacteristic->setCallbacks(new CmdCallbacks());

    service->start();

    BLEAdvertising *adv = BLEDevice::getAdvertising();
    adv->addServiceUUID("12345678-1234-1234-1234-123456789abc");
    adv->setScanResponse(true);
    adv->setMinPreferred(0x06);
    adv->setMinPreferred(0x12);
    BLEDevice::startAdvertising();
    Serial.println("Advertising...");

    // ── Wait up to 8 seconds for iOS to connect and receive data ──
    unsigned long start = millis();
    while (millis() - start < 8000) 
    {
        if (clientConnected && !dataSent) 
        {
            delay(500);  // small gap after connect before sending
            sendBLE(pressureMmhg, temp_c, batPercent);
        }
        if (dataSent) 
        {
            delay(300);  // let iOS process before we disconnect
            break;
        }
        delay(50);
    }

    if (!dataSent)
    {
        Serial.println("No client connected — sleeping anyway");
    }

    // ── Blink LED to signal going to sleep ──
    digitalWrite(LED_BUILTIN, LOW);
    delay(100);
    digitalWrite(LED_BUILTIN, HIGH);

    // ── Deep sleep ──
    Serial.printf("Sleeping for %d seconds...\n", DEEP_SLEEP_SECONDS);
    Serial.flush();
    BLEDevice::deinit(true);
    esp_sleep_enable_timer_wakeup((uint64_t)DEEP_SLEEP_SECONDS * 1000000ULL);
    esp_deep_sleep_start();
}

void loop()
{
    // Never runs — deep sleep restarts from setup() on every wake
}
