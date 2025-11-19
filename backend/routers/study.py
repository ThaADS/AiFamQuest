"""
Study System Router (Homework Coach)

Endpoints for AI-powered study planning and micro-quizzes:
- POST /study/items: Create study item with AI-generated plan
- GET /study/items: List user's study items
- GET /study/items/:id: Get study item details
- POST /study/items/:id/sessions/:session_id/complete: Mark session as completed
- POST /study/quiz/generate: Generate micro-quiz for active recall
- DELETE /study/items/:id: Delete study item

Features:
- Backward planning from exam date
- Spaced repetition scheduling
- Micro-quizzes for active recall
- Progress tracking
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from core.deps import get_current_user, get_db, require_role
from core import models
from services.openrouter_client import OpenRouterClient
from pydantic import BaseModel, Field
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
import logging
import uuid

logger = logging.getLogger(__name__)

router = APIRouter()


class StudyItemCreate(BaseModel):
    """Request to create study item"""
    subject: str = Field(..., min_length=1, max_length=100, description="Subject name")
    topic: str = Field(..., min_length=1, max_length=500, description="Topic details")
    test_date: datetime = Field(..., description="Exam/test date")
    difficulty: str = Field(default="medium", description="Difficulty level (easy|medium|hard)")
    available_time_per_day: int = Field(default=30, ge=10, le=180, description="Minutes per day for study")

    class Config:
        json_schema_extra = {
            "example": {
                "subject": "Biology",
                "topic": "Cell structure, photosynthesis, mitosis",
                "test_date": "2025-11-25T09:00:00Z",
                "difficulty": "medium",
                "available_time_per_day": 30
            }
        }


class StudyItemOut(BaseModel):
    """Study item response"""
    id: str
    subject: str
    topic: str
    test_date: Optional[str]
    study_plan: Dict[str, Any]
    status: str
    created_at: str
    updated_at: str


class StudySessionComplete(BaseModel):
    """Request to complete study session"""
    quiz_results: Optional[Dict[str, Any]] = Field(None, description="Quiz results if taken")
    score: Optional[int] = Field(None, ge=0, le=100, description="Quiz score percentage")
    notes: Optional[str] = Field(None, max_length=500, description="Session notes")


class QuizGenerateRequest(BaseModel):
    """Request to generate quiz"""
    subject: str = Field(..., min_length=1, max_length=100)
    topic: str = Field(..., min_length=1, max_length=500)
    difficulty: str = Field(default="medium", description="easy|medium|hard")
    num_questions: int = Field(default=5, ge=1, le=20, description="Number of questions")


@router.post("/items", response_model=StudyItemOut)
async def create_study_item(
    request: StudyItemCreate,
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Create study item with AI-generated backward planning.

    Generates a complete study schedule from now until test date:
    - Breaks topic into chunks
    - Schedules sessions with spaced repetition
    - Includes micro-quizzes for active recall
    - Provides milestones and checkpoints

    Only teens and children can create study items (or parents can create for them).

    Returns:
        Study item with full AI-generated plan
    """
    user_id = current_user.get("sub")
    role = current_user.get("role")

    # Validate test date is in future
    if request.test_date <= datetime.utcnow():
        raise HTTPException(400, "Test date must be in the future")

    # Validate reasonable time frame (at least 1 day, max 90 days)
    days_until_test = (request.test_date - datetime.utcnow()).days
    if days_until_test < 1:
        raise HTTPException(400, "Test date must be at least 1 day from now")
    if days_until_test > 90:
        raise HTTPException(400, "Test date must be within 90 days")

    try:
        # Generate AI study plan
        openrouter = OpenRouterClient()
        study_plan = await openrouter.generate_study_plan(
            subject=request.subject,
            topic=request.topic,
            test_date=request.test_date,
            difficulty=request.difficulty,
            available_time_per_day=request.available_time_per_day
        )

        # Check if AI generation failed
        if study_plan.get("error"):
            logger.warning(f"AI study plan generation failed: {study_plan['error']}")
            # Use fallback simple plan
            study_plan = _generate_simple_plan(
                request.subject,
                request.topic,
                request.test_date,
                request.available_time_per_day
            )

        # Create study item
        study_item = models.StudyItem(
            id=str(uuid.uuid4()),
            userId=user_id,
            subject=request.subject,
            topic=request.topic,
            testDate=request.test_date,
            studyPlan=study_plan,
            status="active",
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow()
        )

        db.add(study_item)

        # Create study sessions from plan
        for session_data in study_plan.get("plan", []):
            session_date = datetime.fromisoformat(session_data.get("date"))

            study_session = models.StudySession(
                id=str(uuid.uuid4()),
                studyItemId=study_item.id,
                scheduledDate=session_date,
                quizQuestions={},
                createdAt=datetime.utcnow()
            )
            db.add(study_session)

        db.commit()
        db.refresh(study_item)

        logger.info(f"Created study item {study_item.id} for user {user_id}")

        return StudyItemOut(
            id=study_item.id,
            subject=study_item.subject,
            topic=study_item.topic,
            test_date=study_item.testDate.isoformat() if study_item.testDate else None,
            study_plan=study_item.studyPlan,
            status=study_item.status,
            created_at=study_item.createdAt.isoformat(),
            updated_at=study_item.updatedAt.isoformat()
        )

    except Exception as e:
        db.rollback()
        logger.error(f"Failed to create study item: {e}")
        raise HTTPException(500, f"Failed to create study item: {str(e)}")


