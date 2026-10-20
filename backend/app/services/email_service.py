"""Send signup TACs through authenticated SMTP with certificate-verified TLS."""
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr

from app.core.config import get_settings


def send_tac_email(recipient: str, code: str) -> None:
    settings = get_settings()
    if not all((settings.SMTP_HOST, settings.SMTP_USERNAME,
                settings.SMTP_FROM_EMAIL, settings.SMTP_PASSWORD)):
        raise ValueError('Email verification is not configured. Please contact support.')
    if settings.SMTP_PORT not in (465, 587):
        raise ValueError('Email delivery requires SMTP port 465 or 587 with TLS.')

    message = EmailMessage()
    message['Subject'] = 'Your TriageMY verification code'
    message['From'] = formataddr(('TriageMY', settings.SMTP_FROM_EMAIL))
    message['To'] = recipient
    message.set_content(
        f'Your TriageMY verification code is: {code}\n\n'
        'This code expires in 5 minutes. Do not share it with anyone.\n'
        'If you did not request this code, you can ignore this email.\n'
    )
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
        raise ValueError('Unable to send email TAC. Please try again later or contact support.') from exc
