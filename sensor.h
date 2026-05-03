#ifndef SENSOR_H
#define SENSOR_H

#include <Arduino.h>

enum SensorResult {
  SENSOR_OK,
  SENSOR_ERROR,      // I2C failure / bad status byte
  SENSOR_OVERRANGE,  // Pressure above sensor max (counts saturated high)
  SENSOR_UNDERRANGE  // Pressure below sensor min (counts saturated low)
};

void sensorInit();
SensorResult sensorRead(float &pressure_psi, float &temp_c);
float psiToMmhg(float psi);

#endif
