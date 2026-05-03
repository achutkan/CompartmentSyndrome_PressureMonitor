#include "filter.h"
#include "config.h"

static float   buf[FILTER_MAX_WINDOW];
static uint8_t activeWindow = FILTER_DEFAULT_WINDOW;
static uint8_t writeIdx = 0;
static uint8_t count    = 0;

void filterInit() {
  memset(buf, 0, sizeof(buf));
  writeIdx = 0;
  count    = 0;
}

void filterSetWindow(uint8_t n) {
  if (n < 1) n = 1;
  if (n > FILTER_MAX_WINDOW) n = FILTER_MAX_WINDOW;
  if (n % 2 == 0) n++;  // Enforce odd so there is always a single middle element
  activeWindow = n;
  filterInit();
}

uint8_t filterGetWindow() {
  return activeWindow;
}

float filterSample(float newSample) {
  buf[writeIdx] = newSample;
  writeIdx = (writeIdx + 1) % activeWindow;
  if (count < activeWindow) count++;

  // Copy active portion into temp array and insertion-sort it
  float tmp[FILTER_MAX_WINDOW];
  memcpy(tmp, buf, count * sizeof(float));
  for (uint8_t i = 1; i < count; i++) {
    float key = tmp[i];
    int8_t j  = i - 1;
    while (j >= 0 && tmp[j] > key) {
      tmp[j + 1] = tmp[j];
      j--;
    }
    tmp[j + 1] = key;
  }

  return tmp[count / 2];
}

bool filterReady() {
  return count >= activeWindow;
}
