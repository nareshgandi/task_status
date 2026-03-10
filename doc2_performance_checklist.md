**Google Cloud SQL**

**DBE Performance Diagnosis Runbook**

End-to-End Checklist: Dependency Check → Root Cause → Resolution

*Classification: Confidential --- DBE Internal \| Applies to: PostgreSQL 13, 14, 15, 16 on Cloud SQL*

**HOW TO USE THIS RUNBOOK**

Work through each phase in sequence. Do not skip Phase 1 (Dependencies) --- many apparent performance issues are caused by unresolved dependency constraints that make optimizations ineffective or dangerous.

Priority legend: P1 = Immediate risk / potential data loss \| P2 = Significant impact \| P3 = Warning / investigate

**Phase 1: Dependency & Environment Check**

**Complete this phase before any diagnosis or tuning. Dependency issues can mask true root causes and cause dangerous remediation outcomes if undetected.**

Instructions: Check each item. Note actual values in the \'Finding\' column when applicable. Any P1 items must be resolved before proceeding to Phase 2.

**1.1 Replication Slot Status**

  ----------------------------------------------------------------------------------------------------------------------------------------------------
  **Done**   **Check Item**                                                                        **Priority**   **Category**   **Finding / Value**
  ---------- ------------------------------------------------------------------------------------- -------------- -------------- ---------------------
  ☐          Verify no replication slots are inactive (confirmed_flush_lsn not advancing)          **P1**         Replication    

  ☐          Check WAL accumulation caused by inactive slots (pg_wal directory size vs baseline)   **P1**         Replication    

  ☐          Confirm all slot consumers are active and connected (pg_stat_replication)             **P1**         Replication    

  ☐          Validate slot lag: wal_lsn - confirmed_flush_lsn \< \[INSERT THRESHOLD\]              **P2**         Replication    

  ☐          Check max_replication_slots vs active slot count (headroom \> 2)                      **P2**         Replication    

  ☐          Verify wal_level is logical if logical slots exist (otherwise WAL volume is wasted)   **P2**         Replication    
  ----------------------------------------------------------------------------------------------------------------------------------------------------

**Key Diagnosis Queries --- Replication Slots**

\-- List all slots with lag and active status

SELECT slot_name, plugin, active, pg_size_pretty(

pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS lag,

age(xmin) AS xmin_age, database

FROM pg_replication_slots

ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) DESC;

**1.2 Long-Running Transaction & Lock Dependencies**

  --------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Done**   **Check Item**                                                                                  **Priority**   **Category**   **Finding / Value**
  ---------- ----------------------------------------------------------------------------------------------- -------------- -------------- ---------------------
  ☐          Identify transactions running \> \[INSERT THRESHOLD\] minutes (block VACUUM and XID progress)   **P1**         Locks/VACUUM   

  ☐          Check for lock waits: queries blocked \> \[INSERT THRESHOLD\] seconds                           **P1**         Locks          

  ☐          Identify deadlock count in pg_stat_database.deadlocks over the last 24 hours                    **P2**         Locks          

  ☐          Verify idle-in-transaction sessions (state = \'idle in transaction\')                           **P2**         Connections    

  ☐          Check idle_in_transaction_session_timeout is configured (0 = no timeout = risk)                 **P2**         Config         

  ☐          Identify 2PC (two-phase commit) transactions older than \[INSERT THRESHOLD\]                    **P2**         Locks          

  ☐          Verify statement_timeout and lock_timeout are set for application roles                         **P3**         Config         
  --------------------------------------------------------------------------------------------------------------------------------------------------------------

**Key Diagnosis Queries --- Locks & Long Transactions**

\-- Long-running transactions (replace interval as needed)

SELECT pid, now() - pg_stat_activity.query_start AS duration,

state, wait_event_type, wait_event, query

FROM pg_stat_activity

WHERE (now() - pg_stat_activity.query_start) \> interval \'5 minutes\'

ORDER BY duration DESC;

\-- Lock waits --- who is blocking whom

SELECT blocked.pid AS blocked_pid, blocking.pid AS blocking_pid,

blocked.query AS blocked_query, blocking.query AS blocking_query

FROM pg_stat_activity blocked

JOIN pg_stat_activity blocking ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))

