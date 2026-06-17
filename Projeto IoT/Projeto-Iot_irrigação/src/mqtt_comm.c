#include "lwip/apps/mqtt.h"       // Biblioteca MQTT do lwIP
#include "include/mqtt_comm.h"    // Header file com as declarações locais
// Base: https://github.com/BitDogLab/BitDogLab-C/blob/main/wifi_button_and_led/lwipopts.h
#include "lwipopts.h"             // Configurações customizadas do lwIP
#include "pico/stdlib.h"
#include <string.h> // Útil se for manipular as strings recebidas
#include "pico/cyw43_arch.h"

extern void mqtt_incoming_data_callback(const char *topic, const char *payload, size_t len);

#define MQTT_STATUS_TOPIC "Equipe3/dispositivos/raspberry-01/status"
#define PAYLOAD_ONLINE    "online"
#define PAYLOAD_OFFLINE   "offline"

/* Callback 1: Chamado quando o broker começa a enviar uma mensagem
*/
static char string_topico_atual[64];
static void mqtt_incoming_publish_cb(void *arg, const char *topic, u32_t tot_len) {
    printf("Mensagem recebida no tópico: %s (Tamanho: %u bytes)\n", topic, tot_len);
    // Guarda o nome do tópico para sabermos quem enviou quando o dado chegar
    strncpy(string_topico_atual, topic, sizeof(string_topico_atual) - 1);
}

/* Callback 2: Chamado para entregar os dados (payload) da mensagem
*/
static void mqtt_incoming_data_cb(void *arg, const u8_t *data, u16_t len, u8_t flags) {
    // Usamos %.*s para imprimir com segurança, pois o payload pode não ter o '\0' no final
    printf("Conteúdo da mensagem: %.*s\n", len, (const char *)data);
    
    // Passa o tópico salvo no callback anterior (string_topico_atual) 
    // e o payload recebido agora para a fila do FreeRTOS.
    mqtt_incoming_data_callback(string_topico_atual, (const char *)data, len);
    // ====================================================================

    // A flag MQTT_DATA_FLAG_LAST indica se este é o último pedaço da mensagem
    if (flags & MQTT_DATA_FLAG_LAST) {
        printf("Fim da mensagem recebida.\n");
    }
}
/* Variável global estática para armazenar a instância do cliente MQTT
 * 'static' limita o escopo deste arquivo */
static mqtt_client_t *client;
/* Callback de confirmação de publicação
 * Chamado quando o broker confirma recebimento da mensagem (para QoS > 0)
 * Parâmetros:
 *   - arg: argumento opcional
 *   - result: código de resultado da operação */
static void mqtt_pub_request_cb(void *arg, err_t result) {
    if (result == ERR_OK) {
        printf("Publicação MQTT enviada com sucesso!\n");
        gpio_put(11, 1);
    } else {
        printf("Erro ao publicar via MQTT: %d\n", result);
        gpio_put(13, 1);
        
    }
}
/* Callback de conexão MQTT - chamado quando o status da conexão muda
 * Parâmetros:
 *   - client: instância do cliente MQTT
 *   - arg: argumento opcional (não usado aqui)
 *   - status: resultado da tentativa de conexão */
static void mqtt_connection_cb(mqtt_client_t *client, void *arg, mqtt_connection_status_t status) {
    if (status == MQTT_CONNECT_ACCEPTED) {
        printf("Conectado ao broker MQTT com sucesso!\n");
        err_t err = mqtt_publish(
            client, 
            MQTT_STATUS_TOPIC, 
            PAYLOAD_ONLINE, 
            strlen(PAYLOAD_ONLINE), 
            1,  // QoS 1
            1,  // RETAIN = 1 (Importante!)
            mqtt_pub_request_cb, 
            NULL
        );

        if (err != ERR_OK) {
            printf("Erro ao iniciar a publicação do status online: %d\n", err);
        }
        mqtt_comm_subscribe("Equipe3/plantacoes/jardim/atuadores/solenoide", 0);
        mqtt_comm_subscribe("Equipe3/plantacoes/jardim/atuadores/bomba", 0);
    } else {
        printf("Falha ao conectar ao broker, código: %d\n", status);
    }
}

