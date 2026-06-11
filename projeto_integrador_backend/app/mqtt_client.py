import os
import json
import paho.mqtt.client as mqtt
from typing import Dict

user_clients: Dict[int, mqtt.Client] = {}
latest_sensor_data: Dict[int, Dict[str, any]] = {}
user_status: Dict[int, str] = {}

def on_connect(client, userdata, flags, rc):
    user_id = userdata.get("user_id")
    topic = userdata.get("topic", "Equipe3/#")
    if rc == 0:
        print(f"DEBUG: MQTT Connected for User {user_id}!")
        client.subscribe(topic)
        user_status[user_id] = "Conectado"
    else:
        print(f"DEBUG: MQTT Connection FAILED for User {user_id} (rc={rc})")
        user_status[user_id] = f"Erro ({rc})"

def on_disconnect(client, userdata, rc):
    user_id = userdata.get("user_id")
    print(f"DEBUG: MQTT Disconnected for User {user_id} (rc={rc})")
    if rc != 0:
        user_status[user_id] = "Reconectando..."
    else:
        user_status[user_id] = "Desconectado"

def on_message(client, userdata, msg):
    user_id = userdata.get("user_id")
    if user_id not in latest_sensor_data:
        latest_sensor_data[user_id] = {}
    
    try:
        payload_str = msg.payload.decode().replace('“', '"').replace('”', '"').replace('‘', "'").replace('’', "'")
        print(f"DEBUG: Msg on {msg.topic} for User {user_id}: {payload_str}")
        
        try:
            data = json.loads(payload_str)
        except:
            data = payload_str
        
        latest_sensor_data[user_id][msg.topic] = data
    except Exception as e:
        print(f"DEBUG: Msg error: {e}")

def connect_user(user_id: int, host: str, port: int, username: str = None, password: str = None):
    print(f"DEBUG: Connecting User {user_id} to {host}")
    disconnect_user(user_id)

    client_id = f"BackendClient_{user_id}"
    userdata = {"user_id": user_id, "topic": "Equipe3/#"}
    
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, client_id, userdata=userdata)
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message
    
    client.reconnect_delay_set(min_delay=1, max_delay=120)
    
    if username:
        client.username_pw_set(username, password)
    
    try:
        user_status[user_id] = "Conectando..."
        client.connect_async(host, port, 60)
        client.loop_start()
        user_clients[user_id] = client
        return True
    except Exception as e:
        print(f"DEBUG: Connect error: {e}")
        user_status[user_id] = "Falha na conexão"
        return False

def disconnect_user(user_id: int):
    if user_id in user_clients:
        try:
            client = user_clients.pop(user_id)
            client.loop_stop()
            client.disconnect()
        except: pass
    user_status[user_id] = "Desconectado"

def get_user_status(user_id: int):
    status = user_status.get(user_id, "Offline")
    print(f"DEBUG: Status check for User {user_id} -> {status}")
    return status

def get_latest_data(user_id: int):
    return latest_sensor_data.get(user_id, {})

def publish_message(user_id: int, topic: str, message: any):
    client = user_clients.get(user_id)
    if not client: return False
    try:
        payload = json.dumps(message) if isinstance(message, dict) else str(message)
        result = client.publish(topic, payload)
        return result.rc == mqtt.MQTT_ERR_SUCCESS
    except: return False

def start_mqtt(): pass
def stop_mqtt():
    for uid in list(user_clients.keys()): disconnect_user(uid)
