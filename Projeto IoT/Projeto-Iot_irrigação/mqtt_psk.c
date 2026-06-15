#include "pico/stdlib.h"
#include "FreeRTOS.h"
#include "task.h"
#include <stdio.h>
#include "hardware/adc.h"
#include <string.h>
#include "inc/ssd1306.h"
#include "hardware/i2c.h"
#include <stdlib.h>
#include <queue.h>
#include "pico/cyw43_arch.h"        // Driver WiFi para Pico W
#include "include/wifi_conn.h"      // Funções personalizadas de conexão WiFi
#include "include/mqtt_comm.h"      // Funções personalizadas para MQTT
#include "dht/dht.h"
#include "semphr.h"

#define I2C_PORT i2c1
#define I2C_SDA 14
#define I2C_SCL 15
#define DHT11_PIN 16
//#define SSID "BBJE"
//#define senha "AAaa1234@"
#define SSID "Jose_Francisco"
#define senha "27061954"

SemaphoreHandle_t xOLEDMutex;
uint8_t ssd[ssd1306_buffer_length];
const uint led_pin_green = 11;
const uint led_pin_red = 13;
char umidadadeSolo[50] = "none";
char soloDisplay[50] = "none";
float umidadeSoloValor = 0.0f;
char temp[30] = "";
char stemp[100];
char stempDisplay[100];

static QueueHandle_t xQueue = NULL;
  // Preparar área de renderização para o display (ssd1306_width pixels por ssd1306_n_pages páginas)
  struct render_area frame_area = {
      start_column : 0,
      end_column : ssd1306_width - 1,
      start_page : 0,
      end_page : ssd1306_n_pages - 1
  };

void setup_oled(){
    // Inicialização do i2c
  i2c_init(i2c1, ssd1306_i2c_clock * 1000);
  gpio_set_function(I2C_SDA, GPIO_FUNC_I2C);
  gpio_set_function(I2C_SCL, GPIO_FUNC_I2C);
  gpio_pull_up(I2C_SDA);
  gpio_pull_up(I2C_SCL);

  // Processo de inicialização completo do OLED SSD1306
  ssd1306_init();

  calculate_render_area_buffer_length(&frame_area);

  // zera o display inteiro
  
  memset(ssd, 0, ssd1306_buffer_length);
  render_on_display(ssd, &frame_area);
}

void vSensorTempTask(){
    printf("Iniciando tarefa de leitura do sensor DHT11...\n");
    for(;;)
    {
        float temp_atual = 0.0f;
        float umidade_atual = 0.0f;

        initialize_wait();
        start_signal(DHT11_PIN);
        if (read_dht11(DHT11_PIN, &temp_atual, &umidade_atual)) {
            printf("Sucesso! Temperatura: %.1f C, Umidade: %.1f %%\n", temp_atual, umidade_atual);
            sprintf(stemp, "{\"dispositivo\": \"placaBruno\",\"temperatura\": %.1f, \"umidade\": %.1f}", temp_atual, umidade_atual);
            cyw43_arch_lwip_begin();
            mqtt_comm_publish("Equipe3/plantacoes/jardim/sensores/dht22", stemp, strlen(stemp));
            cyw43_arch_lwip_end();
        } else {
            printf("Falha ao ler o sensor DHT22.\n");
        }

        sprintf(stempDisplay, "T%.1f U%.1f", temp_atual, umidade_atual);
        
        if (xSemaphoreTake(xOLEDMutex, portMAX_DELAY) == pdTRUE) {
            ssd1306_draw_string(ssd, 0, 0, "               "); 
            render_on_display(ssd, &frame_area);
            ssd1306_draw_string(ssd, 0, 0, stempDisplay);
            render_on_display(ssd, &frame_area);
            xSemaphoreGive(xOLEDMutex); // Libera o display
        }
        
        vTaskDelay(pdMS_TO_TICKS(100));
        gpio_put(led_pin_green, 0);
        gpio_put(led_pin_red, 0);
        vTaskDelay(pdMS_TO_TICKS(9900));
    }
}

