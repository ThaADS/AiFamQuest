"""
Development data seeder for FamQuest MVP

Creates 2 realistic families with complete data:
- Eva's family (PRD example): Parent + 3 kids (6/9/12 years)
- Mark's family: Parent + 2 teens (14/16 years)

Includes:
- Users with different roles (parent/teen/child/helper)
- Tasks (one-time + recurring) with various statuses
- Events (appointments, school events)
- Points ledger entries
- Badges and streaks
- Rewards shop
- Study items (homework coach)

Usage:
    python scripts/seed_dev_data.py
"""

import os
import sys
from datetime import datetime, timedelta
import uuid

# Add parent directory to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from core.models import (
    Family, User, Event, Task, TaskLog, PointsLedger, Badge,
    UserStreak, Reward, StudyItem, StudySession, Media, Notification,
    DeviceToken, WebPushSub, AuditLog
)
from core.db import Base

# Database connection
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@localhost:5432/famquest')
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)


def gen_uuid():
    return str(uuid.uuid4())


def seed_families(session):
    """Create 2 families"""
    print("Creating families...")

    family1 = Family(
        id=gen_uuid(),
        name="Gezin van Eva",
        createdAt=datetime.utcnow() - timedelta(days=90),
        updatedAt=datetime.utcnow()
    )

    family2 = Family(
        id=gen_uuid(),
        name="Gezin van Mark",
        createdAt=datetime.utcnow() - timedelta(days=60),
        updatedAt=datetime.utcnow()
    )

    session.add_all([family1, family2])
    session.commit()
    print(f"  ✓ Created 2 families")
    return family1, family2


def seed_users(session, family1, family2):
    """Create users for both families"""
    print("Creating users...")

    # Family 1: Eva's family (PRD example)
    eva = User(
        id=gen_uuid(),
        familyId=family1.id,
        email="eva@famquest.dev",
        displayName="Eva",
        role="parent",
        avatar=None,
        passwordHash="$2b$12$dummy_hash_for_dev",  # Password: "famquest123"
        locale="nl",
        theme="classy",
        emailVerified=True,
        twoFAEnabled=False,
        permissions={"childCanCreateTasks": True, "childCanCreateStudyItems": True},
        sso={"providers": ["google"], "google_id": "eva_google_123"},
        createdAt=datetime.utcnow() - timedelta(days=90)
    )

    mark_partner = User(
        id=gen_uuid(),
        familyId=family1.id,
        email="mark@famquest.dev",
        displayName="Mark",
        role="parent",
        avatar=None,
        passwordHash="$2b$12$dummy_hash_for_dev",
        locale="nl",
        theme="minimal",
        emailVerified=True,
        twoFAEnabled=False,
        permissions={},
        sso={"providers": ["microsoft"], "microsoft_id": "mark_ms_456"},
        createdAt=datetime.utcnow() - timedelta(days=90)
    )

    noah = User(
        id=gen_uuid(),
        familyId=family1.id,
        email="noah@famquest.dev",
        displayName="Noah",
        role="child",
        avatar="space_astronaut",
        passwordHash=None,
        locale="nl",
        theme="minimal",  # Boys 10-15: space/tech theme
        emailVerified=True,
        pin="1234",
        permissions={},
        createdAt=datetime.utcnow() - timedelta(days=85)
    )

    luna = User(
        id=gen_uuid(),
        familyId=family1.id,
        email="luna@famquest.dev",
        displayName="Luna",
        role="child",
        avatar="fairy_princess",
        passwordHash=None,
        locale="nl",
        theme="cartoony",  # Girls 10-15: cartoony/pink theme
        emailVerified=True,
        pin="5678",
        permissions={},
        createdAt=datetime.utcnow() - timedelta(days=85)
    )

    sam = User(
        id=gen_uuid(),
        familyId=family1.id,
        email="sam@famquest.dev",
        displayName="Sam",
        role="teen",
        avatar="cool_teen",
        passwordHash="$2b$12$dummy_hash_for_dev",
        locale="nl",
        theme="dark",  # Teens 15+: dark mode
        emailVerified=True,
        twoFAEnabled=True,
        twoFASecret="BASE32SECRET",
        permissions={"childCanCreateTasks": True, "childCanCreateStudyItems": True},
        createdAt=datetime.utcnow() - timedelta(days=85)
    )

    mira = User(
        id=gen_uuid(),
        familyId=family1.id,
        email="mira@famquest.dev",
        displayName="Mira (Schoonmaakster)",
        role="helper",
        avatar=None,
        passwordHash="$2b$12$dummy_hash_for_dev",
        locale="nl",
        theme="minimal",
        emailVerified=True,
        permissions={},
        createdAt=datetime.utcnow() - timedelta(days=30)
    )

    # Family 2: Mark's family (teens)
    mark2 = User(
        id=gen_uuid(),
        familyId=family2.id,
        email="mark2@famquest.dev",
        displayName="Mark",
        role="parent",
        passwordHash="$2b$12$dummy_hash_for_dev",
        locale="en",
        theme="minimal",
        emailVerified=True,
        createdAt=datetime.utcnow() - timedelta(days=60)
    )

    lisa = User(
        id=gen_uuid(),
        familyId=family2.id,
        email="lisa@famquest.dev",
        displayName="Lisa",
        role="teen",
        passwordHash="$2b$12$dummy_hash_for_dev",
        locale="en",
        theme="dark",
        emailVerified=True,
        createdAt=datetime.utcnow() - timedelta(days=60)
    )

    tom = User(
        id=gen_uuid(),
        familyId=family2.id,
        email="tom@famquest.dev",
        displayName="Tom",
        role="teen",
        passwordHash="$2b$12$dummy_hash_for_dev",
        locale="en",
        theme="minimal",
        emailVerified=True,
        createdAt=datetime.utcnow() - timedelta(days=60)
    )

    users = [eva, mark_partner, noah, luna, sam, mira, mark2, lisa, tom]
    session.add_all(users)
    session.commit()
    print(f"  ✓ Created {len(users)} users")
    return {
        "eva": eva, "mark_partner": mark_partner, "noah": noah,
        "luna": luna, "sam": sam, "mira": mira,
        "mark2": mark2, "lisa": lisa, "tom": tom
    }


