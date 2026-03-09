#!/usr/bin/env python3
"""
02_load_data.py
Loads realistic fake data into the partitioned tables.
Simulates near-real-time + historical data.

Requirements:
    pip install faker psycopg2-binary

Usage:
    python3 02_load_data.py
    
    # Or with custom connection:
    DB_URL="postgresql://user:pass@localhost/mydb" python3 02_load_data.py
"""

import os
import random
import psycopg2
from psycopg2.extras import execute_values
from faker import Faker
from datetime import datetime, timedelta, timezone

fake = Faker()

DB_URL = os.getenv("DB_URL", "postgresql://postgres:postgres@localhost/postgres")

# ── Config ────────────────────────────────────────────────────
COUNTERPARTIES     = 500
BILLING_CODES      = 200
CV_RECORDS         = 300
CRC_ROWS_PER_DAY   = 50_000   # 50K rows per day × 7 days = 350K rows
CRBB_ROWS_PER_DAY  = 30_000
TARGET_ID          = 242123   # the id we will search for in the query

# ─────────────────────────────────────────────────────────────

def connect():
    print(f"Connecting to: {DB_URL}")
    return psycopg2.connect(DB_URL)


def load_lookups(conn):
    cur = conn.cursor()

    print("Loading sc1.cp (counterparties)...")
    cp_data = [(i, fake.company(), random.randint(1, CV_RECORDS)) 
               for i in range(1, COUNTERPARTIES + 1)]
    execute_values(cur, "INSERT INTO sc1.cp (cpid, cpn, stid) VALUES %s ON CONFLICT DO NOTHING", cp_data)

    print("Loading impt.bl (billing codes)...")
    bl_data = [(i, fake.bothify(text='BL-????-####')) 
               for i in range(1, BILLING_CODES + 1)]
    execute_values(cur, "INSERT INTO impt.bl (blid, blc) VALUES %s ON CONFLICT DO NOTHING", bl_data)

    print("Loading impt.cv1 (conversion values)...")
    cv_data = [(i, round(random.uniform(0.5, 150.0), 4)) 
               for i in range(1, CV_RECORDS + 1)]
    execute_values(cur, "INSERT INTO impt.cv1 (cvlid, cv) VALUES %s ON CONFLICT DO NOTHING", cv_data)

    conn.commit()
    print("✅ Lookup tables loaded")


def load_crc(conn):
    cur = conn.cursor()
    now = datetime.now(timezone.utc)
    total = 0
    target_inserted = False

    for day_offset in range(6, -1, -1):  # 6 days ago → today
        day_start = (now - timedelta(days=day_offset)).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        print(f"  Loading crc for {day_start.date()} ({CRC_ROWS_PER_DAY:,} rows)...")

        rows = []
        for i in range(CRC_ROWS_PER_DAY):
            # Spread timestamps across the day
            ts = day_start + timedelta(seconds=random.randint(0, 86399))
            row_id = total + i + 1

            rows.append((
                row_id,
                random.randint(1, COUNTERPARTIES),
                random.randint(1, BILLING_CODES),
                ts,
                round(random.uniform(100, 100000), 4),
                random.choice(['SETTLED', 'PENDING', 'FAILED', 'PROCESSING'])
            ))

        # Insert TARGET_ID row into today's last-10-minutes window
        if day_offset == 0 and not target_inserted:
            ts_recent = now - timedelta(minutes=random.randint(1, 8))
            rows.append((
                TARGET_ID,
                random.randint(1, COUNTERPARTIES),
                random.randint(1, BILLING_CODES),
                ts_recent,
                round(random.uniform(100, 100000), 4),
                'SETTLED'
            ))
            target_inserted = True
            print(f"  ✅ Inserted TARGET row id={TARGET_ID} at ts={ts_recent}")

        execute_values(
            cur,
            "INSERT INTO sc1.crc (id, cpid, blid, ts, amount, status) VALUES %s",
            rows,
            page_size=5000
        )
        conn.commit()
        total += CRC_ROWS_PER_DAY

    print(f"✅ crc loaded: {total:,} rows total")


def load_crbb(conn):
    cur = conn.cursor()
    now = datetime.now(timezone.utc)
    total = 0

    for day_offset in range(6, -1, -1):
        day_start = (now - timedelta(days=day_offset)).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        print(f"  Loading crbb for {day_start.date()} ({CRBB_ROWS_PER_DAY:,} rows)...")

        rows = []
        for i in range(CRBB_ROWS_PER_DAY):
            ts = day_start + timedelta(seconds=random.randint(0, 86399))
            row_id = total + i + 1

            # ⚠️ response stored as TEXT — but contains numeric-looking values
            # This simulates the cast bug: response::numeric = 242123
            response_val = str(random.randint(100000, 999999))

            rows.append((
                row_id,
                random.randint(1, CRC_ROWS_PER_DAY),
                response_val,   # TEXT, not numeric
                ts,
                fake.text(max_nb_chars=100)
            ))

        # Also insert a crbb row pointing to TARGET_ID
        if day_offset == 0:
            ts_recent = now - timedelta(minutes=random.randint(1, 8))
            rows.append((
                total + CRBB_ROWS_PER_DAY + 1,
                TARGET_ID,
                str(TARGET_ID),   # response = '242123' as text
                ts_recent,
                'TARGET response payload'
            ))

        execute_values(
            cur,
            "INSERT INTO sc1.crbb (id, crc_id, response, ts, payload) VALUES %s",
            rows,
            page_size=5000
        )
        conn.commit()
        total += CRBB_ROWS_PER_DAY

    print(f"✅ crbb loaded: {total:,} rows total")


def print_summary(conn):
    cur = conn.cursor()
    print("\n── Row counts ──────────────────────────────────")
    for table in ['sc1.crc', 'sc1.crbb', 'sc1.cp', 'impt.bl', 'impt.cv1']:
        cur.execute(f"SELECT COUNT(*) FROM {table}")
        print(f"  {table:20s}: {cur.fetchone()[0]:>10,}")
    print("────────────────────────────────────────────────")


if __name__ == "__main__":
    conn = connect()
    load_lookups(conn)
    print("\nLoading sc1.crc (this takes ~1-2 min)...")
    load_crc(conn)
    print("\nLoading sc1.crbb (this takes ~1 min)...")
    load_crbb(conn)
    print_summary(conn)
    conn.close()
    print("\n✅ All data loaded. Ready to run queries.")
