from fastapi import FastAPI
from contextlib import asynccontextmanager
from app.routers import auth, irrigation
from app.mqtt_client import start_mqtt, stop_mqtt

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Start MQTT client
    start_mqtt()
    yield
    # Shutdown: Stop MQTT client
    stop_mqtt()

app = FastAPI(title="API do Sistema de Irrigação Inteligente", lifespan=lifespan)

app.include_router(auth.router)
app.include_router(irrigation.router)

@app.get("/", tags=["Root"])
async def root():
    return {"mensagem": "API do Sistema de Irrigação Inteligente no ar!"}
