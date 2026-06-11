from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from app import models, schemas
from app.database import get_db
from app.mqtt_client import connect_user, disconnect_user
from typing import List

router = APIRouter()

@router.get("/brokers", tags=["Brokers"], response_model=List[schemas.Broker])
async def listar_brokers(db: Session = Depends(get_db)):
    return db.query(models.Broker).all()

@router.post("/brokers", tags=["Brokers"], response_model=schemas.Broker)
async def criar_broker(broker: schemas.Broker, db: Session = Depends(get_db)):
    novo_broker = models.Broker(
        login=broker.login,
        certificado_cliente=broker.certificado_cliente,
        username=broker.username,
        chave_usuario=broker.chave_usuario,
        host=broker.host,
        fk_id_usuario=broker.fk_id_usuario
    )
    db.add(novo_broker)
    db.commit()
    db.refresh(novo_broker)
    
    # Ao criar/adicionar um broker, tenta conectar automaticamente
    connect_user(
        user_id=broker.fk_id_usuario,
        host=broker.host,
        port=1883,
        username=broker.username,
        password=broker.chave_usuario
    )
    
    return novo_broker

@router.get("/brokers/usuario/{user_id}", tags=["Brokers"], response_model=List[schemas.Broker])
async def listar_brokers_usuario(user_id: int, db: Session = Depends(get_db)):
    return db.query(models.Broker).filter(models.Broker.fk_id_usuario == user_id).all()

@router.delete("/brokers/{broker_id}", tags=["Brokers"])
async def deletar_broker(broker_id: int, db: Session = Depends(get_db)):
    db_broker = db.query(models.Broker).filter(models.Broker.id == broker_id).first()
    if not db_broker:
        raise HTTPException(status_code=404, detail="Broker não encontrado")
    
    # Se deletar o broker, desconecta o cliente se estiver ativo
    disconnect_user(db_broker.fk_id_usuario)
    
    db.delete(db_broker)
    db.commit()
    return {"mensagem": "Broker deletado com sucesso"}

@router.post("/brokers/conectar/{broker_id}", tags=["Brokers"])
async def conectar_broker(broker_id: int, db: Session = Depends(get_db)):
    broker = db.query(models.Broker).filter(models.Broker.id == broker_id).first()
    if not broker:
        raise HTTPException(status_code=404, detail="Broker não encontrado")
    
    sucesso = connect_user(
        user_id=broker.fk_id_usuario,
        host=broker.host,
        port=1883,
        username=broker.username,
        password=broker.chave_usuario
    )
    
    if sucesso:
        return {"mensagem": "Broker conectado com sucesso"}
    else:
        raise HTTPException(status_code=500, detail="Falha ao conectar ao broker")

@router.get("/brokers/status/{user_id}", tags=["Brokers"])
async def obter_status_broker(user_id: int):
    from app.mqtt_client import get_user_status
    return {"status": get_user_status(user_id)}
