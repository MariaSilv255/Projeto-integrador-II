#include <stdio.h>
#include <string.h>
#include <time.h>
#include "pico/stdlib.h"
#include "pico/cyw43_arch.h"
#include "lwip/altcp.h"
#include "lwip/altcp_tls.h"
#include "lwip/dns.h"
#include "lwip/apps/sntp.h"
#include "lwip/pbuf.h"
#include "MQTTPacket.h"
#include "client_chain_data.h"
#include "key_data.h"
#include "ca_data.h"


// --- Configurações de Rede e Broker ---
#define WIFI_SSID           "BBJE_2G-EXT"
#define WIFI_PASSWORD       "AAaa1234"
#define SERVER_NAME         "brokermqtt.eastus-1.ts.eventgrid.azure.net"
#define MQTT_PORT           8883

const char *client_id = "Bruno"; 
const char *username = "?HostName=brokermqtt.eastus-1.ts.eventgrid.azure.net&AuthName=client1-authn-ID";
const char *password = NULL;

// --- Estrutura da Camada de Rede para o Paho MQTT ---
typedef struct Network Network;
struct Network {
    struct altcp_pcb *pcb;
    int (*mqttread)(Network*, unsigned char*, int, int);
    int (*mqttwrite)(Network*, unsigned char*, int, int);
};

// --- Buffers Circulares para Recepção Assíncrona do LwIP ---
#define RX_BUFFER_SIZE 4096
static uint8_t g_rx_buffer[RX_BUFFER_SIZE];
static volatile int g_rx_head = 0;
static volatile int g_rx_tail = 0;

static volatile bool g_tls_connected = false;
static volatile bool g_tls_conn_error = false;
static ip_addr_t g_broker_ip;
static volatile bool g_dns_resolved = false;

// --- Implementação das funções de Leitura/Escrita do Paho MQTT ---
int altcp_network_read(Network* n, unsigned char* buffer, int len, int timeout_ms) {
    int bytes_read = 0;
    absolute_time_t timeout = make_timeout_time_ms(timeout_ms);
    
    while (bytes_read < len && absolute_time_diff_us(get_absolute_time(), timeout) > 0) {
        cyw43_arch_poll(); // Processa a pilha de rede interna
        
        if (g_rx_tail != g_rx_head) {
            buffer[bytes_read] = g_rx_buffer[g_rx_tail];
            g_rx_tail = (g_rx_tail + 1) % RX_BUFFER_SIZE;
            bytes_read++;
        } else {
            sleep_ms(1);
        }
    }
    return bytes_read;
}

int altcp_network_write(Network* n, unsigned char* buffer, int len, int timeout_ms) {
    cyw43_arch_lwip_begin();
    err_t err = altcp_write(n->pcb, buffer, len, TCP_WRITE_FLAG_COPY);
    if (err == ERR_OK) {
        err = altcp_output(n->pcb); // Força o envio imediato dos dados armazenados no buffer TCP
    }
    cyw43_arch_lwip_end();
    
    return (err == ERR_OK) ? len : -1;
}

// --- Callbacks do LwIP ALTCP ---
static err_t tls_recv_callback(void *arg, struct altcp_pcb *pcb, struct pbuf *p, err_t err) {
    if (p != NULL) {
        struct pbuf *q;
        // Copia os dados recebidos para o nosso buffer circular consumido pelo Paho
        for (q = p; q != NULL; q = q->next) {
            for (int i = 0; i < q->len; i++) {
                int next_head = (g_rx_head + 1) % RX_BUFFER_SIZE;
                if (next_head != g_rx_tail) { // Evita estouro de buffer
                    g_rx_buffer[g_rx_head] = ((uint8_t*)q->payload)[i];
                    g_rx_head = next_head;
                }
            }
        }
        altcp_recved(pcb, p->tot_len); // Notifica o LwIP que liberamos espaço na janela TCP
        pbuf_free(p);
    } else {
        printf("[ALTCP] Conexão fechada pelo servidor remoto.");
        g_tls_connected = false;
    }
    return ERR_OK;
}

