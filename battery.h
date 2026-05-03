#ifndef BATTERY_H
#define BATTERY_H

#include <Arduino.h>

void batteryInit();
float readBatteryVoltage();
int batteryPercent(float voltage);
bool isCharging(float voltage);

#endif
