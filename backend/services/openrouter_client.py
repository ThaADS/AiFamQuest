"""
OpenRouter Client Service
Enhanced AI client with voice NLU support using Claude Haiku for fast intent parsing
"""

import os
import httpx
import json
import logging
from typing import Dict, Any, Optional, Tuple, List
from datetime import datetime

logger = logging.getLogger(__name__)

# Configuration
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

# Model configurations for different use cases
MODEL_SONNET = "anthropic/claude-3.5-sonnet"  # High-quality, expensive
MODEL_HAIKU = "anthropic/claude-3-haiku"      # Fast, cheap, perfect for NLU
MODEL_GPT4_VISION = "openai/gpt-4-vision-preview"  # Vision tasks

# Timeouts
TIMEOUT_NLU = 5.0   # Fast intent parsing
TIMEOUT_STUDY = 15.0  # Study plan generation
TIMEOUT_VISION = 20.0  # Vision analysis


class OpenRouterClient:
    """OpenRouter API client with specialized methods for different AI tasks"""

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or OPENROUTER_API_KEY
        if not self.api_key:
            logger.warning("OpenRouter API key not configured")

    def _headers(self) -> Dict[str, str]:
        """Generate OpenRouter API headers"""
        if not self.api_key:
            return {}
        return {
            "Authorization": f"Bearer {self.api_key}",
            "HTTP-Referer": "https://famquest.app",
            "X-Title": "FamQuest",
            "Content-Type": "application/json"
        }

    async def _call_api(
        self,
        messages: List[Dict[str, str]],
        model: str,
        temperature: float = 0.4,
        timeout: float = 30.0,
        max_tokens: Optional[int] = None
    ) -> Tuple[Optional[Dict], Optional[str]]:
        """
        Call OpenRouter API

        Returns:
            (response_dict, error_message)
        """
        if not self.api_key:
            return None, "OpenRouter API key not configured"

        try:
            payload = {
                "model": model,
                "messages": messages,
                "temperature": temperature
            }

            if max_tokens:
                payload["max_tokens"] = max_tokens

            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.post(
                    OPENROUTER_URL,
                    headers=self._headers(),
                    json=payload
                )
                response.raise_for_status()
                return response.json(), None

        except httpx.TimeoutException:
            logger.error(f"OpenRouter timeout after {timeout}s")
            return None, f"Timeout after {timeout}s"
        except httpx.HTTPStatusError as e:
            error_text = e.response.text[:500]
            logger.error(f"OpenRouter HTTP error {e.response.status_code}: {error_text}")
            return None, f"HTTP {e.response.status_code}: {error_text}"
        except Exception as e:
            logger.error(f"OpenRouter error: {str(e)}")
            return None, str(e)

    async def parse_voice_intent(
        self,
        transcript: str,
        user_locale: str = "nl"
    ) -> Dict[str, Any]:
        """
        Parse voice transcript into structured intent using Claude Haiku (fast + cheap)

        Examples:
            NL: "Maak taak stofzuigen morgen 17:00" → create_task
            EN: "Mark vaatwasser as done" → mark_done
            NL: "Wat moet ik vandaag doen?" → show_tasks

        Returns:
        {
            "intent": "create_task",
            "confidence": 0.95,
            "slots": {
                "title": "stofzuigen",
                "datetime": "2025-11-18T17:00:00Z",
                "assignee": null
            },
            "response": "Ik maak de taak 'stofzuigen' aan voor morgen 17:00",
            "locale": "nl"
        }
        """
        system_prompt = f"""You are a voice command parser for FamQuest family task app.
Parse the user's voice command into a structured intent.

**Supported Intents**:
- create_task: Create new task
- mark_done: Mark task as completed
- show_tasks: List user's tasks
- show_points: Show gamification points
- add_event: Add calendar event
- help: Show help

**Locale**: {user_locale}

**Output Format** (pure JSON, no markdown):
{{
  "intent": "create_task",
  "confidence": 0.95,
  "slots": {{
    "title": "extracted task title",
    "datetime": "ISO datetime if mentioned",
    "assignee": "user name if mentioned",
    "action": "specific action keyword"
  }},
  "response": "Friendly confirmation message in user's language",
  "locale": "{user_locale}"
}}

**Examples**:
Input (NL): "Maak taak stofzuigen morgen 17:00"
Output: {{"intent": "create_task", "confidence": 0.95, "slots": {{"title": "stofzuigen", "datetime": "tomorrow 17:00"}}, "response": "Ik maak de taak stofzuigen aan voor morgen 17:00", "locale": "nl"}}

Input (EN): "Show my tasks for today"
Output: {{"intent": "show_tasks", "confidence": 1.0, "slots": {{"filter": "today"}}, "response": "Here are your tasks for today", "locale": "en"}}

Parse this command now (return only JSON):"""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": transcript}
        ]

        response, error = await self._call_api(
            messages,
            model=MODEL_HAIKU,  # Fast + cheap for NLU
            temperature=0.2,  # Low temperature for structured output
            timeout=TIMEOUT_NLU,
            max_tokens=500
        )

        if error or not response:
            logger.error(f"Voice intent parsing failed: {error}")
            return {
                "intent": "unknown",
                "confidence": 0.0,
                "slots": {},
                "response": "Sorry, ik begreep dat niet. Probeer opnieuw." if user_locale == "nl" else "Sorry, I didn't understand that.",
                "error": error,
                "locale": user_locale
            }

        try:
            content = response["choices"][0]["message"]["content"]

            # Extract JSON (handle markdown code blocks)
            if "```json" in content:
                start = content.index("```json") + 7
                end = content.rindex("```")
                content = content[start:end].strip()
            elif "```" in content:
                start = content.index("```") + 3
                end = content.rindex("```")
                content = content[start:end].strip()

            intent_data = json.loads(content)

            # Add usage metadata
            intent_data["tokens_used"] = response.get("usage", {})
            intent_data["model"] = MODEL_HAIKU

            return intent_data

        except (json.JSONDecodeError, KeyError, IndexError) as e:
            logger.error(f"Failed to parse NLU response: {e}")
            return {
                "intent": "unknown",
                "confidence": 0.0,
                "slots": {},
                "response": "Sorry, er ging iets mis." if user_locale == "nl" else "Sorry, something went wrong.",
                "error": str(e),
                "locale": user_locale
            }

    async def generate_study_plan(
        self,
        subject: str,
        topic: str,
        test_date: datetime,
        difficulty: str = "medium",
        available_time_per_day: int = 30
    ) -> Dict[str, Any]:
        """
        Generate backward planning study schedule with micro-quizzes

        Args:
            subject: Subject name (e.g., "Biology")
            topic: Topic details (e.g., "Cell structure, photosynthesis")
            test_date: Exam date
            difficulty: easy|medium|hard
            available_time_per_day: Minutes per day for study

        Returns:
        {
            "plan": [
                {
                    "date": "2025-11-17",
                    "duration": 30,
                    "focus": "Cell structure basics",
                    "tasks": ["Read chapter 3", "Draw cell diagram", "5-min quiz"]
                }
            ],
            "milestones": [
                {"date": "2025-11-21", "checkpoint": "Practice quiz"}
            ],
            "quizzes": [
                {
                    "date": "2025-11-17",
                    "questions": [
                        {"q": "What is the powerhouse of the cell?", "a": "Mitochondria", "type": "text"}
                    ]
                }
            ],
            "total_sessions": 8,
            "estimated_hours": 4
        }
        """
        days_until_test = (test_date - datetime.utcnow()).days

        system_prompt = f"""You are an AI study coach for homework planning.
Create a backward planning study schedule using spaced repetition and active recall.

**Student Info**:
- Subject: {subject}
- Topic: {topic}
- Test Date: {test_date.strftime('%Y-%m-%d')} ({days_until_test} days away)
- Difficulty: {difficulty}
- Available Time: {available_time_per_day} minutes/day

**Planning Strategy**:
1. Work backwards from test date
2. Break topic into digestible chunks
3. Use spaced repetition (review material multiple times)
4. Include active recall (quizzes, practice problems)
5. Progressive difficulty (easy → hard)
6. Final review 1-2 days before test

**Output Format** (pure JSON):
{{
  "plan": [
    {{
      "date": "YYYY-MM-DD",
      "duration": 30,
      "focus": "Topic for this session",
      "tasks": ["Specific study tasks"],
      "difficulty": "easy|medium|hard"
    }}
  ],
  "milestones": [
    {{"date": "YYYY-MM-DD", "checkpoint": "Description"}}
  ],
  "quizzes": [
    {{
      "date": "YYYY-MM-DD",
      "questions": [
        {{"q": "Question text", "a": "Answer", "type": "text"}}
      ]
    }}
  ],
  "total_sessions": 8,
  "estimated_hours": 4
}}

Generate the study plan now (JSON only):"""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Create study plan for: {subject} - {topic}"}
        ]

        response, error = await self._call_api(
            messages,
            model=MODEL_SONNET,  # High quality for educational content
            temperature=0.6,
            timeout=TIMEOUT_STUDY,
            max_tokens=2000
        )

        if error or not response:
            logger.error(f"Study plan generation failed: {error}")
            return {
                "plan": [],
                "milestones": [],
                "quizzes": [],
                "total_sessions": 0,
                "estimated_hours": 0,
                "error": error
            }

        try:
            content = response["choices"][0]["message"]["content"]

            # Extract JSON
            if "```json" in content:
                start = content.index("```json") + 7
                end = content.rindex("```")
                content = content[start:end].strip()
            elif "```" in content:
                start = content.index("```") + 3
                end = content.rindex("```")
                content = content[start:end].strip()

            plan_data = json.loads(content)

            # Add metadata
            plan_data["tokens_used"] = response.get("usage", {})
            plan_data["model"] = MODEL_SONNET
            plan_data["generated_at"] = datetime.utcnow().isoformat()

            return plan_data

        except (json.JSONDecodeError, KeyError, IndexError) as e:
            logger.error(f"Failed to parse study plan response: {e}")
            return {
                "plan": [],
                "milestones": [],
                "quizzes": [],
                "total_sessions": 0,
                "estimated_hours": 0,
                "error": str(e)
            }

    async def generate_quiz(
        self,
        subject: str,
        topic: str,
        difficulty: str = "medium",
        num_questions: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Generate micro-quiz questions for active recall

        Returns:
        [
            {
                "question": "What is the powerhouse of the cell?",
                "correct_answer": "Mitochondria",
                "type": "multiple_choice",
                "options": ["Mitochondria", "Nucleus", "Ribosome", "Chloroplast"],
                "explanation": "Brief explanation of answer"
            }
        ]
        """
        system_prompt = f"""Generate {num_questions} quiz questions for active recall practice.

**Subject**: {subject}
**Topic**: {topic}
**Difficulty**: {difficulty}

**Question Types**:
- multiple_choice: 4 options, 1 correct
- true_false: Boolean answer
- short_answer: Brief text answer

**Output Format** (pure JSON array):
[
  {{
    "question": "Question text",
    "correct_answer": "Answer",
    "type": "multiple_choice",
    "options": ["Option1", "Option2", "Option3", "Option4"],
    "explanation": "Why this is correct"
  }}
]

Generate questions now (JSON only):"""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Generate {num_questions} quiz questions"}
        ]

        response, error = await self._call_api(
            messages,
            model=MODEL_HAIKU,  # Fast for quiz generation
            temperature=0.7,
            timeout=10.0,
            max_tokens=1500
        )

        if error or not response:
            logger.error(f"Quiz generation failed: {error}")
            return []

        try:
            content = response["choices"][0]["message"]["content"]

            # Extract JSON
            if "```json" in content:
                start = content.index("```json") + 7
                end = content.rindex("```")
                content = content[start:end].strip()
            elif "```" in content:
                start = content.index("```") + 3
                end = content.rindex("```")
                content = content[start:end].strip()

            questions = json.loads(content)

            return questions if isinstance(questions, list) else []

        except (json.JSONDecodeError, KeyError, IndexError) as e:
            logger.error(f"Failed to parse quiz response: {e}")
            return []
