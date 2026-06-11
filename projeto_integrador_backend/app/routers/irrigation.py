from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from app import models, schemas
from app.database import get_db
from app.mqtt_client import get_latest_data
from typing import List

router = APIRouter()

@router.get("/irrigacao/dados-tempo-real", tags=["Irrigação"])
async def obter_dados_tempo_real():
    return get_latest_data()

@router.get("/irrigacao/topicos-descobertos", tags=["Irrigação"])
async def listar_topicos_descobertos():

    return list(get_latest_data().keys())

@router.post("/irrigacao", tags=["Irrigação"])
async def criar_cadastro_irrigacao(cadastro: schemas.CadastroIrrigacao, db: Session = Depends(get_db)):
    novo_cadastro = models.CadastroIrrigacao(
        fk_id_usuario=cadastro.fk_id_usuario,
        descricao=cadastro.descricao,
        topico=cadastro.topico,
        device_id=cadastro.device_id,
        fk_id_broker=cadastro.fk_id_broker
    )
    db.add(novo_cadastro)
    db.commit()
    db.refresh(novo_cadastro)
    return {"mensagem": "Cadastro de irrigação criado com sucesso", "id": novo_cadastro.id}

@router.get("/irrigacao/usuario/{usuario_id}", tags=["Irrigação"], response_model=List[schemas.CadastroIrrigacao])
async def listar_cadastros_irrigacao(usuario_id: int, db: Session = Depends(get_db)):
    cadastros = db.query(models.CadastroIrrigacao).filter(models.CadastroIrrigacao.fk_id_usuario == usuario_id).all()
    return cadastros

@router.get("/irrigacao/{irrigacao_id}", tags=["Irrigação"], response_model=schemas.CadastroIrrigacao)
async def obter_cadastro_irrigacao(irrigacao_id: int, db: Session = Depends(get_db)):
    cadastro = db.query(models.CadastroIrrigacao).filter(models.CadastroIrrigacao.id == irrigacao_id).first()
    if not cadastro:
        raise HTTPException(status_code=404, detail="Cadastro de irrigação não encontrado")
    return cadastro

@router.put("/irrigacao/{irrigacao_id}", tags=["Irrigação"], response_model=schemas.CadastroIrrigacao)
async def atualizar_cadastro_irrigacao(irrigacao_id: int, cadastro_data: schemas.CadastroIrrigacao, db: Session = Depends(get_db)):
    db_cadastro = db.query(models.CadastroIrrigacao).filter(models.CadastroIrrigacao.id == irrigacao_id).first()
    if not db_cadastro:
        raise HTTPException(status_code=404, detail="Cadastro de irrigação não encontrado")

    db_cadastro.descricao = cadastro_data.descricao
    db_cadastro.fk_id_broker = cadastro_data.fk_id_broker

    db.commit()
    db.refresh(db_cadastro)
    return db_cadastro

@router.delete("/irrigacao/{irrigacao_id}", tags=["Irrigação"])
async def deletar_cadastro_irrigacao(irrigacao_id: int, db: Session = Depends(get_db)):
    db_cadastro = db.query(models.CadastroIrrigacao).filter(models.CadastroIrrigacao.id == irrigacao_id).first()
    if not db_cadastro:
        raise HTTPException(status_code=404, detail="Cadastro de irrigação não encontrado")

    db.delete(db_cadastro)
    db.commit()
    return {"mensagem": "Cadastro de irrigação deletado com sucesso"}

@router.post("/irrigacao/comando", tags=["Irrigação"])
async def enviar_comando(payload: dict):
    from app.mqtt_client import publish_message

    topic = payload.get("topico")
    comando = payload.get("comando")

    if not topic or comando is None:
        raise HTTPException(status_code=400, detail="Tópico e comando são obrigatórios")

    sucesso = publish_message(topic, comando)
    if sucesso:
        return {"mensagem": "Comando enviado com sucesso"}
    else:
        raise HTTPException(status_code=500, detail="Falha ao enviar comando para o broker")
