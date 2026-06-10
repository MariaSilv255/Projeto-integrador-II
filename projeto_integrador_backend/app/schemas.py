from pydantic import BaseModel
from typing import Optional, List

# Esquemas Pydantic baseados no diagrama de banco de dados

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

    class Config:
        from_attributes = True

class CadastroIrrigacao(BaseModel):
    id: Optional[int] = None
    fk_id_usuario: int
    descricao: str
    topico: Optional[str] = "Equipe3/sensores" # Valor padrão ou fornecido pelo usuário
    fk_id_broker: int

    class Config:
        from_attributes = True

class AgendamentoBase(BaseModel):
    fk_id_irrigacao: int
    atuador: str
    valor: int
    horario: str
    dias_semana: str

class AgendamentoCreate(AgendamentoBase):
    pass

class Agendamento(AgendamentoBase):
    id: int

    class Config:
        from_attributes = True
