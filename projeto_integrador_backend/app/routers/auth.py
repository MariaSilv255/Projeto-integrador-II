from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from app import models, schemas
from app.database import get_db
from app.mqtt_client import connect_user

router = APIRouter()

@router.post("/login", tags=["Autenticação"])
async def login(usuario: schemas.UsuarioLogin, db: Session = Depends(get_db)):
    db_usuario = db.query(models.Usuario).filter(models.Usuario.nome_usuario == usuario.nome_usuario).first()
    if db_usuario and db_usuario.senha == usuario.senha:
        # Tenta conectar ao último broker do usuário se existir
        ultimo_broker = db.query(models.Broker).filter(models.Broker.fk_id_usuario == db_usuario.id).order_by(models.Broker.id.desc()).first()
        if ultimo_broker:
            connect_user(
                user_id=db_usuario.id,
                host=ultimo_broker.host,
                port=1883, # Padrão, pode ser configurável
                username=ultimo_broker.username,
                password=ultimo_broker.chave_usuario
            )
        
        return {
            "mensagem": f"Login bem-sucedido para o usuário {usuario.nome_usuario}",
            "id": db_usuario.id,
            "nome_usuario": db_usuario.nome_usuario
        }
    raise HTTPException(status_code=400, detail="Credenciais inválidas")

@router.post("/registrar", tags=["Autenticação"])
async def registrar(reg_usuario: schemas.UsuarioCreate, db: Session = Depends(get_db)):
    db_usuario = db.query(models.Usuario).filter(models.Usuario.nome_usuario == reg_usuario.nome_usuario).first()
    if db_usuario:
        raise HTTPException(status_code=400, detail="Nome de usuário já registrado")
    
    novo_usuario = models.Usuario(nome_usuario=reg_usuario.nome_usuario, senha=reg_usuario.senha)
    db.add(novo_usuario)
    db.commit()
    db.refresh(novo_usuario)
    
    return {"mensagem": f"Usuário {reg_usuario.nome_usuario} registrado com sucesso"}
