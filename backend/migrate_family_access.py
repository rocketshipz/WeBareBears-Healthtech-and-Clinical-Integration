"""Create single-use family invitations and patient-approved access; preserve existing data."""
from sqlalchemy import text
from app.core.database import get_engine
from app.models.user import User  # Register foreign key target.
from app.models.family_access import FamilyAccess, FamilyInvitation


def main():
    engine = get_engine()
    with engine.begin() as connection:
        for table in (FamilyInvitation.__table__, FamilyAccess.__table__):
            table.create(connection, checkfirst=True)
            if engine.dialect.name == 'postgresql':
                connection.execute(text(f'ALTER TABLE {table.name} ENABLE ROW LEVEL SECURITY'))
    print('Family access tables ready.')


if __name__ == '__main__':
    main()
