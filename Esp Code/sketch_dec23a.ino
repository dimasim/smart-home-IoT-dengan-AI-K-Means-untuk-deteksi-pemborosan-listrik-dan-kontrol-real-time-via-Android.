#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <ArduinoJson.h>

// PIN configuration
#define PIR_PIN D1      // Pin untuk sensor PIR
#define LAMP_PIN D2     // Pin untuk lampu
#define FAN_PIN D5      // Pin untuk kipas
#define ACS_PIN A0      // Pin untuk sensor ACS (ADC pin)

// DHT configuration
#define DHT_PIN D4      // Pin untuk DHT
#define DHT_TYPE DHT11  // DHT11 atau DHT22
DHT dht(DHT_PIN, DHT_TYPE);

// Wi-Fi configuration
const char* ssid = "Free WIFI Nexa";
const char* password = "freenexa";

// MQTT Broker Configuration
const char* mqttServer = "103.172.204.63";
const int mqttPort = 1883;
const char* mqttUser = "uas24_iot";
const char* mqttPassword = "uas24_iot";
const char* mqttSensorTopic = "UAS24-IOT/4.33.22.0.06/sensor"; // Topik pembacaan sensor
const char* mqttLampTopic = "UAS24-IOT/4.33.22.0.06/lamp_on";  // Topik kontrol lampu
const char* mqttFanTopic = "UAS24-IOT/4.33.22.0.06/fan_on";    // Topik kontrol kipas

WiFiClient wifiClient;
PubSubClient client(wifiClient);

// Constants and variables
const float sensitivity = 0.185;           // Sensitivitas ACS (contoh: 185mV/A untuk ACS712 5A)
const int adcResolution = 1024;            // Resolusi ADC (ESP8266 10-bit)
const float vRef = 3.3;                    // Tegangan referensi ADC (3.3V)

bool lampManualControl = false;
bool fanManualControl = false;

// Fungsi membaca arus dari sensor ACS
float readCurrent() {
  int adcValue = analogRead(ACS_PIN);
  float voltage = (adcValue * vRef) / adcResolution;
  float zeroPoint = vRef / 2;
  float current = (voltage - zeroPoint) / sensitivity;
  return current;
}

// Callback untuk menerima pesan MQTT
void callback(char* topic, byte* payload, unsigned int length) {
  StaticJsonDocument<200> doc;
  DeserializationError error = deserializeJson(doc, payload, length);

  if (error) {
    Serial.println("Error parsing JSON");
    return;
  }

  if (strcmp(topic, mqttLampTopic) == 0) {
    lampManualControl = doc["state"] == "ON";
    digitalWrite(LAMP_PIN, lampManualControl ? HIGH : LOW);
  } else if (strcmp(topic, mqttFanTopic) == 0) {
    fanManualControl = doc["state"] == "ON";
    digitalWrite(FAN_PIN, fanManualControl ? HIGH : LOW);
  }
}

// Fungsi untuk publikasi data sensor
void publishSensorData(int pirState, float temperature, float humidity, bool lampOn, bool fanOn, float currentUsage) {
  StaticJsonDocument<256> doc;
  doc["timestamp"] = millis();
  doc["person_detected"] = pirState;
  doc["temperature"] = temperature;
  doc["humidity"] = humidity;
  doc["lamp_on"] = lampOn;
  doc["fan_on"] = fanOn;
  doc["current_usage"] = currentUsage;

  char payload[256];
  serializeJson(doc, payload);
  client.publish(mqttSensorTopic, payload);
}

void setup() {
  Serial.begin(115200);
  dht.begin();

  pinMode(PIR_PIN, INPUT);
  pinMode(LAMP_PIN, OUTPUT);
  pinMode(FAN_PIN, OUTPUT);

  WiFi.begin(ssid, password);
  Serial.print("Menghubungkan ke Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("\nTerhubung ke Wi-Fi");

  client.setServer(mqttServer, mqttPort);
  client.setCallback(callback);

  while (!client.connected()) {
    Serial.print("Menghubungkan ke broker MQTT...");
    if (client.connect("ESP8266Client", mqttUser, mqttPassword)) {
      Serial.println("Terkoneksi ke broker MQTT");
      client.subscribe(mqttLampTopic);
      client.subscribe(mqttFanTopic);
    } else {
      Serial.print("Gagal, coba lagi dalam 5 detik...\n");
      delay(5000);
    }
  }
}

void loop() {
  int pirState = digitalRead(PIR_PIN);
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  float currentUsage = readCurrent();

  // Logika kontrol otomatis
  if (!lampManualControl) {
    digitalWrite(LAMP_PIN, pirState ? HIGH : LOW);
    client.publish(mqttLampTopic, pirState ? "{\"state\":\"ON\"}" : "{\"state\":\"OFF\"}");
  }

  if (!fanManualControl) {
    bool fanState = pirState && (temperature > 30.0);
    digitalWrite(FAN_PIN, fanState ? HIGH : LOW);
    client.publish(mqttFanTopic, fanState ? "{\"state\":\"ON\"}" : "{\"state\":\"OFF\"}");
  }

  // Publikasi data sensor setiap 5 detik
  static unsigned long lastPublishTime = 0;
  unsigned long currentMillis = millis();
  if (currentMillis - lastPublishTime >= 5000) {
    lastPublishTime = currentMillis;
    publishSensorData(pirState, temperature, humidity, digitalRead(LAMP_PIN), digitalRead(FAN_PIN), currentUsage);
  }

  client.loop();
  delay(100);
}
