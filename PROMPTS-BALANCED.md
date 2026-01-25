# Batch Content Generation Prompts - BALANCED VERSION
**PostgresHelp DBA Training Curriculum - 1,470 Pages**

Use with: Claude Code, Cursor, GitHub Copilot in VS Code  
Timeline: 10-12 days

---

## 📋 Balanced Structure Overview

| Topic | Units | Pages | Pages/Unit |
|-------|-------|-------|------------|
| 1. Python for DBAs | 6 chapters | 150 | 25 |
| 2. Linux/Shell | 5 chapters | 100 | 20 |
| 3. AWS Tools | 6 chapters | 150 | 25 |
| 4. Terraform/Docker/K8s | 5 chapters | 120 | 24 |
| 5. PostgreSQL DBA | 25 modules | 500 | 20 |
| 6. SampleBank Project | 25 modules | 450 | 18 |
| **TOTAL** | **72 units** | **1,470** | **~20** |

---

## TOPIC 1: Python for PostgreSQL DBAs (150 pages, 6 chapters)

### Chapter Breakdown (25 pages each)

Each chapter structure:
- **theory/01-concept.md**: 12 pages - Core technical content
- **theory/02-why-dbas-care.md**: 2 pages - Real scenarios
- **theory/03-failure-cases.md**: 4 pages - Production failures
- **theory/04-takeaways.md**: 2 pages - Quick reference
- **lab/lab-guide.md**: 4 pages - Hands-on exercises
- **assessment/quiz.md + lab-assignment.md**: 1 page - Assessment

### Chapter 1 Prompt (25 pages)

```
Generate Python for PostgreSQL DBAs - Chapter 1: Introduction to Python

Target: 25 pages total
Focus: Essentials only, DBA-practical

**theory/01-concept.md** (12 pages):
- What is Python & why DBAs need it (2 pages)
- Python vs Bash comparison for DBAs (1 page)
- psycopg2 quick intro with connection example (2 pages)
- Installation (Ubuntu + RHEL) (2 pages)
- Virtual environments (why + how) (2 pages)
- Core Python overview (vars, functions, loops) (2 pages)
- Recommended tools (1 page)

**theory/02-why-dbas-care.md** (2 pages):
- 3 AM WAL alert prevention scenario
- Intelligent VACUUM vs bash script
- Job interview impact

**theory/03-failure-cases.md** (4 pages):
- ModuleNotFoundError - psycopg2 not installed
- pg_config not found - missing libpq-dev
- Permission denied - sudo pip issues
- Script works in terminal, fails in cron
Include real error messages and exact fixes

**theory/04-takeaways.md** (2 pages):
- Key concepts summary (8 bullets)
- Installation cheatsheet (Ubuntu + RHEL)
- Virtual environment commands
- Top 5 mistakes to avoid

**lab/lab-guide.md** (4 pages):
Compact exercises:
1. Install Python + PostgreSQL dev libs
2. Create venv and install psycopg2
3. Test database connection
4. Create health check script

**assessment/quiz.md** (1 page):
- 10 questions with answers

Keep it concise, production-focused, no academic fluff.
All code examples must be tested and working.
```

### Chapters 2-6

Use same format, adjusting topics:

**Ch 2**: Python Fundamentals (variables, loops, functions, file ops)  
**Ch 3**: PostgreSQL with Python (psycopg2 deep-dive)  
**Ch 4**: Error Handling & Logging  
**Ch 5**: Automating Admin Tasks (VACUUM, bloat, monitoring)  
**Ch 6**: Scheduling & Deployment (cron, systemd)

---

## TOPIC 2: Linux/Shell Scripting (100 pages, 5 chapters)

### Chapter Structure (20 pages each)

- theory/01-concept.md: 10 pages
- theory/02-why-dbas-care.md: 2 pages
- theory/03-failure-cases.md: 3 pages
- theory/04-takeaways.md: 1 page
- lab/lab-guide.md: 3 pages
- assessment: 1 page

### Chapter Topics

**Ch 1**: Linux Fundamentals for DBAs (file system, permissions, processes)  
**Ch 2**: Shell Scripting Basics (variables, loops, functions)  
**Ch 3**: Process Management & Automation (systemd, cron)  
**Ch 4**: Log Analysis & Monitoring (grep, awk, sed)  
**Ch 5**: Backup & Recovery Scripts (pg_dump automation)

---

## TOPIC 3: AWS & PostgreSQL Tools (150 pages, 6 chapters)

### Chapter Structure (25 pages each)

