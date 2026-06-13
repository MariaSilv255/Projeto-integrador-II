from fastapi import FastAPI
from contextlib import asynccontextmanager
from app.routers import auth, plantacoes, brokers
from app.mqtt_client import stop_mqtt
from app.database import engine
from app import models

models.Base.metadata.create_all(bind=engine)

@asynccontextmanager
async def lifespan(app: FastAPI):
    from app.database import SessionLocal
    from app.models import Broker
    from app.mqtt_client import connect_user
    
    db = SessionLocal()
    try:
        all_brokers = db.query(Broker).all()
        for b in all_brokers:
            print(f"Heartbeat: Recovering MQTT connection for User {b.fk_id_usuario} on {b.host}")
            connect_user(
                user_id=b.fk_id_usuario,
                host=b.host,
                port=1883,
                username=b.username,
                password=b.chave_usuario
            )
    except Exception as e:
        print(f"Heartbeat Error: Failed to recover connections: {e}")
    finally:
        db.close()
        
    yield
    stop_mqtt()

app = FastAPI(title="API do Sistema de Irrigação Inteligente", lifespan=lifespan)

app.include_router(auth.router)
app.include_router(plantacoes.router)
app.include_router(brokers.router)

@app.get("/", tags=["Root"])
async def root():
    return {"mensagem": "API do Sistema de Irrigação Inteligente no ar!"}
