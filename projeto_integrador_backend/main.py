from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional

app = FastAPI()

# --- Pydantic Models ---

class User(BaseModel):
    email: str
    senha: str
    nome: Optional[str] = None

class Empresa(BaseModel):
    nome: str
    quantidadePlantacoes: int
    quantidadeLicencas: int

class EmpresaAction(BaseModel):
    empresaId: str

class UsuarioEmpresa(BaseModel):
    nome: str
    email: str
    senha: str
    empresaId: str

# --- Dummy Data Store ---

# In-memory "database" for demonstration
db_users = {}
db_empresas = {}
db_usuarios_empresa = {}

# --- Endpoints ---

@app.post("/login")
async def login(user: User):
    """
    Accepts any user for now and returns a success message.
    In a real app, you'd verify credentials against a database.
    """
    return {"message": f"Login successful for user {user.email}", "user": {"email": user.email, "nome": "Dummy User"}}

@app.post("/register")
async def register(user: User):
    """
    Dummy registration endpoint.
    """
    if user.email in db_users:
        raise HTTPException(status_code=400, detail="Email already registered")
    db_users[user.email] = user
    return {"message": f"User {user.nome} registered successfully"}

@app.post("/empresas")
async def create_empresa(empresa: Empresa):
    """
    Dummy endpoint to create a company.
    """
    # A simple way to "store" the company
    db_empresas[empresa.nome] = empresa
    return {"message": f"Empresa {empresa.nome} created successfully", "empresaId": empresa.nome}

@app.get("/empresas", response_model=List[Empresa])
async def get_empresas():
    """
    Dummy endpoint to list all companies.
    """
    return list(db_empresas.values())

@app.post("/empresas/bloquear")
async def bloquear_empresa(action: EmpresaAction):
    """
    Dummy endpoint to block a company.
    """
    return {"message": f"Empresa {action.empresaId} has been blocked."}

@app.post("/empresas/desbloquear")
async def desbloquear_empresa(action: EmpresaAction):
    """
    Dummy endpoint to unblock a company.
    """
    return {"message": f"Empresa {action.empresaId} has been unblocked."}

@app.get("/usuarios-empresa")
async def get_usuarios_empresa(empresa: str):
    """
    Dummy endpoint to list users of a specific company.
    Filters users based on the 'empresa' query parameter.
    """
    # This is a simplified filter. A real implementation would be more robust.
    filtered_users = [user for user in db_usuarios_empresa.values() if user.empresaId == empresa]
    return filtered_users

@app.post("/usuarios-empresa")
async def create_usuario_empresa(usuario: UsuarioEmpresa):
    """
    Dummy endpoint to create a company user.
    """
    db_usuarios_empresa[usuario.email] = usuario
    return {"message": f"User {usuario.nome} for company {usuario.empresaId} created successfully"}
