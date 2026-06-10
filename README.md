## Sistema de Irrigação Inteligente

## Equipe: AgroTech Solutions (Soluções AgroTech).

## Descrição
Este projeto tem como objetivo desenvolver uma aplicação para automação de sistemas de irrigação, utilizando dados de sensores em tempo real para auxiliar na tomada de decisões. 
A aplicação integra um frontend em Flutter com um backend robusto em FastAPI, utilizando o protocolo MQTT para comunicação com dispositivos IoT (como Raspberry Pi ou Pico W) e banco de dados SQLite para persistência de dados.

## Objetivo
Desenvolver a interface e funcionalidades fim a fim de um sistema de monitoramento agrícola, permitindo o gerenciamento de plantações e a visualização de umidade e temperatura via sensores IoT.

### Protótipo (Figma)
Acesse: [Figma Link](https://www.figma.com/design/YUP2HoXGPRbjeQiaYKgmeb/INICIAL?node-id=0-1&t=p2Ltnb1lcIliyNCq-1)

## Funcionalidades
- **Autenticação Segura:** Login e cadastro de usuários com persistência em SQLite.
- **Monitoramento MQTT:** Recebimento de dados de umidade e temperatura via protocolo MQTT.
- **Gerenciamento de Plantações:** Cadastro de áreas de cultivo vinculadas a dispositivos específicos.
- **Descoberta de Dispositivos:** Identificação automática de novos tópicos MQTT ativos no Broker.
- **Dashboard em Tempo Real:** Visualização gráfica dos sensores ativos.
- **Configuração de Brokers:** Interface para gerenciar conexões com diferentes servidores MQTT.

## Tecnologias Utilizadas
- **Frontend:** Flutter / Dart (Mobile & Desktop)
- **Backend:** Python / FastAPI / SQLAlchemy (ORM)
- **Banco de Dados:** SQLite (sql_app.db)
- **Protocolo:** MQTT (Paho-MQTT)
- **Ferramentas:** VS Code, Git, Figma

## Como Executar o Projeto

### Backend (FastAPI)

1.  **Navegue até a pasta do backend:**
    ```sh
    cd projeto_integrador_backend
    ```

2.  **Ative o ambiente virtual:**
    ```sh
    source venv/bin/activate  # Linux/macOS
    # .venv\Scripts\activate # Windows
    ```

3.  **Instale as dependências:**
    ```sh
    pip install -r requirements.txt
    ```

4.  **Configure o .env:**
    Verifique as credenciais do seu broker MQTT no arquivo `.env`.

5.  **Execute o servidor:**
    ```sh
    uvicorn app.main:app --reload
    ```
    O servidor criará o banco automaticamente e estará disponível em `http://127.0.0.1:8000`.

### Frontend (Flutter)

1.  **Navegue até a pasta do frontend:**
    ```sh
    cd projeto_integrador
    ```

2.  **Instale as dependências:**
    ```sh
    flutter pub get
    ```

3.  **Execute a aplicação:**
    ```sh
    flutter run
    ```
    O app detectará automaticamente o backend (localhost ou 10.0.2.2).

## Print das telas
<img width="682" height="421" alt="image" src="https://github.com/user-attachments/assets/cd78724a-f362-4042-ab7d-b63848bb6a7d" />
<img width="718" height="443" alt="image" src="https://github.com/user-attachments/assets/3d8b92bc-2a39-4956-b40c-1746252d16e2" />
<img width="189" height="520" alt="image" src="https://github.com/user-attachments/assets/c0151b85-a0e9-4c54-912b-c75485108914" />
<img width="765" height="501" alt="image" src="https://github.com/user-attachments/assets/c96653af-0156-46bc-92c0-326a7bbb3226" />

## Equipe
- Aline  
- Bruno   
- Carla  
- Carlos  
- João  
- Maria  
- Raul  
- Rebeca
