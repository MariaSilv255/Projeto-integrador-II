#ifndef MATRIZ_H
#define MATRIZ_H

#include <stdint.h>
#include "pico/stdlib.h"

// 1. Definições de macros aqui
#define LED_COUNT 25
#define LED_PIN 7

// 2. Definição da estrutura apenas UMA vez aqui no Header
typedef struct {
    uint8_t G, R, B;
} matrix_pixel_t;

// 3. O extern fica APENAS aqui no Header
extern matrix_pixel_t leds[LED_COUNT];

// Protótipos das funções
void npInit(uint pin);
void npSetLED(const uint index, const uint8_t r, const uint8_t g, const uint8_t b);
void npClear(void);
void npWrite(void);

#endif // MATRIZ_H