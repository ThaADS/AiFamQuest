"""
In-App Purchase (IAP) Verification Service

Verifies iOS and Android purchase receipts for:
- Family Unlock (€9.99 one-time)
- Premium Monthly (€4.99/month)
- Premium Yearly (€49.99/year)

Integrations:
- iOS: App Store Server API
- Android: Google Play Developer API

Note: This is a stub implementation for MVP.
Full production implementation requires:
- App Store Connect API credentials
- Google Play Service Account JSON
- Webhook handlers for subscription renewals
"""

import os
import httpx
import logging
from typing import Dict, Any, Optional, Tuple
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

# Product IDs (must match App Store Connect / Google Play Console)
PRODUCT_FAMILY_UNLOCK = "app.famquest.family_unlock"
PRODUCT_PREMIUM_MONTHLY = "app.famquest.premium_monthly"
PRODUCT_PREMIUM_YEARLY = "app.famquest.premium_yearly"


class IAPVerificationService:
    """In-App Purchase verification service"""

    def __init__(self):
        self.ios_sandbox = os.getenv("IOS_SANDBOX", "true").lower() == "true"
        self.android_test = os.getenv("ANDROID_TEST", "true").lower() == "true"

    async def verify_ios_receipt(
        self,
        receipt_data: str,
        product_id: str
    ) -> Tuple[bool, Optional[Dict[str, Any]], Optional[str]]:
        """
        Verify iOS App Store receipt.

        Args:
            receipt_data: Base64 encoded receipt from StoreKit
            product_id: Product identifier

        Returns:
            (is_valid, purchase_info, error_message)

        Note: Production implementation requires App Store Connect API.
        """
        # Stub implementation for MVP
        logger.warning("iOS IAP verification is stubbed for MVP")

        # In production, call App Store Server API:
        # POST https://buy.itunes.apple.com/verifyReceipt
        # (or sandbox.itunes.apple.com for testing)

        # For MVP, accept all receipts if in sandbox mode
        if self.ios_sandbox:
            logger.info(f"iOS IAP (sandbox): Accepting receipt for {product_id}")
            return True, {
                "transaction_id": f"ios_sandbox_{datetime.utcnow().timestamp()}",
                "product_id": product_id,
                "purchase_date": datetime.utcnow().isoformat(),
                "environment": "sandbox"
            }, None

        return False, None, "iOS IAP verification not implemented in MVP"

    async def verify_android_receipt(
        self,
        purchase_token: str,
        product_id: str,
        package_name: str = "app.famquest"
    ) -> Tuple[bool, Optional[Dict[str, Any]], Optional[str]]:
        """
        Verify Android Google Play purchase.

        Args:
            purchase_token: Purchase token from Google Play Billing
            product_id: Product SKU
            package_name: App package name

        Returns:
            (is_valid, purchase_info, error_message)

        Note: Production implementation requires Google Play Developer API.
        """
        # Stub implementation for MVP
        logger.warning("Android IAP verification is stubbed for MVP")

        # In production, call Google Play Developer API:
        # GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/products/{productId}/tokens/{token}
        # Requires Google Play Service Account JSON

        # For MVP, accept all purchases if in test mode
        if self.android_test:
            logger.info(f"Android IAP (test): Accepting purchase for {product_id}")
            return True, {
                "order_id": f"android_test_{datetime.utcnow().timestamp()}",
                "product_id": product_id,
                "purchase_time": datetime.utcnow().isoformat(),
                "environment": "test"
            }, None

        return False, None, "Android IAP verification not implemented in MVP"

    def get_product_info(self, product_id: str) -> Dict[str, Any]:
        """
        Get product information by ID.

        Returns product details including price and type.
        """
        products = {
            PRODUCT_FAMILY_UNLOCK: {
                "id": PRODUCT_FAMILY_UNLOCK,
                "name": "Family Unlock",
                "type": "non_consumable",
                "price": 9.99,
                "currency": "EUR",
                "description": "Unlock unlimited family members and remove ads"
            },
            PRODUCT_PREMIUM_MONTHLY: {
                "id": PRODUCT_PREMIUM_MONTHLY,
                "name": "Premium Monthly",
                "type": "subscription",
                "price": 4.99,
                "currency": "EUR",
                "period": "monthly",
                "description": "Premium features with monthly subscription"
            },
            PRODUCT_PREMIUM_YEARLY: {
                "id": PRODUCT_PREMIUM_YEARLY,
                "name": "Premium Yearly",
                "type": "subscription",
                "price": 49.99,
                "currency": "EUR",
                "period": "yearly",
                "description": "Premium features with yearly subscription (save 17%)"
            }
        }

        return products.get(product_id, {
            "id": product_id,
            "name": "Unknown Product",
            "type": "unknown",
            "price": 0,
            "currency": "EUR"
        })

    def calculate_expiry_date(self, product_id: str, purchase_date: datetime) -> Optional[datetime]:
        """
        Calculate subscription expiry date.

        Args:
            product_id: Product identifier
            purchase_date: Purchase/renewal date

        Returns:
            Expiry datetime for subscriptions, None for one-time purchases
        """
        if product_id == PRODUCT_FAMILY_UNLOCK:
            # One-time purchase, no expiry
            return None

        elif product_id == PRODUCT_PREMIUM_MONTHLY:
            # Monthly subscription expires in 30 days
            return purchase_date + timedelta(days=30)

        elif product_id == PRODUCT_PREMIUM_YEARLY:
            # Yearly subscription expires in 365 days
            return purchase_date + timedelta(days=365)

        return None

    async def verify_subscription_active(
        self,
        platform: str,
        subscription_id: str
    ) -> Tuple[bool, Optional[datetime]]:
        """
        Check if subscription is still active.

        Args:
            platform: 'ios' or 'android'
            subscription_id: Original transaction/order ID

        Returns:
            (is_active, expiry_date)

        Note: Production requires webhook handlers for auto-renewal updates.
        """
        # Stub for MVP
        logger.warning("Subscription status check is stubbed for MVP")

        # In production:
        # - iOS: App Store Server Notifications webhooks
        # - Android: Real-time Developer Notifications webhooks

        # For MVP, assume active if in test mode
        if (platform == "ios" and self.ios_sandbox) or (platform == "android" and self.android_test):
            return True, datetime.utcnow() + timedelta(days=30)

        return False, None
