from pydantic import BaseModel
from typing import Optional, List

class UsuarioBase(BaseModel):
    nome_usuario: str

class UsuarioLogin(UsuarioBase):
    senha: str

class UsuarioCreate(UsuarioBase):
    senha: str
    email: Optional[str] = None

class Usuario(UsuarioBase):
    id: Optional[int] = None

    class Config:
        from_attributes = True

class Broker(BaseModel):
    id: Optional[int] = None
    login: str
    certificado_cliente: str
    username: str
    chave_usuario: str
    host: str
    fk_id_usuario: int

    class Config:
        from_attributes = True

class CadastroPlantacao(BaseModel):
    id: Optional[int] = None
    fk_id_usuario: int
    descricao: str
    topico: Optional[str] = "Equipe3/plantacoes/default"
    device_id: Optional[str] = None
    fk_id_broker: int

    class Config:
        from_attributes = True
