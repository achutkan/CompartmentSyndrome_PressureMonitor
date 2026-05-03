#ifndef CONFIG_H
#define CONFIG_H

// ── I2C Pin Definitions ──
#define SDA_PIN       D4
#define SCL_PIN       D5

// ── Sensor Configuration ──
#define I2C_ADDR      0x28    // Honeywell ABP2 default address

// Honeywell ABP2 Transfer Function (10%–90% calibration)
const float P_MIN   = 0.0;           // Min pressure (psi)
const float P_MAX   = 1.0;           // Max pressure (psi)
const float OUT_MIN = 1677722.0;     // 10% of 2^24
const float OUT_MAX = 15099494.0;    // 90% of 2^24

// Unit conversion
const float PSI_TO_MMHG = 51.7149;

// ── Battery Monitoring ──
#define BAT_ADC_PIN   A0      // Battery voltage ADC pin
// Note: On XIAO ESP32-C5, battery voltage reading may require
// enabling via a control pin. Adjust if your board revision differs.

// Battery voltage thresholds (3.7V LiPo)
const float BAT_VOLT_FULL    = 4.2;
const float BAT_VOLT_EMPTY   = 3.0;
const float BAT_VOLT_CHARGING = 4.15;  // Above this = likely charging

// ── WiFi Access Point ──
#define AP_SSID     "ICP-Monitor"
#define AP_PASSWORD "pressure"

// ── Signal Filtering ──
#define FILTER_MAX_WINDOW      21     // Hard maximum window size (array allocation limit; must be odd)
#define FILTER_DEFAULT_WINDOW   5     // Window used on startup

// ── Timing ──
#define SENSOR_INTERVAL_MS   100    // Read sensor at 10 Hz
#define BATTERY_INTERVAL_MS  5000   // Read battery every 5 seconds

#endif
