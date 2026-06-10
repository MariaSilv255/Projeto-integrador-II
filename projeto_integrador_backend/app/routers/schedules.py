from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from app import models, schemas
from app.database import get_db
from typing import List

router = APIRouter()

@router.post("/agendamentos", tags=["Agendamentos"], response_model=schemas.Agendamento)
async def criar_agendamento(agendamento: schemas.AgendamentoCreate, db: Session = Depends(get_db)):
    from app.scheduler_service import carregar_agendamentos
    novo_agendamento = models.Agendamento(**agendamento.model_dump())
    db.add(novo_agendamento)
    db.commit()
    db.refresh(novo_agendamento)
    # Recarrega o agendador para incluir a nova rotina
    carregar_agendamentos()
    return novo_agendamento

@router.get("/agendamentos/irrigacao/{irrigacao_id}", tags=["Agendamentos"], response_model=List[schemas.Agendamento])
async def listar_agendamentos(irrigacao_id: int, db: Session = Depends(get_db)):
    return db.query(models.Agendamento).filter(models.Agendamento.fk_id_irrigacao == irrigacao_id).all()

@router.delete("/agendamentos/{agendamento_id}", tags=["Agendamentos"])
async def deletar_agendamento(agendamento_id: int, db: Session = Depends(get_db)):
    from app.scheduler_service import carregar_agendamentos
    db_agendamento = db.query(models.Agendamento).filter(models.Agendamento.id == agendamento_id).first()
    if not db_agendamento:
        raise HTTPException(status_code=404, detail="Agendamento não encontrado")
    db.delete(db_agendamento)
    db.commit()
    # Recarrega o agendador para remover a rotina excluída
    carregar_agendamentos()
    return {"mensagem": "Agendamento deletado com sucesso"}
