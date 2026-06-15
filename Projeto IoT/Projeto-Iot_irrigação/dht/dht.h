#ifndef DHT_H
#define DHT_H

#include "pico/stdlib.h"
#include <stdbool.h>

// Declaração das funções auxiliares
void dec2bin(uint16_t n);
void dec2bin8(uint8_t n);
void initialize_wait(void);
void start_signal(uint dht11_pin);

/* Função principal de leitura
 * Parâmetros:
 * - dht11_pin: o pino GPIO onde o sensor está conectado
 * - temperature: ponteiro para a variável onde a temperatura será salva
 * - humidity: ponteiro para a variável onde a umidade será salva
 * Retorno: true se a leitura e o checksum foram um sucesso, false em caso de erro
 */
bool read_dht11(uint dht11_pin, float *temperature, float *humidity);

#endif // DHT_H