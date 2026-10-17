import uuid
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest.mark.asyncio
@pytest.mark.parametrize("nationality", ["Malaysia", "Indonesia"])
async def test_auth_flow(nationality):
    # Generate unique test data per run
    unique_suffix = uuid.uuid4().hex[:6]
    test_email = f"user_{unique_suffix}@example.com"
    test_phone = f"012{int(uuid.uuid4().hex[:7], 16) % 10000000:07d}"
    test_ic = f"990101-14-{int(uuid.uuid4().hex[:4], 16) % 10000:04d}"

    if nationality != "Malaysia":
        test_ic = "P" + uuid.uuid4().hex[:10]

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Send verification code
        send_res = await client.post(
            "/api/auth/send-code",
            json={"email": test_email}
        )
        assert send_res.status_code == 200
        send_data = send_res.json()
        assert send_data["success"] is True
        code = send_data["data"]["debug_code"]
        assert len(code) == 6

        # 2. Verify code
        verify_res = await client.post(
            "/api/auth/verify-code",
            json={"email": test_email, "code": code}
        )
        assert verify_res.status_code == 200
        verify_data = verify_res.json()
        assert verify_data["data"]["verified"] is True

        # 3. Register user
        reg_res = await client.post(
            "/api/auth/register",
            json={
                "ic": test_ic,
                "phone": test_phone,
                "email": test_email,
                "password": "Password123!",
                "name": "Test User",
                "sex_at_birth": "intersex",
                "nationality": nationality,
                "date_of_birth": "1995-06-12" if nationality != "Malaysia" else None
            }
        )
        assert reg_res.status_code == 201
        reg_data = reg_res.json()
        assert reg_data["success"] is True
        assert "token" in reg_data["data"]
        token = reg_data["data"]["token"]
        assert reg_data["data"]["user"]["name"] == "Test User"
        assert reg_data["data"]["user"]["sex_at_birth"] == "intersex"

        # 4. Login with email
        login_email_res = await client.post(
            "/api/auth/login",
            json={"identifier": test_email, "password": "Password123!"}
        )
        assert login_email_res.json()["data"]["user"]["nationality"] == nationality
        assert login_email_res.status_code == 200
        assert login_email_res.json()["data"]["user"]["sex_at_birth"] == "intersex"
        assert login_email_res.json()["success"] is True

        # 5. Login with phone
        login_phone_res = await client.post(
            "/api/auth/login",
            json={"identifier": test_phone, "password": "Password123!"}
        )
        assert login_phone_res.status_code == 200
        assert login_phone_res.json()["success"] is True

        # 6. Login with IC
        login_ic_res = await client.post(
            "/api/auth/login",
            json={"identifier": test_ic, "password": "Password123!"}
        )
        assert login_ic_res.status_code == 200

        # 7. Login with invalid password
        bad_login = await client.post(
            "/api/auth/login",
            json={"identifier": test_email, "password": "WrongPassword!"}
        )
        assert bad_login.status_code == 401

        # 8. Check /me with token
        me_res = await client.get(
            "/api/auth/me",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert me_res.status_code == 200
        assert me_res.json()["data"]["email"] == test_email
