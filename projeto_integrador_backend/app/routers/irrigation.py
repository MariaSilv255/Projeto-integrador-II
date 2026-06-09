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

@router.post("/irrigacao", tags=["Irrigação"])
async def criar_cadastro_irrigacao(cadastro: schemas.CadastroIrrigacao, db: Session = Depends(get_db)):
    novo_cadastro = models.CadastroIrrigacao(
        fk_id_usuario=cadastro.fk_id_usuario,
        descricao=cadastro.descricao,
        fk_id_broker=cadastro.fk_id_broker
    )
    db.add(novo_cadastro)
    db.commit()
    db.refresh(novo_cadastro)
    return {"mensagem": "Cadastro de irrigação criado com sucesso", "cadastro_id": novo_cadastro.id}

@router.get("/irrigacao/{usuario_id}", tags=["Irrigação"], response_model=List[schemas.CadastroIrrigacao])
async def listar_cadastros_irrigacao(usuario_id: int, db: Session = Depends(get_db)):
    cadastros = db.query(models.CadastroIrrigacao).filter(models.CadastroIrrigacao.fk_id_usuario == usuario_id).all()
    if not cadastros:
        raise HTTPException(status_code=404, detail="Nenhum cadastro de irrigação encontrado para este usuário")
    return cadastros
