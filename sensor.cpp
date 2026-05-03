#include "sensor.h"
#include "config.h"
#include <Wire.h>

void sensorInit() {
  Wire.begin(SDA_PIN, SCL_PIN);
}

SensorResult sensorRead(float &pressure_psi, float &temp_c) {
  // Send measurement command
  Wire.beginTransmission(I2C_ADDR);
  Wire.write(0xAA);
  Wire.write(0x00);
  Wire.write(0x00);
  if (Wire.endTransmission() != 0) {
    return SENSOR_ERROR;
  }

  delay(10);  // Wait for measurement

  // Request 7 bytes: 1 status + 3 pressure + 3 temperature
  Wire.requestFrom((uint8_t)I2C_ADDR, (uint8_t)7);
  if (Wire.available() != 7) {
    return SENSOR_ERROR;
  }

  uint8_t status = Wire.read();
  uint8_t p1 = Wire.read();
  uint8_t p2 = Wire.read();
  uint8_t p3 = Wire.read();
  uint8_t t1 = Wire.read();
  uint8_t t2 = Wire.read();
  uint8_t t3 = Wire.read();

  // Status 0x40 = powered on, not busy
  if (status != 0x40) {
    return SENSOR_ERROR;
  }

  uint32_t press_counts = ((uint32_t)p1 << 16) | ((uint32_t)p2 << 8) | p3;
  uint32_t temp_counts  = ((uint32_t)t1 << 16) | ((uint32_t)t2 << 8) | t3;

  // Check for saturated output (sensor out of range)
  if (press_counts >= (uint32_t)OUT_MAX) return SENSOR_OVERRANGE;
  if (press_counts <= (uint32_t)OUT_MIN) return SENSOR_UNDERRANGE;

  // Transfer function
  pressure_psi = ((press_counts - OUT_MIN) * (P_MAX - P_MIN)) / (OUT_MAX - OUT_MIN) + P_MIN;
  temp_c = ((temp_counts * 200.0) / 16777215.0) - 50.0;

  return SENSOR_OK;
}

float psiToMmhg(float psi) {
  return psi * PSI_TO_MMHG;
}
