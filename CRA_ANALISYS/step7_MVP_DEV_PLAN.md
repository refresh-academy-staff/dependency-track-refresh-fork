# CRA Phase-1 MVP — Iterative Development Plan

**Source of truth:** `req_analysis.md` (Fase 1 MVP — "actively-exploited vulnerability notification", in force 11 Sep 2026).
**Supersedes:** `step5_DEVELOPMENT_PLAN.md` (that plan targeted a broader scope — B2B customer notification, patch campaigns, installed base, CVD inbound — all **explicitly excluded** by `req_analysis.md §4`, and assumed a standalone Spring Boot backend instead of an extension of Dependency-Track).

---

## 0. Architecture decisions (locked)

| Decision | Choice | Consequence |
|----------|--------|-------------|
| Build relative to DT | **Hybrid** | DT does ingestion / scan / findings / triage / VEX / notify / auth. A thin **CRA companion module** holds only net-new workflow (Product/Release catalog, SRP reporting + SLA, severe incidents, global CVE view, staleness alert, audit/syslog, cross-release triage persistence). Companion reads DT over its REST API + API key. |
| Triage / VEX | **DT-native, mapped to CRA** | Triage = DT `Analysis` (`state`, `justification`, `details`, `AnalysisComment`, suppression). CycloneDX/CRA enums (RF-5-3/5-4) enforced at the **VEX export boundary**, not by a parallel entity. RF-10 uses DT `Finding` history. |
| Internal notifications | **DT-native publishers** (email / Slack / webhook) | Use DT `NotificationRule` + publisher engine. No Sentry dependency (diverges from `req_analysis §5` — see Open Decisions). |
| BDD test suite | **Standalone black-box project** | Separate Maven module `cra-bdd/` runs `.feature` files over **HTTP only** against a `docker-compose` stack (DT + companion + Postgres + MailHog) brought up via Testcontainers. Happy + key sad paths live here; the bulk of sad paths live as **in-process unit/integration tests** inside the companion. |

### What DT already gives us for free (verified in the fork)

| Requirement | DT-native asset |
|---|---|
| RF-1-1 OIDC/LDAP, RF-1-2 RBAC | Alpine `alpine-server` OIDC + LDAP + Teams/Permissions |
| RF-3 SBOM/HBOM (CycloneDX) | Native CycloneDX BOM upload (`BomResource`, `BomUploadProcessingTask`). HBOM = CycloneDX with `classifier=device/firmware` components — same pipeline. |
| RF-4-1 vuln DB sync | `NistMirrorTask` / `NistApiMirrorTask` (NVD), OSV, GitHub Advisory, `EpssMirrorTask` |
| RF-4-3/4/5/7 scan | `VulnerabilityAnalysisTask`, auto-trigger on BOM upload, `NewVulnerableDependencyAnalysisTask`, manual re-analyze |
| RF-4-6 finding history | `Finding` + `Analysis` persisted per project |
| RF-5-2/5/6 triage | `Analysis`, `AnalysisComment`, `details`, suppression |
| RF-5 VEX export | `VexResource` (CycloneDX VEX out) |
| RF-7 internal notify | `NotificationRule` + publishers (email/Slack/Teams/webhook) |
| RF-12-1 NVD key | DT admin config |

### What must be built (the CRA delta)

| Requirement | Built where | Note |
|---|---|---|
| RF-2 Product/Release catalog, CPE/PURL map, CSV import, market/EoS dates | Companion | Each Release ↔ one DT project+version. |
| RF-1-3 ownership, RF-1-4 per-product email list | Companion | Maps owners → DT teams; email list stored companion-side. |
| RF-4-2 **CISA KEV** + **EUVD** mirror & flag | Companion | **Not native** — confirmed absent in fork. Mirror catalog, join by CVE. |
| RF-5-3/5-4 CycloneDX/CRA enum enforcement | Companion (export boundary) | Map DT states → VEX enums; constrain justifications. |
| RF-6 SRP report + approval + SMTP send + SLA 24h/72h/14d | Companion | Core CRA Art.14 obligation. |
| RF-7-1 internal notify threshold | Companion config → DT rule | Global severity threshold gate. |
| RF-8 granular audit, soft-delete, syslog JSON | Companion (+ DT logback) | Append-only audit table; logstash-logback-encoder → SyslogAppender. |
| RF-9 staleness check + admin alert + UI banner | Companion | Reads DT mirror status; banner via companion API. |
| RF-10 cross-release triage persistence | Companion | Don't re-notify a finding fixed on a newer release. |
| RF-11 global CVE view | Companion | Aggregate DT findings across all projects by CVE. |
| RF-13 severe incidents intake + SLA | Companion | Manual entry + 24h/72h timer. |

