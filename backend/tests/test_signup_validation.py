from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import smtplib
import pytest
from pydantic import ValidationError

from app.core.config import get_settings
from app.schemas.auth import RegisterRequest, SendCodeRequest, normalize_phone
from app.services.auth_service import AuthService
from app.repositories.user_repository import UserRepository


def registration(**changes):
    return dict(ic='990101141234', phone='0123456789', email='signup@example.com',
                password='Password1!', name='Test', sex_at_birth='female',
                nationality='Malaysia', **changes)


@pytest.mark.parametrize('email', ['a..b@example.com', '.a@example.com', 'a@-host.com',
                                   'a@example', 'a b@example.com'])
def test_invalid_email(email):
    with pytest.raises(ValidationError):
        SendCodeRequest(email=email, phone='0123456789')


def test_long_email_suffix_and_phone_normalization():
    request = SendCodeRequest(email=' User+tag@clinic.healthcare ', phone='012-345 6789')
    assert request.email == 'user+tag@clinic.healthcare'
    assert request.phone == '+60123456789'


@pytest.mark.parametrize('phone', ['abcdefghij', '1234567890', '+60012345678',
                                   '0123456', '+6011234567', '+601234567890123'])
def test_invalid_phone(phone):
    with pytest.raises(ValueError):
        normalize_phone(phone)


@pytest.mark.parametrize('password', ['Short1!', 'password1!', 'PASSWORD1!',
                                     'Password!!', 'Password12', 'Password1 '])
def test_password_policy(password):
    data = registration()
    data['password'] = password
    with pytest.raises(ValidationError):
        RegisterRequest(**data)


def configure_email(monkeypatch):
    settings = get_settings()
    for field, value in dict(TAC_DELIVERY='email', SMTP_HOST='smtp.gmail.com',
                             SMTP_PORT=465, SMTP_USERNAME='triagemy.wbb@gmail.com',
                             SMTP_FROM_EMAIL='triagemy.wbb@gmail.com',
                             SMTP_PASSWORD='test app password').items():
        monkeypatch.setattr(settings, field, value)
    return settings


def test_email_delivery_and_binding(monkeypatch):
    configure_email(monkeypatch)
    service = AuthService()
    with patch('app.services.email_service.smtplib.SMTP_SSL') as connection:
        smtp = connection.return_value.__enter__.return_value
        smtp.send_message.return_value = {}
        sent = service.send_verification_code('delivery@example.com', '0123456789')
    assert sent.debug_code is None
    connection.assert_called_once()
    assert connection.call_args.args == ('smtp.gmail.com', 465)
    smtp.login.assert_called_once_with('triagemy.wbb@gmail.com', 'testapppassword')
    message = smtp.send_message.call_args.args[0]
    assert message['To'] == 'delivery@example.com'
    assert message['From'] == 'TriageMY <triagemy.wbb@gmail.com>'
    with service._get_db() as session:
        entry = UserRepository(session).get_latest_verification_code(
            service._verification_key('delivery@example.com', '0123456789'))
        code = entry.code
    assert code in message.get_content()
    assert '5 minutes' in message.get_content()
    assert not service.verify_code('other@example.com', code, '0123456789').verified
    assert not service.verify_code('delivery@example.com', code, '0123456790').verified
    assert service.verify_code('delivery@example.com', code, '0123456789').verified
    with pytest.raises(ValueError, match='60 seconds'):
        service.send_verification_code('delivery@example.com', '0123456789')


def test_expiry_and_attempt_limit():
    service = AuthService()
    sent = service.send_verification_code('attempts@example.com', '0123456791')
    wrong = '000000'
    for _ in range(5):
        assert not service.verify_code(sent.email, wrong, '0123456791').verified
    assert not service.verify_code(sent.email, sent.debug_code, '0123456791').verified
    sent = service.send_verification_code('expired@example.com', '0123456792')
    with service._get_db() as session:
        entry = UserRepository(session).get_latest_verification_code(
            service._verification_key(sent.email, '0123456792'))
        entry.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        entry.verified = True
        session.commit()
    assert not service.verify_code(sent.email, sent.debug_code, '0123456792').verified
    data = registration()
    data.update(email=sent.email, phone='0123456792')
    with pytest.raises(ValueError, match='expired'):
        service.register(RegisterRequest(**data))


def test_delivery_failure_does_not_store_code(monkeypatch):
    configure_email(monkeypatch)
    service = AuthService()
    with patch('app.services.email_service.smtplib.SMTP_SSL',
               side_effect=smtplib.SMTPAuthenticationError(535, b'invalid credentials')):
        with pytest.raises(ValueError, match='Unable to send email TAC'):
            service.send_verification_code('failure@example.com', '0123456793')
    with service._get_db() as session:
        assert UserRepository(session).get_latest_verification_code(
            service._verification_key('failure@example.com', '0123456793')) is None


def test_email_starttls(monkeypatch):
    from app.services.email_service import send_tac_email
    settings = configure_email(monkeypatch)
    monkeypatch.setattr(settings, 'SMTP_PORT', 587)
    with patch('app.services.email_service.smtplib.SMTP') as connection:
        smtp = connection.return_value.__enter__.return_value
        smtp.send_message.return_value = {}
        send_tac_email('tls@example.com', '123456')
    assert connection.call_args.args == ('smtp.gmail.com', 587)
    smtp.starttls.assert_called_once()
    assert [call[0] for call in smtp.method_calls] == [
        'ehlo', 'starttls', 'ehlo', 'login', 'send_message']


def test_missing_email_credentials_never_sends(monkeypatch):
    settings = configure_email(monkeypatch)
    monkeypatch.setattr(settings, 'SMTP_PASSWORD', '')
    with patch('app.services.email_service.smtplib.SMTP_SSL') as connection:
        with pytest.raises(ValueError, match='not configured'):
            AuthService().send_verification_code('missing@example.com', '0123456794')
    connection.assert_not_called()


def test_production_cannot_use_debug_delivery(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, 'TAC_DELIVERY', 'test')
    monkeypatch.setattr(settings, 'ENVIRONMENT', 'production')
    with pytest.raises(ValueError, match='Unsupported TAC delivery'):
        AuthService().send_verification_code('production@example.com', '0123456795')
