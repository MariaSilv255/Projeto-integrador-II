from fastapi import FastAPI
from contextlib import asynccontextmanager
from app.routers import auth, irrigation, brokers, schedules
from app.mqtt_client import start_mqtt, stop_mqtt
from app.scheduler_service import start_scheduler, stop_scheduler
from app.database import engine
from app import models

# Cria as tabelas no banco de dados
models.Base.metadata.create_all(bind=engine)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    start_mqtt()
    start_scheduler()
    yield
    # Shutdown
    stop_mqtt()
    stop_scheduler()

app = FastAPI(title="API do Sistema de Irrigação Inteligente", lifespan=lifespan)

app.include_router(auth.router)
app.include_router(irrigation.router)
app.include_router(brokers.router)
app.include_router(schedules.router)

@app.get("/", tags=["Root"])
async def root():
    return {"mensagem": "API do Sistema de Irrigação Inteligente no ar!"}
