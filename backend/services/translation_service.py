"""
Translation Service
Dynamic i18n translation loading for 7 supported languages
"""

import json
import os
from pathlib import Path
from typing import Dict, Any, Optional
from functools import lru_cache

class TranslationService:
    """
    Dynamic translation service with caching and fallback support

    Supported locales: en, nl, de, fr, tr, pl, ar
    Fallback: en (English)
    """

    SUPPORTED_LOCALES = {'en', 'nl', 'de', 'fr', 'tr', 'pl', 'ar'}
    FALLBACK_LOCALE = 'en'

    def __init__(self):
        self.translations: Dict[str, Dict[str, Any]] = {}
        self._load_all_translations()

    def _load_all_translations(self):
        """Load all translation files from backend/translations/ directory."""

        # Get translations directory path
        translations_dir = Path(__file__).parent.parent / "translations"

        if not translations_dir.exists():
            raise FileNotFoundError(
                f"Translations directory not found: {translations_dir}"
            )

        # Load each translation file
        for locale in self.SUPPORTED_LOCALES:
            file_path = translations_dir / f"{locale}.json"

            if not file_path.exists():
                print(f"Warning: Translation file not found: {file_path}")
                continue

            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    self.translations[locale] = json.load(f)
                print(f"Loaded translations for locale: {locale}")
            except Exception as e:
                print(f"Error loading translations for {locale}: {e}")

    def get(self, locale: str, key: str, **kwargs) -> str:
        """
        Get translated string with optional formatting.

        Args:
            locale: Language code (en, nl, de, fr, tr, pl, ar)
            key: Dot-separated translation key (e.g., "tasks.create_task")
            **kwargs: Format parameters (e.g., name="Noah", task="Dishes")

        Returns:
            Translated and formatted string

        Examples:
            >>> t = TranslationService()
            >>> t.get('nl', 'tasks.create_task')
            'Taak aanmaken'
            >>> t.get('nl', 'notifications.task_due', name='Noah', task='Vaatwasser')
            'Noah, je taak "Vaatwasser" verloopt over 60 minuten'
        """

        # Validate locale
        if locale not in self.SUPPORTED_LOCALES:
            locale = self.FALLBACK_LOCALE

        # Fallback to English if locale not loaded
        if locale not in self.translations:
            locale = self.FALLBACK_LOCALE

        # Navigate nested keys (e.g., "tasks.create_task")
        keys = key.split('.')
        value = self.translations.get(locale, {})

        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                # Fallback to English
                value = self.translations.get(self.FALLBACK_LOCALE, {})
                for k2 in keys:
                    if isinstance(value, dict) and k2 in value:
                        value = value[k2]
                    else:
                        # Return key itself if not found
                        return key
                break

        # Return key if value is still a dict (not a leaf node)
        if isinstance(value, dict):
            return key

        # Format with kwargs (e.g., {name}, {task})
        if kwargs and isinstance(value, str):
            try:
                return value.format(**kwargs)
            except KeyError as e:
                print(f"Warning: Missing format parameter {e} for key {key}")
                return value

        return value

    def get_all(self, locale: str) -> Dict[str, Any]:
        """
        Get all translations for a locale.

        Args:
            locale: Language code

        Returns:
            Complete translation dictionary
        """

        # Validate locale
        if locale not in self.SUPPORTED_LOCALES:
            locale = self.FALLBACK_LOCALE

        # Fallback to English if not found
        if locale not in self.translations:
            locale = self.FALLBACK_LOCALE

        return self.translations.get(locale, {})

    def get_supported_locales(self) -> list:
        """Get list of all supported locales."""
        return list(self.SUPPORTED_LOCALES)

    def reload_translations(self):
        """Reload all translation files (useful for development)."""
        self.translations = {}
        self._load_all_translations()


# Singleton instance for application-wide use
_translation_service_instance: Optional[TranslationService] = None

@lru_cache(maxsize=1)
def get_translation_service() -> TranslationService:
    """
    Get singleton TranslationService instance.

    Returns:
        TranslationService singleton
    """
    global _translation_service_instance

    if _translation_service_instance is None:
        _translation_service_instance = TranslationService()

    return _translation_service_instance