---

## 1. Method

- **Iterative & incremental:** each increment below is a **vertical slice** — DB → companion service → REST → (Vue UI where applicable) → BDD `.feature` — that is demoable and shippable on its own.
- **Test-first per slice (S3 + TDD):** write the slice's `.feature` (red, black-box) and the companion unit/integration tests first; implement to green; never break a previously-green `.feature`.
- **Definition of Done (every slice):** see §5.
- **Slice size target:** 1–3 days of work; split further if a scenario list grows past ~10.

### BDD conventions

- `.feature` files: `cra-bdd/src/test/resources/features/<area>/<slice>.feature`, Gherkin, `@tag` per RF (`@RF-6-3`) and per CRA article (`@CRA-Art14`).
- Each feature file: **1 happy path per primary action + the sad paths that are observable over HTTP** (validation 4xx, auth 401/403, conflict 409, workflow guard violations). Sad paths needing white-box visibility (retry/backoff, scheduler edges, DB constraint races) → companion JUnit integration tests, referenced by ID in the feature file header comment.
- Step defs talk to the stack via RestAssured only. Fixtures seeded through public APIs (no DB reach-in) so the suite stays black-box.

---

## 2. Increment roadmap

> Ordering rule: each increment depends only on earlier ones. Phase 0 is the walking skeleton; increments 1→N each add one shippable CRA capability.

### Phase 0 — Walking skeleton & harness  `@infra`
**Goal:** stack boots, companion authenticates to DT, one trivial end-to-end `.feature` is green.
- `docker-compose`: DT API + DT frontend + Postgres + companion + MailHog. Healthchecks.
- Companion scaffold: chosen JVM stack, Flyway, `cra` schema separate from DT, JSON structured logging.
- **Auth bridge** (RF-1): companion trusts DT-issued JWT / shared OIDC; RBAC role map (Security Analyst, Developer, System Administrator) → permissions. *(See Open Decision D1.)*
- `DependencyTrackClient`: API-key auth, typed errors, retry+backoff (WireMock unit tests).
- `cra-bdd/` module: Testcontainers brings the compose stack up; `health.feature` (happy: stack healthy; sad: companion returns 503 when DT unreachable).
- **BDD:** `infra/health.feature`. **Unit:** client retry/backoff, error mapping.

### Increment 1 — Product & Release catalog  `@RF-2` `@CRA-Art13.8`
**Goal:** CRUD products + releases, each Release auto-mapped to a DT project+version.
- Entities `Product` (name, internal_id, family, CPE, PURL), `Release` (version, market_date, support_end_date, dt_project_id).
- `DtSyncService`: create/fetch DT project+version on Release create (idempotent).
- **BDD:** `catalog/product_crud.feature`, `catalog/release_crud.feature`.
  - Happy: create product → 201 + id; create release → 201 + non-null `dt_project_id`; DT project exists.
  - Sad (HTTP): duplicate internal_id → 409; missing required field → 422; `support_end_date < market_date` → 422; read-only role POST → 403; unauthenticated → 401.
- **Unit/integration (sad):** DT sync idempotency, DT-down during create → release persisted in `pending_sync`, retried.

### Increment 2 — Identifier mapping & CSV import  `@RF-2-2` `@RF-2-3`
**Goal:** map internal IDs ↔ CPE/PURL; bulk import from CSV.
- `POST /products/import` (CSV multipart).
- **BDD:** `catalog/identifier_csv_import.feature`.
  - Happy: valid CSV (3 rows) → 200, 3 products mapped.
  - Sad (HTTP): malformed CSV → 422 with row-level error list; partial (row 2 bad) → 207/422 atomic-reject with line numbers; non-CSV mimetype → 415; oversize → 413.
