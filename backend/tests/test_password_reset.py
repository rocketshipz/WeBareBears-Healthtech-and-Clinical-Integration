import uuid
from unittest.mock import patch

import pytest
from httpx import AsyncClient, ASGITransport

from app.main import app


async def _register(client, email: str) -> None:
    phone = f"012{int(uuid.uuid4().hex[:7], 16) % 10000000:07d}"
    code = (await client.post("/api/auth/send-code", json={"email": email, "phone": phone})
            ).json()["data"]["debug_code"]
    res = await client.post("/api/auth/register", json={
        "ic": "P" + uuid.uuid4().hex[:10], "phone": phone, "email": email,
        "password": "Password123!", "code": code, "name": "Reset User",
        "sex_at_birth": "female", "nationality": "Indonesia", "date_of_birth": "1990-01-01",
    })
    assert res.status_code == 201


@pytest.mark.asyncio
async def test_password_reset_flow():
    email = f"reset_{uuid.uuid4().hex[:6]}@example.com"
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        await _register(client, email)
        old_token = (await client.post("/api/auth/login", json={
            "identifier": email, "password": "Password123!"})).json()["data"]["token"]

        sent = await client.post("/api/auth/forgot-password", json={"email": email.upper()})
        assert sent.status_code == 200
        code = sent.json()["data"]["debug_code"]
        wrong = "000000" if code != "000000" else "111111"

        bad = await client.post("/api/auth/verify-reset-code", json={"email": email, "code": wrong})
        assert bad.status_code == 400
        ok = await client.post("/api/auth/verify-reset-code", json={"email": email, "code": code})
        assert ok.status_code == 200

        weak = await client.post("/api/auth/reset-password", json={
            "email": email, "code": code, "new_password": "weakpassword"})
        assert weak.status_code == 422

        reset = await client.post("/api/auth/reset-password", json={
            "email": email, "code": code, "new_password": "NewPassword456!"})
        assert reset.status_code == 200

        # The code is single-use, old sessions are signed out and only the new password works.
        reuse = await client.post("/api/auth/reset-password", json={
            "email": email, "code": code, "new_password": "Another789!"})
        assert reuse.status_code == 400
        me = await client.get("/api/auth/me", headers={"Authorization": f"Bearer {old_token}"})
        assert me.status_code == 401
        assert (await client.post("/api/auth/login", json={
            "identifier": email, "password": "Password123!"})).status_code == 401
        assert (await client.post("/api/auth/login", json={
            "identifier": email, "password": "NewPassword456!"})).status_code == 200


@pytest.mark.asyncio
async def test_unknown_email_gets_same_response_and_no_email():
    email = f"nobody_{uuid.uuid4().hex[:6]}@example.com"
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        with patch("app.services.auth_service.send_tac_email") as send:
            res = await client.post("/api/auth/forgot-password", json={"email": email})
        assert res.status_code == 200
        assert res.json()["data"]["debug_code"] is None
        send.assert_not_called()
        reset = await client.post("/api/auth/reset-password", json={
            "email": email, "code": "123456", "new_password": "NewPassword456!"})
        assert reset.status_code == 400


@pytest.mark.asyncio
async def test_signup_code_cannot_reset_password():
    email = f"cross_{uuid.uuid4().hex[:6]}@example.com"
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        await _register(client, email)
        phone = f"013{int(uuid.uuid4().hex[:7], 16) % 10000000:07d}"
        signup_code = (await client.post("/api/auth/send-code", json={"email": email, "phone": phone})
                       ).json()["data"]["debug_code"]
        res = await client.post("/api/auth/reset-password", json={
            "email": email, "code": signup_code, "new_password": "NewPassword456!"})
        assert res.status_code == 400