- theory/01-concept.md: 12 pages
- theory/02-why-dbas-care.md: 2 pages
- theory/03-failure-cases.md: 4 pages
- theory/04-takeaways.md: 2 pages
- lab/lab-guide-cloud.md: 3 pages
- lab/lab-guide-onprem.md: 2 pages
- assessment: 2 pages (includes both cloud and on-prem)

### Chapter Topics

**Ch 1**: AWS RDS for PostgreSQL  
**Ch 2**: Terraform for RDS Management  
**Ch 3**: CloudWatch Monitoring & Alerting  
**Ch 4**: Backup & DR Strategies  
**Ch 5**: Aurora PostgreSQL  
**Ch 6**: PostgreSQL Tools Ecosystem (pgAdmin, pg_stat_statements, etc.)

---

## TOPIC 4: Terraform, Docker & Kubernetes (120 pages, 5 chapters)

### Chapter Structure (24 pages each)

Same dual-environment structure as AWS chapters.

### Chapter Topics

**Ch 1**: Terraform Basics for DBAs  
**Ch 2**: Docker for PostgreSQL  
**Ch 3**: Docker Compose for PG Stack  
**Ch 4**: Kubernetes Fundamentals  
**Ch 5**: PostgreSQL on Kubernetes (Operators)

---

## TOPIC 5: PostgreSQL DBA Course (500 pages, 25 modules)

### Module Structure (20 pages each)

This is your MAIN course - maintain quality here!

- **theory/01-concept.md**: 8 pages - Deep technical content
- **theory/02-why-dbas-care.md**: 1 page - Production scenarios
- **theory/03-failure-cases.md**: 3 pages - Real failures
- **theory/04-takeaways.md**: 1 page - Quick reference
- **lab/lab-guide-cloud.md**: 3 pages - AWS RDS labs
- **lab/lab-guide-onprem.md**: 3 pages - Docker/VM labs
- **assessment/quiz.md + lab-assignment.md**: 1 page

### Module Prompt Template

```
Generate PostgreSQL DBA Course - Module [N]: [TOPIC]

Target: 20 pages
This is the MAIN DBA course - maintain depth and quality

**theory/01-concept.md** (8 pages):
- PostgreSQL internals and architecture
- Configuration parameters
- Best practices
- Performance implications
Be technical, be thorough, but concise

**theory/02-why-dbas-care.md** (1 page):
- 1-2 production scenarios where this knowledge saved the day

**theory/03-failure-cases.md** (3 pages):
- 3-4 real production failures
- Symptoms, diagnosis, fix, prevention

**theory/04-takeaways.md** (1 page):
- Command cheatsheet
- Quick reference
- Common patterns

**lab/lab-guide-cloud.md** (3 pages):
- AWS RDS hands-on using BankForge demo database
- Step-by-step with Terraform examples

**lab/lab-guide-onprem.md** (3 pages):
- Docker/VM equivalent using BankForge database
- Ensure parity with cloud labs

**assessment** (1 page):
- 10 quiz questions
- 1 practical assignment

Format as production runbook that DBAs can reference.
```

### Module List (25 modules)

**Foundation (1-5)**:
1. Architecture & Installation
2. Configuration & Parameter Tuning
3. Security & Authentication
4. Backup & Point-in-Time Recovery
5. Streaming Replication

**Operations (6-15)**:
6. High Availability (Patroni, repmgr)
7. Monitoring & Alerting
8. Performance Tuning Methodology
9. Query Optimization & EXPLAIN
10. VACUUM, ANALYZE, and Maintenance
11. Table Partitioning
12. Logical Replication
13. Extensions & pg_stat_statements
14. Connection Pooling (PgBouncer)
15. Disaster Recovery Planning

**Advanced (16-25)**:
16. Migration Strategies (upgrades)
17. XID Wraparound Prevention
18. WAL Management & Archiving
19. Checkpoint Tuning
20. Lock Management & Deadlocks
21. Bloat Management
22. Backup Validation & Testing
23. Capacity Planning
24. Zero-Downtime Migrations
25. Production Best Practices & Runbooks

---

## TOPIC 6: SampleBank Project (450 pages, 25 modules)

### Module Structure (18 pages each)

CODE ANALYSIS BASED - Requires your actual SampleBank code!

- **theory/01-concept.md**: 6 pages - Architecture from actual code
- **theory/02-implementation-analysis.md**: 3 pages - Code walkthrough
- **theory/03-failure-cases.md**: 2 pages - Potential failures in this code
- **theory/04-takeaways.md**: 1 page - Key patterns from code
- **lab/lab-guide-cloud.md**: 2 pages - Deploy this module to AWS
- **lab/lab-guide-onprem.md**: 2 pages - Deploy locally with Docker
- **lab/code-walkthrough.md**: 1 page - Detailed code review
- **assessment/hands-on-project.md**: 1 page - Extend this module

