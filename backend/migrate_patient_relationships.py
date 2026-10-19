"""Link hospital/patient/staff keys without deleting or guessing orphaned rows."""
from sqlalchemy import inspect, text
from app.core.database import get_engine


def main():
    engine = get_engine()
    if engine.dialect.name != 'postgresql':
        raise RuntimeError('This migration requires PostgreSQL.')
    with engine.begin() as c:
        for table, column, kind in [
            ('staff_login', 'hospital_id', 'text'),
            ('patient_progress', 'assigned_staff_account_id', 'bigint'),
            ('patient_test_tracking', 'updated_by_account_id', 'bigint'),
            ('patient_diagnosis_treatment', 'recorded_by_account_id', 'bigint'),
        ]:
            c.execute(text(f'ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {column} {kind}'))
        for table, source, target in [
            ('staff_login', 'hospital', 'hospital_id'),
            ('patient_progress', 'hospital_id', 'hospital_id'),
        ]:
            c.execute(text(f'''
                WITH matches AS (
                    SELECT p.ctid AS row_id, min(h.hospital_id) AS hospital_id
                    FROM {table} p JOIN hospital_data h ON
                      lower(trim(p.{source})) IN (lower(trim(h.hospital_name)), lower(trim(h.hospital_code)), lower(trim(h.hospital_id)))
                    GROUP BY p.ctid HAVING count(DISTINCT h.hospital_id)=1
                )
                UPDATE {table} p SET {target}=m.hospital_id FROM matches m
                WHERE p.ctid=m.row_id AND NOT EXISTS (SELECT 1 FROM hospital_data h WHERE h.hospital_id=p.{target})
            '''))
        # A legacy IC in user_id can only be converted when it has one exact account match.
        c.execute(text('''WITH matches AS (
            SELECT p.visit_id, min(u.id) AS user_id FROM patient_progress p JOIN users u
            ON replace(p.user_id, '-', '')=replace(u.ic, '-', '')
            WHERE NOT EXISTS (SELECT 1 FROM users x WHERE x.id=p.user_id)
            GROUP BY p.visit_id HAVING count(*)=1
        ) UPDATE patient_progress p SET user_id=m.user_id FROM matches m WHERE p.visit_id=m.visit_id'''))
        for table, code, account in [
            ('patient_progress', 'assigned_staff_id', 'assigned_staff_account_id'),
            ('patient_test_tracking', 'updated_by', 'updated_by_account_id'),
            ('patient_diagnosis_treatment', 'recorded_by', 'recorded_by_account_id'),
        ]:
            c.execute(text(f'''WITH staff AS (SELECT staff_id,min(id) AS id FROM staff_login GROUP BY staff_id HAVING count(*)=1)
                UPDATE {table} p SET {account}=s.id FROM staff s WHERE p.{code}=s.staff_id AND p.{account} IS NULL'''))
        relations = [
            ('staff_login', 'hospital_id', 'hospital_data', 'hospital_id'),
            ('patient_progress', 'hospital_id', 'hospital_data', 'hospital_id'),
            ('patient_progress', 'user_id', 'users', 'id'),
            ('patient_progress', 'triage_report_id', 'patient_triage_reports', 'report_id'),
            ('patient_progress', 'assigned_staff_account_id', 'staff_login', 'id'),
            ('patient_test_tracking', 'visit_id', 'patient_progress', 'visit_id'),
            ('patient_test_tracking', 'updated_by_account_id', 'staff_login', 'id'),
            ('patient_diagnosis_treatment', 'visit_id', 'patient_progress', 'visit_id'),
            ('patient_diagnosis_treatment', 'recorded_by_account_id', 'staff_login', 'id'),
        ]
        for table, column, parent, key in relations:
            constraint = f'{table}_{column}_link'
            existing = inspect(c).get_foreign_keys(table)
            if not any(f['constrained_columns'] == [column] and f['referred_table'] == parent for f in existing):
                c.execute(text(f'ALTER TABLE {table} ADD CONSTRAINT {constraint} FOREIGN KEY ({column}) REFERENCES {parent}({key}) NOT VALID'))
            orphaned = c.execute(text(f'''SELECT count(*) FROM {table} p WHERE p.{column} IS NOT NULL
                AND NOT EXISTS (SELECT 1 FROM {parent} x WHERE x.{key}=p.{column})''')).scalar()
            owned = c.execute(text('SELECT count(*) FROM pg_constraint WHERE conname=:name'), {'name': constraint}).scalar()
            if orphaned == 0 and owned:
                c.execute(text(f'ALTER TABLE {table} VALIDATE CONSTRAINT {constraint}'))
            print(f'{table}.{column} -> {parent}.{key}: {orphaned} unmatched legacy values; new writes enforced')
    print('Relationship migration committed; unmatched legacy rows preserved.')


if __name__ == '__main__':
    main()
