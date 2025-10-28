"""Pydantic models for CLI Agent"""
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum


class TaskStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class CodeGenerationRequest(BaseModel):
    """Request model for code generation"""
    prompt: str = Field(..., description="User's prompt for code generation", max_length=10000)
    project_name: str = Field(..., description="Name of the project/subdirectory", pattern="^[a-zA-Z0-9_-]+$", max_length=100)
    model: Optional[str] = Field(None, description="Gemini model to use")
    session_id: Optional[str] = Field(None, description="Session ID for anonymous users")
    metadata: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Additional metadata")


class CodeGenerationResponse(BaseModel):
    """Response model for code generation request"""
    task_id: str
    status: TaskStatus
    project_path: str
    created_at: datetime


class TaskStatusResponse(BaseModel):
    """Response model for task status query"""
    task_id: str
    status: TaskStatus
    project_name: str
    project_path: str
    model_used: str
    prompt: str
    created_at: datetime
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    execution_time_seconds: Optional[float] = None
    files_generated: List[str] = Field(default_factory=list)
    execution_log: Optional[str] = None
    error_message: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)


class FileContentRequest(BaseModel):
    """Request model for getting file content"""
    file_path: str = Field(..., description="Relative path to the file within the project")


class FileContentResponse(BaseModel):
    """Response model for file content"""
    task_id: str
    file_path: str
    content: str
    size_bytes: int
    last_modified: datetime


class TaskListResponse(BaseModel):
    """Response model for listing tasks"""
    tasks: List[TaskStatusResponse]
    total: int
    page: int
    page_size: int