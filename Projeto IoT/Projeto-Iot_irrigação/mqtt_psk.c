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
#include "matriz/matriz.h"

#define I2C_PORT i2c1
#define I2C_SDA 14
#define I2C_SCL 15
#define DHT11_PIN 16
#define SSID "BBJE"
#define senha "AAaa1234@"


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
char bombaStatus[20] = "0";
char solenoideStatus[20] = "0";

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
            sprintf(stemp, "{\"temperatura\": %.1f, \"umidade\": %.1f}", temp_atual, umidade_atual);
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

#define BTN_A_PIN 5
#define BTN_B_PIN 6

// Enumeração para identificar a origem/tipo do evento
typedef enum {
    EVENT_MQTT_SOLENOIDE,
    EVENT_MQTT_BOMBA,
    EVENT_BUTTON_A,
    EVENT_BUTTON_B
} event_type_t;

// Estrutura que trafegará na fila de controle
typedef struct {
    event_type_t type;
    int value; // 0 para desligar, 1 para ligar (para botões, pode ser usado como toggle se preferir)
} actuator_event_t;

// Handles globais
static QueueHandle_t xActuatorQueue = NULL;

// Estados atuais de cada lado da matriz (0 = Desligado, 1 = Ligado)
static int estado_esquerdo = 0;
static int estado_direito = 0;

/**
 * Função auxiliar para desenhar o estado atual na matriz de LEDs 5x5.
 * Lado Esquerdo: Colunas 0 e 1.
 * Centro: Coluna 2 (Mapeada opcionalmente ou deixada apagada).
 * Lado Direito: Colunas 3 and 4.
 */
void atualizar_matriz_leds() {
    npClear();
    
    for (int i = 0; i < LED_COUNT; i++) {
        // Mapeamento simplificado para matrizes 5x5 padrão da BitDogLab / Raspberry Pico
        // Se a sua matriz tiver orientação zig-zag invertida, o cálculo de coluna pode mudar,
        // mas a lógica de colunas físicas de 0 a 4 permanece:
        int coluna = i % 5; 

        if ((coluna == 0 || coluna == 1) && estado_esquerdo) {
            npSetLED(i, 0, 0, 50); // Liga Azul (Solenóide/Água) no lado esquerdo
        } 
        else if ((coluna == 3 || coluna == 4) && estado_direito) {
            npSetLED(i, 50, 0, 0); // Liga Vermelho (Bomba) no lado direito
        }
    }
    npWrite();
}

void mqtt_incoming_data_callback(const char *topic, const char *payload, size_t len) {
    actuator_event_t ev;
    
    // Tratamento para o Tópico da Solenóide (Lado Esquerdo)
    if (strstr(topic, "Equipe3/plantacoes/jardim/atuadores/solenoide") != NULL) {
        ev.type = EVENT_MQTT_SOLENOIDE;
        // Parsing simples do JSON procurando o valor da chave "solenoide"
        if (strstr(payload, "{“solenoide”: 1}") != NULL) {
            ev.value = 1;
        } else if (strstr(payload, "{“solenoide”: 0}") != NULL) {
            ev.value = 0;
        } else {
            return; // Payload inválido ignorado
        }
        xQueueSendFromISR(xActuatorQueue, &ev, NULL);
    } 
    // Tratamento para o Tópico da Bomba (Lado Direito)
    else if (strstr(topic, "Equipe3/plantacoes/jardim/atuadores/bomba") != NULL) {
        ev.type = EVENT_MQTT_BOMBA;
        // Parsing simples do JSON procurando o valor da chave "bomba"
        if (strstr(payload, "{“bomba”: 1}") != NULL) {
            ev.value = 1;
        } else if (strstr(payload, "{“bomba”: 0}") != NULL) {
            ev.value = 0;
        } else {
            return; // Payload inválido ignorado
        }
        xQueueSendFromISR(xActuatorQueue, &ev, NULL);
    }
}