def seed_tasks(session, family1, family2, users):
    """Create tasks (one-time + recurring)"""
    print("Creating tasks...")

    now = datetime.utcnow()
    tasks = []

    # Family 1 tasks
    # Completed task (Noah)
    tasks.append(Task(
        id=gen_uuid(),
        familyId=family1.id,
        title="Vaatwasser uitruimen",
        desc="Borden in kast, bestek in lade",
        category="cleaning",
        due=now - timedelta(days=1),
        frequency="daily",
        rrule="FREQ=DAILY;INTERVAL=1",
        assignees=[users["noah"].id],
        status="done",
        points=10,
        photoRequired=False,
        parentApproval=False,
        priority="med",
        estDuration=15,
        createdBy=users["eva"].id,
        completedBy=users["noah"].id,
        completedAt=now - timedelta(hours=20),
        createdAt=now - timedelta(days=30)
    ))

    # Pending approval task (Luna)
    tasks.append(Task(
        id=gen_uuid(),
        familyId=family1.id,
        title="Kamer opruimen met foto",
        desc="Alles netjes, speelgoed in kast, bed opgemaakt",
        category="cleaning",
        due=now - timedelta(hours=2),
        frequency="none",
        assignees=[users["luna"].id],
        status="pendingApproval",
        points=15,
        photoRequired=True,
        parentApproval=True,
        proofPhotos=["https://fake-cdn.com/luna_room_clean.jpg"],
        priority="high",
        estDuration=30,
        createdBy=users["eva"].id,
        completedBy=users["luna"].id,
        completedAt=now - timedelta(hours=2),
        createdAt=now - timedelta(hours=4)
    ))

    # Open task (Sam)
    tasks.append(Task(
        id=gen_uuid(),
        familyId=family1.id,
        title="Hond uitlaten",
        desc="30 minuten lopen, poep opruimen",
        category="pet",
        due=now + timedelta(hours=3),
        frequency="daily",
        rrule="FREQ=DAILY;INTERVAL=1;BYHOUR=18",
        assignees=[users["sam"].id],
        status="open",
        points=12,
        photoRequired=False,
        parentApproval=False,
        priority="high",
        estDuration=30,
        createdBy=users["eva"].id,
        createdAt=now - timedelta(days=20)
    ))

    # Claimable task (pool)
    tasks.append(Task(
        id=gen_uuid(),
        familyId=family1.id,
        title="Afval buitenzetten",
        desc="Groene en zwarte container naar straat",
        category="cleaning",
        due=now + timedelta(days=1, hours=20),
        frequency="weekly",
        rrule="FREQ=WEEKLY;BYDAY=TH",
        assignees=[],
        claimable=True,
        status="open",
        points=8,
        photoRequired=False,
        parentApproval=False,
        priority="med",
        estDuration=10,
        createdBy=users["eva"].id,
        createdAt=now - timedelta(days=10)
    ))

    # Helper task (Mira)
    tasks.append(Task(
        id=gen_uuid(),
        familyId=family1.id,
        title="Badkamer schoonmaken",
        desc="Toilet, douche, wastafel",
        category="cleaning",
        due=now + timedelta(days=2),
        frequency="weekly",
        assignees=[users["mira"].id],
        status="open",
        points=0,  # No points for helper
        photoRequired=True,
        parentApproval=False,
        priority="med",
        estDuration=45,
        createdBy=users["eva"].id,
        createdAt=now - timedelta(days=5)
    ))

    # Family 2 tasks (English)
    tasks.append(Task(
        id=gen_uuid(),
        familyId=family2.id,
        title="Vacuum living room",
        desc="Move furniture, vacuum under couch",
        category="cleaning",
        due=now + timedelta(hours=6),
        frequency="weekly",
        assignees=[users["lisa"].id],
        status="open",
        points=15,
        photoRequired=False,
        parentApproval=False,
        priority="med",
        estDuration=20,
        createdBy=users["mark2"].id,
        createdAt=now - timedelta(days=7)
    ))

    tasks.append(Task(
        id=gen_uuid(),
        familyId=family2.id,
        title="Do the dishes",
        desc="Wash, dry, and put away",
        category="cleaning",
        due=now - timedelta(hours=1),
        frequency="daily",
        assignees=[users["tom"].id],
        status="done",
        points=10,
        photoRequired=False,
        parentApproval=False,
        priority="med",
        estDuration=15,
        createdBy=users["mark2"].id,
        completedBy=users["tom"].id,
        completedAt=now - timedelta(hours=1, minutes=30),
        createdAt=now - timedelta(days=15)
    ))

    session.add_all(tasks)
    session.commit()
    print(f"  ✓ Created {len(tasks)} tasks")
    return tasks


