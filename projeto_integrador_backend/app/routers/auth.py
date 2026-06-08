from fastapi import APIRouter, HTTPException
from app.schemas import Usuario, DadosUsuario
from app.database import db_usuarios, db_dados_usuarios
from pydantic import BaseModel

router = APIRouter()

class UsuarioRegistro(BaseModel):
    nome_usuario: str
    email: str
    senha: str

@router.post("/login", tags=["Autenticação"])
async def login(usuario: Usuario):
    # Lógica de login dummy
    if usuario.nome_usuario in db_usuarios and db_usuarios[usuario.nome_usuario].senha == usuario.senha:
        return {"mensagem": f"Login bem-sucedido para o usuário {usuario.nome_usuario}"}
    raise HTTPException(status_code=400, detail="Credenciais inválidas")

@router.post("/registrar", tags=["Autenticação"])
async def registrar(reg_usuario: UsuarioRegistro):
    if reg_usuario.nome_usuario in db_usuarios:
        raise HTTPException(status_code=400, detail="Nome de usuário já registrado")
    
    # Geração de ID dummy
    novo_id = len(db_usuarios) + 1
    
    novo_usuario = Usuario(id=novo_id, nome_usuario=reg_usuario.nome_usuario, senha=reg_usuario.senha)
    db_usuarios[novo_usuario.nome_usuario] = novo_usuario
    
    novos_dados_usuario = DadosUsuario(id=novo_id, email=reg_usuario.email, fk_id_usuario=novo_id)
    db_dados_usuarios[novo_id] = novos_dados_usuario
    
    return {"mensagem": f"Usuário {reg_usuario.nome_usuario} registrado com sucesso"}