void vAtuadoresTask(void *pvParameters) {
    actuator_event_t recebido;
    printf("Iniciando tarefa de controle da Matriz e Atuadores...\n");
    
    // Estado anterior dos botões para detecção de borda de descida (pressionado)
    bool btn_a_ant = true;
    bool btn_b_ant = true;

    for (;;) {
        // 1. Polling rápido dos botões (a cada 20ms para debounce de software simples)
        bool btn_a_atual = gpio_get(BTN_A_PIN);
        bool btn_b_atual = gpio_get(BTN_B_PIN);

        // Detecta clique (borda de descida: era 1/solto e virou 0/pressionado)
        if (btn_a_ant && !btn_a_atual) {
            actuator_event_t ev = {.type = EVENT_BUTTON_A, .value = 0};
            xQueueSend(xActuatorQueue, &ev, 0);
        }
        if (btn_b_ant && !btn_b_atual) {
            actuator_event_t ev = {.type = EVENT_BUTTON_B, .value = 0};
            xQueueSend(xActuatorQueue, &ev, 0);
        }

        btn_a_ant = btn_a_atual;
        btn_b_ant = btn_b_atual;

        // 2. Processa os eventos acumulados na Fila (vindo do MQTT ou dos botões)
        // Usamos um timeout curto (20ms) para não travar o pooling dos botões acima
        if (xQueueReceive(xActuatorQueue, &recebido, pdMS_TO_TICKS(20)) == pdTRUE) {
            switch (recebido.type) {
                case EVENT_MQTT_SOLENOIDE:
                    estado_esquerdo = recebido.value;
                    printf("MQTT: Solenóide alterada para %d\n", estado_esquerdo);
                    break;

                case EVENT_MQTT_BOMBA:
                    estado_direito = recebido.value;
                    printf("MQTT: Bomba alterada para %d\n", estado_direito);
                    break;

                case EVENT_BUTTON_A:
                    estado_esquerdo = !estado_esquerdo; // Inverte o estado atual (Toggle)
                    printf("Botão A: Solenóide (Esquerdo) alternado para %d\n", estado_esquerdo);
                    sprintf(solenoideStatus, "{“solenoide”: %d}", estado_esquerdo);
                    cyw43_arch_lwip_begin();
                    mqtt_comm_publish("Equipe3/plantacoes/jardim/atuadores/solenoide", solenoideStatus, strlen(solenoideStatus));
                    cyw43_arch_lwip_end();
                    break;

                case EVENT_BUTTON_B:
                    estado_direito = !estado_direito; // Inverte o estado atual (Toggle)
                    printf("Botão B: Bomba (Direito) alternado para %d\n", estado_direito);
                    sprintf(bombaStatus, "{“bomba”: %d}", estado_direito);
                    cyw43_arch_lwip_begin();
                    mqtt_comm_publish("Equipe3/plantacoes/jardim/atuadores/bomba", bombaStatus, strlen(bombaStatus));
                    cyw43_arch_lwip_end();
                    break;
            }
            // Atualiza fisicamente os leds após qualquer mudança de estado
            atualizar_matriz_leds();
        }
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
    BaseType_t task3 = xTaskCreate(vAtuadoresTask, "atuadores Task", 512, NULL, 1, NULL);

    // Verificação de segurança
    if (task1 != pdPASS || task2 != pdPASS || task3 != pdPASS) {
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
    npInit(LED_PIN);
    npClear();

    //Ativação do led verde
    gpio_init(led_pin_green);
    gpio_set_dir(led_pin_green, GPIO_OUT);
    //Ativação do led vermelho
    gpio_init(led_pin_red);
    gpio_set_dir(led_pin_red, GPIO_OUT);
    //ativação dos botões
    gpio_init(BTN_A_PIN); // B_A
    gpio_set_dir(BTN_A_PIN, GPIO_IN);
    gpio_pull_up(BTN_A_PIN);
    gpio_init(BTN_B_PIN);
    gpio_set_dir(BTN_B_PIN, GPIO_IN);
    gpio_pull_up(BTN_B_PIN);
    
    xOLEDMutex = xSemaphoreCreateMutex();

    xActuatorQueue = xQueueCreate(10, sizeof(actuator_event_t));
    if (xActuatorQueue == NULL) {
        printf("Falha ao criar a fila dos atuadores.\n");
    }

    if (xOLEDMutex != NULL) {
        xTaskCreate(vSetupTask, "setup Task", 1024, NULL, 2, NULL);

        vTaskStartScheduler();
    } else {
        printf("Falha ao criar o mutex para o OLED.\n");
    }
 
    while(1){};
    
}