- **Unit:** parser edge cases (quoting, BOM, empty PURL+CPE both null → reject).

### Increment 3 — SBOM/HBOM ingestion wrapper  `@RF-3` `@CRA-AnnexI.II.1`
**Goal:** upload SBOM/HBOM to a Release; DT processes async; metadata (uploader, timestamp, hash) recorded; scan auto-starts.
- `POST /releases/{id}/bom` → forwards to DT `uploadBom`; record `BomUpload` (sha256, user, ts, kind SBOM|HBOM).
- HBOM = CycloneDX; same path, `kind=HBOM`. *(See Open Decision D2 — third-party HBOM.)*
- **BDD:** `sbom/upload.feature`.
  - Happy: upload CycloneDX → 202; metadata GET shows uploader+hash; DT components appear after processing (poll).
  - Sad (HTTP): non-CycloneDX/invalid schema → 422; missing PURL **and** CPE on a component → 422 with component list (warning-only when `is_internal`); upload to frozen/unknown release → 404/409; Developer role required → 403 for others.
- **Unit:** sha256, kind detection, async status polling, DT 5xx during forward → upload `failed` + retry.

### Increment 4 — KEV & EUVD enrichment  `@RF-4-2` `@CRA-Art14.1`
**Goal:** mirror CISA KEV + EUVD; flag findings that match.
- Scheduled `KevMirrorTask` (CISA KEV JSON), `EuvdMirrorTask`. Tables `kev_entry`, `euvd_entry` keyed by CVE.
- Enrichment join: a DT finding whose CVE ∈ KEV/EUVD → `is_kev` / `is_euvd` true.
- **BDD:** `intel/kev_enrichment.feature`.
  - Happy: after sync, finding on a KEV CVE (e.g. CVE-2021-44228) is flagged `is_kev=true`.
  - Sad (HTTP): query enrichment before first sync → flags `unknown` + staleness warning.
- **Unit:** KEV/EUVD parser, mirror failure → previous catalog retained + admin alert (ties to Inc. 10), CVE normalization/alias.

### Increment 5 — Findings view & triage pass-through  `@RF-5-1` `@RF-5-2` `@RF-5-5` `@RF-5-6`
**Goal:** list findings per Release; perform triage (state + justification + technical notes + internal comments) via companion → DT Analysis.
- Read-through to DT findings; `POST /findings/{id}/analysis` → DT `UpdateAnalysis`; comments → DT `AnalysisComment`.
- **BDD:** `triage/triage_findings.feature`.
  - Happy: list findings; set state `not_affected` + justification + note → reflected in DT; add comment → visible.
  - Sad (HTTP): invalid state value → 422; analyst without project access → 403; comment with empty body → 422; triage on non-existent finding → 404.
- **Unit:** state mapping table, optional-note rule (RF-5-5).

### Increment 6 — VEX export with CRA enum enforcement  `@RF-5-3` `@RF-5-4` `@CRA-AnnexI.II.4`
**Goal:** export CycloneDX VEX for a Release using only standard states + CRA/CycloneDX justifications.
- `GET /releases/{id}/vex` → companion validates DT analysis states/justifications against the allowed CycloneDX/CRA enum set, then emits via DT `VexResource` (or builds VEX from findings).
- **BDD:** `vex/vex_export.feature`.
  - Happy: release with triaged findings → VEX file; states ∈ {affected, not_affected, fixed, under_investigation}; justifications ∈ CRA set.
  - Sad (HTTP): release with a finding triaged to a non-CycloneDX state → 409 "non-exportable state" listing offenders; VEX for release with zero findings → 200 empty VEX; unauthorized → 403.
- **Unit:** enum mapping completeness (DT↔CycloneDX), justification whitelist (component_not_present, vulnerable_code_not_in_execute_path, vulnerable_code_cannot_be_controlled_by_adversary).

