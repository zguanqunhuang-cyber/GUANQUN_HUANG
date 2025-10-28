"""Minimal API for CLI Agent"""
from fastapi import APIRouter, HTTPException
from datetime import datetime, timezone
import uuid
from services.supabase import DBConnection
from utils.logger import logger
from pydantic import BaseModel
from .worker import generate_code_task, remix_code_task
from .config import config
import os

router = APIRouter()
db = None

def initialize(db_connection: DBConnection):
    """Initialize API with database connection"""
    global db
    db = db_connection
    logger.info("CLI Agent API initialized")


class GenerateRequest(BaseModel):
    prompt: str


class RemixRequest(BaseModel):
    prompt: str
    content_id: str  # Source content ID to remix from


class TaskResponse(BaseModel):
    task_id: str
    status: str
    project_path: str | None = None
    files_generated: list = []
    index_url: str | None = None
    error_message: str | None = None


@router.post("/generate")
async def generate_code(body: GenerateRequest):
    """Submit a code generation task"""
    
    # Skip database for now, just test the flow
    task_id = str(uuid.uuid4())
    
    # Always use UUID as folder name
    project_folder = task_id
    project_path = os.path.join(config.WORKSPACE_BASE, project_folder)
    
    # # Create task in database - SKIP FOR NOW
    # client = await db.client
    # task_data = {
    #     'id': task_id,
    #     'prompt': body.prompt,
    #     'project_name': project_folder,
    #     'project_path': project_path,
    #     'status': 'pending'
    # }
    # await client.schema('ios_app').table('cli_agent_tasks').insert(task_data).execute()
    
    logger.info(f"Created task (no DB): {task_id} in folder: {project_folder}")
    
    # Send to worker queue
    try:
        result = generate_code_task.send(
            task_id=task_id,
            prompt=body.prompt,
            project_folder=project_folder
        )
        logger.info(f"Task sent to queue. Message ID: {result.message_id if result else 'None'}")
    except Exception as e:
        logger.error(f"Failed to send task to queue: {e}")
    
    return {"task_id": task_id, "status": "pending", "project_path": project_path}


@router.post("/remix")
async def remix_code(body: RemixRequest):
    """Submit a code remix task - takes existing content and modifies it"""
    
    # Generate new task ID for the remixed content
    task_id = str(uuid.uuid4())
    
    # Always use UUID as folder name
    project_folder = task_id
    project_path = os.path.join(config.WORKSPACE_BASE, project_folder)
    
    logger.info(f"Created remix task (no DB): {task_id} from content: {body.content_id}")
    
    # Send to worker queue with source content_id
    try:
        result = remix_code_task.send(
            task_id=task_id,
            prompt=body.prompt,
            project_folder=project_folder,
            source_content_id=body.content_id
        )
        logger.info(f"Remix task sent to queue. Message ID: {result.message_id if result else 'None'}")
    except Exception as e:
        logger.error(f"Failed to send remix task to queue: {e}")
    
    return {"task_id": task_id, "status": "pending", "project_path": project_path, "source_content_id": body.content_id}


@router.get("/task/{task_id}")
async def get_task_status(task_id: str):
    """Get task status from Redis (temporary for testing)"""
    
    from services import redis
    redis_client = await redis.get_client()
    
    # Try to get result from Redis
    result_str = await redis_client.get(f"cli_task:{task_id}")
    
    if not result_str:
        # Task might be still pending or expired
        return TaskResponse(
            task_id=task_id,
            status="pending or expired",
            project_path=None,
            files_generated=[],
            error_message=None
        )
    
    # Parse the result
    import ast
    try:
        result = ast.literal_eval(result_str.decode() if isinstance(result_str, bytes) else result_str)
    except:
        result = {"success": False, "error": "Failed to parse result"}
    
    return TaskResponse(
        task_id=task_id,
        status="completed" if result.get("success") else "failed",
        project_path=result.get("project_path"),
        files_generated=result.get("files_generated", []),
        index_url=result.get("index_url"),
        error_message=result.get("error")
    )