WHERE blocked.wait_event_type = \'Lock\';

**1.3 Autovacuum & XID Wraparound Status**

  ------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Done**   **Check Item**                                                                               **Priority**   **Category**    **Finding / Value**
  ---------- -------------------------------------------------------------------------------------------- -------------- --------------- ---------------------
  ☐          Check max XID age across all databases (datfrozenxid). Alert if \> 1.5B                      **P1**         VACUUM/XID      

  ☐          Identify tables with relfrozenxid age \> autovacuum_freeze_max_age (default 200M)            **P1**         VACUUM/XID      

  ☐          Check if autovacuum is currently running on any relation (pg_stat_activity)                  **P1**         VACUUM          

  ☐          Verify autovacuum is enabled at the instance and table level (not disabled by ALTER TABLE)   **P1**         VACUUM/Config   

  ☐          Check for tables with \> \[INSERT THRESHOLD\] dead tuples causing bloat                      **P2**         VACUUM/Bloat    

  ☐          Verify autovacuum_work_mem or maintenance_work_mem is adequate for table size                **P2**         Config          

  ☐          Check autovacuum_max_workers vs active worker count (saturation)                             **P2**         Config          

  ☐          Review autovacuum_vacuum_cost_delay --- if too high, vacuum is throttled too much            **P2**         Config          

  ☐          Verify last_autovacuum and last_autoanalyze times per table (pg_stat_user_tables)            **P3**         VACUUM          
  ------------------------------------------------------------------------------------------------------------------------------------------------------------

**Key Diagnosis Queries --- XID & Autovacuum**

\-- XID age by database (critical threshold: \> 2,000,000,000 = shutdown)

SELECT datname, age(datfrozenxid) AS xid_age,

round(100.0 \* age(datfrozenxid) / 2000000000, 2) AS pct_toward_wraparound

FROM pg_database ORDER BY age(datfrozenxid) DESC;

\-- Tables most at risk for wraparound

SELECT schemaname, relname, n_live_tup, n_dead_tup,

age(relfrozenxid) AS table_xid_age,

last_autovacuum, last_autoanalyze

FROM pg_stat_user_tables t JOIN pg_class c ON c.relname = t.relname

ORDER BY age(relfrozenxid) DESC LIMIT 20;

**1.4 Connection & Resource Dependencies**

  --------------------------------------------------------------------------------------------------------------------------------------------
  **Done**   **Check Item**                                                               **Priority**   **Category**    **Finding / Value**
  ---------- ---------------------------------------------------------------------------- -------------- --------------- ---------------------
  ☐          Check current connection count vs max_connections (alert if \> 85%)          **P1**         Connections     

  ☐          Identify connections by state: active, idle, idle-in-transaction             **P2**         Connections     

  ☐          Verify connection pooler (PgBouncer) health and pool saturation if present   **P2**         Connections     

  ☐          Check pg_stat_database.conflicts --- replica conflict-based cancellations    **P2**         Replication     

  ☐          Verify work_mem x max_connections doesn\'t exceed available memory           **P2**         Memory/Config   

  ☐          Check shared_buffers hit ratio (pg_statio_user_tables blks_hit/blks_read)    **P3**         Memory          
  --------------------------------------------------------------------------------------------------------------------------------------------

**Phase 2: Performance Baseline & Identification**

Establish current performance state before investigation. Baseline data is required to measure impact of any tuning changes.

**2.1 Slow Query Identification**

  --------------------------------------------------------------------------------------------------------------------------------------------------
  **Done**   **Check Item**                                                                   **Priority**   **Category**      **Finding / Value**
  ---------- -------------------------------------------------------------------------------- -------------- ----------------- ---------------------
  ☐          Confirm pg_stat_statements is enabled (required for all query analysis)          **P1**         Monitoring        

  ☐          Capture top 20 queries by total_exec_time from pg_stat_statements baseline       **P1**         Performance       

  ☐          Identify queries with high mean_exec_time and high calls (chronic offenders)     **P1**         Performance       

  ☐          Capture top 20 queries by rows returned (data volume issues)                     **P2**         Performance       

  ☐          Check for full sequential scans on large tables (pg_stat_user_tables seq_scan)   **P2**         Indexes           

  ☐          Identify queries returning vastly more rows than expected (N+1, no LIMIT)        **P2**         SQL Quality       

  ☐          Review pg_stat_statements for temp file usage (sorts spilling to disk)           **P2**         Memory/Config     

  ☐          Check pg_stat_bgwriter for checkpoint frequency (frequent = write pressure)      **P2**         WAL/Checkpoints   
  --------------------------------------------------------------------------------------------------------------------------------------------------

