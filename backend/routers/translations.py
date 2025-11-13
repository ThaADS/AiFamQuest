"""
Translation Router
API endpoints for i18n translation retrieval
"""

from fastapi import APIRouter, HTTPException, Response
from services.translation_service import get_translation_service
from typing import Dict, Any

router = APIRouter(prefix="/translations", tags=["translations"])

# Get singleton translation service
translation_service = get_translation_service()


@router.get("/{locale}", response_model=Dict[str, Any])
async def get_translations(locale: str):
    """
    Get all translations for a specific locale.

    Args:
        locale: Language code (en, nl, de, fr, tr, pl, ar)

    Returns:
        Complete translation dictionary for the locale

    Example:
        GET /translations/nl
        {
            "common": {...},
            "auth": {...},
            "tasks": {...},
            ...
        }
    """

    # Validate locale
    supported_locales = translation_service.get_supported_locales()

    if locale not in supported_locales:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported locale: {locale}. Supported: {', '.join(supported_locales)}"
        )

    try:
        translations = translation_service.get_all(locale)
        return translations
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error retrieving translations: {str(e)}"
        )


@router.get("/")
async def get_supported_locales():
    """
    Get list of all supported locales.

    Returns:
        {
            "supported_locales": ["en", "nl", "de", "fr", "tr", "pl", "ar"],
            "default_locale": "en"
        }
    """

    return {
        "supported_locales": translation_service.get_supported_locales(),
        "default_locale": translation_service.FALLBACK_LOCALE
    }


@router.post("/reload")
async def reload_translations():
    """
    Reload all translation files (development only).

    Returns:
        {"success": true, "message": "Translations reloaded"}
    """

    try:
        translation_service.reload_translations()
        return {
            "success": True,
            "message": "Translations reloaded successfully"
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error reloading translations: {str(e)}"
        )
