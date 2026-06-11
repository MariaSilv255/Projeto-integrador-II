from fastapi import FastAPI
from contextlib import asynccontextmanager
from app.routers import auth, plantacoes, brokers
from app.mqtt_client import stop_mqtt
from app.database import engine
from app import models

models.Base.metadata.create_all(bind=engine)

@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    stop_mqtt()

app = FastAPI(title="API do Sistema de Irrigação Inteligente", lifespan=lifespan)

app.include_router(auth.router)
app.include_router(plantacoes.router)
app.include_router(brokers.router)

@app.get("/", tags=["Root"])
async def root():
    return {"mensagem": "API do Sistema de Irrigação Inteligente no ar!"}
