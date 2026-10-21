"""Send signup and password-reset TACs by SMTP (certificate-verified TLS) or the Brevo HTTP API.

EMAIL_PROVIDER picks the transport. Use "brevo" on hosts that block SMTP ports
(e.g. Render's free tier). Both send from SMTP_FROM_EMAIL.
"""
import logging
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)

BREVO_SEND_URL = 'https://api.brevo.com/v3/smtp/email'
SUBJECT = 'Your TriageMY verification code'
RESET_SUBJECT = 'Reset your TriageMY password'
NOT_CONFIGURED = 'Email verification is not configured. Please contact support.'
SEND_FAILED = 'Unable to send email TAC. Please try again later or contact support.'


def _provider() -> str:
    return get_settings().EMAIL_PROVIDER.strip().lower()


def _body(code: str, reset: bool = False) -> str:
    purpose = 'password reset code' if reset else 'verification code'
    return (
        f'Your TriageMY {purpose} is: {code}\n\n'
        'This code expires in 5 minutes. Do not share it with anyone.\n'
        'If you did not request this code, you can ignore this email.\n'
    )


def email_configured() -> bool:
    """True when the selected provider has the settings it needs."""
    settings = get_settings()
    if _provider() == 'brevo':
        return bool(settings.BREVO_API_KEY and settings.SMTP_FROM_EMAIL)
    if _provider() == 'smtp':
        return all((settings.SMTP_HOST, settings.SMTP_USERNAME,
                    settings.SMTP_FROM_EMAIL, settings.SMTP_PASSWORD))
    return False


def send_tac_email(recipient: str, code: str, reset: bool = False) -> None:
    """Email a TAC; reset=True words it as a password reset code."""
    if not email_configured():
        raise ValueError(NOT_CONFIGURED)
    subject, body = (RESET_SUBJECT if reset else SUBJECT), _body(code, reset)
    if _provider() == 'brevo':
        _send_brevo(recipient, subject, body)
    else:
        _send_smtp(recipient, subject, body)


def _send_brevo(recipient: str, subject: str, body: str) -> None:
    settings = get_settings()
    try:
        resp = httpx.post(
            BREVO_SEND_URL,
            json={'sender': {'name': 'TriageMY', 'email': settings.SMTP_FROM_EMAIL},
                  'to': [{'email': recipient}],
                  'subject': subject,
                  'textContent': body},
            headers={'api-key': settings.BREVO_API_KEY, 'accept': 'application/json'},
            timeout=8,
        )
        resp.raise_for_status()
    except httpx.HTTPStatusError as exc:
        # Brevo's error body ({"code", "message"}) holds neither the key nor the TAC. Log it for the
        # operator; clients only get the generic message.
        hint = (' (this is an SMTP key; the HTTP API needs an API key starting "xkeysib-")'
                if settings.BREVO_API_KEY.startswith('xsmtpsib-') else '')
        logger.error('Brevo rejected the TAC email: HTTP %s %s%s',
                     exc.response.status_code, exc.response.text[:300], hint)
        raise ValueError(SEND_FAILED) from exc
    except httpx.HTTPError as exc:
        logger.error('Brevo request failed: %s', type(exc).__name__)
        raise ValueError(SEND_FAILED) from exc


def _send_smtp(recipient: str, subject: str, body: str) -> None:
    settings = get_settings()
    if settings.SMTP_PORT not in (465, 587):
        raise ValueError('Email delivery requires SMTP port 465 or 587 with TLS.')

    message = EmailMessage()
    message['Subject'] = subject
    message['From'] = formataddr(('TriageMY', settings.SMTP_FROM_EMAIL))
    message['To'] = recipient
    message.set_content(body)
    password = settings.SMTP_PASSWORD.replace(' ', '')
    context = ssl.create_default_context()
    try:
        if settings.SMTP_PORT == 465:
            connection = smtplib.SMTP_SSL(settings.SMTP_HOST, settings.SMTP_PORT,
                                          timeout=8, context=context)
        else:
            connection = smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=8)
        with connection as smtp:
            if settings.SMTP_PORT == 587:
                smtp.ehlo()
                smtp.starttls(context=context)
                smtp.ehlo()
            smtp.login(settings.SMTP_USERNAME, password)
            refused = smtp.send_message(message)
            if refused:
                raise ValueError('Email delivery was refused. Please check your email address.')
    except (smtplib.SMTPException, OSError) as exc:
        # Do not expose SMTP responses, credentials, or TAC contents to clients.
        raise ValueError(SEND_FAILED) from exc
