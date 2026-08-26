from django.contrib.auth.tokens import PasswordResetTokenGenerator


class EmailVerificationTokenGenerator(PasswordResetTokenGenerator):
    """Stateless, self-invalidating email verification token.

    Hashes on `is_email_verified` instead of password/last_login (which is what
    the default password-reset generator uses) so a password change doesn't
    invalidate a pending verification link, and the link stops working on its
    own the moment it's used — no separate "used" flag needs to be persisted.
    """

    def _make_hash_value(self, user, timestamp):
        return f"{user.pk}{user.is_email_verified}{timestamp}"


email_verification_token_generator = EmailVerificationTokenGenerator()
