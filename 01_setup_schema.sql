-- ============================================================
-- STEP 1: SETUP SCHEMA + PARTITIONED TABLES
-- Simulates your production structure
-- ============================================================

-- Clean slate
DROP SCHEMA IF EXISTS sc1 CASCADE;
DROP SCHEMA IF EXISTS impt CASCADE;

CREATE SCHEMA sc1;
CREATE SCHEMA impt;

-- ── Lookup tables (non-partitioned) ──────────────────────────

CREATE TABLE sc1.cp (
    cpid    INT PRIMARY KEY,
    cpn     TEXT,           -- counterparty name
    stid    INT             -- used to join cv1
);

CREATE TABLE impt.bl (
    blid    INT PRIMARY KEY,
    blc     TEXT            -- billing code
);

CREATE TABLE impt.cv1 (
    cvlid   INT PRIMARY KEY,
    cv      NUMERIC(18,4)   -- conversion value
);

-- ── Main transaction table: partitioned by ts (RANGE) ────────
-- This is sc1.crc — partitioned by day to simulate production

CREATE TABLE sc1.crc (
    id      BIGINT,
    cpid    INT,
    blid    INT,
    ts      TIMESTAMPTZ NOT NULL,
    amount  NUMERIC(18,4),
    status  TEXT
) PARTITION BY RANGE (ts);

-- Create 7 daily partitions (last 6 days + today)
CREATE TABLE sc1.crc_1 PARTITION OF sc1.crc
    FOR VALUES FROM (CURRENT_DATE - INTERVAL '6 days') TO (CURRENT_DATE - INTERVAL '5 days');

CREATE TABLE sc1.crc_2 PARTITION OF sc1.crc
    FOR VALUES FROM (CURRENT_DATE - INTERVAL '5 days') TO (CURRENT_DATE - INTERVAL '4 days');

CREATE TABLE sc1.crc_3 PARTITION OF sc1.crc
    FOR VALUES FROM (CURRENT_DATE - INTERVAL '4 days') TO (CURRENT_DATE - INTERVAL '3 days');

CREATE TABLE sc1.crc_4 PARTITION OF sc1.crc
    FOR VALUES FROM (CURRENT_DATE - INTERVAL '3 days') TO (CURRENT_DATE - INTERVAL '2 days');

CREATE TABLE sc1.crc_5 PARTITION OF sc1.crc
    FOR VALUES FROM (CURRENT_DATE - INTERVAL '2 days') TO (CURRENT_DATE - INTERVAL '1 day');

CREATE TABLE sc1.crc_6 PARTITION OF sc1.crc
    FOR VALUES FROM (CURRENT_DATE - INTERVAL '1 day') TO (CURRENT_DATE);

CREATE TABLE sc1.crc_7 PARTITION OF sc1.crc
    FOR VALUES FROM (CURRENT_DATE) TO (CURRENT_DATE + INTERVAL '1 day');

-- ── crbb table: partitioned, with response stored as TEXT ─────
-- Simulates the second table causing Seq Scans due to cast

CREATE TABLE sc1.crbb (
    id          BIGINT,
    crc_id      BIGINT,
    response    TEXT,       -- ⚠️ stored as TEXT but queried as numeric — the bug
    ts          TIMESTAMPTZ NOT NULL,
    payload     TEXT
) PARTITION BY RANGE (ts);

CREATE TABLE sc1.crbb_1 PARTITION OF sc1.crbb
    FOR VALUES FROM (CURRENT_DATE - INTERVAL '6 days') TO (CURRENT_DATE - INTERVAL '5 days');

CREATE TABLE sc1.crbb_2 PARTITION OF sc1.crbb
    FOR VALUES FROM (CURRENT_DATE - INTERVAL '5 days') TO (CURRENT_DATE - INTERVAL '4 days');

CREATE TABLE sc1.crbb_3 PARTITION OF sc1.crbb
    FOR VALUES FROM (CURRENT_DATE - INTERVAL '4 days') TO (CURRENT_DATE - INTERVAL '3 days');

CREATE TABLE sc1.crbb_4 PARTITION OF sc1.crbb
    FOR VALUES FROM (CURRENT_DATE - INTERVAL '3 days') TO (CURRENT_DATE - INTERVAL '2 days');

CREATE TABLE sc1.crbb_5 PARTITION OF sc1.crbb
    FOR VALUES FROM (CURRENT_DATE - INTERVAL '2 days') TO (CURRENT_DATE - INTERVAL '1 day');

CREATE TABLE sc1.crbb_6 PARTITION OF sc1.crbb
    FOR VALUES FROM (CURRENT_DATE - INTERVAL '1 day') TO (CURRENT_DATE);

CREATE TABLE sc1.crbb_7 PARTITION OF sc1.crbb
    FOR VALUES FROM (CURRENT_DATE) TO (CURRENT_DATE + INTERVAL '1 day');

-- ── Indexes ───────────────────────────────────────────────────
-- Intentionally NO index on response (to simulate the problem)
-- Intentionally NO index on crc.ts (to simulate the problem)

-- We will add them later in the fix script

\echo '✅ Schema and tables created successfully'
