import pytest
from app.core.config import Settings


@pytest.mark.parametrize("mode, expected", [
    ("release", False), ("debug", True), ("false", False), ("true", True),
])
def test_debug_accepts_boolean_and_build_modes(mode, expected):
    assert Settings(DEBUG=mode, _env_file=None).DEBUG is expected
