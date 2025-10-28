"""Configuration for CLI Agent module"""
import os
from typing import Optional
from utils.config import config as global_config


class CLIAgentConfig:
    """Configuration for CLI Agent"""
    
    # Gemini CLI settings - use from global config
    DEFAULT_MODEL = global_config.GEMINI_MODEL or "gemini-2.0-flash-thinking-exp-01-21"
    GEMINI_API_KEY = global_config.GEMINI_API_KEY or ""
    
    # Workspace settings
    WORKSPACE_BASE = os.getenv("CLI_WORKSPACE_BASE", "/tmp/codex")
    MAX_PROJECT_SIZE_MB = int(os.getenv("CLI_MAX_PROJECT_SIZE_MB", "1024"))  # 1GB default
    
    # Execution settings
    DEFAULT_TIMEOUT_SECONDS = int(os.getenv("CLI_DEFAULT_TIMEOUT", "300"))  # 5 minutes
    MAX_TIMEOUT_SECONDS = int(os.getenv("CLI_MAX_TIMEOUT", "3600"))  # 1 hour
    MAX_CONCURRENT_TASKS_PER_USER = int(os.getenv("CLI_MAX_CONCURRENT_TASKS", "2"))
    
    # Redis settings
    TASK_RESULT_TTL_SECONDS = int(os.getenv("CLI_RESULT_TTL", "86400"))  # 24 hours
    
    # Security settings
    ALLOWED_PROJECT_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
    MAX_PROMPT_LENGTH = 10000
    MAX_FILES_PER_PROJECT = 1000
    
    @classmethod
    def get_user_workspace(cls, user_id: Optional[str], session_id: Optional[str]) -> str:
        """Get workspace path for a user or session"""
        if user_id:
            return os.path.join(cls.WORKSPACE_BASE, f"user_{user_id}")
        elif session_id:
            return os.path.join(cls.WORKSPACE_BASE, f"session_{session_id}")
        else:
            raise ValueError("Either user_id or session_id must be provided")
    
    @classmethod
    def get_project_path(cls, user_id: Optional[str], session_id: Optional[str], project_name: str) -> str:
        """Get full project path"""
        workspace = cls.get_user_workspace(user_id, session_id)
        return os.path.join(workspace, project_name)


config = CLIAgentConfig()