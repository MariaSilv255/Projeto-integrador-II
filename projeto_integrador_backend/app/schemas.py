from pydantic import BaseModel
from typing import Optional

# Esquemas Pydantic baseados no diagrama de banco de dados

class Usuario(BaseModel):
    id: Optional[int] = None
    nome_usuario: str
    senha: str

class DadosUsuario(BaseModel):
    id: Optional[int] = None
    email: str
    fk_id_usuario: int

class Broker(BaseModel):
    id: Optional[int] = None
    login: str
    certificado_cliente: str
    username: str
    chave_usuario: str
    host: str

class CadastroIrrigacao(BaseModel):
    id: Optional[int] = None
    fk_id_usuario: int
    descricao: str
    fk_id_broker: int
