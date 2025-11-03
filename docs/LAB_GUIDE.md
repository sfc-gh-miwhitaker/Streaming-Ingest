# RFID Streaming Lab: Customer & Partner Playbook

## Why This Lab Matters

You are advising a property-security team that needs real-time badge telemetry without standing up intermediate services. This lab walks both the **customer** (security & data engineering) and their **integration partner** through Snowflake’s native streaming pattern that just reached General Availability (GA, September 2025). The deliverable is a ready-to-run pipeline plus a blueprint the partner can replicate at each site.

- **Storyline**: Simulated RFID vendors push badge scans directly into Snowflake via Snowpipe Streaming REST endpoints. Streams + Tasks materialize curated analytics within minutes, powering dashboards and alerting.
- **Outcome**: Customer can demonstrate end-to-end flow, align ownership, and provide repeatable instructions to partners—even if they cannot run the full lab in real time.

## At-a-Glance Roles

| Phase | Customer Team Owns | Partner Owns |
|-------|--------------------|--------------|
| 0. Success Alignment | Define access outcomes, SLAs, data retention, tagging | Share deployment constraints, badge schema |
| 1. Foundation | Execute numbered SQL scripts (`sql/setup`) | N/A |
| 2. Vendor Integration | Issue Snowflake credentials, configure Snowpipe Streaming pipe | Plug readers into provided REST endpoint, map fields |
| 3. Validation & QA | Run data-quality checks (`sql/data_quality`) | Provide sample payloads, confirm data governance |
| 4. Monitoring & Dashboards | Create Snowsight worksheets or BI dashboards | Confirm operational KPIs |
| 5. Scale Out | Define partner onboarding checklist | Reuse automation for each location |

## Phase 0 – Success Criteria & Field Mapping (15 minutes)

1. **Define what “good” looks like**
   - Latency target: <10 seconds from scan to analytics view.
   - Compliance: ensure key tags (`owner`, `cost_center`, `environment`) are captured for cost attribution.
2. **Map vendor payload to canonical schema**
   - Start with `python/shared/models.py::BadgeEvent` and list the fields your vendor actually sends.
   - If a field differs (e.g., `door_id` vs `reader_id`), document the mapping and note any optional attributes.
3. **Document onboarding packet**
   - Include REST endpoint template, authentication steps, expected JSON structure, and example curl command.

## Phase 1 – Deploy the Snowflake Foundation (30 minutes)

1. Run the numbered scripts in `sql/setup/` (01 → 08). Each script follows Snowflake-recommended performance patterns: sargable predicates, QUALIFY-based deduplication, and the STREAM + TASK CDC flow.
2. GA Streaming update to share with customers:
   - **Serverless ingestion**: Snowpipe Streaming REST API (GA Sep 2025) eliminates the middle tier and supports up to 10 GB/s per table.
   - **Continuation tokens** prevent data loss on reconnect.
   - **Result cache aware** tasks process only new data via `SYSTEM$STREAM_HAS_DATA`.
3. Confirm objects with `SHOW STREAMS`, `SHOW TASKS`, and tag warehouses using the mandatory tags described in `RULES_AUDIT.md`.

## Phase 2 – Configure Authentication & Pipes (20 minutes)

1. Customer creates service principal / key pair following `config/jwt_keypair_setup.md`.
2. Populate `config/.env` from the template.
3. Review `sql/setup/03_pipe_object.sql`. If vendor fields differ:
   - Adjust the `SELECT` clause casting logic (e.g., `COALESCE($1:signal_strength)`).
   - Maintain sargable predicates—transform literals, not columns.
4. For multiple partners, create additional pipes and channels following the naming convention `BADGE_EVENTS_PIPE__<partner>`.

**Key Management Best Practices (share with security teams):**
- Issue **one Snowflake service user + RSA key pair per partner and per environment**; never reuse prod keys elsewhere.
- Generate encrypted private keys (`openssl genrsa -aes256 ...`) and store them in a managed secrets vault (Vault, AWS Secrets Manager, Azure Key Vault).
- Grant the minimal Snowflake role permissions (OPERATE/MONITOR on the pipe) and rotate keys every 90–180 days; the `config/jwt_keypair_setup.md` guide includes rotation steps.
- Automate onboarding so the customer retains control: customer provisions the Snowflake user and uploads the partner’s public key; partner only receives the channel URL and required role.

## Phase 3 – Run the Simulator or Vendor Traffic (Optional 20 minutes)

1. Install Python dependencies: `pip install -r python/requirements.txt` inside a virtual environment.
2. Launch simulator with aligned parameters:
   ```bash
   python -m python.rfid_simulator.simulator --duration-days 1 --events-per-second 200
   ```
3. Validate ingestion health:
   - `scripts/check_channel_status.sh`
   - Snowsight query: `SELECT * FROM V_INGESTION_METRICS ORDER BY event_hour DESC LIMIT 20;`
4. Partner delivers real payloads using `scripts/post_events.sh` as a template.

## Phase 4 – Real-Time Dashboards & Alerting (30 minutes)

1. **Snowsight Live Worksheet** (Customer)
   - Query `ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS` and build charts for occupancy, after-hours access, and weak signal rates.
   - The GA streaming update ensures new records materialize within a minute, so charts refresh without ETL windows.
2. **Operational Metrics**
   - Use the bundled monitoring views: `V_END_TO_END_LATENCY`, `V_PARTITION_EFFICIENCY`, `V_STREAMING_COSTS`.
   - Optional: connect to external BI (Tableau, Power BI) with live connection; ensure warehouse `BI_WH` uses multi-cluster auto-scale.
3. **Alerting Hooks**
   - Leverage tasks to populate alert tables or call Cortex functions for anomaly detection (future enhancement).

## Phase 5 – Scale with Additional Partners

1. **Clone and Customize**
   - Use zero-copy clones (`CREATE SCHEMA PARTNER_A_STG CLONE STAGE_BADGE_TRACKING;`) for testing partner-specific logic.
2. **Channel Strategy**
   - Assign dedicated streaming channels per partner to isolate throughput and simplify troubleshooting.
   - Increase `MAX_CLIENT_LAG` for partners with bursty traffic to keep micro-partitions efficient.
3. **Cost and Governance**
   - Attach each partner’s warehouses to dedicated resource monitors.
   - Require tagging at creation; automate via Terraform or Snowflake CLI.
4. **Field Divergence**
   - Document transformations in `help/DATA_DICTIONARY.md` and add partner-specific views (`V_PARTNER_A_EVENTS`) to abstract differences.

## Executive Summary (Shareable Slide Text)

- Snowflake’s GA Snowpipe Streaming REST API ingests badge scans directly—no middleware—achieving <10 second latency.
- Streams + Tasks pattern keeps compute off until changes arrive, minimizing spend while meeting real-time SLAs.
- Built-in monitoring views plus Snowsight charts deliver live dashboards for security and facilities teams.
- Lab artifacts double as partner onboarding kit: field mappings, simulator, automation scripts, and scaling playbook.
- Extensible: add partners by cloning schemas, creating new pipes/channels, and reusing the governance model.

## Suggested Customer Communication Packet

1. **One-page overview** (use the Executive Summary).
2. **Implementation checklist** (Phases 0–5 table).
3. **Partner-ready instructions** (Phase 2 and Phase 3 subsections).
4. **Dashboard screenshots** (capture from Snowsight or BI tool once data flows).

This balanced format allows a busy customer to read the narrative in under 10 minutes while giving hands-on teams everything they need to finish the lab quickly—or delegate to partners with confidence.

