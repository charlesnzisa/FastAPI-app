from fastapi import FastAPI, HTTPException, Depends
from sqlalchemy import create_engine, Column, Integer, String, Sequence
from sqlalchemy.orm import declarative_base, sessionmaker, Session, scoped_session
from databases import Database
from pydantic import BaseModel
import requests

DATABASE_URL = "sqlite:///./test.db"

#Establishing Database connection based on the database url
engine = create_engine(DATABASE_URL)

#Creating a new database session object
SessionLocal = scoped_session(sessionmaker(autocommit=False, autoflush=False, bind=engine))

Base = declarative_base()

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, Sequence("user_id_seq"), primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    password = Column(String)

#Code to create a database table
Base.metadata.create_all(bind=engine)

# pydantic model to validate and serialize the incoming data(request payloads)
class UserCreate(BaseModel):
    username: str
    password: str

# pydantic model to validate and serialize the response data(response payloads)
class UserResponse(BaseModel):
    id: int
    username: str

app = FastAPI()

# Dependency to get the database session(manages and shares resources across multiple endpionts/routes)
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Route to create a new user
@app.post("/create_user")
async def create_user(user_create: UserCreate, db: Session = Depends(get_db)):
    # Check if the username already exists
    existing_user = db.query(User).filter(User.username == user_create.username).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    # If the username is unique, proceed with creating the user
    with db:
        user = User(username=user_create.username, password=user_create.password)
        db.add(user)
        db.commit()
        db.refresh(user)
    return user

# Route to get all users(fetching users from the database)
@app.get("/get_users", response_model=list[UserResponse])
async def get_users(db: Session = Depends(get_db)):
    users = db.query(User).all()
    return users

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="127.0.0.1", port=8000, reload=True)
