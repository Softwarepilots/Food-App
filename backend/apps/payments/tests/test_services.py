from decimal import Decimal

import pytest

from apps.payments.models import Payment, PaymentGatewayStatus, PaymentMethod
from apps.payments.services import create_payment_for_order

pytestmark = pytest.mark.django_db


def test_create_payment_for_order(make_order):
    order = make_order()

    payment = create_payment_for_order(order, method=PaymentMethod.RAZORPAY, amount=Decimal("130.00"))

    assert Payment.objects.filter(pk=payment.pk).exists()
    assert payment.order_id == order.id
    assert payment.method == PaymentMethod.RAZORPAY
    assert payment.amount == Decimal("130.00")
    assert payment.status == PaymentGatewayStatus.CREATED


def test_payment_status_change_syncs_order_via_orders_service(make_order):
    """apps.payments.signals.sync_order_payment_status now calls
    apps.orders.services.set_payment_status instead of writing Order directly
    — this is an end-to-end regression check that the sync still happens."""
    from apps.orders.models import OrderPaymentStatus

    order = make_order()
    payment = create_payment_for_order(order, method=PaymentMethod.RAZORPAY, amount=Decimal("130.00"))

    payment.status = PaymentGatewayStatus.CAPTURED
    payment.save(update_fields=["status"])

    order.refresh_from_db()
    assert order.payment_status == OrderPaymentStatus.PAID