**Key Diagnosis Queries --- Slow Query Baseline**

\-- Top 20 by total execution time (requires pg_stat_statements)

SELECT substring(query, 1, 80) AS query_snippet,

calls, round(total_exec_time::numeric, 2) AS total_ms,

round(mean_exec_time::numeric, 2) AS avg_ms,

round(stddev_exec_time::numeric, 2) AS stddev_ms,

rows, shared_blks_hit, shared_blks_read

FROM pg_stat_statements

ORDER BY total_exec_time DESC LIMIT 20;

**2.2 Index & Statistics Health**

  -----------------------------------------------------------------------------------------------------------------------------------------------------
  **Done**   **Check Item**                                                                         **Priority**   **Category**   **Finding / Value**
  ---------- -------------------------------------------------------------------------------------- -------------- -------------- ---------------------
  ☐          Identify unused indexes (pg_stat_user_indexes idx_scan = 0 for \> 30 days)             **P2**         Indexes        

  ☐          Check for duplicate/redundant indexes on same column set                               **P2**         Indexes        

  ☐          Verify ANALYZE has been run after any bulk data load (check pg_stat_user_tables)       **P2**         Statistics     

  ☐          Check statistics target on skewed columns (default_statistics_target may be too low)   **P2**         Statistics     

  ☐          Identify tables with stale statistics (last_analyze \> \[INSERT THRESHOLD\] days)      **P2**         Statistics     

  ☐          Look for index bloat --- index size vs logical size (pgstattuple if available)         **P3**         Bloat          

  ☐          Check for missing FK indexes (foreign key columns without supporting index)            **P3**         Indexes        

  ☐          Verify covering indexes for top slow queries (include clause, multi-col ordering)      **P3**         Indexes        
  -----------------------------------------------------------------------------------------------------------------------------------------------------

**Key Diagnosis Queries --- Index Health**

\-- Unused indexes (candidates for removal --- verify first with application team)

SELECT schemaname, tablename, indexname, pg_size_pretty(pg_relation_size(indexrelid)) AS size,

idx_scan AS scans_last_reset

FROM pg_stat_user_indexes

WHERE idx_scan = 0

ORDER BY pg_relation_size(indexrelid) DESC;

\-- Sequential scans on large tables (possible missing index)

SELECT relname, seq_scan, seq_tup_read, idx_scan,

pg_size_pretty(pg_relation_size(relid)) AS table_size

FROM pg_stat_user_tables

WHERE seq_scan \> 0

ORDER BY seq_tup_read DESC LIMIT 20;

**Phase 3: Pattern-Specific Diagnosis Checklists**

**3.1 Checklist: Major Version Upgrade Blocked (P-01)**

