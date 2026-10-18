"""Key patient_triage_reports by triage session id and add subject linking, without deleting rows.

Renames `id` to `session_id` (older rows keep their random ids; patient_progress.triage_report_id keeps
pointing at them) and adds `subject`, `subject_user_id`, `updated_at` and the flat report columns
(`main_symptom`, `reported_severity`, `danger_signs`, `duration`, `report_id`).
"""
from sqlalchemy import inspect, text
from app.core.database import get_engine
from app.models.triage_report import SavedReport


def main():
    engine = get_engine()
    postgres = engine.dialect.name == 'postgresql'
    if not inspect(engine).has_table('patient_triage_reports'):
        SavedReport.__table__.create(engine)
        print('Created patient_triage_reports.')
        return
    with engine.begin() as c:
        columns = {col['name'] for col in inspect(c).get_columns('patient_triage_reports')}
        if 'id' in columns and 'session_id' not in columns:
            # Foreign keys that reference the column follow the rename.
            c.execute(text('ALTER TABLE patient_triage_reports RENAME COLUMN id TO session_id'))
            print('Renamed patient_triage_reports.id -> session_id')
        timestamp = 'timestamptz' if postgres else 'DATETIME'
        for column, kind in [('subject', 'varchar(10)'), ('subject_user_id', 'varchar(50)'),
                             ('updated_at', timestamp), ('main_symptom', 'text'), ('reported_severity', 'text'),
                             ('danger_signs', 'text'), ('duration', 'text'), ('report_id', 'varchar(64)')]:
            if column not in columns:
                c.execute(text(f'ALTER TABLE patient_triage_reports ADD COLUMN {column} {kind}'))
                print(f'Added patient_triage_reports.{column}')
        c.execute(text('CREATE INDEX IF NOT EXISTS ix_patient_triage_reports_subject_user_id '
                       'ON patient_triage_reports (subject_user_id)'))
        if postgres:
            existing = inspect(c).get_foreign_keys('patient_triage_reports')
            if not any(f['constrained_columns'] == ['subject_user_id'] for f in existing):
                c.execute(text('ALTER TABLE patient_triage_reports ADD CONSTRAINT '
                               'patient_triage_reports_subject_user_id_link FOREIGN KEY (subject_user_id) '
                               'REFERENCES users(id) NOT VALID'))
                c.execute(text('ALTER TABLE patient_triage_reports '
                               'VALIDATE CONSTRAINT patient_triage_reports_subject_user_id_link'))
    print('Triage report migration committed; existing rows preserved.')


if __name__ == '__main__':
    main()