static err_t tls_connected_callback(void *arg, struct altcp_pcb *pcb, err_t err) {
    if (err == ERR_OK) {
        printf("[ALTCP] Handshake TLS completado com sucesso!");
        g_tls_connected = true;
        altcp_recv(pcb, tls_recv_callback);
    } else {
        printf("[ALTCP] Erro na conexão TCP/TLS: %d", err);
        g_tls_conn_error = true;
    }
    return ERR_OK;
}

static void tls_error_callback(void *arg, err_t err) {
    printf("[ALTCP] Erro fatal na camada de transporte: %d", err);
    g_tls_conn_error = true;
    g_tls_connected = false;
}

// --- Callback de Resolução DNS ---
static void dns_callback(const char *name, const ip_addr_t *ipaddr, void *callback_arg) {
    if (ipaddr != NULL) {
        ip_addr_copy(g_broker_ip, *ipaddr);
        g_dns_resolved = true;
        printf("[DNS] Host %s resolvido para: %s", name, ipaddr_ntoa(ipaddr));
    } else {
        printf("[DNS] Falha crítica ao resolver o host: %s", name);
    }
}

// --- Sincronização de Tempo via NTP (Essencial para TLS) ---
bool sincronizar_rtc_ntp() {
    printf("[NTP] Inicializando sincronização de tempo (pool.ntp.org)...\n");
    cyw43_arch_lwip_begin();
    sntp_setoperatingmode(SNTP_OPMODE_POLL);
    //sntp_setservername(0, "pool.ntp.org");
    ip_addr_t ntp_server_ip;
    ipaddr_aton("162.159.200.1", &ntp_server_ip);
    sntp_setserver(0, &ntp_server_ip);
    sntp_init();
    cyw43_arch_lwip_end();
    time_t now = 0;
    struct tm timeinfo = {0};
    int tentativas = 0;

    // Aguarda até o relógio ultrapassar o Epoch de 01/01/2025
    // CORREÇÃO: Dividimos o tempo e inserimos o cyw43_arch_poll()
    while (now < 1735689600 && tentativas < 200) { // 200 iterações de 100ms = 20 segundos
        cyw43_arch_poll(); // <-- DEIXA O LWIP PROCESSAR O DNS E O PACOTE UDP DO NTP
        sleep_ms(100);
        time(&now);
        tentativas++;
        
        if (tentativas % 10 == 0) {
            printf("."); // Imprime um ponto a cada 1 segundo
        }
    }
    printf("\n");

    if (now < 1735689600) {
        printf("[NTP] Erro: Falha ao sincronizar horário. Validação do TLS falhará.\n");
        return false;
    }

    localtime_r(&now, &timeinfo);
    printf("[NTP] Horário do sistema sincronizado (UTC): %s", asctime(&timeinfo));
    return true;
}