### Module Prompt Template (CODE ANALYSIS)

```
I'm creating SampleBank PostgreSQL project documentation.

**CRITICAL**: I have actual SampleBank code at `/path/to/samplebank/module-[N]/`

Analyze the ACTUAL code and create Module [N]: [TOPIC] documentation.

Target: 18 pages
Focus: Code-driven, not generic

**STEP 1: Code Analysis**

Examine:
- /path/to/module-[N]/schema/*.sql
- /path/to/module-[N]/scripts/*.py or *.sh
- /path/to/module-[N]/config/*

Identify actual tables, functions, scripts, patterns used.

**STEP 2: Generate Documentation**

**theory/01-concept.md** (6 pages):
Based on ACTUAL code:
- Architecture of this module (from code structure)
- Database objects created (exact DDL from files)
- Design decisions evident in code
Include code snippets from actual files with file:line references

**theory/02-implementation-analysis.md** (3 pages):
- Key files and their purposes
- Step-by-step code explanation
- Why specific approaches chosen
Line-by-line breakdown of critical sections

**theory/03-failure-cases.md** (2 pages):
- Potential failure points in THIS implementation
- What happens if X fails (based on error handling)
- How to fix/improve

**theory/04-takeaways.md** (1 page):
- Key patterns from this module
- Code snippets worth remembering

**lab/lab-guide-cloud.md** (2 pages):
Deploy this module to AWS RDS:
1. Use provided Terraform
2. Test the actual scripts
3. Verify implementation

**lab/lab-guide-onprem.md** (2 pages):
Same with Docker locally

**lab/code-walkthrough.md** (1 page):
File-by-file explanation with actual file names

**assessment/hands-on-project.md** (1 page):
Extend Module [N] with [FEATURE]
Based on actual code structure

**CRITICAL**:
- Reference ACTUAL file names, line numbers
- Use real table/column names from schema
- Include actual error messages from testing
- No generic placeholders

Example:
✅ "In schema/create_tables.sql line 47, the users table..."
❌ "A typical table might..."
```

### Module List (25 modules)

**Modules 1-10**: Foundation
1. Project Setup & Architecture
2. Database Schema Design
3. User Management System
4. Account Management
5. Transaction Processing
6. Security & Audit Logging
7. Data Validation & Constraints
8. Stored Procedures & Functions
9. Reports & Analytics Queries
10. Backup Strategy Implementation

**Modules 11-20**: Core Operations
11. Monitoring & Alerting Setup
12. Performance Optimization
13. Replication Configuration
14. Connection Pooling
15. Error Handling & Recovery
16. Deployment Pipeline
17. Advanced Partitioning
18. Logical Replication for Analytics
19. Zero-Downtime Migration Practice
20. Custom Monitoring Dashboards

**Modules 21-25**: Advanced Topics
21. Disaster Recovery Testing
22. Load Testing & Benchmarking
23. Security Hardening
24. Capacity Planning
25. Automation Scripts Library & Runbooks

---

## Daily Workflow

### Morning (3-4 hours)
1. Open topic folder in VS Code
2. Copy prompts for 2-3 chapters/modules
3. Generate content using VS Code AI
4. Initial review

### Afternoon (3-4 hours)
1. Test all code examples
2. Refine content
3. Validate page counts (±10% acceptable)
4. Complete assessments

---

## Page Count Validation

```bash
# Quick check (rough estimate: 300-400 words/page)
wc -w Module-XX/theory/*.md Module-XX/lab/*.md

# Target ranges:
# - Python chapters: 6,000-8,000 words (25 pages)
# - PostgreSQL modules: 4,800-6,400 words (20 pages)
# - SampleBank modules: 4,320-5,760 words (18 pages)
```

---

## Tips for Balanced Content

1. **No padding** - Every page must be valuable
2. **Focus on depth** - Better deep on fewer topics than shallow on many
3. **Code quality** - All examples must work
4. **Real scenarios** - Use production examples, not made-up ones
5. **Consistent format** - Same structure across all modules

---

## 10-12 Day Timeline

**Days 1-2**: Python (150p)  
**Day 3**: Linux (100p)  
**Day 4**: AWS (150p)  
**Day 5**: Terraform/Docker/K8s (120p)  
**Days 6-9**: PostgreSQL (500p)  
**Days 10-12**: SampleBank (450p)

**Average**: ~120-145 pages/day  
**Realistic with AI assistance!**

---

This balanced structure gives you production-ready content without overwhelming scope! 🚀
