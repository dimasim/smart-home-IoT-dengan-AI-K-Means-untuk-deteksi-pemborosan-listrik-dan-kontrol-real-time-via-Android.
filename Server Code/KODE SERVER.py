import pandas as pd
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
import paho.mqtt.client as mqtt
import json
import time


mqtt_broker = "103.172.204.63"  
mqtt_port = 1883
mqtt_user = "uas24_iot"  
mqtt_password = "uas24_iot"  
mqtt_input_topic = "UAS24-IOT/4.33.22.0.06/sensor" 
mqtt_output_topic = "UAS24-IOT/4.33.22.0.06/prediction"  
kmeans = None
scaler = None


def train_decision_tree(csv_file):
    global kmeans, scaler  
    data = pd.read_csv(csv_file)
    features = ['person_detected', 'temperature', 'lamp_on', 'fan_on', 'current_usage']
    X = data[features]
    
    
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    
    kmeans = KMeans(n_clusters=2, random_state=42)
    data['cluster'] = kmeans.fit_predict(X_scaled)
   
    data['wastage_prediction'] = data['cluster'].apply(lambda x: 1 if x == 1 else 0)
    
    return kmeans, scaler

def on_message(client, userdata, msg):
    payload = msg.payload.decode()
    data = json.loads(payload)
    
    features = [data['person_detected'], data['temperature'], data['lamp_on'], data['fan_on'], data['current_usage']]
    features_scaled = scaler.transform([features])
    cluster = kmeans.predict(features_scaled)
    
    wastage_prediction = 1 if cluster == 1 else 0
    
    result = {
        "timestamp": data["timestamp"],
        "wastage_prediction": wastage_prediction
    }
    
    client.publish(mqtt_output_topic, json.dumps(result))
    print(f"Prediksi keborosan dikirim: {result}")

client = mqtt.Client()
client.username_pw_set(mqtt_user, mqtt_password)  
client.on_message = on_message

def on_connect(client, userdata, flags, rc):
    print(f"Connected with result code {rc}")
    client.subscribe(mqtt_input_topic)

def on_disconnect(client, userdata, rc):
    print(f"Disconnected with result code {rc}")

client.connect(mqtt_broker, mqtt_port, 60)

kmeans, scaler = train_decision_tree('dataset.csv')

client.on_connect = on_connect
client.on_disconnect = on_disconnect

client.subscribe(mqtt_input_topic)

client.loop_start()

try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    client.loop_stop()  