## Sistema de Irrigação Inteligente

## Equipe: AgroTech Solutions(Soluções AgroTech).

## Descrição
Este projeto tem como objetivo desenvolver uma aplicação mobile para automação de sistemas de irrigação, utilizando dados do solo como umidade para auxiliar na tomada de decisões.
A aplicação permite monitorar as condições do solo e automatizar a irrigação, promovendo economia de água e maior eficiência no cultivo.

## Objetivo
Desenvolver a interface e funcionalidades iniciais de um aplicativo mobile utilizando Flutter, com base nos protótipos criados no Figma, como parte do Projeto Integrador.

 Protótipo (Figma)
 Acesse: https://www.figma.com/design/YUP2HoXGPRbjeQiaYKgmeb/INICIAL?node-id=0-1&t=p2Ltnb1lcIliyNCq-1


## Telas do Protótipo:

 Funcionalidades
 Monitoramento da umidade do solo
 Controle automático de irrigação
 Tela de login e autenticação
 Visualização de dados em tempo real
 Interface intuitiva para o usuário

##  Fluxo da Aplicação
1. O usuário acessa o aplicativo
2. Realiza login com email e senha
3. O administrador cadastra a empresa
4. O usuário acessa a tela principal
5. Visualiza os dados do solo
6. Controla ou monitora a irrigação

## Tecnologias Utilizadas
- Flutter
- Dart
- Python
- FastAPI
- Android Studio
- Figma
- Git

## Como Executar o Projeto

### Backend (FastAPI)

1.  **Navegue até a pasta do backend:**
    ```sh
    cd projeto_integrador_backend
    ```

2.  **Crie e ative um ambiente virtual:**
    ```sh
    # Criar o ambiente virtual
    python3 -m venv venv
    # Ativar no macOS/Linux
    source venv/bin/activate
    # Ativar no Windows
    .\\venv\\Scripts\\activate
    ```

3.  **Instale as dependências:**
    ```sh
    pip install -r requirements.txt
    ```

4.  **Execute o servidor:**
    ```sh
    uvicorn main:app --reload
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

## Melhorias Futuras
- Integração com sensores reais de umidade do solo
- Finalizar integração e lógica do backend (API)
- Notificações automáticas para o usuário
- Dashboard mais detalhado

## Organização do Projeto
Uso de Git para controle de versão
Commits frequentes documentando o progresso

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
