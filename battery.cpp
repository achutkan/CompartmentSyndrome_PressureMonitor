#include "battery.h"
#include <Arduino.h>

static float smoothedVoltage = -1.0;

void batteryInit()
{
    analogReadResolution(12);
    analogSetAttenuation(ADC_11db);
    delay(100);
}

float readBatteryVoltage()
{
    uint32_t sum = 0;
    for (int i = 0; i < 16; i++)
    {
        sum += analogReadMilliVolts(A0);
        delay(1);
    }
    
    float avg_mv = sum / 16.0;
    float voltage = (avg_mv * 2.0) / 1000.0;

    if (smoothedVoltage < 0)
    {
        smoothedVoltage = voltage;  // seed on first call — no smoothing needed
        return smoothedVoltage;     // return immediately, already accurate
    }
    
    smoothedVoltage = (0.2 * voltage) + (0.8 * smoothedVoltage);
    return smoothedVoltage;
}

int batteryPercent(float voltage)
{
    if (voltage < 2.5) return -1;
    if (voltage >= BAT_VOLT_FULL)  return 100;
    if (voltage <= BAT_VOLT_EMPTY) return 0;
    return (int)(((voltage - BAT_VOLT_EMPTY) / (BAT_VOLT_FULL - BAT_VOLT_EMPTY)) * 100.0); //assuming a linear relationship
}
