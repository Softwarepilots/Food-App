from .models import Payment


def create_payment_for_order(order, *, method, amount):
    return Payment.objects.create(order=order, method=method, amount=amount)
