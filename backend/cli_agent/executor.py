"""Minimal Gemini CLI executor"""
import asyncio
import os
from typing import Dict, Any
from utils.logger import logger
from .config import config


class GeminiExecutor:
    """Execute Gemini CLI to generate code"""
    
    async def execute(self, prompt: str, project_path: str) -> Dict[str, Any]:
        """Execute Gemini CLI
        
        Returns:
            Dictionary with execution results
        """
        # Ensure directory exists
        os.makedirs(project_path, exist_ok=True)
        
        # Build combined command - add MCP server and then run gemini
        cmd = [
            "sh", "-c",
            f"gemini mcp add mcp-fal https://mcp-fal.fastmcp.app/mcp --transport http && gemini -y -m {config.DEFAULT_MODEL} -p '{prompt}' -a"
        ]
        
        logger.info(f"Executing Gemini CLI with MCP-FAL in {project_path}")
        
        try:
            # Execute command
            process = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=project_path,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                env={
                    **os.environ,
                    "GEMINI_API_KEY": config.GEMINI_API_KEY
                }
            )
            
            # Wait for completion (15 min timeout for video generation tasks)
            stdout, stderr = await asyncio.wait_for(
                process.communicate(),
                timeout=900
            )
            
            # Log output for debugging
            stdout_text = stdout.decode('utf-8') if stdout else ""
            stderr_text = stderr.decode('utf-8') if stderr else ""
            
            logger.info(f"Gemini stdout: {stdout_text}")  # First 500 chars
            if stderr_text:
                logger.warning(f"Gemini stderr: {stderr_text}")
            logger.info(f"Return code: {process.returncode}")
            
            # List generated files
            files = []
            for root, dirs, filenames in os.walk(project_path):
                for filename in filenames:
                    if not filename.startswith('.'):
                        files.append(filename)
            
            logger.info(f"Files found in {project_path}: {files}")
            
            return {
                "success": process.returncode == 0,
                "files_generated": files,
                "project_path": project_path,
                "error": stderr_text if process.returncode != 0 else None
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "project_path": project_path
            }