"""Minimal Dramatiq worker for CLI Agent"""
import asyncio
from datetime import datetime, timezone
import dramatiq
from dramatiq.brokers.redis import RedisBroker
import os
from pathlib import Path
from typing import List, Dict
from services import redis
from services.supabase import DBConnection
from utils.logger import logger
from utils.aws_s3_upload import storage_client
from .executor import GeminiExecutor
from .config import config

# Redis broker
redis_host = os.getenv('REDIS_HOST', 'localhost')
redis_port = int(os.getenv('REDIS_PORT', 6379))
redis_broker = RedisBroker(host=redis_host, port=redis_port, middleware=[dramatiq.middleware.AsyncIO()])
dramatiq.set_broker(redis_broker)

db = DBConnection()

@dramatiq.actor
async def generate_code_task(task_id: str, prompt: str, project_folder: str):
    """Generate code using Gemini CLI"""
    
    logger.info(f"Starting task (no DB): {task_id} in folder: {project_folder}")
    
    try:
        # Initialize Redis only
        await redis.initialize_async()
        
        # Skip database updates for now
        # await db.initialize()
        # client = await db.client
        # await client.schema('ios_app').table('cli_agent_tasks').update({
        #     'status': 'running',
        #     'started_at': datetime.now(timezone.utc).isoformat()
        # }).eq('id', task_id).execute()
        
        # Build project path
        project_path = os.path.join(config.WORKSPACE_BASE, project_folder)
        
        # Execute Gemini CLI
        executor = GeminiExecutor()
        result = await executor.execute(prompt, project_path)
        
        # Upload generated files to S3 if successful
        index_url = None
        if result["success"] and result.get("files_generated"):
            logger.info(f"Uploading {len(result['files_generated'])} files to S3...")
            
            for filename in result["files_generated"]:
                file_path = Path(project_path) / filename
                if file_path.exists():
                    try:
                        # Read file content
                        with open(file_path, 'rb') as f:
                            content = f.read()
                        
                        # Create S3 key: contents/{task_id}/{filename}
                        s3_key = f"contents/{task_id}/{filename}"
                        
                        # Upload to S3
                        url = await storage_client.upload_file(s3_key, content)
                        logger.info(f"Uploaded {filename} to {url}")
                        
                        # Save index.html URL specifically
                        if filename == "index.html":
                            index_url = url
                    except Exception as e:
                        logger.error(f"Failed to upload {filename}: {str(e)}")
            
            result["index_url"] = index_url
        
        # Store result in Redis temporarily for testing
        redis_client = await redis.get_client()
        await redis_client.setex(
            f"cli_task:{task_id}",
            300,  # Expire in 5 minutes
            str(result)
        )
        
        if result["success"]:
            logger.info(f"Task {task_id} completed. Files: {result.get('files_generated', [])}. Index URL: {index_url}")
        else:
            logger.error(f"Task {task_id} failed: {result.get('error')}")
            
    except Exception as e:
        logger.error(f"Task {task_id} error: {str(e)}")
        
        # Store error in Redis for testing
        try:
            redis_client = await redis.get_client()
            await redis_client.setex(
                f"cli_task:{task_id}",
                300,  # Expire in 5 minutes
                str({"success": False, "error": str(e)})
            )
        except:
            pass


@dramatiq.actor
async def remix_code_task(task_id: str, prompt: str, project_folder: str, source_content_id: str):
    """Remix existing code using Gemini CLI"""
    
    logger.info(f"Starting remix task (no DB): {task_id} from content: {source_content_id}")
    
    try:
        # Initialize Redis only
        await redis.initialize_async()
        
        # Build project path
        project_path = os.path.join(config.WORKSPACE_BASE, project_folder)
        
        # Create project directory
        Path(project_path).mkdir(parents=True, exist_ok=True)
        
        # Download all files from source content folder in S3
        source_prefix = f"contents/{source_content_id}/"
        logger.info(f"Downloading files from S3 with prefix: {source_prefix}")
        
        # List all files in the source folder
        files_to_download = await storage_client.list_files(source_prefix)
        
        if not files_to_download:
            raise ValueError(f"No files found for content_id: {source_content_id}")
        
        logger.info(f"Found {len(files_to_download)} files to download")
        
        # Download each file from S3 to local project folder
        for file_info in files_to_download:
            s3_key = file_info["key"]
            # Extract filename from S3 key (remove prefix)
            filename = s3_key.replace(source_prefix, "")
            
            if filename:  # Skip if empty (folder itself)
                local_file_path = Path(project_path) / filename
                
                # Create subdirectories if needed
                local_file_path.parent.mkdir(parents=True, exist_ok=True)
                
                # Download file content
                content = await storage_client.download_file(s3_key)
                
                # Write to local file
                with open(local_file_path, 'wb') as f:
                    f.write(content)
                
                logger.info(f"Downloaded {filename} to {local_file_path}")
        
        # Execute Gemini CLI with the remix prompt
        executor = GeminiExecutor()
        result = await executor.execute(prompt, project_path)
        
        # Upload remixed files to S3 if successful
        index_url = None
        if result["success"] and result.get("files_generated"):
            logger.info(f"Uploading {len(result['files_generated'])} remixed files to S3...")
            
            # Get all files in project directory (including downloaded ones)
            all_files = []
            for root, dirs, files in os.walk(project_path):
                for file in files:
                    file_path = Path(root) / file
                    relative_path = file_path.relative_to(project_path)
                    all_files.append(str(relative_path))
            
            # Upload all files to new location
            for filename in all_files:
                file_path = Path(project_path) / filename
                if file_path.exists():
                    try:
                        # Read file content
                        with open(file_path, 'rb') as f:
                            content = f.read()
                        
                        # Create S3 key: contents/{new_task_id}/{filename}
                        s3_key = f"contents/{task_id}/{filename}"
                        
                        # Upload to S3
                        url = await storage_client.upload_file(s3_key, content)
                        logger.info(f"Uploaded {filename} to {url}")
                        
                        # Save index.html URL specifically
                        if filename == "index.html":
                            index_url = url
                    except Exception as e:
                        logger.error(f"Failed to upload {filename}: {str(e)}")
            
            result["index_url"] = index_url
            result["source_content_id"] = source_content_id
        
        # Store result in Redis temporarily for testing
        redis_client = await redis.get_client()
        await redis_client.setex(
            f"cli_task:{task_id}",
            300,  # Expire in 5 minutes
            str(result)
        )
        
        if result["success"]:
            logger.info(f"Remix task {task_id} completed. Files: {all_files}. Index URL: {index_url}")
        else:
            logger.error(f"Remix task {task_id} failed: {result.get('error')}")
            
    except Exception as e:
        logger.error(f"Remix task {task_id} error: {str(e)}")
        
        # Store error in Redis for testing
        try:
            redis_client = await redis.get_client()
            await redis_client.setex(
                f"cli_task:{task_id}",
                300,  # Expire in 5 minutes
                str({"success": False, "error": str(e)})
            )
        except:
            pass