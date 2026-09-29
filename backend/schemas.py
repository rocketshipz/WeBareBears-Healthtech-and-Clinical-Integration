from pydantic import BaseModel
from typing import List, Any, Dict, Optional

class QueryResult(BaseModel):
    """Schema for validating the response from database queries."""
    success: bool
    data: Optional[List[Dict[str, Any]]] = None
    error: Optional[str] = None
