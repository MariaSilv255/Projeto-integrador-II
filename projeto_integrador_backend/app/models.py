from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from .database import Base

class Usuario(Base):
    __tablename__ = "usuarios"

    id = Column(Integer, primary_key=True, index=True)
    nome_usuario = Column(String, unique=True, index=True)
    senha = Column(String)

    cadastros_irrigacao = relationship("CadastroIrrigacao", back_populates="usuario")

class Broker(Base):
    __tablename__ = "brokers"

    id = Column(Integer, primary_key=True, index=True)
    login = Column(String)
    certificado_cliente = Column(String)
    username = Column(String)
    chave_usuario = Column(String)
    host = Column(String)

    cadastros_irrigacao = relationship("CadastroIrrigacao", back_populates="broker")

class CadastroIrrigacao(Base):
    __tablename__ = "cadastros_irrigacao"

    id = Column(Integer, primary_key=True, index=True)
    descricao = Column(String)
    topico = Column(String)
    device_id = Column(String)
    fk_id_usuario = Column(Integer, ForeignKey("usuarios.id"))
    fk_id_broker = Column(Integer, ForeignKey("brokers.id"))

    usuario = relationship("Usuario", back_populates="cadastros_irrigacao")
    broker = relationship("Broker", back_populates="cadastros_irrigacao")
