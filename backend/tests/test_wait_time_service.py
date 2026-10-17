import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from app.services import wait_time_service as svc


@pytest.mark.parametrize("ratio,expected", [
    (0.0, "low"), (0.49, "low"), (0.5, "moderate"), (0.99, "moderate"),
    (1.0, "busy"), (1.99, "busy"), (2.0, "very busy"), (10, "very busy"),
])
def test_label_for_ratio(ratio, expected):
    assert svc.label_for_ratio(ratio, 0.5, 1.0, 2.0) == expected


def test_update_wait_labels_end_to_end(monkeypatch, tmp_path):
    engine = create_engine(f"sqlite:///{tmp_path / 't.db'}")
    with engine.begin() as c:
        c.execute(text("CREATE TABLE hospitals (hospital_id TEXT, patients_waiting INT, "
                       "staff_on_duty INT, wait_time_label TEXT)"))
        c.execute(text("INSERT INTO hospitals VALUES ('a', 1, 10, NULL), ('b', 30, 10, NULL), "
                       "('c', 5, 0, 'keep'), ('d', NULL, 5, 'keep')"))
    monkeypatch.setattr(svc, "get_session_factory", lambda: sessionmaker(bind=engine))

    assert svc.update_wait_labels() == 2
    with engine.connect() as c:
        labels = dict(c.execute(text("SELECT hospital_id, wait_time_label FROM hospitals")).all())
    assert labels == {"a": "low", "b": "very busy", "c": "keep", "d": "keep"}
