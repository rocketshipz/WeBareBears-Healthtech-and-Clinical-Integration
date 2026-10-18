"""Non-destructive migration of the three existing patient tracking tables."""
from sqlalchemy import inspect, text
from app.core.database import get_engine


def main():
    engine = get_engine()
    if engine.dialect.name != 'postgresql':
        raise RuntimeError('This migration is for PostgreSQL.')
    with engine.begin() as connection:
        schema = inspect(connection)
        required = ['patient_progress', 'patient_test_tracking', 'patient_diagnosis_treatment']
        if any(not schema.has_table(table) for table in required):
            raise RuntimeError('The three existing patient tables must be present.')
        additions = {
            'patient_progress': {'department': 'text', 'assigned_staff_id': 'text',
                'queue_number': 'text', 'triage_report_id': 'text', 'chief_complaint': 'text',
                'outcome': 'text', 'version': 'integer NOT NULL DEFAULT 1',
                'audit_log': "jsonb DEFAULT '[]'::jsonb", 'family_sharing': 'boolean DEFAULT false',
                'share_token': 'text'},
            'patient_test_tracking': {'position': 'integer DEFAULT 0',
                'is_test': 'boolean DEFAULT true', 'result_documents': "jsonb DEFAULT '[]'::jsonb"},
        }
        for table, columns in additions.items():
            for name, kind in columns.items():
                connection.execute(text(f'ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {name} {kind}'))
        connection.execute(text("UPDATE patient_test_tracking SET test_id='legacy-' || md5(visit_id) WHERE test_id IS NULL OR test_id=''"))
        key = schema.get_pk_constraint('patient_test_tracking')
        if set(key['constrained_columns']) != {'visit_id', 'test_id'}:
            if key['name']:
                quoted = connection.dialect.identifier_preparer.quote(key['name'])
                connection.execute(text(f'ALTER TABLE patient_test_tracking DROP CONSTRAINT {quoted}'))
            connection.execute(text('ALTER TABLE patient_test_tracking ADD PRIMARY KEY (visit_id, test_id)'))
        connection.execute(text('CREATE INDEX IF NOT EXISTS patient_progress_user_idx ON patient_progress(user_id, arrival_time)'))
        connection.execute(text('CREATE INDEX IF NOT EXISTS patient_progress_staff_idx ON patient_progress(hospital_id, assigned_staff_id)'))
        # These tables contain medical information. Access is through the authenticated API.
        # Existing Supabase policies are kept; direct anon access has no new grant.
        for table in required:
            connection.execute(text(f'ALTER TABLE {table} ENABLE ROW LEVEL SECURITY'))
    print('Progress migration completed; existing patient rows preserved.')


if __name__ == '__main__':
    main()