def seed_events(session, family1, family2, users):
    """Create calendar events"""
    print("Creating events...")

    now = datetime.utcnow()
    events = []

    # Family 1 events
    events.append(Event(
        id=gen_uuid(),
        familyId=family1.id,
        title="Tandarts Noah",
        description="Controle 6 maanden",
        start=now + timedelta(days=3, hours=14),
        end=now + timedelta(days=3, hours=14, minutes=30),
        allDay=False,
        attendees=[users["noah"].id, users["eva"].id],
        color="#FF5722",
        category="appointment",
        createdBy=users["eva"].id,
        createdAt=now - timedelta(days=10)
    ))

    events.append(Event(
        id=gen_uuid(),
        familyId=family1.id,
        title="Gymles Sam",
        description="School gym class",
        start=now + timedelta(days=1, hours=10),
        end=now + timedelta(days=1, hours=11),
        allDay=False,
        attendees=[users["sam"].id],
        color="#4CAF50",
        category="school",
        rrule="FREQ=WEEKLY;BYDAY=TU,TH",
        createdBy=users["eva"].id,
        createdAt=now - timedelta(days=60)
    ))

    events.append(Event(
        id=gen_uuid(),
        familyId=family1.id,
        title="Verjaardagsfeestje Luna",
        description="Thuis, 8 vriendinnetjes",
        start=now + timedelta(days=14, hours=14),
        end=now + timedelta(days=14, hours=17),
        allDay=False,
        attendees=[users["luna"].id, users["eva"].id, users["mark_partner"].id],
        color="#E91E63",
        category="family",
        createdBy=users["eva"].id,
        createdAt=now - timedelta(days=20)
    ))

    # Family 2 events
    events.append(Event(
        id=gen_uuid(),
        familyId=family2.id,
        title="Soccer practice (Lisa)",
        description="Bring cleats and water",
        start=now + timedelta(days=2, hours=17),
        end=now + timedelta(days=2, hours=18, minutes=30),
        allDay=False,
        attendees=[users["lisa"].id],
        color="#2196F3",
        category="sport",
        rrule="FREQ=WEEKLY;BYDAY=MO,WE,FR",
        createdBy=users["mark2"].id,
        createdAt=now - timedelta(days=45)
    ))

    session.add_all(events)
    session.commit()
    print(f"  ✓ Created {len(events)} events")


