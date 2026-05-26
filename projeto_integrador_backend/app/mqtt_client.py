import os
import ssl
import json
import paho.mqtt.client as mqtt
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

MQTT_SERVER = os.getenv("MQTT_SERVER")
MQTT_PORT = int(os.getenv("MQTT_PORT", 8883))
MQTT_USERNAME = os.getenv("MQTT_USERNAME")
MQTT_PASSWORD = os.getenv("MQTT_PASSWORD")
MQTT_CLIENT_ID = os.getenv("MQTT_CLIENT_ID", "BackendClient")
MQTT_TOPIC = os.getenv("MQTT_TOPIC", "Equipe3/sensores")

MQTT_CLIENT_CERT = os.getenv("MQTT_CLIENT_CERT")
MQTT_CLIENT_KEY = os.getenv("MQTT_CLIENT_KEY")

# Global storage for the latest sensor data per topic
latest_sensor_data = {}

def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        print(f"Connected to MQTT Broker! Subscribing to wildcard {MQTT_TOPIC}...")
        client.subscribe(MQTT_TOPIC)
    else:
        # Paho will automatically retry even if rc != 0
        print(f"Connection failed with result code {rc}. Paho will retry automatically.")

def on_disconnect(client, userdata, rc, properties=None):
    if rc != 0:
        print(f"Unexpected MQTT disconnection (rc={rc}). Will attempt to reconnect...")
    else:
        print("MQTT client disconnected gracefully.")

def on_message(client, userdata, msg):
    global latest_sensor_data
    try:
        payload = msg.payload.decode().replace('“', '"').replace('”', '"').replace('‘', "'").replace('’', "'")
        # print(f"Received message from topic `{msg.topic}`") # Too verbose for production, keep it light
        
        # Try to parse as JSON, otherwise store as raw string
        try:
            data = json.loads(payload)
        except json.JSONDecodeError:
            data = payload
            
        latest_sensor_data[msg.topic] = data
    except Exception as e:
        print(f"Error processing MQTT message on topic {msg.topic}: {e}")

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, MQTT_CLIENT_ID)
client.on_connect = on_connect
client.on_disconnect = on_disconnect
client.on_message = on_message

# Configure automatic reconnection with exponential backoff (1s to 120s)
client.reconnect_delay_set(min_delay=1, max_delay=120)

# Configure MQTTS (SSL/TLS)
if MQTT_CLIENT_CERT and MQTT_CLIENT_KEY:
    # Use certificates for authentication
    client.tls_set(
        certfile=MQTT_CLIENT_CERT,
        keyfile=MQTT_CLIENT_KEY,
        cert_reqs=ssl.CERT_NONE,
        tls_version=ssl.PROTOCOL_TLSv1_2
    )
    client.tls_insecure_set(True)
else:
    # Fallback to insecure connection without certs
    client.tls_set(cert_reqs=ssl.CERT_NONE)
    client.tls_insecure_set(True)

if MQTT_USERNAME:
    client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)

def start_mqtt():
    try:
        # connect_async is non-blocking and handles initial connection in the background
        print(f"Connecting to MQTT Broker {MQTT_SERVER}:{MQTT_PORT} (Async)...")
        client.connect_async(MQTT_SERVER, MQTT_PORT, 60)
        client.loop_start()
    except Exception as e:
        print(f"Could not initialize MQTT connection: {e}")

def stop_mqtt():
    client.loop_stop()
    client.disconnect()

def get_latest_data():
    return latest_sensor_data
