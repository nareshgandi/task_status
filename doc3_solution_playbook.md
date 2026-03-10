**Google Cloud SQL**

**DBE Solution Playbook**

Structured Resolution Guides for Top Customer Ticket Patterns

*Classification: Confidential --- DBE Internal \| Format: KB-Ready \| Version: 1.0*

SCOPE: This playbook covers P-01 through P-06 patterns identified in the 6-month ticket analysis. Each entry is structured for both human DBE use and RAG-based AI agent retrieval. Populate \[INSERT\] fields with your measured data before publishing.

**Quick Reference --- Solution Entries in this Document:**

  -------------------------------------------------------------------------------------------------------------
  **KB ID**            **Pattern**                                          **Severity**   **Page**
  -------------------- ---------------------------------------------------- -------------- --------------------
  KB-UPGRADE-001       Major Version Upgrade Blocked --- High Table Count   P2             \[Page N\]

  KB-SECURITY-001      Cannot Drop Role --- Dependency Cascade              P2             \[Page N\]

  KB-VACUUM-001        XID Wraparound Risk / Emergency                      P1             \[Page N\]

  KB-REPLICATION-001   Inactive Replication Slot                            P1/P2          \[Page N\]

  KB-MIGRATION-001     Performance Degradation Post Oracle Migration        P2             \[Page N\]

  KB-PERFORMANCE-001   Slow Query / SQL Tuning                              P2/P3          \[Page N\]
  -------------------------------------------------------------------------------------------------------------

**KB-UPGRADE-001 Major Version Upgrade Blocked --- High Table Count**

**Severity: P2 --- Significant Impact / Service Disruption Risk**

**Problem Statement --- Customer-Facing Triggers**

-   \"My Cloud SQL instance cannot complete the major version upgrade\"

-   \"pg_upgrade is timing out / upgrade is stuck for hours\"

-   \"The upgrade pre-check fails but I don\'t know which tables are the problem\"

-   \"I have \[X\] tables and the upgrade never finishes\"

-   \"Upgrade estimated duration keeps increasing / never completes\"

**Root Cause**

pg_upgrade performs per-object catalog validation during the pre-check phase. At table counts above approximately 100,000, the catalog traversal (pg_class, pg_attribute, pg_depend) takes disproportionately long due to:

-   O(n) complexity of catalog scanning with no parallelism in pg_upgrade pre-check phase

-   Catalog bloat: dead tuples in pg_class and pg_attribute amplify scan duration

-   Extension-owned catalog entries that require compatibility verification per object

-   Cloud SQL upgrade timeout of \[INSERT TIMEOUT\] --- may expire before pre-check completes

**Diagnosis --- Confirm and Quantify**

\-- Step 1: Count total tables and confirm threshold

SELECT count(\*) AS total_tables

FROM pg_class

WHERE relkind = \'r\';

\-- Step 2: Tables by schema (identify concentration)

SELECT n.nspname AS schema, count(\*) AS table_count

FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace

WHERE c.relkind = \'r\'

GROUP BY n.nspname

ORDER BY table_count DESC LIMIT 20;

\-- Step 3: Catalog bloat (dead tuples in system tables)

SELECT relname, n_live_tup, n_dead_tup,