def seed_points_and_badges(session, family1, users, tasks):
    """Create points ledger entries and badges"""
    print("Creating points and badges...")

    now = datetime.utcnow()
    points = []
    badges = []

    # Noah's points (completed task yesterday)
    points.append(PointsLedger(
        id=gen_uuid(),
        userId=users["noah"].id,
        delta=10,
        reason="Completed: Vaatwasser uitruimen",
        taskId=tasks[0].id,
        createdAt=now - timedelta(hours=20)
    ))

    # Sam's points (multiple past completions)
    for i in range(7):
        points.append(PointsLedger(
            id=gen_uuid(),
            userId=users["sam"].id,
            delta=12,
            reason=f"Completed: Hond uitlaten (day {i+1})",
            createdAt=now - timedelta(days=i+1)
        ))

    # Tom's points
    points.append(PointsLedger(
        id=gen_uuid(),
        userId=users["tom"].id,
        delta=10,
        reason="Completed: Do the dishes",
        taskId=tasks[6].id,
        createdAt=now - timedelta(hours=1, minutes=30)
    ))

    # Badges
    badges.append(Badge(
        id=gen_uuid(),
        userId=users["sam"].id,
        code="week_streak_7",
        awardedAt=now - timedelta(hours=2)
    ))

    badges.append(Badge(
        id=gen_uuid(),
        userId=users["noah"].id,
        code="first_task_complete",
        awardedAt=now - timedelta(days=25)
    ))

    session.add_all(points + badges)
    session.commit()
    print(f"  ✓ Created {len(points)} points entries and {len(badges)} badges")


def seed_streaks(session, users):
    """Create streak tracking"""
    print("Creating streaks...")

    now = datetime.utcnow()
    streaks = []

    # Sam has 7-day streak
    streaks.append(UserStreak(
        id=gen_uuid(),
        userId=users["sam"].id,
        currentStreak=7,
        longestStreak=12,
        lastCompletionDate=now - timedelta(hours=2),
        updatedAt=now - timedelta(hours=2)
    ))

    # Noah has 1-day streak
    streaks.append(UserStreak(
        id=gen_uuid(),
        userId=users["noah"].id,
        currentStreak=1,
        longestStreak=4,
        lastCompletionDate=now - timedelta(hours=20),
        updatedAt=now - timedelta(hours=20)
    ))

    # Tom has 1-day streak
    streaks.append(UserStreak(
        id=gen_uuid(),
        userId=users["tom"].id,
        currentStreak=1,
        longestStreak=3,
        lastCompletionDate=now - timedelta(hours=1, minutes=30),
        updatedAt=now - timedelta(hours=1, minutes=30)
    ))

    session.add_all(streaks)
    session.commit()
    print(f"  ✓ Created {len(streaks)} streaks")


def seed_rewards(session, family1, family2):
    """Create reward shop items"""
    print("Creating rewards...")

    now = datetime.utcnow()
    rewards = []

    # Family 1 rewards (Dutch)
    rewards.append(Reward(
        id=gen_uuid(),
        familyId=family1.id,
        name="Extra schermtijd (30 min)",
        description="30 minuten extra iPad of TV tijd",
        cost=50,
        icon="screen_time",
        isActive=True,
        createdAt=now - timedelta(days=80)
    ))

    rewards.append(Reward(
        id=gen_uuid(),
        familyId=family1.id,
        name="Bioscoop uitje",
        description="Naar de film met de hele familie",
        cost=200,
        icon="movie",
        isActive=True,
        createdAt=now - timedelta(days=80)
    ))

    rewards.append(Reward(
        id=gen_uuid(),
        familyId=family1.id,
        name="Later naar bed (1 uur)",
        description="1 uur later naar bed op vrijdag/zaterdag",
        cost=75,
        icon="bedtime",
        isActive=True,
        createdAt=now - timedelta(days=80)
    ))

    # Family 2 rewards (English)
    rewards.append(Reward(
        id=gen_uuid(),
        familyId=family2.id,
        name="Extra allowance ($10)",
        description="$10 bonus for your savings",
        cost=100,
        icon="money",
        isActive=True,
        createdAt=now - timedelta(days=55)
    ))

    session.add_all(rewards)
    session.commit()
    print(f"  ✓ Created {len(rewards)} rewards")


