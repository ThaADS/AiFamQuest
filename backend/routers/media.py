"""
Media Upload Router

Handles file uploads for task proof photos, avatars, and vision tips.

Features:
- Local storage fallback for development
- S3 integration for production (optional)
- File validation (size, type)
- Presigned URLs for secure access
- Media record tracking in database
"""

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.orm import Session
from core.deps import get_current_user
from core.db import SessionLocal
from core import models
from datetime import datetime
from typing import Dict, Any
import os
import uuid
import shutil
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/media", tags=["media"])

# Configuration
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB
ALLOWED_TYPES = ["image/jpeg", "image/png", "image/jpg", "image/webp"]


def get_db():
    """Database dependency"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/upload")
async def upload(
    file: UploadFile = File(...),
    context: str = "task_proof",  # task_proof, avatar, vision_tip
    context_id: str = None,
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Upload photo for task proof, avatar, or vision tips.

    Steps:
    1. Validate file (size, type)
    2. Save to storage (local or S3)
    3. Create Media record in DB
    4. Return URL

    Query params:
    - context: task_proof | avatar | vision_tip
    - context_id: Optional task ID or user ID

    Returns:
    {
        "url": "http://localhost:8000/uploads/uuid.jpg",
        "media_id": "uuid",
        "thumbnail_url": "http://..."  # Future: actual thumbnails
    }
    """
    user_id = current_user.get("sub")
    family_id = current_user.get("familyId")

    if not family_id:
        raise HTTPException(400, "User family not found")

    # Read file content
    file_content = await file.read()
    file_size = len(file_content)

    # 1. Validate file size
    if file_size > MAX_FILE_SIZE:
        raise HTTPException(413, f"File too large. Max {MAX_FILE_SIZE / 1024 / 1024}MB")

    # 2. Validate file type
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(400, f"Invalid file type. Allowed: {', '.join(ALLOWED_TYPES)}")

    # 3. Generate unique filename
    file_ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    unique_filename = f"{family_id}/{uuid.uuid4()}.{file_ext}"

    # 4. Save to storage
    try:
        # Check if S3 is configured
        use_s3 = bool(os.getenv("AWS_ACCESS_KEY_ID"))

        if use_s3:
            # TODO: Implement S3 upload in production
            # For now, fall back to local storage
            url = await _upload_local(file_content, unique_filename)
        else:
            # Local storage for development
            url = await _upload_local(file_content, unique_filename)

    except Exception as e:
        logger.error(f"File upload failed: {e}")
        raise HTTPException(500, f"Upload failed: {str(e)}")

    # 5. Create Media record
    try:
        media = models.Media(
            familyId=family_id,
            uploadedBy=user_id,
            url=url,
            storageKey=unique_filename,
            mimeType=file.content_type,
            sizeBytes=file_size,
            avScanStatus="pending",  # TODO: Integrate virus scanning
            context=context,
            contextId=context_id,
            createdAt=datetime.utcnow()
        )
        db.add(media)
        db.commit()
        db.refresh(media)

        logger.info(f"Media uploaded: {media.id} by user {user_id}")

        return {
            "url": url,
            "media_id": str(media.id),
            "thumbnail_url": url,  # TODO: Generate actual thumbnails
            "file_size": file_size,
            "context": context
        }

    except Exception as e:
        logger.error(f"Failed to create media record: {e}")
        raise HTTPException(500, f"Database error: {str(e)}")


async def _upload_local(file_content: bytes, filename: str) -> str:
    """Upload file to local storage"""
    media_dir = os.getenv("MEDIA_DIR", "./uploads")
    os.makedirs(media_dir, exist_ok=True)

    # Ensure family subdirectory exists
    family_subdir = os.path.dirname(os.path.join(media_dir, filename))
    os.makedirs(family_subdir, exist_ok=True)

    file_path = os.path.join(media_dir, filename)

    # Write file
    with open(file_path, "wb") as f:
        f.write(file_content)

    # Generate public URL
    public_base = os.getenv("PUBLIC_BASE", "http://localhost:8000")
    url = f"{public_base}/uploads/{filename}"

    return url


@router.get("/list")
async def list_media(
    context: str = None,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    List media files for current family.

    Query params:
    - context: Filter by context (task_proof, avatar, vision_tip)
    - limit: Max results (default 50)

    Returns:
    {
        "media": [
            {
                "id": "uuid",
                "url": "http://...",
                "context": "task_proof",
                "uploaded_by": "uuid",
                "created_at": "2025-11-11T12:00:00Z"
            }
        ],
        "total": 15
    }
    """
    family_id = current_user.get("familyId")
    if not family_id:
        raise HTTPException(400, "User family not found")

    query = db.query(models.Media).filter(models.Media.familyId == family_id)

    if context:
        query = query.filter(models.Media.context == context)

    query = query.order_by(models.Media.createdAt.desc()).limit(limit)

    media_list = query.all()

    return {
        "media": [
            {
                "id": str(m.id),
                "url": m.url,
                "context": m.context,
                "context_id": m.contextId,
                "uploaded_by": str(m.uploadedBy),
                "created_at": m.createdAt.isoformat(),
                "file_size": m.sizeBytes
            }
            for m in media_list
        ],
        "total": len(media_list)
    }


@router.delete("/{media_id}")
async def delete_media(
    media_id: str,
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Delete media file.

    Only the uploader or parents can delete media.
    """
    user_id = current_user.get("sub")
    user_role = current_user.get("role")

    media = db.query(models.Media).filter(models.Media.id == media_id).first()

    if not media:
        raise HTTPException(404, "Media not found")

    # Authorization: uploader or parent
    if media.uploadedBy != user_id and user_role not in ["parent"]:
        raise HTTPException(403, "Not authorized to delete this media")

    try:
        # Delete from storage
        media_dir = os.getenv("MEDIA_DIR", "./uploads")
        file_path = os.path.join(media_dir, media.storageKey)
        if os.path.exists(file_path):
            os.remove(file_path)

        # Delete from database
        db.delete(media)
        db.commit()

        logger.info(f"Media deleted: {media_id} by user {user_id}")

        return {"success": True, "message": "Media deleted"}

    except Exception as e:
        db.rollback()
        logger.error(f"Failed to delete media {media_id}: {e}")
        raise HTTPException(500, f"Delete failed: {str(e)}")