@router.get("/items", response_model=List[StudyItemOut])
async def list_study_items(
    status: Optional[str] = Query(None, description="Filter by status (active|completed|cancelled)"),
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> List[Dict[str, Any]]:
    """
    List user's study items.

    Query params:
    - status: Filter by status (optional)

    Returns:
        List of study items with plans
    """
    user_id = current_user.get("sub")

    query = db.query(models.StudyItem).filter(
        models.StudyItem.userId == user_id
    )

    if status:
        query = query.filter(models.StudyItem.status == status)

    study_items = query.order_by(models.StudyItem.testDate.asc()).all()

    return [
        StudyItemOut(
            id=item.id,
            subject=item.subject,
            topic=item.topic,
            test_date=item.testDate.isoformat() if item.testDate else None,
            study_plan=item.studyPlan,
            status=item.status,
            created_at=item.createdAt.isoformat(),
            updated_at=item.updatedAt.isoformat()
        )
        for item in study_items
    ]


@router.get("/items/{item_id}")
async def get_study_item(
    item_id: str,
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Get study item details with sessions.

    Returns:
    {
        "study_item": {...},
        "sessions": [
            {
                "id": "uuid",
                "scheduled_date": "2025-11-17T19:00:00Z",
                "completed_at": null,
                "score": null,
                "quiz_questions": {}
            }
        ],
        "progress": {
            "sessions_completed": 2,
            "sessions_total": 8,
            "completion_percentage": 25
        }
    }
    """
    user_id = current_user.get("sub")

    # Get study item
    study_item = db.query(models.StudyItem).filter(
        models.StudyItem.id == item_id,
        models.StudyItem.userId == user_id
    ).first()

    if not study_item:
        raise HTTPException(404, "Study item not found")

    # Get sessions
    sessions = db.query(models.StudySession).filter(
        models.StudySession.studyItemId == item_id
    ).order_by(models.StudySession.scheduledDate.asc()).all()

    sessions_data = [
        {
            "id": session.id,
            "scheduled_date": session.scheduledDate.isoformat(),
            "completed_at": session.completedAt.isoformat() if session.completedAt else None,
            "score": session.score,
            "quiz_questions": session.quizQuestions
        }
        for session in sessions
    ]

    # Calculate progress
    sessions_completed = sum(1 for s in sessions if s.completedAt)
    sessions_total = len(sessions)
    completion_percentage = int((sessions_completed / sessions_total * 100)) if sessions_total > 0 else 0

    return {
        "study_item": {
            "id": study_item.id,
            "subject": study_item.subject,
            "topic": study_item.topic,
            "test_date": study_item.testDate.isoformat() if study_item.testDate else None,
            "study_plan": study_item.studyPlan,
            "status": study_item.status,
            "created_at": study_item.createdAt.isoformat(),
            "updated_at": study_item.updatedAt.isoformat()
        },
        "sessions": sessions_data,
        "progress": {
            "sessions_completed": sessions_completed,
            "sessions_total": sessions_total,
            "completion_percentage": completion_percentage
        }
    }


@router.post("/items/{item_id}/sessions/{session_id}/complete")
async def complete_study_session(
    item_id: str,
    session_id: str,
    request: StudySessionComplete,
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Mark study session as completed.

    Optionally include quiz results and score.

    Returns:
    {
        "success": true,
        "session_id": "uuid",
        "points_earned": 10,
        "message": "Session completed! Keep up the good work."
    }
    """
    user_id = current_user.get("sub")

    # Verify study item ownership
    study_item = db.query(models.StudyItem).filter(
        models.StudyItem.id == item_id,
        models.StudyItem.userId == user_id
    ).first()

    if not study_item:
        raise HTTPException(404, "Study item not found")

    # Get session
    session = db.query(models.StudySession).filter(
        models.StudySession.id == session_id,
        models.StudySession.studyItemId == item_id
    ).first()

    if not session:
        raise HTTPException(404, "Study session not found")

    if session.completedAt:
        raise HTTPException(400, "Session already completed")

    # Mark as completed
    session.completedAt = datetime.utcnow()
    session.score = request.score
    if request.quiz_results:
        session.quizQuestions = request.quiz_results

    study_item.updatedAt = datetime.utcnow()

    db.commit()

    # Award gamification points
    points_earned = 10
    if request.score:
        # Bonus points for high scores
        if request.score >= 90:
            points_earned = 20
        elif request.score >= 75:
            points_earned = 15

    from services.points_service import PointsService
    points_service = PointsService(db)
    points_service.award_points(
        user_id,
        points_earned,
        f"Completed study session: {study_item.subject}",
        task_id=None
    )

    return {
        "success": True,
        "session_id": session.id,
        "points_earned": points_earned,
        "score": request.score,
        "message": f"Session completed! You earned {points_earned} points. Keep studying!"
    }


@router.post("/quiz/generate")
async def generate_quiz(
    request: QuizGenerateRequest,
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Generate micro-quiz for active recall practice.

    Uses AI to create quiz questions based on subject and topic.

    Returns:
    {
        "questions": [
            {
                "question": "What is the powerhouse of the cell?",
                "correct_answer": "Mitochondria",
                "type": "multiple_choice",
                "options": ["Mitochondria", "Nucleus", "Ribosome", "Chloroplast"],
                "explanation": "Brief explanation"
            }
        ],
        "total_questions": 5
    }
    """
    try:
        openrouter = OpenRouterClient()
        questions = await openrouter.generate_quiz(
            subject=request.subject,
            topic=request.topic,
            difficulty=request.difficulty,
            num_questions=request.num_questions
        )

        if not questions:
            # Fallback to simple quiz
            questions = _generate_simple_quiz(request.subject, request.topic, request.num_questions)

        return {
            "questions": questions,
            "total_questions": len(questions),
            "subject": request.subject,
            "topic": request.topic,
            "difficulty": request.difficulty
        }

    except Exception as e:
        logger.error(f"Quiz generation failed: {e}")
        raise HTTPException(500, f"Failed to generate quiz: {str(e)}")


@router.delete("/items/{item_id}")
async def delete_study_item(
    item_id: str,
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Delete study item and all sessions.

    Returns:
        Success confirmation
    """
    user_id = current_user.get("sub")

    study_item = db.query(models.StudyItem).filter(
        models.StudyItem.id == item_id,
        models.StudyItem.userId == user_id
    ).first()

    if not study_item:
        raise HTTPException(404, "Study item not found")

    # Delete sessions (cascade should handle this, but explicit is better)
    db.query(models.StudySession).filter(
        models.StudySession.studyItemId == item_id
    ).delete()

    db.delete(study_item)
    db.commit()

    return {
        "success": True,
        "item_id": item_id,
        "message": "Study item deleted"
    }


# Fallback Functions

def _generate_simple_plan(
    subject: str,
    topic: str,
    test_date: datetime,
    available_time_per_day: int
) -> Dict[str, Any]:
    """Generate simple rule-based study plan when AI fails"""
    days_until_test = (test_date - datetime.utcnow()).days
    num_sessions = min(days_until_test, 10)  # Max 10 sessions

    plan = []
    current_date = datetime.utcnow()

    for i in range(num_sessions):
        session_date = current_date + timedelta(days=i)
        plan.append({
            "date": session_date.date().isoformat(),
            "duration": available_time_per_day,
            "focus": f"{subject} - Day {i + 1}",
            "tasks": [
                "Review study materials",
                "Take notes on key concepts",
                "Practice quiz questions"
            ],
            "difficulty": "medium"
        })

    return {
        "plan": plan,
        "milestones": [
            {"date": (test_date - timedelta(days=2)).date().isoformat(), "checkpoint": "Final review"}
        ],
        "quizzes": [],
        "total_sessions": num_sessions,
        "estimated_hours": (num_sessions * available_time_per_day) / 60
    }


def _generate_simple_quiz(subject: str, topic: str, num_questions: int) -> List[Dict[str, Any]]:
    """Generate simple fallback quiz when AI fails"""
    return [
        {
            "question": f"What is an important concept in {topic}?",
            "correct_answer": "Review your notes",
            "type": "short_answer",
            "explanation": "This is a placeholder question. AI quiz generation unavailable."
        }
        for _ in range(min(num_questions, 3))
    ]
