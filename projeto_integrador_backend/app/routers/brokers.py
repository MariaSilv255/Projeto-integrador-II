from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from app import models, schemas
from app.database import get_db
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
        host=broker.host
    )
    db.add(novo_broker)
    db.commit()
    db.refresh(novo_broker)
    return novo_broker

@router.get("/brokers/{broker_id}", tags=["Brokers"], response_model=schemas.Broker)
async def obter_broker(broker_id: int, db: Session = Depends(get_db)):
    broker = db.query(models.Broker).filter(models.Broker.id == broker_id).first()
    if not broker:
        raise HTTPException(status_code=404, detail="Broker não encontrado")
    return broker

@router.put("/brokers/{broker_id}", tags=["Brokers"], response_model=schemas.Broker)
async def atualizar_broker(broker_id: int, broker_data: schemas.Broker, db: Session = Depends(get_db)):
    db_broker = db.query(models.Broker).filter(models.Broker.id == broker_id).first()
    if not db_broker:
        raise HTTPException(status_code=404, detail="Broker não encontrado")

    db_broker.login = broker_data.login
    db_broker.certificado_cliente = broker_data.certificado_cliente
    db_broker.username = broker_data.username
    db_broker.chave_usuario = broker_data.chave_usuario
    db_broker.host = broker_data.host

    db.commit()
    db.refresh(db_broker)
    return db_broker

@router.delete("/brokers/{broker_id}", tags=["Brokers"])
async def deletar_broker(broker_id: int, db: Session = Depends(get_db)):
    db_broker = db.query(models.Broker).filter(models.Broker.id == broker_id).first()
    if not db_broker:
        raise HTTPException(status_code=404, detail="Broker não encontrado")

    db.delete(db_broker)
    db.commit()
    return {"mensagem": "Broker deletado com sucesso"}
