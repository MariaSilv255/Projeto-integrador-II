#include "wifi_manager.h"
#include <ESP8266WiFi.h>
#include <Arduino.h>

WifiManager::WifiManager(const char* ssid, const char* password) {
    _ssid = ssid;
    _password = password;
}

void WifiManager::setup() {
    delay(10);
    Serial.println();
    Serial.print("Connecting to ");
    Serial.println(_ssid);

    WiFi.begin(_ssid, _password);

    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }

    Serial.println("");
    Serial.println("WiFi connected");
    Serial.println("IP address: ");
    Serial.println(WiFi.localIP());
}
