#include <Arduino.h>
#include <DHT.h>
#include <ArduinoJson.h>
#include <NTPClient.h>
#include <WiFiUdp.h>
#include "wifi_manager.h"
#include "mqtt_manager.h"

#define DHTPIN D2
#define DHTTYPE DHT22

DHT dht(DHTPIN, DHTTYPE);

// WiFi credentials
const char* ssid = "brisa-4250951";
const char* password = "bieQIzf7";

// MQTT broker
const char* mqtt_server = "brokermqtt.eastus-1.ts.eventgrid.azure.net";
const int mqtt_port = 8883;
const char* mqtt_client_id = "ESP8266Client";
const char* mqtt_username = "joao-authn-ID";

WifiManager wifiManager(ssid, password);
MqttManager mqttManager(mqtt_server, mqtt_port, mqtt_client_id, mqtt_username);

// NTP client
const long utcOffsetInSeconds = -3 * 3600;
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org", utcOffsetInSeconds);

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  for (unsigned int i = 0; i < length; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();
}

void setup() {
  Serial.begin(115200);
  Serial.println("DHT22 test!");

  pinMode(DHTPIN, INPUT_PULLUP);
  dht.begin();

  wifiManager.setup();
  
  Serial.println("Starting NTP client...");
  timeClient.begin();
  timeClient.update();
  Serial.print("Current time: ");
  Serial.println(timeClient.getFormattedTime());

  mqttManager.setup(callback);
}

void loop() {
  mqttManager.loop();
  
  static unsigned long last_time_sync = 0;
  if (millis() - last_time_sync > 3600000) {
    timeClient.update();
    last_time_sync = millis();
    Serial.print("Time synchronized: ");
    Serial.println(timeClient.getFormattedTime());
  }


  static unsigned long last_sensor_read = 0;
  if(millis() - last_sensor_read > 5000) {
    last_sensor_read = millis();

    float h = dht.readHumidity();
    float t = dht.readTemperature();

    if (isnan(h) || isnan(t)) {
      Serial.println("Failed to read from DHT sensor!");
      return;
    }

    float hic = dht.computeHeatIndex(t, h, false);

    Serial.print("Umidade: ");
    Serial.print(h);
    Serial.print(" %	");
    Serial.print("Temperatura: ");
    Serial.print(t);
    Serial.print(" *C	");
    Serial.print("Sensação Térmica: ");
    Serial.print(hic);
    Serial.println(" *C");

    StaticJsonDocument<256> doc;
    doc["dispositivo"] = mqtt_client_id;
    doc["temperatura"] = t;
    doc["umidade"] = h;
    doc["data_hora"] = timeClient.getFormattedTime();

    char jsonBuffer[256];
    serializeJson(doc, jsonBuffer);

    Serial.print("Publishing message: ");
    Serial.println(jsonBuffer);
    mqttManager.publish("Equipe3/sensores", jsonBuffer);
  }
}
