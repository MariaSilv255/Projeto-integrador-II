from app.schemas import Usuario, DadosUsuario

# Simulação de um banco de dados em memória com um usuário padrão

db_usuarios = {
    "testuser": Usuario(id=1, nome_usuario="testuser", senha="password")
}

db_dados_usuarios = {
    1: DadosUsuario(id=1, email="test@user.com", fk_id_usuario=1)
}

db_brokers = {}
db_cadastros_irrigacao = {}