// --- Fluxo Principal ---
int main() {
    stdio_init_all();
    
    if (cyw43_arch_init()) {
        printf("Erro ao inicializar chip Wi-Fi CYW43");
        return -1;
    }

    cyw43_arch_enable_sta_mode();
    printf("Conectando ao Wi-Fi %s...", WIFI_SSID);
    
    int wifi_status = cyw43_arch_wifi_connect_timeout_ms(WIFI_SSID, WIFI_PASSWORD, CYW43_AUTH_WPA2_AES_PSK, 30000);
    if (wifi_status != 0) {
        printf("Erro ao conectar ao Wi-Fi: %d", wifi_status);
        return -1;
    }
    printf("Wi-Fi Conectado com sucesso!");
    printf("Wi-Fi Conectado! IP: %s\n", ip4addr_ntoa(netif_ip4_addr(netif_list)));

    // 1. Sincronização de tempo obrigatória para mTLS
    if (!sincronizar_rtc_ntp()) {
        return -1;
    }

    // 2. Resolução DNS dinâmica do servidor Azure
    printf("[DNS] Buscando IP para o host: %s..", SERVER_NAME);
    cyw43_arch_lwip_begin();
    err_t dns_err = dns_gethostbyname(SERVER_NAME, &g_broker_ip, dns_callback, NULL);
    cyw43_arch_lwip_end();

    if (dns_err == ERR_OK) {
        g_dns_resolved = true;
        printf("[DNS] IP obtido imediatamente do cache: %s", ipaddr_ntoa(&g_broker_ip));
    } else if (dns_err == ERR_INPROGRESS) {
        uint32_t timeout = 0;
        while (!g_dns_resolved && timeout < 10000) {
            cyw43_arch_poll();
            sleep_ms(10);
            timeout += 10;
        }
    }

    if (!g_dns_resolved) {
        printf("[DNS] Erro: Timeout ou falha na resolução do servidor Azure.");
        return -1;
    }

    // 3. Configuração manual da camada TLS nativa (ALTCP)
    // Permite contornar a abstração do lwip/apps/mqtt.h e injetar o SNI diretamente
    printf("[TLS] Inicializando configurações mTLS...");
    
    // Configura autenticação mútua bidirecional (Passando chaves privadas e certificados de cliente)
    struct altcp_tls_config *tls_config = altcp_tls_create_config_client_2wayauth(
    DigiCertGlobalRootG3_der,    // CA Root (se não tiver, NULL)
    DigiCertGlobalRootG3_der_len,            // CA Root (se não tiver, 0)
    client1_authn_ID_der,           // A variável que veio de key_data.h
    client1_authn_ID_der_len,       // A variável que veio de key_data.h
    NULL, 0,                            // Senha (NULL)
    NULL,          // A variável que veio de cert_data.h
    0       // A variável que veio de cert_data.h
);
    printf("Tamanho da cadeia cliente sendo enviada: %d bytes\n", client_chain_der_len);
    if (!tls_config) {
        printf("[TLS] Erro crítico ao criar estrutura altcp_tls_config");
        return -1;
    }
    

    static const char *alpn_protocols[] = { "mqtt", NULL };
    mbedtls_ssl_conf_alpn_protocols((mbedtls_ssl_config *)tls_config, alpn_protocols);

    // Cria a conexão abstrata de transporte ALTCP usando a camada TLS criada
    sleep_ms(100);
    struct altcp_pcb *tls_pcb = altcp_tls_new(tls_config, IPADDR_TYPE_V4);
    if (!tls_pcb) {
        printf("[TLS] Erro ao alocar altcp_pcb");
        return -1;
    }

    mbedtls_ssl_context *ssl_ctx = altcp_tls_context(tls_pcb);
    if (ssl_ctx != NULL) {
        mbedtls_ssl_set_hostname(ssl_ctx, SERVER_NAME);
        printf("[TLS] SNI injetado com sucesso para o host: %s", SERVER_NAME);
    } else {
        printf("[TLS] Erro grave: Contexto interno mbedTLS não encontrado!");
        return -1;
    }

    // Vincula estruturas de rede para a biblioteca Paho MQTT usar posteriormente
    Network network;
    network.pcb = tls_pcb;
    network.mqttread = altcp_network_read;
    network.mqttwrite = altcp_network_write;

    // Registra callback de erros do transporte TCP/TLS
    altcp_err(tls_pcb, tls_error_callback);

    // Inicia conexão TCP + Handshake TLS assíncrono
    printf("[TLS] Iniciando Handshake TLS com o Broker Azure...");
    cyw43_arch_lwip_begin();
    err_t conn_err = altcp_connect(tls_pcb, &g_broker_ip, MQTT_PORT, tls_connected_callback);
    cyw43_arch_lwip_end();

    if (conn_err != ERR_OK && conn_err != ERR_INPROGRESS) {
        printf("[TLS] Falha imediata ao chamar altcp_connect: %d", conn_err);
        return -1;
    }

    // Aguarda o estabelecimento completo da camada segura criptografada
    while (!g_tls_connected && !g_tls_conn_error) {
        cyw43_arch_poll();
        printf(".");
        sleep_ms(100);
    }
    printf("");
    
    if (g_tls_conn_error || !g_tls_connected) {
        printf("[TLS] Erro crítico: Falha ao estabelecer Handshake seguro mTLS.");
        return -1;
    }

    // 4. Integração com Paho MQTT Packet Layer
    // Nota: Como estamos controlando o fluxo de transporte, usamos a camada estável 
    // de serialização de pacotes do Paho MQTT Embedded C para montar buffers estáveis.
    printf("[MQTT] Inicializando envio do pacote CONNECT via Paho MQTT...");

    unsigned char tx_mqtt_buf[512];
    MQTTPacket_connectData mqtt_data = MQTTPacket_connectData_initializer;
    mqtt_data.MQTTVersion = 4; // MQTT v3.1.1
    mqtt_data.clientID.cstring = client_id;
    mqtt_data.username.cstring = username;
    mqtt_data.password.cstring = NULL;
    mqtt_data.keepAliveInterval = 100;
    mqtt_data.cleansession = 1;

    // Serializa os dados do CONNECT estruturados pelo Paho para o buffer de transmissão
    int len = MQTTSerialize_connect(tx_mqtt_buf, sizeof(tx_mqtt_buf), &mqtt_data);
    if (len <= 0) {
        printf("[MQTT] Erro ao serializar pacote CONNECT do Paho.");
        return -1;
    }

    // Envia o pacote CONNECT via transporte mTLS configurado
    if (network.mqttwrite(&network, tx_mqtt_buf, len, 5000) != len) {
        printf("[MQTT] Erro ao transmitir pacote CONNECT para o broker.");
        return -1;
    }
    printf("[MQTT] Pacote CONNECT enviado! Aguardando resposta CONNACK...");

    // Aguarda e lê o pacote de resposta CONNACK do Broker
    unsigned char rx_mqtt_buf[128];
    int read_len = network.mqttread(&network, rx_mqtt_buf, sizeof(rx_mqtt_buf), 5000);
    
    unsigned char connack_rcv_packet_type = 0;
    unsigned char connack_rcv_dup = 0;
    int connack_rcv_qos = 0;
    unsigned char connack_rcv_retained = 0;
    unsigned short connack_rcv_packet_id = 0;
    
    unsigned char connack_session_present = 0;
    unsigned char connack_conn_return_code = 0;

    // Decodifica a resposta vinda do broker usando o parser do Paho
    if (read_len > 0 && ((rx_mqtt_buf[0] >> 4) == CONNACK)) {
        if (MQTTDeserialize_connack(&connack_session_present, &connack_conn_return_code, rx_mqtt_buf, read_len) == 1) {
            if (connack_conn_return_code == 0) {
                printf("[MQTT] Conectado com sucesso ao Broker Azure Event Grid via Paho MQTT!");
            } else {
                printf("[MQTT] Conexão recusada pelo broker. Código de retorno: %d", connack_conn_return_code);
                return -1;
            }
        } else {
            printf("[MQTT] Falha ao desserializar CONNACK.");
            return -1;
        }
    } else {
        printf("[MQTT] Resposta inválida ou timeout aguardando o CONNACK.");
        return -1;
    }

    // 5. Loop de Aplicação (Envio de Telemetria periódico)
    printf("[APP] Inicializando loop estável de telemetria...");
    while (g_tls_connected) {
        cyw43_arch_poll();

        MQTTString topic_string = MQTTString_initializer;
        topic_string.cstring = "Equipe3/";
        unsigned char payload[] = "Olá, mundo via Paho MQTT & SNI Fixo!";
        int payload_len = strlen((char*)payload);

        // Serializa um pacote de publicação estável usando Paho
        int pub_len = MQTTSerialize_publish(tx_mqtt_buf, sizeof(tx_mqtt_buf), 0, 1, 0, 0, 
                                            topic_string, payload, payload_len);
        
        if (pub_len > 0) {
            if (network.mqttwrite(&network, tx_mqtt_buf, pub_len, 2000) == pub_len) {
                printf("[PUBLISH] Mensagem enviada com sucesso para o tópico 'Equipe3/'!");
            } else {
                printf("[PUBLISH] Falha de escrita ao publicar telemetria.");
            }
        }

        sleep_ms(5000); // Aguarda 5 segundos antes do próximo envio
    }

    printf("[ALERTA] Desconectado do servidor. Finalizando aplicação.");
    cyw43_arch_deinit();
    return 0;
}