import os
import json
import paho.mqtt.client as mqtt
from typing import Dict
import threading
import time

user_clients: Dict[int, mqtt.Client] = {}
latest_sensor_data: Dict[int, Dict[str, any]] = {}
user_status: Dict[int, str] = {}

data_lock = threading.Lock()

def on_connect(client, userdata, flags, rc):
    user_id = userdata.get("user_id")
    topic = userdata.get("topic", "Equipe3/#")
    
    with data_lock:
        if rc == 0:
            print(f"DEBUG: MQTT Connected!")
            user_status[user_id] = "Conectado"
        else:
            print(f"DEBUG: MQTT Connection FAILED for User {user_id} (rc={rc})")
            user_status[user_id] = f"Erro ({rc})"
    
    if rc == 0:
        client.subscribe(topic)

def on_disconnect(client, userdata, rc):
    user_id = userdata.get("user_id")
    print(f"DEBUG: MQTT Disconnected for User {user_id} (rc={rc})")
    with data_lock:
        if rc != 0:
            user_status[user_id] = "Reconectando..."
        else:
            user_status[user_id] = "Desconectado"

def on_message(client, userdata, msg):
    user_id = userdata.get("user_id")
    
    try:
        payload_str = msg.payload.decode().replace('“', '"').replace('”', '"').replace('‘', "'").replace('’', "'")
        
        try:
            data = json.loads(payload_str)
        except:
            data = payload_str
        
        with data_lock:
            if user_id not in latest_sensor_data:
                latest_sensor_data[user_id] = {}
            
            latest_sensor_data[user_id][msg.topic] = {
                "payload": data,
                "timestamp": time.time()
            }
    except Exception as e:
        print(f"DEBUG: Msg error: {e}")

def connect_user(user_id: int, host: str, port: int, username: str = None, password: str = None):
    print(f"DEBUG: Connecting User {user_id} to {host}")
    
    disconnect_user(user_id)

    client_id = f"BackendClient_{user_id}_{int(time.time())}"
    userdata = {"user_id": user_id, "topic": "Equipe3/#"}
    
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, client_id, userdata=userdata)
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message
    
    client.reconnect_delay_set(min_delay=1, max_delay=120)
    
    if username:
        client.username_pw_set(username, password)
    
    with data_lock:
        user_status[user_id] = "Conectando..."
    
    try:
        client.connect_async(host, port, 60)
        client.loop_start()
        
        with data_lock:
            user_clients[user_id] = client
        return True
    except Exception as e:
        print(f"DEBUG: Connect error: {e}")
        with data_lock:
            user_status[user_id] = "Falha na conexão"
        return False

def disconnect_user(user_id: int):
    client = None
    with data_lock:
        if user_id in user_clients:
            client = user_clients.pop(user_id)
        
        user_status[user_id] = "Desconectado"
        if user_id in latest_sensor_data:
            latest_sensor_data.pop(user_id)

    if client:
        try:
            client.loop_stop()
            client.disconnect()
            print(f"DEBUG: Fully stopped MQTT client for User {user_id}")
        except Exception as e:
            print(f"DEBUG: Error stopping client for User {user_id}: {e}")

def get_user_status(user_id: int):
    with data_lock:
        return user_status.get(user_id, "Offline")

def get_latest_data(user_id: int):
    with data_lock:
        raw_data = latest_sensor_data.get(user_id, {})
        processed_data = {}
        current_time = time.time()
        
        for topic, info in raw_data.items():
            payload = info["payload"]
            is_offline = (current_time - info["timestamp"]) > 120
            
            if topic.endswith("/status"):
                if isinstance(payload, str) and payload.lower() == "offline":
                    is_offline = True
                elif isinstance(payload, dict) and payload.get("status") == "offline":
                    is_offline = True

            if isinstance(payload, dict):
                p_copy = payload.copy()
                p_copy["_offline"] = is_offline
                p_copy["_last_seen"] = int(current_time - info["timestamp"])
                processed_data[topic] = p_copy
            else:
                processed_data[topic] = {"value": payload, "_offline": is_offline, "_last_seen": int(current_time - info["timestamp"])}
            
        return processed_data

def publish_message(user_id: int, topic: str, message: any):
    client = None
    with data_lock:
        client = user_clients.get(user_id)
    
    if not client: return False
    try:
        payload = json.dumps(message) if isinstance(message, dict) else str(message)
        result = client.publish(topic, payload)
        return result.rc == mqtt.MQTT_ERR_SUCCESS
    except: return False

def start_mqtt(): pass
def stop_mqtt():
    uids = []
    with data_lock:
        uids = list(user_clients.keys())
    for uid in uids:
        disconnect_user(uid)
