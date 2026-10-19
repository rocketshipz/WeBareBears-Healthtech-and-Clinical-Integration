from app.models.hospital_directory import HospitalDirectory
from app.services.hospital_location_service import check_hospital, classify, name_similarity, pick_match


def place(pid, name, lat, lon):
    return {"id": pid, "displayName": {"text": name}, "location": {"latitude": lat, "longitude": lon}}


def test_name_similarity():
    assert name_similarity("KLSMC HOSPITAL", "Kuala Lumpur Sports Medicine Centre (KLSMC HOSPITAL)") == 1.0
    assert name_similarity("GLENEAGLES HOSPITAL KUALA LUMPUR", "Gleneagles Hospital Kuala Lumpur") == 1.0
    # A generic chain name alone must not match a different branch outright.
    assert name_similarity("KPJ HOSPITAL", "KPJ Ampang Puteri Specialist Hospital") < 1.0
    assert name_similarity("TUNG SHIN HOSPITAL", "Sunway Medical Centre") < 0.5
    # Real false matches seen on the first run: same town or chain, different place.
    assert name_similarity("TAIPING MEDICAL CENTRE", "Columbia Asia Hospital Taiping") < 0.6
    assert name_similarity("SUNWAY MEDICAL CENTRE IPOH",
                           "Ipoh Eye Specialist | Dr Abirami Shavani | Sunway Ipoh") < 0.6
    assert name_similarity("SENA SPEACIALIST HOSPITAL SEGAMAT", "Sena Specialist Hospital Segamat") >= 0.8


def test_pick_match_prefers_similar_name():
    places = [place("x", "Sunway Pyramid", 3.07, 101.6), place("y", "Tung Shin Hospital", 3.145, 101.70)]
    assert pick_match("TUNG SHIN HOSPITAL", places)["id"] == "y"
    assert pick_match("TUNG SHIN HOSPITAL", [places[0]]) is None


def test_classify_and_check():
    assert classify(None, 1.0) == "not_found"
    assert classify(0.4, 1.0) == "match" and classify(2.5, 1.0) == "mismatch"
    h = HospitalDirectory(hospital_id="H1", hospital_name="TUNG SHIN HOSPITAL", latitude=3.10, longitude=101.70)
    check = check_hospital(h, [place("y", "Tung Shin Hospital", 3.145, 101.70)], 1.0)
    assert check.status == "mismatch" and check.google_place_id == "y" and check.distance_km > 4
    assert check_hospital(h, [], 1.0).status == "not_found"
    # Far away with only a moderate name match: kept for review, not relocated.
    similar = check_hospital(h, [place("z", "Tung Shin Clinic", 3.145, 101.70)], 1.0)
    assert similar.status == "uncertain"
    # A weak name match is accepted only where Google agrees with the DB location.
    near = HospitalDirectory(hospital_id="H3", hospital_name="PEACE MEDICAL CENTRE", latitude=3.10, longitude=101.70)
    assert check_hospital(near, [place("p", "Peace Hospital KL", 3.101, 101.70)], 1.0).status == "match"
    assert check_hospital(near, [place("p", "Peace Hospital KL", 3.20, 101.70)], 1.0).status == "not_found"
    # Real false matches from the full run: another chain's branch, or a separate "II" hospital.
    for db_name, google_name in (("HOSPITAL PASIR GUDANG", "KPJ Pasir Gudang Specialist Hospital"),
                                 ("HOSPITAL QUEEN ELIZABETH", "Queen Elizabeth Hospital II, Kota Kinabalu")):
        other = HospitalDirectory(hospital_id="H4", hospital_name=db_name, latitude=3.10, longitude=101.70)
        assert check_hospital(other, [place("q", google_name, 3.145, 101.70)], 1.0).status == "uncertain"
    # A brand only in brackets ("formerly known as …") does not count.
    kemena = HospitalDirectory(hospital_id="H5", hospital_name="KEMENA PACIFIC HOSPITAL", latitude=3.10, longitude=101.70)
    assert check_hospital(kemena, [place("k", "Kemena Pacific Hospital (formerly Columbia Asia Hospital - Bintulu)",
                                         3.145, 101.70)], 1.0).status == "mismatch"
    no_coords = HospitalDirectory(hospital_id="H2", hospital_name="TUNG SHIN HOSPITAL")
    assert check_hospital(no_coords, [place("y", "Tung Shin Hospital", 3.145, 101.70)], 1.0).status == "mismatch"
