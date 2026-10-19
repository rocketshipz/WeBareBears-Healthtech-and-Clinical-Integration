from sqlalchemy import Column, DateTime, ForeignKey, String, inspect, text

from app.core.database import Base


class FamilyInvitation(Base):
    __tablename__ = 'patient_family_invitations'
    token_hash = Column(String(64), primary_key=True)
    patient_id = Column(String(50), ForeignKey('users.id'), nullable=False, index=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    consumed_at = Column(DateTime(timezone=True))
    consumed_by = Column(String(50), ForeignKey('users.id'))


class FamilyAccess(Base):
    __tablename__ = 'patient_family_access'
    patient_id = Column(String(50), ForeignKey('users.id'), primary_key=True)
    viewer_id = Column(String(50), ForeignKey('users.id'), primary_key=True)
    status = Column(String(20), nullable=False, default='pending')
    updated_at = Column(DateTime(timezone=True), nullable=False)


def ensure_family_tables(engine):
    with engine.begin() as connection:
        for table in (FamilyInvitation.__table__, FamilyAccess.__table__):
            if inspect(connection).has_table(table.name):
                continue
            table.create(connection, checkfirst=True)
            if engine.dialect.name == 'postgresql':
                connection.execute(text(f'ALTER TABLE {table.name} ENABLE ROW LEVEL SECURITY'))
