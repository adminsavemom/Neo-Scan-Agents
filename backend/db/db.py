from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()
class Base(DeclarativeBase):
    pass


DATABASE_URL = os.environ.get("DATABASE_URL")  

engine = create_async_engine(DATABASE_URL, echo=False)

# Use the new async_sessionmaker instead
async_session = async_sessionmaker(engine, expire_on_commit=False)


async def get_db():
    async with async_session() as session:
        try:
            yield session
            # await session.commit()
        except Exception:
            await session.rollback()
            raise


