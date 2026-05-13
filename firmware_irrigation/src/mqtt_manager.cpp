#include "mqtt_manager.h"
#include <Arduino.h>
#include <FS.h>
#include <BearSSLHelpers.h>

MqttManager::MqttManager(const char* server, int port, const char* client_id, const char* username) : 
    _server(server), 
    _port(port), 
    _client_id(client_id),
    _username(username),
    _client(_espClient) {
}

void MqttManager::setup(void (*callback)(char*, byte*, unsigned int)) {
    Serial.println("Initializing SPIFFS...");
    if (!SPIFFS.begin()) {
        Serial.println("Failed to mount file system");
        return;
    }
    Serial.println("SPIFFS mounted successfully.");

    // Load client cert
    Serial.println("Loading client certificate...");
    File certFile = SPIFFS.open("/client.pem", "r");
    if (!certFile) {
        Serial.println("Failed to open cert file /client.pem");
        return;
    }
    Serial.print("Cert file size: ");
    Serial.println(certFile.size());
    
    // Load private key
    Serial.println("Loading private key...");
    File keyFile = SPIFFS.open("/client.key", "r");
    if (!keyFile) {
        Serial.println("Failed to open key file /client.key");
        return;
    }
    Serial.print("Key file size: ");
    Serial.println(keyFile.size());

    BearSSL::X509List client_cert(certFile);
    BearSSL::PrivateKey client_key(keyFile);

    Serial.println("Setting client certificate...");
    _espClient.setClientRSACert(&client_cert, &client_key);
    // The setClientRSACert method does not return a value, so we cannot check for success here.
    // If there is an issue with the certificate or key, it will likely manifest as a handshake failure during connection.
    Serial.println("Client certificate and key have been set.");


    // The user did not provide a CA certificate, so we will use setInsecure() to bypass server verification.
    // This is not recommended for production environments.
    Serial.println("Setting insecure connection (no server verification).");
    _espClient.setInsecure();
    
    _client.setServer(_server, _port);
    _client.setCallback(callback);
}

void MqttManager::reconnect() {
    while (!_client.connected()) {
        Serial.print("Attempting MQTT connection...");
        if (_client.connect(_client_id, _username, nullptr)) {
            Serial.println("connected");
            _client.subscribe("esp8266/test");
        } else {
            Serial.print("failed, rc=");
            Serial.print(_client.state());
            Serial.println(" try again in 5 seconds");
            delay(5000);
        }
    }
}

void MqttManager::loop() {
    if (!_client.connected()) {
        reconnect();
    }
    _client.loop();
}

void MqttManager::publish(const char* topic, const char* payload) {
    _client.publish(topic, payload);
}

bool MqttManager::connected() {
    return _client.connected();
}
