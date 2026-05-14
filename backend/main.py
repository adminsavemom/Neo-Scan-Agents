from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware




app = FastAPI()



app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


from v1.analysis import router as analysis_router


app.include_router(analysis_router, prefix="/v1", tags=["analysis"])



