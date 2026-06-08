from fastapi import APIRouter, HTTPException
from app.schemas import CadastroIrrigacao
from app.database import db_cadastros_irrigacao
from app.mqtt_client import get_latest_data
from typing import List

router = APIRouter()

@router.get("/irrigacao/dados-tempo-real", tags=["Irrigação"])
async def obter_dados_tempo_real():
    return get_latest_data()

@router.post("/irrigacao", tags=["Irrigação"])
async def criar_cadastro_irrigacao(cadastro: CadastroIrrigacao):
    novo_id = len(db_cadastros_irrigacao) + 1
    cadastro.id = novo_id
    db_cadastros_irrigacao[novo_id] = cadastro
    return {"mensagem": "Cadastro de irrigação criado com sucesso", "cadastro_id": novo_id}

@router.get("/irrigacao/{usuario_id}", tags=["Irrigação"], response_model=List[CadastroIrrigacao])
async def listar_cadastros_irrigacao(usuario_id: int):
    cadastros = [c for c in db_cadastros_irrigacao.values() if c.fk_id_usuario == usuario_id]
    if not cadastros:
        raise HTTPException(status_code=404, detail="Nenhum cadastro de irrigação encontrado para este usuário")
    return cadastros
