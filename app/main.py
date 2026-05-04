from fastapi import FastAPI

from app.routes import router

app = FastAPI(title="devops-cicd-lab")
app.include_router(router)
