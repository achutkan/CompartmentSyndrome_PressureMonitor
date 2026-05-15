#ifndef CONFIG_H
#define CONFIG_H

// I2C Pin Definitions
#define SDA_PIN       D4
#define SCL_PIN       D5

// Sensor Configuration
#define I2C_ADDR      0x28    // Honeywell ABP2 default address


// Honeywell ABP2 Transfer Function (10%–90% calibration)
const float P_MIN   = 0.0;           // Min pressure (psi)
const float P_MAX   = 1.0;           // Max pressure (psi)
const float OUT_MIN = 1677722.0;     // 10% of 2^24
const float OUT_MAX = 15099494.0;    // 90% of 2^24

// Unit conversion
const float PSI_TO_MMHG = 51.7149;

// Battery Monitoring
#define BAT_ADC_PIN   A0      // Battery voltage A0 pin, 200k ohm resistors from negative and positive battery pins to A0

// Battery voltage thresholds (3.7V LiPo)
const float BAT_VOLT_FULL    = 4.13; //rough estimate from battery, adjust as needed
const float BAT_VOLT_EMPTY   = 3.0;

// WiFi Access Point, not needed for bluetooth version
//#define AP_SSID     "ICP-Monitor"
//#define AP_PASSWORD "pressure"

// Signal Filtering
#define FILTER_MAX_WINDOW      21     // Hard maximum window size (array allocation limit; must be odd)
#define FILTER_DEFAULT_WINDOW   5     // Window used on startup

// Timing
#define SENSOR_INTERVAL_MS   60000  // 1 sample per minute
#define BATTERY_INTERVAL_MS  300000 // check battery every 5 minutes

#endif
