from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models import Agendamento, CadastroIrrigacao
from app.mqtt_client import publish_message
import datetime

scheduler = BackgroundScheduler()

def executar_comando(agendamento_id: int):
    """Função que será chamada pelo agendador para enviar o comando MQTT"""
    db = SessionLocal()
    try:
        agendamento = db.query(Agendamento).filter(Agendamento.id == agendamento_id).first()
        if agendamento:
            # Busca a plantação para pegar o tópico
            irrigacao = db.query(CadastroIrrigacao).filter(CadastroIrrigacao.id == agendamento.fk_id_irrigacao).first()
            if irrigacao:
                # Comandos de atuadores costumam ir para um tópico específico ou do dispositivo
                # Aqui usamos o padrão do projeto: Equipe3/atuadores
                topic = "Equipe3/atuadores"
                comando = {agendamento.atuador: agendamento.valor}
                
                print(f"[{datetime.datetime.now()}] Executando agendamento {agendamento_id}: {comando}")
                publish_message(topic, comando)
    finally:
        db.close()

def carregar_agendamentos():
    """Lê todos os agendamentos do banco e adiciona ao APScheduler"""
    # Remove todos os jobs existentes para recarregar do zero (evita duplicatas)
    scheduler.remove_all_jobs()
    
    db = SessionLocal()
    try:
        agendamentos = db.query(Agendamento).all()
        for agenda in agendamentos:
            hora, minuto = agenda.horario.split(':')
            
            # Adiciona o job no agendador
            scheduler.add_job(
                executar_comando,
                CronTrigger(
                    day_of_week=agenda.dias_semana,
                    hour=int(hora),
                    minute=int(minuto)
                ),
                args=[agenda.id],
                id=f"job_{agenda.id}"
            )
        print(f"Agendador: {len(agendamentos)} rotinas carregadas com sucesso.")
    finally:
        db.close()

def start_scheduler():
    if not scheduler.running:
        scheduler.start()
        carregar_agendamentos()

def stop_scheduler():
    if scheduler.running:
        scheduler.shutdown()