Run this checklist BEFORE any upgrade attempt and share results with customer.

  ----------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Done**   **Check Item**                                                                                   **Priority**   **Category**    **Finding / Value**
  ---------- ------------------------------------------------------------------------------------------------ -------------- --------------- ---------------------
  ☐          Count total tables in instance (pg_class WHERE relkind = \'r\'). Document exact count.           **P1**         Pre-Check       

  ☐          Count tables per schema --- identify schemas with \> 10K tables (partition sets, multi-tenant)   **P1**         Pre-Check       

  ☐          Run VACUUM ANALYZE on all system catalogs (pg_class, pg_attribute, pg_depend)                    **P1**         Pre-Check       

  ☐          Verify all installed extensions are compatible with the target PostgreSQL version                **P1**         Extensions      

  ☐          Check for deprecated functions used in the instance (pg_deprecated_funcs if available)           **P1**         Compatibility   

  ☐          Verify no tables use data types removed in target version                                        **P2**         Compatibility   

  ☐          Check replication setup --- upgrade requires logical replication teardown/rebuild                **P2**         Replication     

  ☐          Estimate upgrade duration based on catalog size (table in runbook appendix)                      **P2**         Planning        

  ☐          Confirm maintenance window is adequate for estimated duration + rollback buffer                  **P2**         Planning        

  ☐          Verify storage has \> \[INSERT %\] free space (upgrade creates temporary data copy)              **P2**         Storage         

  ☐          Capture current performance baseline (pg_stat_statements reset)                                  **P2**         Baseline        

  ☐          Document current postgresql.conf settings (backup before upgrade)                                **P2**         Config          

  ☐          Test upgrade on non-production clone first --- mandatory for high table count instances          **P1**         Validation      
  ----------------------------------------------------------------------------------------------------------------------------------------------------------------

**Upgrade Duration Estimation Table**

  -----------------------------------------------------------------------------------------------------------------------------------------------------
  **Table Count**   **Est. Pre-Check Duration**   **Est. Upgrade Duration**                   **Recommendation**
  ----------------- ----------------------------- ------------------------------------------- ---------------------------------------------------------
  \< 10,000         \< 2 min                      \[INSERT BENCHMARK\]                        Standard upgrade window

  10K -- 50K        2--10 min                     \[INSERT BENCHMARK\]                        Extended window; catalog vacuum first

  50K -- 100K       10--30 min                    \[INSERT BENCHMARK\]                        DBE-assisted; test clone mandatory

  \> 100K           \> 30 min                     \[INSERT BENCHMARK --- may not complete\]   Schema consolidation discussion required before upgrade
  -----------------------------------------------------------------------------------------------------------------------------------------------------

*\[INSERT YOUR BENCHMARKS --- measure on production-equivalent clone. Do not publish estimated durations without internal Cloud SQL benchmark data.\]*

**3.2 Checklist: Cannot Drop Role --- Dependency Resolution (P-02)**

Run this checklist before attempting any DROP ROLE or DROP USER. Always execute REASSIGN OWNED before DROP OWNED.

  -------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Done**   **Check Item**                                                                                       **Priority**   **Category**   **Finding / Value**
  ---------- ---------------------------------------------------------------------------------------------------- -------------- -------------- ---------------------
  ☐          List all objects owned by the role (pg_class, pg_proc, pg_namespace filtered by relowner/nspowner)   **P1**         Ownership      

  ☐          List all schemas owned by the role                                                                   **P1**         Ownership      

  ☐          List all functions/procedures owned by the role (pg_proc.proowner)                                   **P1**         Ownership      

  ☐          List all sequences owned by the role (common after pg_dump/restore)                                  **P1**         Ownership      

  ☐          Check for publications owned by the role (pg_publication.pubowner)                                   **P1**         Replication    

  ☐          Check for subscriptions associated with the role                                                     **P1**         Replication    

  ☐          List all privileges granted TO the role (pg_auth_members)                                            **P2**         Privileges     

  ☐          List all privileges granted BY the role to others (must be revoked first)                            **P2**         Privileges     

  ☐          Check for default privileges set by the role (pg_default_acl)                                        **P2**         Privileges     

  ☐          Identify RLS policies that reference the role (pg_policies)                                          **P2**         Security/RLS   

  ☐          Check pg_depend for any broken dependencies referencing this role\'s OID                             **P2**         Broken Deps    

  ☐          Identify target role for REASSIGN OWNED (typically postgres or application owner)                    **P1**         Planning       

  ☐          Execute REASSIGN OWNED BY \[old_role\] TO \[new_role\] --- and verify                                **P1**         Action         

  ☐          Execute DROP OWNED BY \[role\] --- removes remaining privileges                                      **P1**         Action         

  ☐          Execute DROP ROLE \[role\] --- should now succeed                                                    **P1**         Action         
  -------------------------------------------------------------------------------------------------------------------------------------------------------------------

**Role Dependency Inventory Queries**

\-- All objects owned by role (replace \'role_to_drop\' with actual role name)

SELECT c.relname AS object_name, c.relkind AS type,

n.nspname AS schema, r.rolname AS owner

FROM pg_class c JOIN pg_roles r ON r.oid = c.relowner

JOIN pg_namespace n ON n.oid = c.relnamespace

WHERE r.rolname = \'role_to_drop\';

\-- Grants given by this role to others

SELECT grantor.rolname AS grantor, grantee.rolname AS grantee, privilege_type

FROM information_schema.role_table_grants rtg

JOIN pg_roles grantor ON grantor.rolname = rtg.grantor

WHERE rtg.grantor = \'role_to_drop\';

\-- Broken dependencies in pg_depend (objects with dangling owner references)

SELECT d.classid::regclass, d.objid, d.deptype, r.rolname AS owner_role

FROM pg_depend d LEFT JOIN pg_roles r ON r.oid = d.refobjid

WHERE d.refclassid = \'pg_authid\'::regclass

AND NOT EXISTS (SELECT 1 FROM pg_roles WHERE oid = d.refobjid);

**3.3 Checklist: XID Wraparound Emergency Response (P-03)**

P1 Protocol: If age \> 1.9B XIDs, execute Phase 1 items immediately. Do not wait for complete diagnosis.

**EMERGENCY: If datfrozenxid age \> 1,900,000,000, the database will shut down new transactions at 2,000,000,000. This is a P0 --- call DBE on-call immediately.**

  -------------------------------------------------------------------------------------------------------------------------------------------------
  **Done**   **Check Item**                                                                     **Priority**   **Category**   **Finding / Value**
  ---------- ---------------------------------------------------------------------------------- -------------- -------------- ---------------------
  ☐          Run XID age query --- document current age and calculate remaining headroom        **P1**         VACUUM/XID     

  ☐          Identify all blocking conditions: long txns, idle-in-txn, 2PC transactions         **P1**         Locks          

  ☐          Check for inactive replication slots (cross-reference P-04 checklist)              **P1**         Replication    

  ☐          Terminate blocking long-running transactions (with customer approval)              **P1**         Action         

  ☐          Drop inactive replication slots preventing VACUUM from advancing (with approval)   **P1**         Action         

  ☐          Manually trigger VACUUM FREEZE on highest-age tables                               **P1**         Action         

  ☐          Temporarily increase autovacuum aggressiveness (cost_delay = 0, max_workers up)    **P1**         Config         

  ☐          Monitor XID age every 5 minutes until below safe threshold (\< 200M from limit)    **P1**         Monitoring     

  ☐          After emergency resolved: root cause analysis --- why autovacuum fell behind       **P2**         RCA            

  ☐          Set up monitoring alert for XID age \> \[INSERT THRESHOLD\] going forward          **P2**         Prevention     

  ☐          Review autovacuum configuration for all high-write tables                          **P2**         Config         
  -------------------------------------------------------------------------------------------------------------------------------------------------

**3.4 Checklist: Oracle Migration Performance (P-05)**

Run this checklist for any performance complaint following Oracle-to-PostgreSQL migration. Check dependency phase first --- missing ANALYZE after migration is the most common cause.

  ---------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Done**   **Check Item**                                                                               **Priority**   **Category**       **Finding / Value**
  ---------- -------------------------------------------------------------------------------------------- -------------- ------------------ ---------------------
  ☐          Confirm ANALYZE was run after data load (check last_analyze in pg_stat_user_tables)          **P1**         Statistics         

  ☐          Verify pg_stat_statements is capturing the exact slow queries                                **P1**         Monitoring         

  ☐          Run EXPLAIN (ANALYZE, BUFFERS) on top 5 slow queries --- document actual vs estimated rows   **P1**         Query Plan         

  ☐          Check for ROWNUM-based pagination rewritten as subqueries (common Oracle migration error)    **P1**         SQL Anti-Pattern   

  ☐          Check for implicit type conversions preventing index use (varchar = integer etc.)            **P1**         SQL Anti-Pattern   

  ☐          Check for Oracle-style date/timestamp functions rewritten incorrectly                        **P2**         SQL Anti-Pattern   

  ☐          Verify collation settings match expected sort behavior (LC_COLLATE)                          **P2**         Config             

  ☐          Review any HINT comments in migrated SQL --- PostgreSQL ignores Oracle hints silently        **P2**         SQL Anti-Pattern   

  ☐          Check statistics target on key columns with skewed distribution (low selectivity)            **P2**         Statistics         

  ☐          Verify indexes migrated correctly --- ora2pg may not transfer all index types                **P2**         Indexes            

  ☐          Check for function-based indexes that exist in Oracle but weren\'t migrated                  **P2**         Indexes            

  ☐          Review partition pruning --- Oracle and PostgreSQL partition strategies differ               **P2**         Partitioning       

  ☐          Compare actual execution plans Oracle vs PostgreSQL for top 5 slowest queries                **P2**         Query Plan         

  ☐          Verify work_mem is adequate for the sort/hash operations in migrated queries                 **P2**         Config             

  ☐          Set statistics target higher (200-500) for columns in high-impact WHERE clauses              **P3**         Statistics         
  ---------------------------------------------------------------------------------------------------------------------------------------------------------------

**Phase 4: Configuration Tuning Reference**

Configuration changes must always be validated on non-production first. Document current values before changing.

**4.1 Autovacuum Tuning Parameters**

  -----------------------------------------------------------------------------------------------------------------------------------
  **Parameter**                    **Default**   **Tuned Value**   **When to Change**
  -------------------------------- ------------- ----------------- ------------------------------------------------------------------
  autovacuum_vacuum_cost_delay     2ms           0-1ms             VACUUM too slow; wraparound risk approaching

  autovacuum_max_workers           3             4-6               autovacuum saturated; many tables need vacuum simultaneously

  autovacuum_freeze_max_age        200M          150M              Proactive --- start vacuuming earlier to prevent wraparound risk

  autovacuum_vacuum_scale_factor   0.2 (20%)     0.01-0.05         Large tables --- trigger vacuum after 1-5% change, not 20%

  maintenance_work_mem             64MB          512MB-1GB         Autovacuum performance on large tables

  \[INSERT PARAM\]                 \[DEFAULT\]   \[INSERT\]        \[INSERT GUIDANCE\]
  -----------------------------------------------------------------------------------------------------------------------------------

*\[INSERT CLOUD SQL-SPECIFIC PARAMETER NAMES --- some parameters map differently in Cloud SQL managed environment. Validate against Cloud SQL documentation before applying.\]*

**4.2 Memory Tuning Reference**

  -------------------------------------------------------------------------------------------------------------------------------
  **Parameter**          **Default**   **Typical Range**   **Guidance**
  ---------------------- ------------- ------------------- ----------------------------------------------------------------------
  shared_buffers         128MB         25% of RAM          Set at instance create --- requires restart

  work_mem               4MB           16-256MB            Per-operation, per-sort. Multiply by max_connections before setting.

  effective_cache_size   4GB           75% of RAM          Planner hint only --- does not allocate memory

  wal_buffers            4MB           16MB-64MB           Increase for high write workloads

  \[INSERT PARAM\]       \[DEFAULT\]   \[INSERT\]          \[INSERT GUIDANCE\]
  -------------------------------------------------------------------------------------------------------------------------------

**4.3 Resolution Sign-Off**

Complete this section before closing the ticket or handing back to customer.

  --------------------------------------------------------------------------------------------------------------------------
  **Verification Item**                                    **Expected Outcome**                 **Actual Outcome / Notes**
  -------------------------------------------------------- ------------------------------------ ----------------------------
  Re-run baseline slow query capture from Phase 2          Execution time reduced by target %   \[FILL IN\]

  XID age / wraparound verified (if applicable)            Age decreasing; below threshold      \[FILL IN\]

  Replication slot lag verified (if applicable)            All slots active; lag within SLO     \[FILL IN\]

  Blocking role/dependency resolved (if applicable)        DROP ROLE succeeded cleanly          \[FILL IN\]

  Customer acceptance confirmed                            Customer signed off on resolution    \[DATE / CONTACT\]

  Monitoring / alerting configured to prevent recurrence   Alert rule active and tested         \[FILL IN\]

  KB entry updated or created for this pattern             KB reference number                  \[KB-XX-XXX\]

  DBE engineer sign-off                                    Name + date                          \[NAME / DATE\]
  --------------------------------------------------------------------------------------------------------------------------