### Increment 7 — Global CVE view  `@RF-11`
**Goal:** portfolio-wide list of all CVEs across all Releases, per-CVE detail with affected products/releases and per-release VEX state.
- Aggregation over DT findings grouped by CVE.
- **BDD:** `view/global_cve.feature`.
  - Happy: list distinct CVEs; CVE detail → all affected releases + each release's VEX state.
  - Sad (HTTP): unknown CVE → 404; viewer sees only releases in their accessible teams (RBAC scoping); empty portfolio → empty list.
- **Unit:** grouping/dedup by CVE+alias, RBAC scoping filter.

### Increment 8 — Cross-release triage persistence  `@RF-10` `@CRA-Art13.8`
**Goal:** a finding marked resolved/fixed on a newer release must not re-notify the product owner on each periodic scan.
- On scan completion, suppress notification when same (component,CVE) is `fixed`/`resolved` on a release ≥ current. Persist decision so it survives re-scan.
- **BDD:** `triage/persistence.feature`.
  - Happy: mark CVE fixed on v2; re-scan v1 → no new owner notification for that CVE; finding still listed (not hidden, just not re-notified).
  - Sad (integration, referenced): two concurrent scans → single suppression record (idempotent); new *different* CVE still notifies.
- **Unit:** suppression key, version-ordering comparator, notify-gate logic.

### Increment 9 — Internal vulnerability notifications  `@RF-7`
**Goal:** auto-notify product owners (user/group + per-product email list) when a finding crosses a global severity threshold.
- Global threshold config; on `NewVulnerableDependency`, if severity ≥ threshold and not suppressed (Inc. 8) → DT notification rule fires to owner team + per-product email list (RF-1-3/1-4).
- **BDD:** `notify/internal_vuln.feature`.
  - Happy: finding ≥ threshold on owned product → owner email received (MailHog assert).
  - Sad (HTTP/integration): below threshold → no email; product with no owner → admin fallback alert; threshold mis-set (e.g. invalid) → 422.
- **Unit:** threshold gate, owner resolution, suppression interaction.

### Increment 10 — Platform monitoring, staleness banner & admin alerts  `@RF-9` `@req§13-alert`
**Goal:** detect stale vuln/KEV DB (>24h) and platform malfunction; warn in UI; alert System Administrator.
- Companion polls DT mirror status + own KEV/EUVD task status; `GET /status` exposes freshness; banner data for UI; admin alert on stale/failure.
- **BDD:** `ops/staleness_and_alerts.feature`.
  - Happy: all sources <24h → status OK, no banner.
  - Sad (HTTP): simulate KEV sync age >24h → status `stale` + banner flag true + admin alert dispatched; DT unreachable → status `degraded` + admin alert.
