"""Add application report fields while preserving the original report table and rows."""
from sqlalchemy import inspect, text

from app.core.database import get_engine


def migrate(engine):
    if engine.dialect.name != 'postgresql':
        raise RuntimeError('This migration requires PostgreSQL.')
    with engine.begin() as connection:
        schema = inspect(connection)
        if not schema.has_table('patient_triage_reports'):
            raise RuntimeError('The patient_triage_reports table must exist.')
        columns = {c['name'] for c in schema.get_columns('patient_triage_reports')}
        if not {'id', 'report_id'} & columns:
            raise RuntimeError('No recognized report identifier; no changes made.')
        additions = {'id': 'varchar(64)', 'report': 'jsonb', 'report_id': 'varchar(64)',
                     'main_symptom': 'text', 'reported_severity': 'text',
                     'danger_signs': 'text', 'duration': 'text'}
        for name, kind in additions.items():
            connection.execute(text(f'ALTER TABLE patient_triage_reports ADD COLUMN IF NOT EXISTS {name} {kind}'))
        connection.execute(text('UPDATE patient_triage_reports SET id=report_id WHERE id IS NULL'))
        connection.execute(text('UPDATE patient_triage_reports SET report_id=id WHERE report_id IS NULL'))
        connection.execute(text('ALTER TABLE patient_triage_reports ALTER COLUMN id SET NOT NULL'))
        connection.execute(text('CREATE UNIQUE INDEX IF NOT EXISTS patient_triage_reports_app_id_idx ON patient_triage_reports(id)'))
        # Old reports have no recorded triage level. Leave report NULL rather than inventing one.
    print('Report schema updated; existing report IDs, fields and rows preserved.')


if __name__ == '__main__':
    migrate(get_engine())
