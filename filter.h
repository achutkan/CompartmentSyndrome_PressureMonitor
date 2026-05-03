#ifndef FILTER_H
#define FILTER_H

#include <Arduino.h>

// Initialize (or reset) the filter — also called after zeroing
void filterInit();

// Feed a new raw sample. Returns the median of the last filterGetWindow() samples.
float filterSample(float newSample);

// Change the window size at runtime (enforces odd, clamps to FILTER_MAX_WINDOW).
// Automatically resets the filter buffer.
void filterSetWindow(uint8_t n);

// Returns the currently active window size in samples.
uint8_t filterGetWindow();

// True once the buffer is full (no startup transient)
bool filterReady();

#endif