- **Unit:** freshness math (24h boundary), alert de-dup (don't spam), recovery clears banner.

### Increment 11 — SRP report: build & approval workflow  `@RF-6-3` `@CRA-Art14.1`
**Goal:** Security Analyst assembles an SRP report for a KEV/EUVD finding and approves it before send.
- `SrpReport` entity (finding ref, payload, status draft→pending_approval→approved→sent). Structured payload (component PURL/version/hash, CVSS, CVE, affected releases, mitigation).
- `POST /srp-reports` (draft), `/submit`, `/approve`, `/reject`.
- **BDD:** `srp/srp_workflow.feature`.
  - Happy: draft from a KEV finding → preview → submit → approve → status `approved`.
  - Sad (HTTP): approve without submit → 409; non-Analyst approve → 403; edit after approval → 409; draft for non-KEV/non-EUVD finding → allowed but flagged (per RF-6 scope) / or 422 per policy *(see D3)*.
- **Unit:** state machine guards, payload completeness validation.

### Increment 12 — SRP SLA countdown timers  `@RF-6-1` `@RF-6-2` `@CRA-Art14.2`
**Goal:** per KEV/EUVD finding (and severe incident, Inc. 13) show 24h / 72h / 14d countdowns in the dashboard.
- Compute due times from detection; expose remaining; scheduled checker drives "approaching"/"overdue" admin/analyst alerts.
- **BDD:** `srp/sla_timers.feature`.
  - Happy: KEV finding detected → 3 countdowns present and decreasing.
  - Sad (HTTP/integration): clock past 24h with no early-warning sent → `overdue` flag + alert; severe-incident timer mirrors 24h/72h.
- **Unit:** due-time math, transition approaching→overdue, timezone/UTC correctness.

### Increment 13 — SRP transmission (SMTP) + Severe Incidents  `@RF-6-4` `@RF-13`
**Goal:** send the approved SRP report via SMTP (SRP simulation); manual severe-incident intake with its own SLA.
- `POST /srp-reports/{id}/send` (only if `approved`) → SMTP to configured SRP address (MailHog in test). Record `sent_at`, recipient, payload hash (immutable).
- `SevereIncident` intake form + 24h/72h timers (reuses Inc. 12).
- **BDD:** `srp/srp_send.feature`, `incidents/severe_incident.feature`.
  - Happy: approved report → send → email captured in MailHog with structured payload; status `sent`.
  - Sad (HTTP): send unapproved → 409; SMTP down → status `send_failed` + retry + admin alert; re-send already-sent → 409 (idempotent).
  - Severe incident happy: create → 201 + 24h/72h timers; sad: missing mandatory fields → 422.
- **Unit:** SMTP adapter (Nullable), payload hashing, retry policy.

### Increment 14 — Granular audit trail, soft-delete & syslog export  `@RF-8`
**Goal:** append-only audit of writes (Products, Releases, BOMs, triage/VEX decisions, comments) + security events (login/logout/upload); soft-delete; structured JSON logs → syslog.
- Append-only `audit_log` (DB rule blocks UPDATE/DELETE). `@Auditable` interception on write paths. Soft-delete flags. logstash-logback-encoder JSON → `SyslogAppender` (DT logback + companion).
- **BDD:** `audit/audit_trail.feature`.
  - Happy: create product → audit record with actor+before/after; login → security event logged; deleted release → soft-deleted (still queryable as inactive).
  - Sad (HTTP/integration): attempt to mutate audit row → DB error / 403; export audit without CISO/Admin role → 403.
- **Unit:** append-only enforcement, field-level diff capture, JSON log schema, syslog appender wiring.

### Increment 15 — Hardening, E2E gold path & go-live  `@infra`
**Goal:** full CRA happy-path E2E green; security & RBAC matrix; deploy docs.
- **BDD (gold path):** `e2e/cra_golden_path.feature` —
  product+release → SBOM upload → scan → KEV-flagged finding → triage + VEX → SRP draft→approve→send (MailHog) → SLA satisfied → audit trail complete.
- RBAC matrix tests (parametrized): each role × each endpoint → allowed/denied.
- `docker-compose.prod.yml`, runbook, backup/restore, go-live checklist (NVD key, SMTP/SRP addr, OIDC, schedules).

---

## 3. RF → Increment → CRA traceability

| RF | Increment(s) | CRA mapping |
|----|--------------|-------------|
| RF-1 (IAM, ownership, email list) | P0, 1, 9 | Art.13.8 (governance) |
| RF-2 (product inventory, CPE/PURL, CSV) | 1, 2 | Art.13.8, Annex I.II.1 |
| RF-3 (SBOM/HBOM) | 3 | Annex I.II.1 |
| RF-4 (scan, mirror, KEV) | P0(DT), 3, 4 | Art.14.1, Annex I.II.1 |
| RF-5 (triage, VEX, enums) | 5, 6 | Annex I.II.4 |
| RF-6 (SRP semi-auto) | 11, 12, 13 | Art.14.1, Art.14.2.a/b, Art.14.2.c |
| RF-7 (internal notify) | 9 | Art.13.8 |
| RF-8 (audit, soft-delete, syslog) | 14 | Art.13.8 (governance evidence) |
| RF-9 (monitoring/banner) | 10 | operational |
| RF-10 (triage persistence) | 8 | Art.13.8 |
| RF-11 (global CVE view) | 7 | Art.14.1 (situational awareness) |
| RF-12 (NVD key) | P0 (DT config) | — |
| RF-13 (severe incidents) | 12, 13 | Art.14.2.c |

Every RF lands in at least one increment; every increment carries `@RF-*` and `@CRA-*` tags so the BDD report doubles as a compliance coverage matrix.

---

## 4. BDD feature-file inventory

```
cra-bdd/src/test/resources/features/
  infra/health.feature
  catalog/product_crud.feature
  catalog/release_crud.feature
  catalog/identifier_csv_import.feature
  sbom/upload.feature
  intel/kev_enrichment.feature
  triage/triage_findings.feature
  triage/persistence.feature
  vex/vex_export.feature
  view/global_cve.feature
  notify/internal_vuln.feature
  ops/staleness_and_alerts.feature
  srp/srp_workflow.feature
  srp/sla_timers.feature
  srp/srp_send.feature
  incidents/severe_incident.feature
  audit/audit_trail.feature
  e2e/cra_golden_path.feature
```

Sad-path division of labour:
- **In `.feature` (black-box, HTTP-observable):** validation (422), auth (401/403), not-found (404), conflict/workflow-guard (409), payload (413/415).
- **In companion JUnit (white-box):** retry/backoff, scheduler/timer boundaries, DB constraint & concurrency races, append-only enforcement, SMTP/DT outage recovery, idempotency under concurrent scans. Each `.feature` names the JUnit class covering its non-HTTP sad paths in a header comment.

---

## 5. Definition of Done (per increment)

- [ ] Slice's `.feature` (happy + HTTP sad paths) green in `cra-bdd`.
- [ ] Companion unit + integration tests green; white-box sad paths covered; service-layer coverage ≥ 80%.
- [ ] No previously-green `.feature` broken.
- [ ] OpenAPI/Swagger updated for new endpoints.
- [ ] Audit trail emitted for every new write path (from Inc. 14 onward; earlier slices leave `@Auditable` hooks).
- [ ] RBAC enforced + asserted for every new endpoint.
- [ ] `@RF-*` / `@CRA-*` tags present on the new scenarios.

---

## 6. Open decisions / assumptions to confirm

- **D1 — Auth bridge.** Does the companion validate DT-issued JWTs, or stand behind the same OIDC IdP independently? (Affects P0.) `req §5` says "JWT base"; DT+Alpine already issue JWTs → leaning *companion trusts DT JWT*.
- **D2 — Third-party HBOM.** `req §6` open question: third-party/supplier HBOMs not in CycloneDX. Assumption: Phase-1 accepts CycloneDX HBOM only; non-CycloneDX is out of scope (manual conversion).
- **D3 — SRP demo channel.** `req §6` open question: no official SRP spec yet. Assumption: SMTP to a configured address (MailHog in test) as the "SRP simulation" per RF-6-4. Confirm recipient/format.
- **D4 — Sentry.** `req §5` names Sentry for internal notifications; we chose DT-native publishers. Confirm this divergence is acceptable, or add a Sentry publisher in Inc. 9/10.
- **D5 — EUVD source.** EUVD feed format/endpoint not yet stable; KEV is the firm one. EUVD mirror (Inc. 4) may ship as best-effort.

---

## 7. Sequencing summary

```
P0  skeleton + auth + DT client + BDD harness        (foundation)
 1  product/release catalog ──┐
 2  identifier map + CSV       │ ingestion spine
 3  SBOM/HBOM upload ──────────┘
 4  KEV/EUVD enrichment
 5  findings + triage ─────────┐
 6  VEX export                 │ triage/VEX
 7  global CVE view            │
 8  cross-release persistence ─┘
 9  internal notifications
10  monitoring + staleness
11  SRP build + approval ──────┐
12  SLA timers                 │ SRP / Art.14
13  SRP send (SMTP) + incidents┘
14  audit + soft-delete + syslog
15  hardening + golden-path E2E + go-live
```

Each row is independently demoable. Cut line for a thinnest-viable CRA demo: **P0 → 1 → 3 → 4 → 5 → 6 → 11 → 12 → 13** (catalog → SBOM → KEV → triage/VEX → SRP notify with SLA). Increments 2, 7, 8, 9, 10, 14 harden and complete; 15 ships.
```
