## Sistema de Irrigação Inteligente

## Equipe: AgroTech Solutions (Soluções AgroTech).

## Descrição
Este projeto tem como objetivo desenvolver uma aplicação mobile para automação de sistemas de irrigação, utilizando dados do solo como umidade para auxiliar na tomada de decisões.
A aplicação permite monitorar as condições do solo e automatizar a irrigação, promovendo economia de água e maior eficiência no cultivo.

## Objetivo
Desenvolver a interface e funcionalidades iniciais de um aplicativo mobile utilizando Flutter, com base nos protótipos criados no Figma, como parte do Projeto Integrador.

### Protótipo (Figma)
Acesse: [Figma Link](https://www.figma.com/design/YUP2HoXGPRbjeQiaYKgmeb/INICIAL?node-id=0-1&t=p2Ltnb1lcIliyNCq-1)

## Funcionalidades
- Monitoramento de umidade do solo via MQTT
- API REST para controle e autenticação
- Sistema de login e cadastro de usuários/empresas
- Visualização de dados de sensores em tempo real
- Controle manual e automático de irrigação

## Tecnologias Utilizadas
- **Frontend:** Flutter / Dart
- **Backend:** Python / FastAPI
- **Protocolo:** MQTT (Paho-MQTT)
- **Ferramentas:** Android Studio, VS Code, Figma, Git

## Como Executar o Projeto

### Backend (FastAPI)

1.  **Navegue até a pasta do backend:**
    ```sh
    cd projeto_integrador_backend
    ```

2.  **Crie e ative um ambiente virtual:**
    ```sh
    python3 -m venv .venv
    source .venv/bin/activate  # Linux/macOS
    .venv/Scripts/activate # Windows
    ```

3.  **Instale as dependências:**
    ```sh
    pip install -r requirements.txt
    ```

4.  **Configure as variáveis de ambiente:**
    Copie o arquivo de exemplo e preencha com as credenciais do seu broker MQTT:
    ```sh
    cp .env.example .env
    ```

5.  **Execute o servidor:**
    ```sh
    uvicorn app.main:app --reload
    ```
    O servidor estará disponível em `http://127.0.0.1:8000`.

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
    Certifique-se de que o servidor backend esteja rodando e que um emulador/dispositivo esteja conectado.
    ```sh
    flutter run
    ```


## Print das telas
<img width="682" height="421" alt="image" src="https://github.com/user-attachments/assets/cd78724a-f362-4042-ab7d-b63848bb6a7d" />
<img width="718" height="443" alt="image" src="https://github.com/user-attachments/assets/3d8b92bc-2a39-4956-b40c-1746252d16e2" />
<img width="189" height="520" alt="image" src="https://github.com/user-attachments/assets/c0151b85-a0e9-4c54-912b-c75485108914" />
<img width="765" height="501" alt="image" src="https://github.com/user-attachments/assets/c96653af-0156-46bc-92c0-326a7bbb3226" />
<img width="695" height="575" alt="image" src="https://github.com/user-attachments/assets/890476f9-f76a-49c6-b650-298c1442cc60" />
<img width="373" height="429" alt="image" src="https://github.com/user-attachments/assets/159d5e1e-9c6f-4aeb-a1c1-855c497af163" />

## Equipe
- Aline  
- Bruno   
- Carla  
- Carlos  
- João  
- Maria  
- Raul  
- Rebeca
