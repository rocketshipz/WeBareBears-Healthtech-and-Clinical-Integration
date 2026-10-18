"""Set the staff starter password default and repair uninitialized accounts."""
from sqlalchemy import text
from app.core.database import get_engine
from app.services.auth_service import _hash_password


def valid_hash(value):
    try:
        salt, key = value.split(':')
        return len(bytes.fromhex(salt)) == 16 and len(bytes.fromhex(key)) == 32
    except (AttributeError, ValueError):
        return False


def main():
    engine = get_engine()
    if engine is None or engine.dialect.name != 'postgresql':
        raise RuntimeError('This setup requires the configured PostgreSQL database.')
    repaired = 0
    activated = 0
    with engine.begin() as connection:
        # Generated hash contains only hex digits and a colon, never user input.
        default_hash = _hash_password('triagemy123')
        connection.execute(text(
            f"ALTER TABLE staff_login ALTER COLUMN password_hash SET DEFAULT '{default_hash}'"))
        connection.execute(text('ALTER TABLE staff_login ALTER COLUMN is_active SET DEFAULT true'))
        rows = connection.execute(text('SELECT id, staff_id, password_hash FROM staff_login FOR UPDATE')).mappings()
        for row in rows:
            if not valid_hash(row['password_hash']):
                connection.execute(text('UPDATE staff_login SET password_hash=:password_hash, updated_at=CURRENT_TIMESTAMP '
                                        'WHERE id=:id AND staff_id=:staff_id'),
                                   dict(id=row['id'], staff_id=row['staff_id'], password_hash=_hash_password('triagemy123')))
                repaired += 1
        activated = connection.execute(text('UPDATE staff_login SET is_active=true WHERE is_active IS NULL')).rowcount
    print(f'Staff password default configured. Initialized {repaired} passwords; enabled {activated} uninitialized accounts. Existing valid hashes and disabled accounts preserved.')


if __name__ == '__main__':
    main()
