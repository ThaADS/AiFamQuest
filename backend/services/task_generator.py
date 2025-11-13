"""
Task Generation Service

Handles generation of recurring task instances from templates.

Features:
- Expand RRULE for recurring tasks
- Apply rotation logic to assign users
- Skip specific occurrences
- Generate tasks for date ranges
- Track generated instances to prevent duplicates
"""

from datetime import date, datetime, timedelta
from typing import List, Optional, Dict
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from dateutil.rrule import rrulestr
from uuid import uuid4

from core import models
from core.fairness import FairnessEngine


class TaskGenerator:
    """
    Service for generating recurring task instances.

    Handles:
    - RRULE expansion for recurring tasks
    - Rotation logic application
    - Duplicate prevention via TaskLog
    - Occurrence skipping and management
    """

    def __init__(self, db: Session):
        """
        Initialize task generator.

        Args:
            db: Database session
        """
        self.db = db
        self.fairness_engine = FairnessEngine(db)

    def generate_recurring_tasks(
        self,
        family_id: str,
        start_date: date,
        end_date: date,
        max_occurrences: int = 365
    ) -> List[models.Task]:
        """
        Generate task occurrences from recurring templates for date range.

        Process:
        1. Fetch all recurring tasks for family
        2. Expand RRULE for date range (max 365 occurrences)
        3. For each occurrence:
           - Check if already generated (TaskLog)
           - Check if skipped
           - Apply rotation logic (get assignee)
           - Create task instance with due date
        4. Return list of generated tasks

        Args:
            family_id: Family ID to generate tasks for
            start_date: Start of date range
            end_date: End of date range
            max_occurrences: Maximum occurrences per template (safety limit)

        Returns:
            List of generated Task instances
        """
        # Get all recurring task templates for family
        recurring_tasks = self.db.query(models.Task).filter(
            and_(
                models.Task.familyId == family_id,
                models.Task.rrule.isnot(None),
                models.Task.status == "open"  # Only active templates
            )
        ).all()

        generated_tasks = []

        for template in recurring_tasks:
            occurrences = self._expand_task_rrule(template, start_date, end_date, max_occurrences)

            for occurrence_date in occurrences:
                # Check if already generated
                if self._is_occurrence_generated(template.id, occurrence_date):
                    continue

                # Check if skipped
                if self._is_occurrence_skipped(template.id, occurrence_date):
                    continue

                # Generate task instance
                task_instance = self._create_task_instance(template, occurrence_date)

                if task_instance:
                    generated_tasks.append(task_instance)

        return generated_tasks

    def _expand_task_rrule(
        self,
        task: models.Task,
        start_date: date,
        end_date: date,
        max_occurrences: int
    ) -> List[date]:
        """
        Expand RRULE for task into occurrence dates.

        Args:
            task: Task template with rrule
            start_date: Range start
            end_date: Range end
            max_occurrences: Maximum occurrences

        Returns:
            List of occurrence dates within range
        """
        if not task.rrule:
            # Not a recurring task
            if task.due:
                task_date = task.due.date()
                if start_date <= task_date <= end_date:
                    return [task_date]
            return []

        try:
            # Parse RRULE with task's due date as start
            dtstart = task.due if task.due else datetime.combine(start_date, datetime.min.time())
            rule = rrulestr(task.rrule, dtstart=dtstart)

            occurrences = []
            count = 0

            for occurrence_dt in rule:
                if count >= max_occurrences:
                    break

                occurrence_date = occurrence_dt.date()

                # Check if within range
                if occurrence_date > end_date:
                    break

                if occurrence_date >= start_date:
                    occurrences.append(occurrence_date)
                    count += 1

            return occurrences

        except Exception as e:
            # RRULE parsing failed - log and skip
            print(f"Failed to parse RRULE for task {task.id}: {e}")
            return []

    def _is_occurrence_generated(self, template_id: str, occurrence_date: date) -> bool:
        """
        Check if occurrence was already generated.

        Uses TaskLog with action='generated' to track.

        Args:
            template_id: Template task ID
            occurrence_date: Occurrence date

        Returns:
            True if already generated
        """
        log_entry = self.db.query(models.TaskLog).filter(
            and_(
                models.TaskLog.taskId == template_id,
                models.TaskLog.action == "generated",
                models.TaskLog.metadata["occurrence_date"].astext == occurrence_date.isoformat()
            )
        ).first()

        return log_entry is not None

    def _is_occurrence_skipped(self, template_id: str, occurrence_date: date) -> bool:
        """
        Check if occurrence was marked as skipped.

        Args:
            template_id: Template task ID
            occurrence_date: Occurrence date

        Returns:
            True if skipped
        """
        log_entry = self.db.query(models.TaskLog).filter(
            and_(
                models.TaskLog.taskId == template_id,
                models.TaskLog.action == "skipped",
                models.TaskLog.metadata["occurrence_date"].astext == occurrence_date.isoformat()
            )
        ).first()

        return log_entry is not None

    def _create_task_instance(
        self,
        template: models.Task,
        occurrence_date: date
    ) -> Optional[models.Task]:
        """
        Create task instance from template for specific occurrence.

        Applies rotation logic to determine assignee.

        Args:
            template: Task template
            occurrence_date: Date of occurrence

        Returns:
            Created Task instance, or None if creation failed
        """
        # Determine assignee using rotation strategy
        assignee_id = self._get_occurrence_assignee(template, occurrence_date)

        if not assignee_id:
            # No assignee determined - skip this occurrence
            return None

        # Create due datetime for occurrence
        if template.due:
            # Use template's time with occurrence date
            due_time = template.due.time()
            due_datetime = datetime.combine(occurrence_date, due_time)
        else:
            # Default to end of day
            due_datetime = datetime.combine(occurrence_date, datetime.max.time().replace(microsecond=0))

        # Create task instance
        task_instance = models.Task(
            id=str(uuid4()),
            familyId=template.familyId,
            title=template.title,
            desc=template.desc,
            category=template.category,
            due=due_datetime,
            frequency="none",  # Instance is not recurring
            rrule=None,  # Instance has no rrule
            assignees=[assignee_id],  # Single assignee for instance
            claimable=template.claimable,
            status="open",
            points=template.points,
            photoRequired=template.photoRequired,
            parentApproval=template.parentApproval,
            priority=template.priority,
            estDuration=template.estDuration,
            createdBy=template.createdBy,
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow(),
            version=0
        )

        self.db.add(task_instance)

        # Create TaskLog to track generation
        log_entry = models.TaskLog(
            id=str(uuid4()),
            taskId=template.id,  # Log against template
            userId=template.createdBy,
            action="generated",
            metadata={
                "occurrence_date": occurrence_date.isoformat(),
                "instance_id": task_instance.id,
                "assignee_id": assignee_id,
                "rotation_strategy": getattr(template, "rotationStrategy", "manual")
            },
            createdAt=datetime.utcnow()
        )

        self.db.add(log_entry)
        self.db.commit()
        self.db.refresh(task_instance)

        return task_instance

    def _get_occurrence_assignee(self, template: models.Task, occurrence_date: date) -> Optional[str]:
        """
        Determine assignee for occurrence using rotation strategy.

        Args:
            template: Task template
            occurrence_date: Occurrence date

        Returns:
            User ID of assignee, or None
        """
        return self.fairness_engine.rotate_assignee(template, occurrence_date)

    def skip_task_occurrence(
        self,
        task_id: str,
        occurrence_date: date,
        user_id: str
    ) -> bool:
        """
        Mark occurrence as skipped (don't generate).

        Creates TaskLog entry with action='skipped'.

        Args:
            task_id: Template task ID
            occurrence_date: Occurrence date to skip
            user_id: User who requested skip

        Returns:
            True if successful
        """
        # Check if already skipped or generated
        if self._is_occurrence_skipped(task_id, occurrence_date):
            return False  # Already skipped

        if self._is_occurrence_generated(task_id, occurrence_date):
            return False  # Already generated - cannot skip

        # Create skip log entry
        log_entry = models.TaskLog(
            id=str(uuid4()),
            taskId=task_id,
            userId=user_id,
            action="skipped",
            metadata={
                "occurrence_date": occurrence_date.isoformat(),
                "reason": "manually_skipped"
            },
            createdAt=datetime.utcnow()
        )

        self.db.add(log_entry)
        self.db.commit()

        return True

    def complete_series(
        self,
        task_id: str,
        user_id: str
    ) -> bool:
        """
        Mark entire recurring task series as done.

        Updates template status to 'done' to stop generating future occurrences.

        Args:
            task_id: Template task ID
            user_id: User who completed series

        Returns:
            True if successful
        """
        task = self.db.query(models.Task).filter_by(id=task_id).first()

        if not task:
            return False

        # Update template status
        task.status = "done"
        task.completedBy = user_id
        task.completedAt = datetime.utcnow()
        task.updatedAt = datetime.utcnow()
        task.version += 1

        # Create log entry
        log_entry = models.TaskLog(
            id=str(uuid4()),
            taskId=task_id,
            userId=user_id,
            action="series_completed",
            metadata={
                "completion_date": datetime.utcnow().isoformat()
            },
            createdAt=datetime.utcnow()
        )

        self.db.add(log_entry)
        self.db.commit()

        return True

    def get_recurring_templates(self, family_id: str) -> List[models.Task]:
        """
        Get all recurring task templates for family.

        Args:
            family_id: Family ID

        Returns:
            List of recurring task templates
        """
        return self.db.query(models.Task).filter(
            and_(
                models.Task.familyId == family_id,
                models.Task.rrule.isnot(None)
            )
        ).all()

    def get_task_occurrences(
        self,
        task_id: str,
        start_date: date,
        end_date: date
    ) -> List[Dict]:
        """
        Get all occurrences (generated and pending) for recurring task.

        Args:
            task_id: Template task ID
            start_date: Range start
            end_date: Range end

        Returns:
            List of occurrence info dicts
        """
        template = self.db.query(models.Task).filter_by(id=task_id).first()

        if not template or not template.rrule:
            return []

        # Expand RRULE
        occurrence_dates = self._expand_task_rrule(template, start_date, end_date, max_occurrences=365)

        occurrences = []
        for occurrence_date in occurrence_dates:
            # Check status
            is_generated = self._is_occurrence_generated(template.id, occurrence_date)
            is_skipped = self._is_occurrence_skipped(template.id, occurrence_date)

            # Get instance if generated
            instance = None
            if is_generated:
                log = self.db.query(models.TaskLog).filter(
                    and_(
                        models.TaskLog.taskId == template.id,
                        models.TaskLog.action == "generated",
                        models.TaskLog.metadata["occurrence_date"].astext == occurrence_date.isoformat()
                    )
                ).first()

                if log and log.metadata.get("instance_id"):
                    instance = self.db.query(models.Task).filter_by(
                        id=log.metadata["instance_id"]
                    ).first()

            occurrences.append({
                "occurrence_date": occurrence_date.isoformat(),
                "is_generated": is_generated,
                "is_skipped": is_skipped,
                "instance_id": instance.id if instance else None,
                "status": instance.status if instance else "pending",
                "assignee_id": instance.assignees[0] if instance and instance.assignees else None
            })

        return occurrences
