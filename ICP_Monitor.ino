#include "config.h"
#include "sensor.h"
#include "battery.h"
#include "filter.h"

// New imports for BLE
#include <NimBLEDevice.h>

// ── Runtime-adjustable settings ──
volatile uint16_t sensorIntervalMs = SENSOR_INTERVAL_MS;  // adjusted via dashboard

// ── Zero (tare) offset ──
float zeroOffsetMmhg = 0.0;
volatile bool zeroRequested = false;

// ── Last valid readings ──
float lastPressureMmhg = 0.0;
float lastTempC = 0.0;
bool  lastSensorOk = false;
bool  lastOverrange = false;

// ── Battery state ──
int  batPercent = -1;
bool batCharging = false;

// ── Timing ──
unsigned long lastSensorRead = 0;
unsigned long lastBatteryRead = 0;

// –– For BLE ––
NimBLECharacteristic *pCharacteristic;
bool deviceConnected = false;

void sendBLE(float pressure, float temp, int bat) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%.2f,%.2f,%d", pressure, temp, bat);
    pCharacteristic->setValue(buf);
    pCharacteristic->notify();
  }

void setup() {
  Serial.begin(115200);
  delay(3000);
  Serial.println("\n=== ICP Monitor ===");

  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, HIGH);  // HIGH = off (active low on XIAO)

  sensorInit();
  filterInit();
  Serial.println("Sensor initialized (I2C)");

  batteryInit();
  Serial.println("Battery monitor initialized");

  //setupWiFiAP();

  NimBLEDevice::init("ICP_Monitor");

  NimBLEServer *server = NimBLEDevice::createServer();

  NimBLEService *service = server->createService("12345678-1234-1234-1234-123456789abc");

  pCharacteristic = service->createCharacteristic(
      "abcd1234-5678-90ab-cdef-123456789abc",
      NIMBLE_PROPERTY::NOTIFY
  );


  service->start();

  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();

  // Create advertisement data
  NimBLEAdvertisementData advData;
  advData.setName("ICP_Monitor");
  advData.addServiceUUID("12345678-1234-1234-1234-123456789abc");

  // Apply it
  adv->setAdvertisementData(advData);

  // Start advertising
  adv->start();

  Serial.println("Advertising started");
}

void loop() {

  unsigned long now = millis();

  // ── Read sensor at runtime-adjustable rate ──
  if (now - lastSensorRead >= sensorIntervalMs) {
    lastSensorRead = now;

    float psi = 0, tempC = 0;
    SensorResult result = sensorRead(psi, tempC);

    lastOverrange = (result == SENSOR_OVERRANGE);
    lastSensorOk  = (result == SENSOR_OK);

    if (result == SENSOR_OK) {
      float rawMmhg = psiToMmhg(psi);

      if (zeroRequested) {
        zeroOffsetMmhg = rawMmhg;
        zeroRequested = false;
        filterInit();
        Serial.printf("Zeroed. Offset = %.1f mmHg\n", zeroOffsetMmhg);
      }

      float offsetMmhg = rawMmhg - zeroOffsetMmhg;
      lastPressureMmhg = filterSample(offsetMmhg);
      lastTempC = tempC;
    }

    // Compute Hz from current interval for the broadcast payload (float * 100 to preserve 0.1)
    // Sent as integer tenths-of-Hz so JSON stays simple: 1 = 0.1 Hz, 10 = 1 Hz, 100 = 10 Hz
    uint16_t rateTenths = (uint16_t)round(10000.0f / sensorIntervalMs);
  

    sendBLE(lastPressureMmhg, lastTempC, batPercent);


    // Blink LED on each measurement (active low on XIAO)
    digitalWrite(LED_BUILTIN, LOW);
    delay(20);
    digitalWrite(LED_BUILTIN, HIGH);

    // Serial debug — print every ~1 s regardless of sample rate
    static uint32_t lastDbgMs = 0;
    if (now - lastDbgMs >= 1000) {
      lastDbgMs = now;
      Serial.printf("P: %.1f mmHg | T: %.1f C | Bat: %d%% %s | %s | %.1f Hz | fwin=%d\n",
        lastPressureMmhg, lastTempC, batPercent,
        batCharging ? "(chg)" : "",
        lastOverrange ? "OVERRANGE" : (lastSensorOk ? "OK" : "ERROR"),
        rateTenths / 10.0f, filterGetWindow());
    }
  }

  // ── Read battery every 5 seconds ──
  if (now - lastBatteryRead >= BATTERY_INTERVAL_MS) {
    lastBatteryRead = now;
    float voltage = readBatteryVoltage();
    batPercent = batteryPercent(voltage);
    batCharging = isCharging(voltage);
  }
}
