#ifndef MQTT_MANAGER_H
#define MQTT_MANAGER_H

#include <PubSubClient.h>
#include <WiFiClientSecure.h>

class MqttManager {
public:
    MqttManager(const char* server, int port, const char* client_id, const char* username);
    void setup(void (*callback)(char*, byte*, unsigned int));
    void loop();
    void publish(const char* topic, const char* payload);
    bool connected();
private:
    void reconnect();
    const char* _server;
    int _port;
    const char* _client_id;
    const char* _username;
    WiFiClientSecure _espClient;
    PubSubClient _client;
};

#endif