/* Função para configurar e iniciar a conexão MQTT
 * Parâmetros:
 *   - client_id: identificador único para este cliente
 *   - broker_ip: endereço IP do broker como string (ex: "192.168.1.1")
 *   - user: nome de usuário para autenticação (pode ser NULL)
 *   - pass: senha para autenticação (pode ser NULL) */
void mqtt_setup(const char *client_id, const char *broker_ip, const char *user, const char *pass) {
    ip_addr_t broker_addr;  // Estrutura para armazenar o IP do broker
    
    // Converte o IP de string para formato numérico
    if (!ip4addr_aton(broker_ip, &broker_addr)) {
        printf("Erro no IP\n");
        return;
    }

    // Cria uma nova instância do cliente MQTT
    client = mqtt_client_new();
    if (client == NULL) {
        printf("Falha ao criar o cliente MQTT\n");
        return;
    }

    mqtt_set_inpub_callback(client, mqtt_incoming_publish_cb, mqtt_incoming_data_cb, NULL);

   
 // Configura as informações de conexão do cliente
    struct mqtt_connect_client_info_t ci = {
        .client_id = client_id,  // ID do cliente
        .client_user = user,     // Usuário (opcional)
        .client_pass = pass,      // Senha (opcional)
        .keep_alive = 60, // Broker vai esperar 60s antes de considerar o dispositivo morto
        .will_topic = MQTT_STATUS_TOPIC, // Tópico para a mensagem de "last will"
        .will_msg = PAYLOAD_OFFLINE, // Mensagem que será publicada se o cliente
        .will_qos = 1, // QoS da mensagem de "last will"
        .will_retain = 1 // A mensagem de "last will" deve ser retida pelo broker
    };

    // Inicia a conexão com o broker
    // Parâmetros:
    //   - client: instância do cliente
    //   - &broker_addr: endereço do broker
    //   - 1883: porta padrão MQTT
    //   - mqtt_connection_cb: callback de status
    //   - NULL: argumento opcional para o callback
    //   - &ci: informações de conexão
    cyw43_arch_lwip_begin();
    err_t err = mqtt_client_connect(client, &broker_addr, 1883, mqtt_connection_cb, NULL, &ci);
    cyw43_arch_lwip_end();
}

/* Função para publicar dados em um tópico MQTT
 * Parâmetros:
 *   - topic: nome do tópico (ex: "sensor/temperatura")
 *   - data: payload da mensagem (bytes)
 *   - len: tamanho do payload */
void mqtt_comm_publish(const char *topic, const uint8_t *data, size_t len) {
    // Envia a mensagem MQTT
    err_t status = mqtt_publish(
        client,              // Instância do cliente
        topic,               // Tópico de publicação
        data,                // Dados a serem enviados
        len,                 // Tamanho dos dados
        0,                   // QoS 0 (nenhuma confirmação)
        1,                   // reter mensagem
        mqtt_pub_request_cb, // Callback de confirmação
        NULL                 // Argumento para o callback
    );

    if (status != ERR_OK) {
        printf("mqtt_publish falhou ao ser enviada: %d\n", status);
        gpio_put(13, 1);
    }
}

/* Callback de confirmação de inscrição
 * Chamado quando o broker confirma que fomos inscritos no tópico */
static void mqtt_sub_request_cb(void *arg, err_t result) {
    if (result == ERR_OK) {
        printf("Inscrição no tópico realizada com sucesso!\n");
    } else {
        printf("Erro ao se inscrever no tópico: %d\n", result);
    }
}

/* Função para se inscrever em um tópico MQTT
 * Parâmetros:
 * - topic: nome do tópico (ex: "sensor/comandos")
 * - qos: Qualidade de serviço (geralmente 0 ou 1) */
void mqtt_comm_subscribe(const char *topic, u8_t qos) {
    if (client != NULL && mqtt_client_is_connected(client)) {
        err_t status = mqtt_sub_unsub(
            client,               // Instância do cliente
            topic,                // Tópico para se inscrever
            qos,                  // QoS desejado
            mqtt_sub_request_cb,  // Callback de confirmação
            NULL,                 // Argumento para o callback
            1                     // 1 = Subscribe, 0 = Unsubscribe
        );

        if (status != ERR_OK) {
            printf("Falha ao enviar requisição de inscrição: %d\n", status);
        }
    } else {
        printf("Erro: Cliente não está conectado ao broker.\n");
    }
}