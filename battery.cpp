#include "battery.h"
#include "config.h"

void batteryInit() {
  analogReadResolution(12);
  pinMode(BAT_ADC_PIN, INPUT);

  // Print raw ADC value at startup to help debug pin/divider issues
  delay(100);
  uint32_t raw = analogReadMilliVolts(BAT_ADC_PIN);
  Serial.printf("[Battery] Raw ADC on A0: %lu mV  (x2 = %.2f V)\n", raw, (raw * 2.0) / 1000.0);
}

float readBatteryVoltage() {
  // Take 16 samples and average for stability
  uint32_t sum = 0;
  for (int i = 0; i < 16; i++) {
    sum += analogReadMilliVolts(BAT_ADC_PIN);
  }
  float avg_mv = sum / 16.0;

  // XIAO ESP32-C5 has a 1:2 resistor divider on the battery pin
  float voltage = (avg_mv * 2.0) / 1000.0;
  return voltage;
}

// Returns 0-100, or -1 if no battery detected (USB only)
int batteryPercent(float voltage) {
  if (voltage < 2.5) return -1;  // No battery / floating pin
  if (voltage >= BAT_VOLT_FULL)  return 100;
  if (voltage <= BAT_VOLT_EMPTY) return 0;
  return (int)(((voltage - BAT_VOLT_EMPTY) / (BAT_VOLT_FULL - BAT_VOLT_EMPTY)) * 100.0);
}

bool isCharging(float voltage) {
  return voltage > BAT_VOLT_CHARGING;
}
