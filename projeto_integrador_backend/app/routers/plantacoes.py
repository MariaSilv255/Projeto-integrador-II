from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from app import models, schemas
from app.database import get_db
from app.mqtt_client import get_latest_data, publish_message
from typing import List

router = APIRouter()

@router.get("/plantacoes/dados-tempo-real/{user_id}", tags=["Plantações"])
async def obter_dados_tempo_real(user_id: int):
    return get_latest_data(user_id)

@router.get("/plantacoes/topicos-descobertos/{user_id}", tags=["Plantações"])
async def listar_topicos_descobertos(user_id: int):
    return list(get_latest_data(user_id).keys())

@router.post("/plantacoes", tags=["Plantações"])
async def criar_cadastro_plantacao(cadastro: schemas.CadastroPlantacao, db: Session = Depends(get_db)):
    novo_cadastro = models.CadastroPlantacao(
        fk_id_usuario=cadastro.fk_id_usuario,
        descricao=cadastro.descricao,
        topico=cadastro.topico,
        device_id=cadastro.device_id,
        fk_id_broker=cadastro.fk_id_broker
    )
    db.add(novo_cadastro)
    db.commit()
    db.refresh(novo_cadastro)
    return {"mensagem": "Cadastro de plantação criado com sucesso", "id": novo_cadastro.id}

@router.get("/plantacoes/usuario/{usuario_id}", tags=["Plantações"], response_model=List[schemas.CadastroPlantacao])
async def listar_cadastros_plantacoes(usuario_id: int, db: Session = Depends(get_db)):
    return db.query(models.CadastroPlantacao).filter(models.CadastroPlantacao.fk_id_usuario == usuario_id).all()

@router.get("/plantacoes/{plantacao_id}", tags=["Plantações"], response_model=schemas.CadastroPlantacao)
async def obter_cadastro_plantacao(plantacao_id: int, db: Session = Depends(get_db)):
    plantacao = db.query(models.CadastroPlantacao).filter(models.CadastroPlantacao.id == plantacao_id).first()
    if not plantacao:
        raise HTTPException(status_code=404, detail="Plantação não encontrada")
    return plantacao

@router.put("/plantacoes/{plantacao_id}", tags=["Plantações"], response_model=schemas.CadastroPlantacao)
async def atualizar_cadastro_plantacao(plantacao_id: int, cadastro_data: schemas.CadastroPlantacao, db: Session = Depends(get_db)):
    db_plantacao = db.query(models.CadastroPlantacao).filter(models.CadastroPlantacao.id == plantacao_id).first()
    if not db_plantacao:
        raise HTTPException(status_code=404, detail="Plantação não encontrada")
    
    db_plantacao.descricao = cadastro_data.descricao
    db_plantacao.fk_id_broker = cadastro_data.fk_id_broker
    db_plantacao.topico = cadastro_data.topico
    db_plantacao.device_id = cadastro_data.device_id
    
    db.commit()
    db.refresh(db_plantacao)
    return db_plantacao

@router.delete("/plantacoes/{plantacao_id}", tags=["Plantações"])
async def deletar_cadastro_plantacao(plantacao_id: int, db: Session = Depends(get_db)):
    db_plantacao = db.query(models.CadastroPlantacao).filter(models.CadastroPlantacao.id == plantacao_id).first()
    if not db_plantacao:
        raise HTTPException(status_code=404, detail="Plantação não encontrada")
    
    db.delete(db_plantacao)
    db.commit()
    return {"mensagem": "Plantação deletada com sucesso"}

@router.post("/plantacoes/comando/{user_id}", tags=["Plantações"])
async def enviar_comando(user_id: int, payload: dict):
    topic = payload.get("topico")
    comando = payload.get("comando")
    
    if not topic or comando is None:
        raise HTTPException(status_code=400, detail="Tópico e comando são obrigatórios")
    
    sucesso = publish_message(user_id, topic, comando)
    if sucesso:
        return {"mensagem": "Comando enviado com sucesso"}
    else:
        raise HTTPException(status_code=500, detail="Falha ao enviar comando para o broker")
