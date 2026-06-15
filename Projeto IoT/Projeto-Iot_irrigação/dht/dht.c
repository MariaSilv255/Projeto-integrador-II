#include <stdio.h>
#include "pico/stdlib.h"
#include <stdbool.h>
#include "dht.h" // Inclui o seu novo header
#include "FreeRTOS.h"
#include "task.h"

void dec2bin(uint16_t n)
{
    for (int c = 15; c >= 0; c--)
    {
        putchar((n & (1 << c)) ? '1' : '0');
    }
}

void dec2bin8(uint8_t n)
{
    for (int c = 7; c >= 0; c--)
    {
        putchar((n & (1 << c)) ? '1' : '0');
    }
}

void initialize_wait(void)
{
    sleep_us(2000);
}

void start_signal(uint dht11_pin)
{
    gpio_init(dht11_pin);
    gpio_set_dir(dht11_pin, GPIO_OUT);

    gpio_put(dht11_pin, 0);
    vTaskDelay(pdMS_TO_TICKS(18)); // Espera 18ms corretos

    gpio_put(dht11_pin, 1);
    sleep_us(30); // Correção: espera apenas 30 microssegundos (busy-wait)
    
    gpio_set_dir(dht11_pin, GPIO_IN); // Deixa em modo entrada para ouvir o sensor
}

// Modificado para receber os ponteiros e retornar um status
bool read_dht11(uint dht11_pin, float *temperature, float *humidity)
{
    uint16_t rawHumidity = 0;
    uint16_t rawTemperature = 0;
    uint8_t checkSum = 0;
    uint16_t data = 0;

    uint8_t humi, humd, tempi, tempd;
    
    uint32_t startTime;
    uint32_t live;
    //taskENTER_CRITICAL();
    for (int8_t i = -3; i < 80; i++)
    {
        startTime = time_us_32();

        while (gpio_get(dht11_pin) == ((i & 1) ? 1 : 0))
        {
            live = time_us_32() - startTime;
            if (live > 200)
            {
                //taskEXIT_CRITICAL();
                // Timeout no pino
                return false; 
            }
        }

        if (i >= 0 && (i & 1))
        {
            data <<= 1;

            if (live > 30)
            {
                data |= 1;
            }
        }

        switch (i)
        {
            case 31:
                rawHumidity = data;
                break;

            case 63:
                rawTemperature = data;
                break;

            case 79:
                checkSum = data;
                data = 0;
                break;
        }
        
    }
    //taskEXIT_CRITICAL();

    humi = rawHumidity >> 8;
    humd = rawHumidity & 0xFF;

    tempi = rawTemperature >> 8;
    tempd = rawTemperature & 0xFF;

    // Verifica se a leitura é válida através do checksum
    if (checkSum == (uint8_t)(tempi + tempd + humi + humd))
    {
        // Se passarem ponteiros válidos, salva os valores convertendo para float
        if (humidity != NULL) {
            // Junta os 8 bits altos com os 8 bits baixos e divide por 10
            uint16_t raw_h = (humi << 8) | humd;
            *humidity = (float)raw_h / 10.0f;
        }
        
        if (temperature != NULL) {
            // Junta os 8 bits altos com os 8 bits baixos
            uint16_t raw_t = (tempi << 8) | tempd;
            
            // Mascara os 15 bits de valor (ignora o bit de sinal) e divide por 10
            float t = (float)(raw_t & 0x7FFF) / 10.0f;
            
            // O bit 15 (0x8000) indica se a temperatura é negativa
            if (raw_t & 0x8000) {
                t = -t; 
            }
            *temperature = t;
        }
        return true; 
    }
        else
    {
        return false;
    }
}