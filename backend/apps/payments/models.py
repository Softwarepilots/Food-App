from decimal import Decimal

from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator
from django.db import models
from django.db.models import F

from apps.common.models import BaseModel


class PaymentMethod(models.TextChoices):
    RAZORPAY = "razorpay", "Razorpay"
    WALLET = "wallet", "Wallet"
    COD = "cod", "Cash on Delivery"


class PaymentGatewayStatus(models.TextChoices):
    CREATED = "created", "Created"
    AUTHORIZED = "authorized", "Authorized"
    CAPTURED = "captured", "Captured"
    FAILED = "failed", "Failed"
    REFUNDED = "refunded", "Refunded"


class Payment(BaseModel):
    order = models.OneToOneField("orders.Order", on_delete=models.CASCADE, related_name="payment")
    method = models.CharField(max_length=10, choices=PaymentMethod.choices, default=PaymentMethod.RAZORPAY)
    razorpay_order_id = models.CharField(max_length=64, blank=True, db_index=True)
    razorpay_payment_id = models.CharField(max_length=64, blank=True, db_index=True)
    razorpay_signature = models.CharField(max_length=255, blank=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(Decimal("0.01"))])
    currency = models.CharField(max_length=3, default="INR")
    status = models.CharField(
        max_length=10, choices=PaymentGatewayStatus.choices, default=PaymentGatewayStatus.CREATED, db_index=True
    )
    failure_reason = models.CharField(max_length=255, blank=True)
    refunded_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0, validators=[MinValueValidator(Decimal("0"))])

    class Meta:
        db_table = "payments_payment"
        verbose_name = "Payment"
        verbose_name_plural = "Payments"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status"]),
        ]

    def __str__(self):
        return f"Payment for {self.order.order_number}"

    def clean(self):
        if self.refunded_amount > self.amount:
            raise ValidationError("refunded_amount cannot exceed the paid amount.")


class Wallet(BaseModel):
    user = models.OneToOneField("accounts.User", on_delete=models.CASCADE, related_name="wallet")
    balance = models.DecimalField(max_digits=10, decimal_places=2, default=0, validators=[MinValueValidator(Decimal("0"))])
    currency = models.CharField(max_length=3, default="INR")
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "payments_wallet"
        verbose_name = "Wallet"
        verbose_name_plural = "Wallets"

    def __str__(self):
        return f"Wallet({self.user.full_name}) = {self.currency} {self.balance}"

    def credit(self, amount):
        if amount <= 0:
            raise ValidationError("Credit amount must be positive.")
        Wallet.objects.filter(pk=self.pk).update(balance=F("balance") + amount)
        self.refresh_from_db(fields=["balance"])

    def debit(self, amount):
        if amount <= 0:
            raise ValidationError("Debit amount must be positive.")
        updated = Wallet.objects.filter(pk=self.pk, balance__gte=amount).update(balance=F("balance") - amount)
        if not updated:
            raise ValidationError("Insufficient wallet balance.")
        self.refresh_from_db(fields=["balance"])
