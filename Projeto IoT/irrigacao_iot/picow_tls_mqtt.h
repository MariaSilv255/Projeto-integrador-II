
#ifndef __PICOW_TLS_CLIENT_H__
#define __PICOW_TLS_CLIENT_H__
#include "lwip/pbuf.h"
#include "lwip/altcp_tcp.h"
#include "lwip/altcp_tcp.h"
#include "lwip/altcp_tls.h"
#include "lwip/dns.h"
#include "lwip/apps/mqtt.h"
#define RECV_BUFF_MAX_LEN   1024

typedef struct {
    mqtt_client_t *client;
    struct altcp_tls_config *tls_config;
    ip_addr_t ipaddr;
    struct mqtt_connect_client_info_t mqtt_connect_client_info;
    bool connected;
    uint8_t sub_topic[256];
    uint8_t sub_message[RECV_BUFF_MAX_LEN];
    uint16_t sub_message_offset;
    bool sub_message_recved;
} mqtt_client_instance_t;

#endif
