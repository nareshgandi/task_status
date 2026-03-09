-- ============================================================
-- STEP 3: THE BROKEN QUERY — reproduce the slow explain plan
-- Run this first. You should see Seq Scans on all partitions.
-- ============================================================

\echo ''
\echo '════════════════════════════════════════════════════'
\echo '  BROKEN QUERY — Expected: Seq Scans on ALL partitions'
\echo '════════════════════════════════════════════════════'
\echo ''

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT 
  b.blc,
  cv.cv,
  y.cpn
FROM sc1.crc x
LEFT JOIN sc1.cp   y  ON x.cpid  = y.cpid
LEFT JOIN impt.bl  b  ON x.blid  = b.blid
LEFT JOIN impt.cv1 cv ON cv.cvlid = y.stid
  AND x.id = 242123                          -- ⚠️ BUG 1: AND inside JOIN, not WHERE
WHERE x.ts >= CURRENT_DATE - INTERVAL '10 minutes';  -- ⚠️ BUG 2: CURRENT_DATE may not prune partitions

-- What you should see in the output:
-- -> Seq Scan on crc_1   (all 7 partitions scanned)
-- -> Seq Scan on crc_2
-- -> Seq Scan on crc_3
-- ...
-- -> Seq Scan on crc_7
-- No partition pruning happening


\echo ''
\echo '════════════════════════════════════════════════════'
\echo '  BROKEN crbb QUERY — Cast kills index + all partitions'
\echo '════════════════════════════════════════════════════'
\echo ''

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM sc1.crbb
WHERE response::numeric = 242123;   -- ⚠️ BUG 3: cast on text column kills index

-- What you should see:
-- -> Seq Scan on crbb_1 (all partitions)
-- -> Seq Scan on crbb_2
-- ...
-- Filter: (response::numeric = 242123)
