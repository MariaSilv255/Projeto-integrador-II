#include "matriz.h"
#include "hardware/pio.h"

// Tratamento do PIO
#if defined(__has_include)
#  if __has_include("ws2818b.pio.h")
#    include "ws2818b.pio.h"
#  else
extern const pio_program_t ws2818b_program;
void ws2818b_program_init(PIO pio, uint sm, uint offset, uint pin, float freq);
#  endif
#else
#include "ws2818b.pio.h"
#endif

// ---------------------------------------------------------
// ALOCAÇÃO REAL DA VARIÁVEL (Sem a palavra extern)
// Como o matriz.h já foi incluído, o compilador já sabe o que é matrix_pixel_t
matrix_pixel_t leds[LED_COUNT];
// ---------------------------------------------------------

// Variáveis para uso da máquina PIO.
PIO np_pio;
uint sm;

/**
* Inicializa a máquina PIO para controle da matriz de LEDs.
*/
void npInit(uint pin) {
    uint offset = pio_add_program(pio0, &ws2818b_program);
    np_pio = pio0;

    int sm_idx = pio_claim_unused_sm(np_pio, false);
    if (sm_idx < 0) {
        np_pio = pio1;
        sm_idx = pio_claim_unused_sm(np_pio, true); 
    }
    
    sm = (uint)sm_idx;

    ws2818b_program_init(np_pio, sm, offset, pin, 800000.f);

    for (uint i = 0; i < LED_COUNT; ++i) {
        leds[i].R = 0;
        leds[i].G = 0;
        leds[i].B = 0;
    }
}

/**
* Atribui uma cor RGB a um LED.
*/
void npSetLED(const uint index, const uint8_t r, const uint8_t g, const uint8_t b) {
    if (index < LED_COUNT) {
        leds[index].R = r;
        leds[index].G = g;
        leds[index].B = b;
    }
}

/**
* Limpa o buffer de pixels.
*/
void npClear() {
    for (uint i = 0; i < LED_COUNT; ++i)
        npSetLED(i, 0, 0, 0);
}

/**
* Escreve os dados do buffer nos LEDs.
*/
void npWrite() {
    for (uint i = 0; i < LED_COUNT; ++i) {
        pio_sm_put_blocking(np_pio, sm, leds[i].G);
        pio_sm_put_blocking(np_pio, sm, leds[i].R);
        pio_sm_put_blocking(np_pio, sm, leds[i].B);
    }
}