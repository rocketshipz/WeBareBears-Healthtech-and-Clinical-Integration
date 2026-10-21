from sqlalchemy import Column, DateTime, String
from app.core.database import Base


class RoutingTriageClear(Base):
    """When a user last cleared their recent triage result from hospital routing.

    Routing ignores triage reports saved before cleared_at; the reports themselves are kept (history, staff lookup).
    A new triage after clearing is used again.
    """
    __tablename__ = "routing_triage_clear"

    user_id = Column(String(50), primary_key=True)
    cleared_at = Column(DateTime(timezone=True), nullable=False)