round(100.0 \* n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct

FROM pg_stat_user_tables

WHERE schemaname = \'pg_catalog\'

ORDER BY n_dead_tup DESC;

\-- Step 4: Extension compatibility check

SELECT name, default_version, installed_version

FROM pg_available_extensions

WHERE installed_version IS NOT NULL

ORDER BY name;

**Resolution Steps --- Ordered by Risk (Lowest to Highest)**

Always test upgrade on a non-production clone that mirrors table count and extension set before attempting production upgrade.

**Step 1 --- Immediate: Assess and document scope**

1.  Run diagnosis queries above. Document total table count, top schemas by count, catalog bloat %, and installed extensions.

2.  Share table count report with customer and set expectations on upgrade duration.

3.  Confirm whether table count can be reduced (old data, temp tables, partition consolidation opportunity).

**Step 2 --- Pre-upgrade: Eliminate catalog bloat**

4.  Run VACUUM ANALYZE on pg_catalog tables and all user tables with high dead tuple counts.

VACUUM ANALYZE;

5.  For Cloud SQL, confirm autovacuum has been running recently (check last_autovacuum).

6.  If catalog bloat is \> \[INSERT THRESHOLD %\], escalate to Tier 2 --- manual VACUUM FULL on catalog may be required (requires downtime).

**Step 3 --- Pre-upgrade: Extension audit**

7.  Cross-reference each installed extension against the Cloud SQL extension compatibility matrix for the target version.

8.  Flag any extensions not available in target version --- customer must DROP EXTENSION before upgrade or accept unavailability.

9.  Document extension upgrade path for each compatible extension.

**Step 4 --- Upgrade execution**

10. Schedule maintenance window: use \[INSERT ESTIMATED DURATION TABLE\] + 50% buffer + rollback window.

11. Attempt upgrade. Monitor pre-check phase duration --- if timeout imminent, pause and reassess.

12. For \> 100K table instances: engage Cloud SQL engineering for extended timeout or alternative upgrade path (dump/restore in parallel may be faster).

**Prevention --- For Future Instances**

-   Instrument table count monitoring alert at \> 75K tables --- proactive DBE engagement before customer hits upgrade wall

-   Recommend schema consolidation pattern for multi-tenant customers: schema-per-tenant → row-per-tenant with RLS

-   Pre-upgrade compatibility check should be a standard DBE engagement deliverable for any major version upgrade request

**Related Patterns**

-   KB-VACUUM-001: Ensure wraparound is not contributing to catalog age before upgrade

-   KB-REPLICATION-001: Replication slots must be dropped and rebuilt across major version upgrades

  -------------------------------------------------------------------------------------------------------------------------------
  **Category**    **PostgreSQL Versions**   **Keywords**                                                       **Last Updated**
  --------------- ------------------------- ------------------------------------------------------------------ ------------------
  UPGRADE         All (13, 14, 15, 16)      pg_upgrade, table count, catalog bloat, extension, major version   \[INSERT DATE\]

  -------------------------------------------------------------------------------------------------------------------------------

**KB-SECURITY-001 Cannot Drop Role --- Dependency Cascade**

**Severity: P2 --- Service Impact / Security Compliance Risk**

**Problem Statement --- Customer-Facing Triggers**

-   \"DROP ROLE fails with \'role cannot be dropped because some objects depend on it\'\"

-   \"I cannot remove a user --- it owns things but I don\'t know what\"

-   \"REASSIGN OWNED fails --- objects reference roles that don\'t exist\"

-   \"Security audit requires removing unused roles but every drop fails\"

-   \"We have broken dependencies from old pg_dump/restore --- how do we clean up\"

**Root Cause**

PostgreSQL\'s DROP ROLE requires the role to own zero objects and have zero privileges. In production systems that have evolved organically, roles accumulate ownership of tables, schemas, sequences, functions, publications, and subscriptions. Additional complexity arises from:

-   Broken dependencies: pg_dump/restore or cross-database migrations can leave pg_class.relowner referencing OIDs that no longer exist in pg_authid

-   Default privileges (ALTER DEFAULT PRIVILEGES) are invisible to most customers and survive role cleanup attempts

-   Row-level security policies referencing the role --- DROP ROLE silently fails even after REASSIGN OWNED

-   Publications and subscriptions owned by the role --- especially relevant in logical replication setups

**Resolution --- Step-by-Step Script (Populate Before Use)**

CRITICAL ORDER: Always execute REASSIGN OWNED before DROP OWNED. Never reverse this order --- DROP OWNED without REASSIGN first will destroy objects the customer needs.

**Step 1: Inventory all dependencies**

\-- Full object inventory for target role

\-- Replace \'target_role\' with actual role name throughout

\-- Objects owned

SELECT c.relname, c.relkind, n.nspname AS schema

FROM pg_class c

JOIN pg_roles r ON r.oid = c.relowner

JOIN pg_namespace n ON n.oid = c.relnamespace

WHERE r.rolname = \'target_role\';

\-- Schemas owned

SELECT nspname FROM pg_namespace n

JOIN pg_roles r ON r.oid = n.nspowner

WHERE r.rolname = \'target_role\';

\-- Functions owned

SELECT proname, pronamespace::regnamespace

FROM pg_proc p JOIN pg_roles r ON r.oid = p.proowner

WHERE r.rolname = \'target_role\';

\-- Check for broken dependencies (relowner with no matching pg_authid entry)

SELECT c.relname, c.relowner AS orphaned_oid

FROM pg_class c

WHERE NOT EXISTS (

SELECT 1 FROM pg_authid WHERE oid = c.relowner

);

**Step 2: Identify ownership transfer target role**

-   Determine the correct target role for REASSIGN OWNED --- typically the superuser, the application owner, or a dedicated ownership role

-   Confirm with customer --- incorrect assignment may give application roles unintended access

**Step 3: Execute cleanup sequence**

\-- Execute as superuser. Replace \'target_role\' and \'new_owner\'

\-- 3a: Reassign all owned objects

REASSIGN OWNED BY target_role TO new_owner;

\-- 3b: Revoke all remaining privileges

DROP OWNED BY target_role;

\-- 3c: Drop the role

DROP ROLE target_role;

**Step 4: Broken dependency cleanup (if Step 3 fails due to orphaned OIDs)**

Directly modifying pg_class.relowner requires superuser access and should only be done with DBE approval. Document the change in the audit log.

\-- Reassign orphaned objects to postgres (superuser)

UPDATE pg_class SET relowner = (SELECT oid FROM pg_roles WHERE rolname = \'postgres\')

WHERE NOT EXISTS (SELECT 1 FROM pg_authid WHERE oid = relowner);

**Prevention**

-   Implement role lifecycle policy: roles must be documented with owning team at creation

-   Quarterly role audit query: flag roles with no login activity in 90 days

-   Before any role creation, document what the role will own --- prevents orphaned ownership at offboarding

  ------------------------------------------------------------------------------------------------------------------------------------------
  **Category**    **PostgreSQL Versions**   **Keywords**                                                                  **Last Updated**
  --------------- ------------------------- ----------------------------------------------------------------------------- ------------------
  SECURITY        All                       DROP ROLE, REASSIGN OWNED, pg_depend, broken dependency, pg_dump, pg_authid   \[INSERT DATE\]

  ------------------------------------------------------------------------------------------------------------------------------------------

**KB-VACUUM-001 XID Wraparound Risk / Emergency**

**Severity: P1 --- DATA LOSS RISK --- IMMEDIATE ACTION REQUIRED**

P1 PROTOCOL: If database age \> 1,900,000,000 XIDs, do not proceed with standard diagnosis. Call DBE on-call. The database will begin refusing transactions at 2,000,000,000 XIDs --- this is a hard PostgreSQL limit.

**Problem Statement --- Customer-Facing Triggers**

-   \"ERROR: database is not accepting commands to avoid wraparound data loss\"

-   \"My autovacuum is not keeping up --- XID age keeps growing\"

-   \"pg_database shows age close to 2 billion\"

-   \"I see \'WARNING: database must be vacuumed within X transactions\' in the logs\"

**Severity Thresholds**

  ---------------------------------------------------------------------------------------------------------------------
  **XID Age**     **% of Limit**   **Severity**         **Required Action**
  --------------- ---------------- -------------------- ---------------------------------------------------------------
  \< 500M         \< 25%           P3 --- Monitor       Ensure autovacuum is running normally

  500M -- 1B      25-50%           P2 --- Investigate   Review autovacuum config; ensure no blockers

  1B -- 1.5B      50-75%           P2 --- Escalate      Manual VACUUM FREEZE on highest-age tables; DBE review

  1.5B -- 1.9B    75-95%           P1 --- Emergency     Immediate action; terminate blockers; aggressive vacuum

  \> 1.9B         \> 95%           P0 --- CRITICAL      Database shutdown imminent; call on-call engineer immediately
  ---------------------------------------------------------------------------------------------------------------------

**Root Cause Identification**

Determine which of these conditions is causing XID age to advance faster than VACUUM can address:

13. Long-running transactions preventing VACUUM from advancing relfrozenxid

14. Inactive replication slots holding back xmin horizon (see KB-REPLICATION-001)

15. autovacuum misconfigured or disabled --- VACUUM not running frequently enough

16. autovacuum throttled too aggressively --- cost_delay too high for write volume

17. High dead tuple accumulation rate outpacing autovacuum workers

**Emergency Resolution Sequence**

**Execute in this exact order --- do not skip steps:**

\-- STEP 1: Measure current risk level

SELECT datname, age(datfrozenxid) AS xid_age,

2000000000 - age(datfrozenxid) AS transactions_remaining

FROM pg_database ORDER BY age(datfrozenxid) DESC;

\-- STEP 2: Identify blockers (long-running transactions)

SELECT pid, usename, now() - xact_start AS txn_duration, state, query

FROM pg_stat_activity

WHERE xact_start IS NOT NULL

ORDER BY xact_start ASC LIMIT 10;

\-- STEP 3: Terminate blockers (with customer approval)

SELECT pg_terminate_backend(pid)

FROM pg_stat_activity

WHERE xact_start \< now() - interval \'\[INSERT THRESHOLD\]\'

AND pid \<\> pg_backend_pid();

\-- STEP 4: Check and drop inactive replication slots

SELECT slot_name, active, age(xmin) AS xmin_age

FROM pg_replication_slots WHERE NOT active;

\-- With approval: SELECT pg_drop_replication_slot(\'slot_name\');

\-- STEP 5: Boost autovacuum temporarily

ALTER SYSTEM SET autovacuum_vacuum_cost_delay = 0;

ALTER SYSTEM SET autovacuum_max_workers = 6;

SELECT pg_reload_conf();

\-- STEP 6: Manual VACUUM FREEZE on highest-age tables

VACUUM FREEZE ANALYZE \[highest_age_table_name\];

\-- STEP 7: Monitor progress (run every 5 minutes)

SELECT datname, age(datfrozenxid) AS xid_age FROM pg_database

ORDER BY age(datfrozenxid) DESC;

**Permanent Prevention Configuration**

  ----------------------------------------------------------------------------------------------------------------------------------------
  **Parameter**                  **Recommended Value**   **Rationale**
  ------------------------------ ----------------------- ---------------------------------------------------------------------------------
  autovacuum_freeze_max_age      150000000               Start vacuuming tables earlier (default 200M is too late for fast-write tables)

  autovacuum_vacuum_cost_delay   1ms                     Reduce throttle for high-write environments

  autovacuum_max_workers         4-6                     More workers for large instances with many tables

  vacuum_freeze_min_age          1000000                 Freeze old tuples more aggressively
  ----------------------------------------------------------------------------------------------------------------------------------------

  --------------------------------------------------------------------------------------------------------------------------------
  **Category**    **PostgreSQL Versions**   **Keywords**                                                        **Last Updated**
  --------------- ------------------------- ------------------------------------------------------------------- ------------------
  VACUUM          All                       wraparound, XID, datfrozenxid, autovacuum, freeze, transaction ID   \[INSERT DATE\]

  --------------------------------------------------------------------------------------------------------------------------------

**KB-REPLICATION-001 Inactive Replication Slot Blocking WAL Cleanup**

**Severity: P1/P2 --- WAL Disk Risk / Wraparound Risk**

**Problem Statement --- Customer-Facing Triggers**

-   \"My disk is filling up and I see pg_wal growing\"

-   \"Replication slot is inactive but I\'m afraid to drop it\"

-   \"My CDC consumer (Debezium / Striim / pglogical) disconnected --- how do I safely clean up\"

-   \"XID age is growing and I have replication slots --- are they related?\"

-   \"pg_replication_slots shows \'active = false\' --- what does that mean?\"

**Risk Cascade --- Why This Matters**

  -------------------------------------------------------------------------------------------------------------------------------
  **Risk Level**   **What Happens**                                      **Consequence**
  ---------------- ----------------------------------------------------- --------------------------------------------------------
  Immediate        WAL accumulates because slot LSN is not advancing     pg_wal directory fills disk → database goes read-only

  Short-term       xmin horizon held back by slot xmin age               XID age increases → wraparound risk (KB-VACUUM-001)

  Ongoing          VACUUM cannot reclaim dead tuples held by slot xmin   Table and index bloat increases → performance degrades

  Storage          pg_wal growth triggers Cloud SQL storage autoscale    Unexpected cost increase; potential storage limit hit
  -------------------------------------------------------------------------------------------------------------------------------

**Diagnosis**

\-- List all replication slots with lag and active status

SELECT slot_name, plugin, active, database,

pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS wal_lag,

age(xmin) AS xmin_age,

catalog_xmin

FROM pg_replication_slots

ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) DESC;

**Resolution**

**Decision tree for inactive slots:**

18. Is the consumer permanently discontinued? → Drop the slot immediately.

19. Is the consumer temporarily unavailable (planned)? → Set a recovery deadline. If not reconnected by deadline, drop the slot.

20. Is the consumer accidentally disconnected? → Reconnect consumer first. Only drop slot if data gap is acceptable.

\-- Drop inactive slot (get customer approval first)

SELECT pg_drop_replication_slot(\'slot_name_here\');

Dropping a replication slot is irreversible. The consumer must be reconfigured to create a new slot. Confirm with customer that the data gap from the slot\'s last LSN is acceptable before dropping.

**Prevention**

-   Set wal_max_slot_wal_keep_size = \[INSERT VALUE\]GB to limit WAL accumulation per slot (PG 13+)

-   Alert when any slot is inactive for \> \[INSERT THRESHOLD\] hours

-   Alert when any slot WAL lag exceeds \[INSERT THRESHOLD\]GB

-   Document all replication slots with owner/consumer/team at creation time

  -----------------------------------------------------------------------------------------------------------------------------------------------------
  **Category**    **PostgreSQL Versions**   **Keywords**                                                                             **Last Updated**
  --------------- ------------------------- ---------------------------------------------------------------------------------------- ------------------
  REPLICATION     All                       replication slot, WAL, pg_wal, CDC, Debezium, logical replication, inactive slot, xmin   \[INSERT DATE\]

  -----------------------------------------------------------------------------------------------------------------------------------------------------

**KB-MIGRATION-001 Performance Degradation Post Oracle Migration**

**Severity: P2 --- Significant Performance Impact**

**Problem Statement --- Customer-Facing Triggers**

-   \"PostgreSQL is \[X\]x slower than Oracle for the same query\"

-   \"Our migration ran fine but now production is too slow\"

-   \"EXPLAIN shows sequential scans but we have indexes\"

-   \"Queries that took 1 second in Oracle take 60 seconds in PostgreSQL\"

-   \"We ran ANALYZE but queries are still slow\"

**Mandatory First Step**

Before any SQL tuning: confirm ANALYZE was run after all data loads. Missing statistics is the single most common cause of post-migration performance issues and masks all other diagnosis.

\-- Verify ANALYZE ran recently on all tables

SELECT relname, last_analyze, last_autoanalyze,

n_live_tup, n_dead_tup

FROM pg_stat_user_tables

WHERE last_analyze IS NULL OR last_analyze \< now() - interval \'1 day\'

ORDER BY n_live_tup DESC;

\-- If tables are missing ANALYZE:

ANALYZE; \-- Full database ANALYZE

**Common Oracle Anti-Patterns and PostgreSQL Rewrites**

**Anti-Pattern 1: ROWNUM for pagination**

\-- Oracle (slow in PostgreSQL --- full scan before ROWNUM filter)

SELECT \* FROM (SELECT \* FROM orders ORDER BY order_date) WHERE ROWNUM \<= 100;

\-- PostgreSQL correct form

SELECT \* FROM orders ORDER BY order_date LIMIT 100;

**Anti-Pattern 2: Implicit type conversion blocking index use**

\-- Oracle allows implicit VARCHAR to INT comparison

WHERE customer_id = \'12345\' \-- customer_id is INTEGER in PostgreSQL

\-- PostgreSQL: above prevents index use. Fix:

WHERE customer_id = 12345 \-- or CAST(\'12345\' AS INTEGER)

**Anti-Pattern 3: Missing covering index for high-selectivity queries**

\-- Oracle optimizer may use different index selection strategy

\-- PostgreSQL needs explicit covering index for INCLUDE columns

CREATE INDEX CONCURRENTLY idx_orders_customer_status

ON orders(customer_id, status)

INCLUDE (order_date, total_amount);

**Anti-Pattern 4: Statistics target too low for skewed data**

\-- Oracle uses adaptive statistics; PostgreSQL default_statistics_target = 100

\-- For highly skewed columns, increase statistics target

ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500;

ANALYZE orders;

**EXPLAIN Analysis Quick Reference**

  ------------------------------------------------------------------------------------------------------------------------------------
  **EXPLAIN Output Indicator**         **What It Means**                  **Resolution**
  ------------------------------------ ---------------------------------- ------------------------------------------------------------
  Seq Scan on large table              Missing or unused index            Create index; check type match; update statistics

  rows=1 estimated vs rows=1M actual   Stale or insufficient statistics   ANALYZE; increase statistics target on key columns

  Hash Join (very high memory)         work_mem too low; spill to disk    Increase work_mem for session; check temp file usage

  Nested Loop on large result          Join strategy mismatch             Review join selectivity; SET enable_nestloop = off to test

  Sort (external merge)                Sort spilling to disk              Increase work_mem; add sorting index

  \[INSERT PATTERN\]                   \[INSERT MEANING\]                 \[INSERT RESOLUTION\]
  ------------------------------------------------------------------------------------------------------------------------------------

  -----------------------------------------------------------------------------------------------------------------------------------------------------
  **Category**              **PostgreSQL Versions**   **Keywords**                                                                   **Last Updated**
  ------------------------- ------------------------- ------------------------------------------------------------------------------ ------------------
  MIGRATION / PERFORMANCE   All                       Oracle, ora2pg, ROWNUM, statistics, ANALYZE, EXPLAIN, type conversion, index   \[INSERT DATE\]

  -----------------------------------------------------------------------------------------------------------------------------------------------------

**Appendix: Monitoring Queries Library**

Production-ready monitoring queries for dashboard integration. All queries are read-only and safe to run on live instances.

**A.1 Wraparound Age Dashboard Query**

SELECT datname,

age(datfrozenxid) AS xid_age,

round(100.0 \* age(datfrozenxid) / 2000000000, 1) AS pct_of_limit,

CASE

WHEN age(datfrozenxid) \> 1900000000 THEN \'CRITICAL\'

WHEN age(datfrozenxid) \> 1500000000 THEN \'WARNING\'

WHEN age(datfrozenxid) \> 1000000000 THEN \'ELEVATED\'

ELSE \'OK\'

END AS status

FROM pg_database

ORDER BY age(datfrozenxid) DESC;

**A.2 Replication Slot Health Dashboard**

SELECT slot_name, active, database,

pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS wal_lag,

age(xmin) AS xmin_age,

CASE

WHEN NOT active AND pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) \> 10737418240 THEN \'CRITICAL\'

WHEN NOT active THEN \'WARNING\'

ELSE \'OK\'

END AS status

FROM pg_replication_slots

ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) DESC;

**A.3 Long Transaction Alert Query**

SELECT pid, usename, datname,

now() - xact_start AS txn_duration,

state, wait_event_type, wait_event,

left(query, 120) AS query_snippet

FROM pg_stat_activity

WHERE xact_start IS NOT NULL

AND now() - xact_start \> interval \'\[INSERT THRESHOLD\]\'

ORDER BY xact_start ASC;

**A.4 Table Count Pre-Upgrade Alert**

SELECT count(\*) AS total_tables,

CASE

WHEN count(\*) \> 100000 THEN \'UPGRADE_RISK_HIGH\'

WHEN count(\*) \> 50000 THEN \'UPGRADE_RISK_MEDIUM\'

ELSE \'UPGRADE_OK\'

END AS upgrade_readiness

FROM pg_class WHERE relkind = \'r\';