void vbuttonsTask(){
    printf("Iniciando tarefa de leitura dos botões e umidade do solo...\n");
    for(;;)
    {
        //leituras no eixo  y para simular umidade do solo
        adc_select_input(0);
        uint adc_y_raw = adc_read();
        umidadeSoloValor = adc_y_raw / 4095.0f * 100.0f; // Convertendo para porcentagem
        
        sprintf(umidadadeSolo, "%.1f%%", umidadeSoloValor);
        sprintf(soloDisplay, "US %.1f", umidadeSoloValor);
            
        if (xSemaphoreTake(xOLEDMutex, portMAX_DELAY) == pdTRUE) {
            ssd1306_draw_string(ssd, 0, 15, "               "); 
            render_on_display(ssd, &frame_area);
            ssd1306_draw_string(ssd, 0, 15, soloDisplay);
            render_on_display(ssd, &frame_area);
            xSemaphoreGive(xOLEDMutex); // Libera o display
        }
        
        printf("Umidade do solo: %.2f\n", umidadeSoloValor);
        
        cyw43_arch_lwip_begin();
        mqtt_comm_publish("Equipe3/plantacoes/jardim/sensores/higrometro", umidadadeSolo, strlen(umidadadeSolo));
        cyw43_arch_lwip_end();
        
        vTaskDelay(pdMS_TO_TICKS(100));
        gpio_put(led_pin_green, 0);
        gpio_put(led_pin_red, 0);
        vTaskDelay(pdMS_TO_TICKS(10000));
    }
}

void vSetupTask(void *pvParameters) {
    printf("Iniciando conexao Wi-Fi...\n");
    connect_to_wifi(SSID, senha);
    
    printf("Conectando ao broker MQTT...\n");
    mqtt_setup("placaBruno", "201.23.7.15", "equipe3", "equipe3@tsi");

    printf("Aguardando negociacao MQTT...\n");
    vTaskDelay(pdMS_TO_TICKS(3000)); 

    printf("Iniciando tarefas dos sensores...\n");
    
    // Tentativa de criação com stack menor (512 palavras) e salvando o resultado
    BaseType_t task1 = xTaskCreate(vSensorTempTask, "sensor Task", 512, NULL, 1, NULL);
    BaseType_t task2 = xTaskCreate(vbuttonsTask, "botoes Task", 512, NULL, 1, NULL);

    // Verificação de segurança
    if (task1 != pdPASS || task2 != pdPASS) {
        printf("ERRO FATAL: Memoria (Heap) insuficiente para criar as tarefas!\n");
    } else {
        printf("SUCESSO: Tarefas cadastradas no sistema.\n");
    }

    vTaskDelete(NULL);
}

int main()
{
    stdio_init_all();
    adc_init();
    setup_oled();
    //Inicialização dos eixo y do joystick
    adc_gpio_init(26); //eixo Y

    //Ativação do led verde
    gpio_init(led_pin_green);
    gpio_set_dir(led_pin_green, GPIO_OUT);
    //Ativação do led vermelho
    gpio_init(led_pin_red);
    gpio_set_dir(led_pin_red, GPIO_OUT);
    //ativação dos botões
    gpio_init(5); // B_A
    gpio_set_dir(5, GPIO_IN);
    gpio_pull_up(5);
    gpio_init(6);
    gpio_set_dir(6, GPIO_IN);
    gpio_pull_up(6);
    
    xOLEDMutex = xSemaphoreCreateMutex();

    if (xOLEDMutex != NULL) {
        xTaskCreate(vSetupTask, "setup Task", 1024, NULL, 2, NULL);

        vTaskStartScheduler();
    } else {
        printf("Falha ao criar o mutex para o OLED.\n");
    }
 
    while(1){};
    
}