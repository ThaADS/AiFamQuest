"""
Test i18n Translation System
Tests TranslationService and translation router endpoints
"""

import pytest
from services.translation_service import TranslationService, get_translation_service
from pathlib import Path


class TestTranslationService:
    """Test translation service functionality"""

    def test_service_initialization(self):
        """Test that translation service loads all 7 languages"""
        service = TranslationService()

        assert len(service.translations) >= 7
        assert 'en' in service.translations
        assert 'nl' in service.translations
        assert 'de' in service.translations
        assert 'fr' in service.translations
        assert 'tr' in service.translations
        assert 'pl' in service.translations
        assert 'ar' in service.translations

    def test_get_simple_translation(self):
        """Test getting simple translation"""
        service = TranslationService()

        # English
        assert service.get('en', 'common.loading') == 'Loading...'
        assert service.get('en', 'tasks.create_task') == 'Create Task'

        # Dutch
        assert service.get('nl', 'common.loading') == 'Laden...'
        assert service.get('nl', 'tasks.create_task') == 'Taak aanmaken'

        # German
        assert service.get('de', 'common.loading') == 'Laden...'
        assert service.get('de', 'tasks.create_task') == 'Aufgabe erstellen'

    def test_get_nested_translation(self):
        """Test getting nested translation keys"""
        service = TranslationService()

        # Nested category keys
        assert service.get('en', 'tasks.categories.cleaning') == 'Cleaning'
        assert service.get('nl', 'tasks.categories.cleaning') == 'Schoonmaken'
        assert service.get('de', 'tasks.categories.cleaning') == 'Reinigung'

    def test_format_with_parameters(self):
        """Test translation formatting with parameters"""
        service = TranslationService()

        # English
        result = service.get('en', 'notifications.task_due', name='Noah', task='Dishes')
        assert 'Noah' in result
        assert 'Dishes' in result
        assert '60 minutes' in result

        # Dutch
        result = service.get('nl', 'notifications.task_due', name='Noah', task='Vaatwasser')
        assert 'Noah' in result
        assert 'Vaatwasser' in result

    def test_fallback_to_english(self):
        """Test fallback to English for unsupported locale"""
        service = TranslationService()

        # Request unsupported locale (should fallback to English)
        result = service.get('xx', 'common.loading')
        assert result == 'Loading...'

    def test_fallback_for_missing_key(self):
        """Test fallback for missing translation key"""
        service = TranslationService()

        # Request non-existent key
        result = service.get('en', 'nonexistent.key')
        assert result == 'nonexistent.key'  # Returns key itself

    def test_get_all_translations(self):
        """Test getting all translations for a locale"""
        service = TranslationService()

        translations = service.get_all('en')

        assert 'common' in translations
        assert 'auth' in translations
        assert 'tasks' in translations
        assert 'calendar' in translations
        assert 'gamification' in translations
        assert 'premium' in translations

    def test_supported_locales(self):
        """Test getting supported locales"""
        service = TranslationService()

        locales = service.get_supported_locales()

        assert len(locales) == 7
        assert 'en' in locales
        assert 'nl' in locales
        assert 'de' in locales
        assert 'fr' in locales
        assert 'tr' in locales
        assert 'pl' in locales
        assert 'ar' in locales

    def test_reload_translations(self):
        """Test reloading translations"""
        service = TranslationService()

        initial_count = len(service.translations)
        service.reload_translations()

        assert len(service.translations) == initial_count

    def test_singleton_service(self):
        """Test that get_translation_service returns singleton"""
        service1 = get_translation_service()
        service2 = get_translation_service()

        assert service1 is service2

    def test_translation_coverage(self):
        """Test that all languages have core translations"""
        service = TranslationService()

        core_keys = [
            'common.app_name',
            'common.loading',
            'auth.login',
            'tasks.title',
            'calendar.title',
            'gamification.points',
            'premium.title'
        ]

        for locale in ['en', 'nl', 'de', 'fr', 'tr', 'pl', 'ar']:
            translations = service.get_all(locale)

            for key in core_keys:
                keys = key.split('.')
                value = translations

                for k in keys:
                    assert k in value, f"Missing key '{key}' in locale '{locale}'"
                    value = value[k]

    def test_arabic_rtl_support(self):
        """Test Arabic (RTL language) translations exist"""
        service = TranslationService()

        ar_translations = service.get_all('ar')

        assert ar_translations is not None
        assert 'common' in ar_translations
        assert ar_translations['common']['app_name'] == 'FamQuest'

    def test_premium_translations(self):
        """Test premium feature translations"""
        service = TranslationService()

        # English premium translations
        assert service.get('en', 'premium.title') == 'Premium Features'
        assert service.get('en', 'premium.family_unlock') == 'Family Unlock'
        assert service.get('en', 'premium.pricing.family_unlock_price') == '€9.99 one-time'

        # Dutch premium translations
        assert service.get('nl', 'premium.title') == 'Premium functies'
        assert service.get('nl', 'premium.pricing.premium_monthly') == '€4.99/maand'
