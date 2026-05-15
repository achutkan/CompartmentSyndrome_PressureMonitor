#ifndef BATTERY_H
#define BATTERY_H

#include "config.h"

#define BAT_READ_ENABLE_PIN 14

void batteryInit();
float readBatteryVoltage();
int batteryPercent(float voltage);

#endif