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
            json={"email": test_email, "phone": test_phone}
        )
        assert send_res.status_code == 200
        send_data = send_res.json()
        assert send_data["success"] is True
        code = send_data["data"]["debug_code"]
        assert len(code) == 6

        # 2. Verify code
        verify_res = await client.post(
            "/api/auth/verify-code",
            json={"email": test_email, "phone": test_phone, "code": code}
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
                "code": code if nationality == "Malaysia" else None,
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

        # Registration creates exactly one linked demographics row.
        from app.core.database import get_session_factory
        from app.models.user import User
        from app.models.user_information import UserInformation
        user_id = reg_data["data"]["user"]["id"]
        with get_session_factory()() as session:
            assert session.get(User, user_id).name == "Test User"
            assert session.get(UserInformation, user_id).nationality == nationality

        headers = {"Authorization": f"Bearer {token}"}
        for weight, allergy in [(60.5, "Penicillin"), (62.0, "Peanuts")]:
            save = await client.put("/api/auth/profile", headers=headers, json={
                "weight_kg": weight, "allergies": [{"substance": allergy}],
                "preferred_language": "Bahasa Melayu", "location_consent": True,
            })
            assert save.status_code == 200, save.text
            loaded = await client.get("/api/auth/profile", headers=headers)
            assert loaded.status_code == 200
            assert float(loaded.json()["data"]["weight_kg"]) == weight
            assert loaded.json()["data"]["allergies"] == [{"substance": allergy}]
            with get_session_factory()() as session:
                record = session.get(UserInformation, user_id)
                assert float(record.weight_kg) == weight
                assert record.allergies == [{"substance": allergy}]
                assert session.query(UserInformation).filter_by(user_id=user_id).count() == 1
                assert session.get(User, user_id).name == "Test User"

        # A separate login reads the same persisted profile.
        other_token = login_phone_res.json()["data"]["token"]
        refreshed = await client.get("/api/auth/profile", headers={"Authorization": f"Bearer {other_token}"})
        assert float(refreshed.json()["data"]["weight_kg"]) == 62.0
        locked = await client.put("/api/auth/profile", headers=headers, json={"name": "Changed"})
        assert locked.status_code == 422
        invalid = await client.put("/api/auth/profile", headers=headers, json={"weight_kg": -1})
        assert invalid.status_code == 422
        unauthenticated = await client.get("/api/auth/profile")
        assert unauthenticated.status_code == 401
        invalid_token = await client.put("/api/auth/profile", headers={"Authorization": "Bearer invalid"}, json={})
        assert invalid_token.status_code == 401

        # Photo-only updates persist without marking medical information complete.
        import base64
        photo = 'data:image/png;base64,' + base64.b64encode(
            b'\x89PNG\r\n\x1a\n' + b'photo-content').decode()
        before = (await client.get('/api/auth/profile', headers=headers)).json()['data']['medical_info_updated_at']
        saved_photo = await client.put('/api/auth/profile', headers=headers,
                                      json={'photo_data_url': photo})
        assert saved_photo.status_code == 200, saved_photo.text
        loaded_photo = await client.get('/api/auth/profile', headers={'Authorization': f'Bearer {other_token}'})
        assert loaded_photo.json()['data']['photo_data_url'] == photo
        assert loaded_photo.json()['data']['medical_info_updated_at'] == before
        invalid_photo = await client.put('/api/auth/profile', headers=headers,
                                        json={'photo_data_url': 'data:image/png;base64,aGVsbG8='})
        assert invalid_photo.status_code == 422
        removed_photo = await client.put('/api/auth/profile', headers=headers,
                                        json={'photo_data_url': None})
        assert removed_photo.status_code == 200
        assert removed_photo.json()['data']['photo_data_url'] is None
