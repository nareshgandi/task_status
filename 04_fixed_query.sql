-- ============================================================
-- STEP 4: APPLY FIXES
-- Run this after seeing the broken explain plan
-- ============================================================

\echo 'Adding indexes...'

-- Index on ts for partition pruning + fast range scan
CREATE INDEX IF NOT EXISTS idx_crc_ts   ON sc1.crc  (ts);
CREATE INDEX IF NOT EXISTS idx_crbb_ts  ON sc1.crbb (ts);

-- Index on response as TEXT (no cast needed after fix)
CREATE INDEX IF NOT EXISTS idx_crbb_response ON sc1.crbb (response);

-- Run ANALYZE so planner has fresh stats
ANALYZE sc1.crc;
ANALYZE sc1.crbb;
ANALYZE sc1.cp;
ANALYZE impt.bl;
ANALYZE impt.cv1;

\echo '✅ Indexes created and stats updated'
\echo ''


-- ============================================================
-- STEP 5: THE FIXED QUERY
-- ============================================================

\echo '════════════════════════════════════════════════════'
\echo '  FIXED QUERY — Expected: Only current partition scanned'
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
WHERE x.ts >= now() - INTERVAL '10 minutes'   -- ✅ FIX 1: now() prunes partitions correctly
  AND x.id = 242123;                           -- ✅ FIX 2: AND moved to WHERE clause


-- What you should now see:
-- -> Index Scan on crc_7   (ONLY today's partition)
-- Partitions 1-6 should be PRUNED (not shown in plan)


\echo ''
\echo '════════════════════════════════════════════════════'
\echo '  FIXED crbb QUERY — Index used, no cast'
\echo '════════════════════════════════════════════════════'
\echo ''

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM sc1.crbb
WHERE response = '242123';   -- ✅ FIX 3: compare as text, index can be used

-- What you should now see:
-- -> Index Scan on crbb_7
-- Filter: (response = '242123')


-- ============================================================
-- STEP 6: SIDE BY SIDE COMPARISON (actual results)
-- ============================================================

\echo ''
\echo '── Broken query result ──'
SELECT 
  b.blc,
  cv.cv,
  y.cpn,
  x.ts,
  x.id
FROM sc1.crc x
LEFT JOIN sc1.cp   y  ON x.cpid  = y.cpid
LEFT JOIN impt.bl  b  ON x.blid  = b.blid
LEFT JOIN impt.cv1 cv ON cv.cvlid = y.stid
  AND x.id = 242123
WHERE x.ts >= CURRENT_DATE - INTERVAL '10 minutes'
LIMIT 5;

\echo ''
\echo '── Fixed query result ──'
SELECT 
  b.blc,
  cv.cv,
  y.cpn,
  x.ts,
  x.id
FROM sc1.crc x
LEFT JOIN sc1.cp   y  ON x.cpid  = y.cpid
LEFT JOIN impt.bl  b  ON x.blid  = b.blid
LEFT JOIN impt.cv1 cv ON cv.cvlid = y.stid
WHERE x.ts >= now() - INTERVAL '10 minutes'
  AND x.id = 242123;