def seed_study_items(session, users):
    """Create homework coach items"""
    print("Creating study items...")

    now = datetime.utcnow()
    study_items = []
    study_sessions = []

    # Sam's math test
    math_item = StudyItem(
        id=gen_uuid(),
        userId=users["sam"].id,
        subject="Wiskunde",
        topic="Algebra - vergelijkingen oplossen",
        testDate=now + timedelta(days=7),
        studyPlan={
            "sessions": [
                {"date": (now + timedelta(days=1)).isoformat(), "duration": 30, "topics": ["basis vergelijkingen"]},
                {"date": (now + timedelta(days=3)).isoformat(), "duration": 30, "topics": ["haakjes wegwerken"]},
                {"date": (now + timedelta(days=5)).isoformat(), "duration": 30, "topics": ["oefenopgaven"]}
            ]
        },
        status="active",
        createdAt=now - timedelta(days=3)
    ))
    study_items.append(math_item)

    # Study session for Sam (completed yesterday)
    study_sessions.append(StudySession(
        id=gen_uuid(),
        studyItemId=math_item.id,
        scheduledDate=now - timedelta(days=2),
        completedAt=now - timedelta(days=2, hours=2),
        quizQuestions={
            "questions": [
                {"q": "Los op: 2x + 5 = 13", "a": "x = 4", "correct": True},
                {"q": "Los op: 3(x - 2) = 9", "a": "x = 5", "correct": True},
                {"q": "Los op: 5x - 8 = 2x + 4", "a": "x = 4", "correct": True}
            ]
        },
        score=100
    ))

    # Lisa's history test
    history_item = StudyItem(
        id=gen_uuid(),
        userId=users["lisa"].id,
        subject="History",
        topic="World War 2 - key events",
        testDate=now + timedelta(days=10),
        studyPlan={
            "sessions": [
                {"date": (now + timedelta(days=2)).isoformat(), "duration": 30, "topics": ["Pearl Harbor"]},
                {"date": (now + timedelta(days=5)).isoformat(), "duration": 30, "topics": ["D-Day invasion"]},
                {"date": (now + timedelta(days=8)).isoformat(), "duration": 30, "topics": ["VE and VJ Day"]}
            ]
        },
        status="active",
        createdAt=now - timedelta(days=5)
    ))
    study_items.append(history_item)

    session.add_all(study_items + study_sessions)
    session.commit()
    print(f"  ✓ Created {len(study_items)} study items and {len(study_sessions)} sessions")


def seed_audit_logs(session, family1, users):
    """Create audit log entries"""
    print("Creating audit logs...")

    now = datetime.utcnow()
    logs = []

    logs.append(AuditLog(
        id=gen_uuid(),
        actorUserId=users["eva"].id,
        familyId=family1.id,
        action="task_created",
        meta={"taskId": "task_123", "title": "Vaatwasser uitruimen"},
        createdAt=now - timedelta(days=30)
    ))

    logs.append(AuditLog(
        id=gen_uuid(),
        actorUserId=users["noah"].id,
        familyId=family1.id,
        action="task_completed",
        meta={"taskId": "task_123", "pointsEarned": 10},
        createdAt=now - timedelta(hours=20)
    ))

    logs.append(AuditLog(
        id=gen_uuid(),
        actorUserId=users["eva"].id,
        familyId=family1.id,
        action="reward_created",
        meta={"rewardId": "reward_456", "name": "Extra schermtijd"},
        createdAt=now - timedelta(days=80)
    ))

    session.add_all(logs)
    session.commit()
    print(f"  ✓ Created {len(logs)} audit logs")


def main():
    """Main seeder function"""
    print("\n" + "="*60)
    print("FamQuest Development Data Seeder")
    print("="*60 + "\n")

    session = Session()

    try:
        # Seed data in order (respecting foreign keys)
        family1, family2 = seed_families(session)
        users = seed_users(session, family1, family2)
        tasks = seed_tasks(session, family1, family2, users)
        seed_events(session, family1, family2, users)
        seed_points_and_badges(session, family1, users, tasks)
        seed_streaks(session, users)
        seed_rewards(session, family1, family2)
        seed_study_items(session, users)
        seed_audit_logs(session, family1, users)

        print("\n" + "="*60)
        print("✓ Seeding completed successfully!")
        print("="*60)
        print("\nTest accounts:")
        print("  Parent (Eva): eva@famquest.dev / famquest123")
        print("  Parent (Mark): mark@famquest.dev / famquest123")
        print("  Teen (Sam): sam@famquest.dev / famquest123")
        print("  Child (Noah): PIN 1234")
        print("  Child (Luna): PIN 5678")
        print("  Helper (Mira): mira@famquest.dev / famquest123")
        print("\n" + "="*60 + "\n")

    except Exception as e:
        print(f"\n❌ Error during seeding: {e}")
        session.rollback()
        raise
    finally:
        session.close()


if __name__ == "__main__":
    main()
