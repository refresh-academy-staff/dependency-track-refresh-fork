# CRA Gap Analysis: Dependency-Track v4.14 vs EU Regulation 2024/2847 (Cyber Resilience Act)

**Regulation:** REGULATION (EU) 2024/2847 OF THE EUROPEAN PARLIAMENT AND OF THE COUNCIL of 23 October 2024  
**Full title:** Horizontal cybersecurity requirements for products with digital elements (Cyber Resilience Act — CRA)  
**Published:** Official Journal of the EU, L series 2024/2847, 20.11.2024  
**Baseline spec:** `dependency-track.allium` (distilled from DT v4.14.0)

---

## How to read this document

Dependency-Track is a software supply chain intelligence platform used by **manufacturers** of products with digital elements to fulfil their CRA obligations. The gaps below are grouped into two categories:

- **Gaps where DT is the implementation vehicle** — DT needs new features so that its users (manufacturers) can satisfy CRA obligations using the platform.
- **Gaps in DT's own CRA posture** — DT is itself a product with digital elements; its own compliance matters separately.

Both categories are covered here. Each gap section includes:
1. **The CRA requirement** — exact article/annex citation
2. **Current DT state** — what exists today
3. **The gap** — what is missing or insufficient
4. **Implementation approach** — specific, concrete steps to address it

---

## GAP 1 — Support Period Tracking

### CRA requirement

**Article 13(8):** Manufacturers shall ensure that vulnerabilities are handled effectively for the entire **support period**. The support period shall be at least **five years** (or the expected use time if shorter). Manufacturers shall document the rationale for the chosen support period.

**Article 13(9):** Each security update shall remain available for a minimum of **10 years** or the remainder of the support period, whichever is longer.

**Article 13(19):** The end date of the support period, **including at least month and year**, shall be clearly specified at the time of purchase and displayed on the product or its packaging. Where technically feasible, manufacturers shall notify users when the product reaches end of support.

**Annex VII(4):** Technical documentation must include the information used to determine the support period.

### Current DT state

The `Project` entity has:
- `name`, `version`, `is_latest`, `is_active` flags
- No date fields representing when the product was placed on the market
- No concept of a support period or its end date
- No end-of-support notification workflow

### The gap

Dependency-Track has no model for the product lifecycle as the CRA defines it. It cannot answer: "When does support for this product version end?" It cannot alert users or operators when a project is approaching or past its end-of-support date. It cannot enforce the 5-year minimum or surface the 10-year update retention requirement.

### Implementation approach

**Step 1 — Extend the `Project` entity with lifecycle fields:**

```java
// In model/Project.java — add:
@Persistent
@Column(name = "FIRST_MARKET_DATE", jdbcType = "TIMESTAMP", allowsNull = "true")
private Date firstMarketDate;           // when product was first placed on market

@Persistent
@Column(name = "SUPPORT_PERIOD_END_DATE", jdbcType = "TIMESTAMP", allowsNull = "true")
private Date supportPeriodEndDate;      // CRA minimum: firstMarketDate + 5 years

@Persistent
@Column(name = "SUPPORT_PERIOD_RATIONALE", jdbcType = "CLOB", allowsNull = "true")
private String supportPeriodRationale;  // Annex VII(4) documentation requirement
```

**Step 2 — Add a validation rule** that warns when `supportPeriodEndDate` is set to less than 5 years after `firstMarketDate`. This can live in `model/validation/` as a custom Bean Validation constraint.

**Step 3 — Add end-of-support lifecycle events.** Create two new events:
- `ProjectApproachingEndOfSupportEvent` — fired when `now > supportPeriodEndDate - 90 days`
- `ProjectEndOfSupportReachedEvent` — fired when `now >= supportPeriodEndDate`

Wire these into `TaskScheduler` as scheduled checks (daily). Each fires notifications via existing `NotificationRule` machinery — add two new `NotificationGroup` enum values: `PROJECT_APPROACHING_END_OF_SUPPORT` and `PROJECT_END_OF_SUPPORT_REACHED`.

**Step 4 — REST API extension.** Add lifecycle fields to `ProjectResource` GET/PUT. Add a new `GET /api/v1/project/{uuid}/lifecycle` endpoint returning lifecycle status in a CRA-structured JSON format.

**Step 5 — Upgrade migration.** Add a new class in `upgrade/v4140/` (or a new version folder) that back-fills `firstMarketDate = null` and `supportPeriodEndDate = null` for existing projects, and adds a UI warning to projects with null lifecycle dates.

**Step 6 — Allium spec update.** Extend `Project` entity with `first_market_date`, `support_period_end_date`, `support_period_rationale`. Add rules `WarnApproachingEndOfSupport` and `NotifyEndOfSupportReached`.

---

## GAP 2 — Actively Exploited Vulnerability Flagging (CISA KEV Integration)

### CRA requirement

**Article 14(1):** A manufacturer shall notify any **actively exploited vulnerability** simultaneously to the CSIRT designated as coordinator and ENISA, within:
- **24 hours**: early warning notification
- **72 hours**: full vulnerability notification
- **14 days** after corrective measure: final report

**Article 14(8):** After becoming aware of an actively exploited vulnerability, the manufacturer shall inform impacted users **in a structured, machine-readable format that is easily automatically processable**.

### Current DT state

DT tracks EPSS scores (`epssScore`, `epssPercentile`) which predict exploitation probability. It tracks severity (CRITICAL/HIGH/MEDIUM/LOW). It has no distinct "is actively exploited" flag on vulnerabilities.

EPSS is a probability score, not a confirmed exploitation status. The CRA specifically distinguishes "actively exploited" as a distinct trigger for the 24-hour reporting obligation — this corresponds to sources like the **CISA Known Exploited Vulnerabilities (KEV) catalog** or equivalent ENISA/CERT-level intelligence.

### The gap

DT has no:
- `is_actively_exploited` boolean field on `Vulnerability`
- Integration with CISA KEV or equivalent actively-exploited intelligence feeds
- 24h/72h/14-day reporting timeline tracking
- Mechanism to distinguish CRA-reportable from non-reportable vulnerability events

### Implementation approach

**Step 1 — Add `is_actively_exploited` flag to `Vulnerability`:**

```java
// In model/Vulnerability.java
@Persistent(defaultFetchGroup = "true")
@Column(name = "IS_ACTIVELY_EXPLOITED", allowsNull = "true")
private Boolean activelyExploited;

@Persistent(defaultFetchGroup = "true")
@Column(name = "ACTIVELY_EXPLOITED_SINCE", jdbcType = "TIMESTAMP", allowsNull = "true")
private Date activelyExploitedSince;    // when exploitation was first confirmed
```

**Step 2 — New KEV mirror task.** Create `tasks/CisaKevMirrorTask.java` implementing the existing `AbstractNistMirrorTask` pattern. The CISA KEV is a public JSON catalog at `https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json`. The task:
- Downloads the catalog on a configurable schedule (default: every 6 hours)
- For each KEV entry, looks up matching `Vulnerability` by `vulnId` (CVE ID)
- Sets `activelyExploited = true`, `activelyExploitedSince = dateAdded from KEV`
- Clears `activelyExploited` for vulns removed from the KEV (CRA does not require this but operationally useful)

Add `CisaKevMirrorEvent.java` and `KevMirrorTask` to `TaskScheduler`.

**Step 3 — Add a new `CraReportingObligation` entity** to track the regulatory reporting lifecycle:

```
entity CraReportingObligation {
    project: Project
    vulnerability: Vulnerability
    detected_at: Timestamp          // when DT first saw active exploitation
    early_warning_due_at: Timestamp // detected_at + 24 hours
    notification_due_at: Timestamp  // detected_at + 72 hours
    final_report_due_at: Timestamp? // set when corrective measure available
    early_warning_submitted_at: Timestamp?
    notification_submitted_at: Timestamp?
    final_report_submitted_at: Timestamp?
    status: pending | early_warning_overdue | notification_overdue | 
            final_report_overdue | completed
}
```

**Step 4 — Wire to existing notification system.** When `activelyExploited` transitions from `false` to `true` on a vulnerability that affects an active project, fire `ActivelyExploitedVulnerabilityDetectedEvent`. This creates a `CraReportingObligation` and sends notifications via the existing `NotificationRule` system (add `ACTIVELY_EXPLOITED_VULNERABILITY` to `NotificationGroup`).

**Step 5 — Add TaskScheduler job** that checks `CraReportingObligation` records for overdue steps and escalates them with additional notifications.

**Step 6 — REST API endpoint** `GET /api/v1/cra/reporting-obligations` returning open obligations, filterable by project, sorted by urgency. This gives operators a compliance dashboard.

---

## GAP 3 — CRA-Compliant Structured Vulnerability Advisory Output (CSAF)

### CRA requirement

**Article 14(8):** Manufacturers shall inform impacted users of actively exploited vulnerabilities "in a **structured, machine-readable format that is easily automatically processable**."

**Annex I Part II(4):** Once a security update is available, manufacturers shall publicly disclose: vulnerability description, affected product identification, impact, severity, and "clear and accessible information helping users to remediate the vulnerabilities."

The industry standard for this structured format is **CSAF (Common Security Advisory Framework)** — ISO/IEC 29147 / OASIS CSAF 2.0 — which is already referenced in the EU's own vulnerability disclosure guidelines.

### Current DT state

DT's notification system sends to Slack/Email/Teams/Mattermost/Webhook channels. These are human-readable messages rendered via Pebble templates. DT also consumes and produces CycloneDX VEX documents (though VEX generation is not fully surfaced in the spec).

There is no CSAF output publisher. There is no structured JSON advisory format aligned with CRA article 14(8). There is no "publish advisory to security.txt or CSAF feed" workflow.

### The gap

DT cannot produce CRA-compliant machine-readable security advisories. It cannot generate CSAF 2.0 documents. It cannot serve a CSAF advisory feed that affected parties can subscribe to programmatically.

### Implementation approach

**Step 1 — Add a CSAF publisher to `notification/publisher/`.** Create `CsafAdvisoryPublisher.java` implementing the `Publisher` interface. This publisher:
- Accepts a `Finding` + `Vulnerability` + `Project` context
- Produces a CSAF 2.0 JSON document (see https://docs.oasis-open.org/csaf/csaf/v2.0/csaf-v2.0.html)
- Stores it as a `SecurityAdvisory` entity (see step 2)

Key CSAF fields to populate from DT data:
- `document.title` ← from vulnerability `vulnId` + project `name`
- `document.tracking.id` ← advisory UUID
- `document.tracking.status` ← `draft` | `interim` | `final`
- `vulnerabilities[].cve` ← `vulnerability.vulnId`
- `vulnerabilities[].scores` ← CVSS v3/v4 from `vulnerability.cvss`
- `product_tree.branches` ← from `component.coordinates.purl` / `project.name`
- `vulnerabilities[].remediations` ← from `Analysis.response` + `Analysis.details`

**Step 2 — Add a `SecurityAdvisory` entity:**

```java
// New model/SecurityAdvisory.java
// Maps a Finding to a published advisory document
// Fields: uuid, finding (FK), project, format (CSAF|VEX), document_json (CLOB),
//         status (draft|interim|final), published_at, revised_at
```

**Step 3 — Add CSAF advisory feed endpoint.** New resource `resources/v1/AdvisoryResource.java`:
- `GET /api/v1/project/{uuid}/advisories` — list advisories for a project (CSAF Provider Metadata)
- `GET /api/v1/advisories/{advisoryUuid}` — get single CSAF document
- `GET /.well-known/csaf/provider-metadata.json` — CSAF provider metadata document (required by CSAF spec)

**Step 4 — VEX export surfacing.** DT already consumes VEX but the export path is hidden. Add explicit `GET /api/v1/project/{uuid}/vex` returning a CycloneDX VEX document populated from current `Analysis` states. This satisfies CRA requirements for communicating "not affected" statuses to downstream integrators.

**Step 5 — Integrate CSAF generation into `BomUploadProcessingTask` post-analysis.** When a finding with `is_actively_exploited = true` is detected, automatically draft a CSAF advisory (status: draft). Analysts promote it to `interim` / `final` via the triage surface.

---

## GAP 4 — Coordinated Vulnerability Disclosure (CVD) Policy Management

### CRA requirement

**Annex I Part II(5):** Manufacturers shall "put in place and enforce a **policy on coordinated vulnerability disclosure**."

**Annex VII(2)(b):** Technical documentation must include "the **coordinated vulnerability disclosure policy**."

**Article 13(8):** Manufacturers shall have "appropriate policies and procedures, including **coordinated vulnerability disclosure policies**... to process and remediate potential vulnerabilities... reported from internal or external sources."

### Current DT state

DT has no CVD policy entity. It has no way to store, version, or publish a CVD policy document for a product or manufacturer. There is no `security.txt` generation (RFC 9116), which is the standard mechanism for publishing a CVD policy URL.

### The gap

Manufacturers using DT to manage their products have nowhere in the platform to attach a formal CVD policy. There is no platform support for the full CVD lifecycle: policy definition → publication → inbound report intake → triage → disclosure coordination.

### Implementation approach

**Step 1 — Add a `CvdPolicy` entity:**

```java
// New model/CvdPolicy.java
// Fields:
//   name: String
//   project: Project? (null = organisation-wide)
//   policy_text: CLOB (the full policy text, markdown or HTML)
//   policy_url: String? (public URL where policy is published)
//   contact_email: String (required - Annex I Part II(6))
//   contact_url: String? (alternative contact)
//   disclosure_deadline_days: Integer (default: 90 - typical CVD window)
//   is_published: Boolean
//   created_at: Timestamp
//   updated_at: Timestamp
//   version: String
```

**Step 2 — Link CVD policy to Project and Portfolio level.** A project inherits the portfolio-level CVD policy if it has no specific one defined. Add `cvd_policy: CvdPolicy?` FK to `Project`.

**Step 3 — security.txt generation endpoint.** CRA Annex I Part II(6) + RFC 9116. Add endpoint `GET /api/v1/project/{uuid}/security.txt` that generates a `security.txt` file per project:

```
Contact: mailto:{policy.contact_email}
Expires: {project.support_period_end_date}
Policy: {policy.policy_url}
Preferred-Languages: en
Canonical: https://{host}/.well-known/security.txt
```

Also add `GET /.well-known/security.txt` for the platform-level policy.

**Step 4 — CVD policy REST API.** New `resources/v1/CvdPolicyResource.java`:
- `POST /api/v1/cvdpolicy` — create policy
- `GET /api/v1/cvdpolicy/{uuid}` — get policy
- `PUT /api/v1/cvdpolicy/{uuid}` — update policy (versions the old one)
- `GET /api/v1/project/{uuid}/cvdpolicy` — get effective CVD policy for a project

**Step 5 — Policy version history.** Each update to a `CvdPolicy` creates a `CvdPolicyRevision` record (similar to `AnalysisComment` audit trail). This satisfies the "documentation" requirement of Annex VII.

---

## GAP 5 — External Vulnerability Report Intake

### CRA requirement

**Annex I Part II(6):** Manufacturers shall "take measures to facilitate the sharing of information about potential vulnerabilities... including by providing a **contact address for the reporting of the vulnerabilities** discovered in the product."

**Article 13(17):** Manufacturers shall designate a **single point of contact** to enable users to "communicate directly and rapidly," including for **vulnerability reporting**. The contact shall "not limit such means to automated tools."

### Current DT state

DT manages vulnerabilities detected by automated scanners (NVD, OSS Index, Snyk, etc.) and allows analysts to triage them. It has no mechanism to receive, log, track, or manage **externally reported vulnerabilities** — vulnerabilities reported by security researchers, customers, or third parties who discover issues in the manufacturer's product.

### The gap

DT is entirely inbound-scanner-driven. There is no:
- External vulnerability report intake form or API
- `InboundVulnerabilityReport` entity tracking external disclosures
- Workflow for triaging reports received from external parties
- Link between an external report and a CVD policy response process
- Coordination state machine (received → triaged → confirmed → patch_in_progress → patch_released → disclosed)

### Implementation approach

**Step 1 — Add an `InboundVulnerabilityReport` entity:**

```java
// New model/InboundVulnerabilityReport.java
// Fields:
//   project: Project
//   reporter_name: String? (may be anonymous)
//   reporter_contact: String?
//   report_body: CLOB
//   received_at: Timestamp
//   status: received | triaging | confirmed | invalid | patch_in_progress |
//           patch_released | disclosed | rejected
//   assigned_to: User? (FK to analyst)
//   linked_vulnerability: Vulnerability? (FK, set when confirmed)
//   linked_finding: Finding? (FK, set when matched to component)
//   disclosure_target_date: Timestamp?  // CVD deadline
//   disclosure_actual_date: Timestamp?
//   cvss_reporter_score: BigDecimal?
//   severity_reporter: Severity?
//   is_anonymous: Boolean
//   notes: InboundReportComment with report = this (audit trail)
```

**Step 2 — Public intake endpoint** (no auth required, or API-key optional):
- `POST /api/v1/vulnerability/report` — accepts report JSON with product identifier, description, optionally CVSS vector
- Rate-limited (prevent spam). Returns a tracking ID the reporter can use to check status.
- `GET /api/v1/vulnerability/report/{trackingId}/status` — public status check endpoint

**Step 3 — Analyst triage surface.** Extend the existing `FindingTriage` surface or create a new `InboundReportTriage` surface. Analysts can:
- Confirm or reject the report
- Link it to a finding (or create a new `INTERNAL` vulnerability record)
- Assign a CVD disclosure deadline
- Respond to the reporter (generates an `InboundReportComment` visible to reporter via tracking ID)

**Step 4 — Notifications.** When a new `InboundVulnerabilityReport` arrives, fire `InboundVulnerabilityReportReceivedEvent`. Wire to `NotificationGroup.NEW_EXTERNAL_VULNERABILITY_REPORT`. This alerts the security team immediately.

**Step 5 — CVD deadline tracking.** When an `InboundVulnerabilityReport` reaches `confirmed` status, set `disclosure_target_date = confirmed_at + policy.disclosure_deadline_days`. Add to `TaskScheduler` a daily check that fires `CvdDeadlineApproachingEvent` when deadline is within 14 days and `CvdDeadlineExceededEvent` when past it.

**Step 6 — Integration with `CraReportingObligation`.** If a confirmed report maps to a vulnerability with `is_actively_exploited = true`, automatically create a `CraReportingObligation` for the 24h/72h/14-day CRA reporting chain.

---

## GAP 6 — Patch / Fix Availability Tracking

### CRA requirement

**Annex I Part II(2):** Manufacturers shall "address and remediate vulnerabilities **without delay**, including by providing security updates; where technically feasible, new security updates shall be provided **separately from functionality updates**."

**Annex I Part II(4):** Once a security update is available: share description, affected product ID, impacts, severity, and "**clear and accessible information helping users to remediate the vulnerabilities**."

**Annex I Part II(8):** Security updates shall be "disseminated **without delay**... free of charge, accompanied by **advisory messages** providing users with the relevant information."

### Current DT state

DT fetches "latest version" metadata from package registries via `RepositoryMetaEvent`. The `ComponentAnalysisCache` and repository tasks (`tasks/repositories/`) retrieve this. However:
- There is no "fixed in version X" field on `Vulnerability`
- There is no "patched version available" flag on `Finding`
- `Analysis.response` can include free-text remediation notes but this is manual, unstructured
- There is no automated cross-reference between "latest version from registry" and "version that fixes this CVE"

### The gap

DT cannot automatically tell a user: "Vulnerability CVE-XXXX-YYYY in component `foo:bar:1.2.3` is fixed in version `1.2.5` — upgrade available." It cannot track whether a recommended patch has been applied (i.e., whether the BOM was updated with the fixed version). It cannot generate the CRA-required advisory message content automatically.

### Implementation approach

**Step 1 — Add fix version data to `Vulnerability`:**

```java
// In model/Vulnerability.java
@Persistent
@Column(name = "PATCHED_VERSIONS", jdbcType = "CLOB", allowsNull = "true")
private String patchedVersions; // JSON array of affected/patched version ranges per PURL ecosystem

// Example value: [{"purl_type": "maven", "affected": "<1.2.5", "fixed": "1.2.5"}]
```

This data is already available in upstream vuln sources (OSV provides it, NVD provides it via CPE Applicability Statements, Snyk provides it). Wire the existing parsers (`parser/nvd/`, `parser/osv/`, `parser/snyk/`) to populate this field.

**Step 2 — Add a `recommended_upgrade_version` derived field on `Finding`:**

This is a computed field, not stored. When `Finding` is returned via `FindingResource`, compute:
- Look at `component.coordinates.purl` + `finding.vulnerability.patchedVersions`
- Cross-reference with `RepositoryMetaResult` (latest version from registry)
- Return `recommendedVersion` = earliest fixed version ≥ current component version

**Step 3 — Add `is_patch_applied` tracking.** When a BOM is re-uploaded and reconciliation detects that a component version has been upgraded past a previously vulnerable version:
- Fire `PatchAppliedEvent(project, component, vulnerability, old_version, new_version)`
- Automatically update `Finding.analysis.state = RESOLVED` with `analysis.response = "Component upgraded to {new_version} which includes fix for {vuln_id}"`
- This enables automated "closed loop" patch verification

**Step 4 — Patch advisory generation.** Extend the `SecurityAdvisory` entity (from GAP 3) to include `remediation_steps` auto-populated from `patchedVersions` data. The CSAF output automatically picks this up.

**Step 5 — `FindingResource` API extension.** Add `recommendedVersion`, `patchedVersions`, `isPatchApplied` to the Finding response JSON. This enables CI/CD pipelines to programmatically know what to upgrade to.

---

## GAP 7 — Cybersecurity Risk Assessment per Product

### CRA requirement

**Article 13(2):** Manufacturers shall undertake an **assessment of the cybersecurity risks** associated with each product and take the outcome into account during all phases (planning, design, development, production, delivery, maintenance).

**Article 13(3):** The assessment shall be documented and updated during the support period. It must at minimum:
- Analyse cybersecurity risks based on intended purpose and reasonably foreseeable use
- Indicate which Annex I Part I requirements apply and how they are implemented
- Address the intended operational environment

**Article 13(4):** The assessment must be included in the **technical documentation** per Annex VII.

**Annex VII(3):** Technical documentation must include "an assessment of the cybersecurity risks against which the product... is designed, developed, produced, delivered and maintained."

### Current DT state

DT computes risk metrics (critical/high/medium/low vulnerability counts, inherited risk score, EPSS scores, policy violations). These are operational risk indicators — snapshots of discovered vulnerabilities. They are not the same as the CRA's concept of a **pre-market risk assessment** documenting threats to the product's design.

DT has no:
- `CybersecurityRiskAssessment` entity
- Risk assessment history/versioning (the CRA requires updates during support period)
- Assessment of Annex I Part I requirements (secure by default, no known exploitable vulns, etc.) against a product
- Mapping from policy conditions to specific CRA requirements

### The gap

DT is a reactive tool (it detects issues in what exists). The CRA requires a **proactive documented process** (assessing risks during design). DT needs to bridge this gap by providing a structured record of the risk assessment that leverages its existing vulnerability and policy data.

### Implementation approach

**Step 1 — Add a `CybersecurityRiskAssessment` entity:**

```java
// New model/CybersecurityRiskAssessment.java
// Fields:
//   project: Project
//   version: String (assessment version, e.g. "1.0", "1.1")
//   assessment_date: Timestamp
//   assessor: User
//   intended_purpose: CLOB
//   operational_environment: CLOB
//   expected_use_duration: Duration (informs support period)
//   status: draft | under_review | approved | superseded
//   cra_annex1_part1_analysis: CLOB (structured JSON mapping each Annex I point)
//   cra_annex1_part2_process: CLOB (vulnerability handling process description)
//   approved_by: User?
//   approved_at: Timestamp?
//   revision_notes: CLOB?
//   linked_policy_violations: Set<PolicyViolation> (evidence)
//   snapshot_metrics: ProjectMetrics (FK to metrics at assessment time)
```

**Step 2 — Assessment templates.** Pre-populate `cra_annex1_part1_analysis` with a JSON template containing all 13 Annex I Part I requirements as checklist items:

```json
{
  "annex_i_part1": [
    {"point": "2a", "text": "No known exploitable vulnerabilities", "applicable": null, "implementation": null, "evidence_from_dt": "auto"},
    {"point": "2b", "text": "Secure by default configuration", "applicable": null, "implementation": null},
    {"point": "2c", "text": "Vulnerabilities can be addressed through security updates", "applicable": null, "implementation": null},
    ...
  ]
}
```

For `"evidence_from_dt": "auto"` items, automatically populate evidence from DT data:
- Point 2a → current `critical` + `high` findings count for the project
- Point 2l → check if logging/monitoring policy conditions are configured

**Step 3 — Assessment lifecycle workflow.** Add REST endpoints in a new `resources/v1/CybersecurityRiskAssessmentResource.java`:
- `POST /api/v1/project/{uuid}/risk-assessment` — create new draft assessment
- `PUT /api/v1/project/{uuid}/risk-assessment/{assessmentId}` — update
- `POST /api/v1/project/{uuid}/risk-assessment/{assessmentId}/approve` — mark approved
- `GET /api/v1/project/{uuid}/risk-assessment` — list all (version history)
- `GET /api/v1/project/{uuid}/risk-assessment/current` — get latest approved

**Step 4 — Link risk assessment to support period.** When creating an assessment, the `expected_use_duration` field auto-calculates the minimum `supportPeriodEndDate` (first_market_date + max(5years, expected_use_duration)).

**Step 5 — Notification.** When `ProjectMetrics` changes significantly (e.g., new CRITICAL finding), fire a recommendation to update the risk assessment. Add to `TaskScheduler` a quarterly check that warns if no approved risk assessment exists or if the last approved assessment is older than 12 months.

---

## GAP 8 — End-of-Support Notification to Users

### CRA requirement

**Article 13(19):** "Where technically feasible... manufacturers shall **display a notification to users informing them that their product with digital elements has reached the end of its support period**."

**Article 13(11):** When maintaining public software archives with historical versions, "users shall be clearly informed in an easily accessible manner about **risks associated with using unsupported software**."

### Current DT state

DT has `is_active` flag on `Project` and `isLatest` flag to mark current versions. There is no end-of-support date, no EOL notification workflow, and no "unsupported software risk" advisory mechanism.

### The gap

No end-of-support date storage, no automated EOL detection, no user notification pathway for EOL events.

### Implementation approach

This gap is partially covered by GAP 1 (adding `supportPeriodEndDate` to `Project`). The additional implementation items specific to EOL notification:

**Step 1 — Add EOL risk policy condition evaluator.** Create `EolRiskPolicyEvaluator.java` in `policy/`:
- Condition: `COMPONENT_EOL` — evaluates whether a component's `Project` (or the component itself if it's an external library) has reached end-of-support
- Sources: consume end-of-life data from `https://endoflife.date/api/` (public API) for common ecosystems
- Violation type: `OPERATIONAL`

**Step 2 — EOL data mirror task.** Create `EndOfLifeMirrorTask.java` fetching EOL dates from endoflife.date API. Persist as a new `ComponentEolRecord` entity (component purl prefix + eol_date). Include in `TaskScheduler`.

**Step 3 — Warning banner in API.** When `GET /api/v1/project/{uuid}` is called and `supportPeriodEndDate < now`, add a `cra_warnings: ["END_OF_SUPPORT_REACHED"]` field to the response. CI/CD pipelines polling DT can use this to gate deployments.

**Step 4 — Public EOL advisory.** When a project reaches EOL, automatically draft a CSAF advisory (from GAP 3) with `document.tracking.status = "final"` and `vulnerabilities[].remediations[].category = "no_fix_planned"`. This is the CRA Article 13(11) "clearly inform users of risks" mechanism.

---

## GAP 9 — Machine-Readable Vulnerability Notification to Affected Users

### CRA requirement

**Article 14(8):** After becoming aware of an actively exploited vulnerability or severe incident, the manufacturer shall inform impacted users "in a **structured, machine-readable format** that is easily automatically processable."

### Current DT state

DT's notification publishers (Slack, Email, Teams, Mattermost, Webex, Webhook, Jira) all send human-readable rendered text via Pebble templates. The Webhook publisher sends JSON but it is an internal DT schema, not a standardised format.

### The gap

None of DT's publishers produce:
- CSAF 2.0 format (the EU/OASIS standard)
- STIX 2.1 format
- CVRF format (predecessor to CSAF)
- CycloneDX VEX (for "not affected" communications)

No publisher routes notifications to "product users" (downstream consumers of the product) — only to internal platform team members.

### Implementation approach

**Step 1 — CRA Advisory Webhook publisher.** Create `CraAdvisoryWebhookPublisher.java` in `notification/publisher/`. Unlike the existing generic webhook, this:
- Produces a CSAF 2.0 JSON document as the notification body
- Is triggered only for `ACTIVELY_EXPLOITED_VULNERABILITY` and `SEVERE_INCIDENT` notification groups
- Includes the structured fields required by Article 14(2) and 14(4) (early warning, notification, final report)
- Sets `Content-Type: application/csaf+json`

**Step 2 — Notification subscriber registry.** Add a `NotificationSubscriber` entity:

```java
// New model/NotificationSubscriber.java
// Represents an external party (user of the manufacturer's product) who
// should receive CRA-mandated notifications.
// Fields:
//   project: Project
//   name: String
//   contact_type: email | webhook | csaf_feed
//   contact_address: String
//   subscribed_groups: Set<NotificationGroup>
//   is_verified: Boolean
//   subscribed_at: Timestamp
```

`NotificationRule` routing is extended to also dispatch to `NotificationSubscriber` records when the group is in a CRA-mandated set (`ACTIVELY_EXPLOITED_VULNERABILITY`, `SEVERE_INCIDENT`).

**Step 3 — CSAF distribution feed endpoint.** Each project gets a public CSAF distribution feed: `GET /api/v1/project/{uuid}/csaf-feed` returning a list of published advisories. Subscribers poll this feed. This is the "automatic" dissemination mechanism per Annex I Part II(7).

**Step 4 — CSAF Provider Index.** Per the CSAF specification, add `GET /.well-known/csaf/provider-metadata.json` returning the platform-level CSAF provider document so automated consumers (CERT/CC aggregators) can discover and subscribe.

---

## GAP 10 — SBOM Completeness and CRA-Format Export

### CRA requirement

**Annex I Part II(1):** "drawing up a **software bill of materials** in a **commonly used and machine-readable format** covering at the very least the **top-level dependencies** of the products."

**Article 13(24):** The Commission may specify "the format and elements of the software bill of materials."

**Annex VII(2)(b):** The SBOM shall be included in technical documentation.

**Annex VII(8):** The SBOM must be available to market surveillance authorities "further to a reasoned request."

**Annex II(9):** If the manufacturer decides to make the SBOM available to users, information on where it can be accessed must be provided.

### Current DT state

DT consumes SBOMs (CycloneDX, SPDX). It can export CycloneDX BOMs via `BomResource`. The `Bom` entity records the import event but DT treats the BOM as an analysis trigger, not as a **maintained authoritative artifact**.

Gaps in the current SBOM implementation:
- The "current SBOM" for a project is the latest import — not explicitly maintained as a versioned artifact
- No enrichment pipeline that adds discovered vulnerability data back into the exported SBOM (i.e., CycloneDX BOMs with `vulnerabilities` component filled in)
- No SBOM signing (integrity guarantee required for regulatory submission)
- No SBOM completeness validation (CRA requires at minimum top-level deps; no checks exist for this)

### Implementation approach

**Step 1 — SBOM as versioned artifact.** Change `Bom` from an event record to a versioned artifact:
- Add `Bom.is_current: Boolean` — only one Bom per project is `is_current = true`
- Add `Bom.serial_number` (CycloneDX serial number UUID) as the canonical identity
- When a new BOM is uploaded, the previous `is_current` BOM transitions to `is_current = false`

**Step 2 — Enriched SBOM export endpoint.** Enhance `GET /api/v1/bom/cyclonedx/project/{uuid}`:
- Include all components with their full coordinate sets (purl, cpe, hashes)
- Include the `vulnerabilities` array in the CycloneDX output populated from DT findings
- Include VEX statements from current analyses (suppress findings where `is_suppressed = true` or `state = NOT_AFFECTED`)
- Include `metadata.supplier` from project organisational entity
- Include `metadata.lifecycles` reflecting `project.firstMarketDate` and `project.supportPeriodEndDate`

**Step 3 — SBOM signing.** Add optional SBOM signing via JCA (Java Cryptography Architecture). When `SBOM_SIGNING_KEY_PATH` is configured, the export endpoint signs the CycloneDX JSON document using CycloneDX's `signature` field (supports RSA/ECDSA). This proves SBOM integrity for regulatory submissions.

**Step 4 — SBOM completeness policy condition.** Add `SbomCompletenessEvaluator.java` to `policy/`:
- Checks that all components have at least one of: valid purl, cpe, or hashes
- Checks that all components have a `version` (version-less components cannot be vulnerability-matched)
- Flags components with `is_internal = false` that have no `license_id`
- Violations are `OPERATIONAL` type, triggering the existing policy workflow

**Step 5 — Market surveillance authority export.** Add a `GET /api/v1/project/{uuid}/cra-technical-documentation` endpoint that bundles:
- Current SBOM (CycloneDX with vulnerabilities and VEX)
- Current approved `CybersecurityRiskAssessment` (from GAP 7)
- CVD policy document (from GAP 4)
- Active `CraReportingObligation` records (from GAP 2)
- Support period information (from GAP 1)

Returns as a ZIP archive. This directly satisfies Article 13(22) ("provide... all the information and documentation... necessary to demonstrate conformity").

---

## GAP 11 — Severe Incident Tracking and Reporting

### CRA requirement

**Article 14(3)-(5):** Manufacturers shall report **severe incidents** (incidents that negatively affect availability/authenticity/integrity/confidentiality of sensitive data or lead to malicious code execution) within:
- **24 hours**: early warning
- **72 hours**: full incident notification
- **1 month**: final report

A severe incident must be reported to CSIRT designated as coordinator and to ENISA simultaneously.

### Current DT state

DT has `PolicyViolation` with types `SECURITY / LICENSE / OPERATIONAL`. It has `Analysis` tracking per vulnerability finding. It has no concept of a "severe incident" as the CRA defines it. There is no incident lifecycle distinct from vulnerability triage.

### The gap

No `SevereIncident` entity, no incident timeline tracking, no CSIRT/ENISA notification integration, no structured incident reporting workflow distinct from finding triage.

### Implementation approach

**Step 1 — Add a `SevereIncident` entity:**

```java
// New model/SevereIncident.java
// Fields:
//   project: Project
//   title: String
//   description: CLOB
//   incident_type: malicious_code_introduced | availability_impacted | 
//                  integrity_violated | confidentiality_violated | other
//   detected_at: Timestamp
//   severity: Severity
//   affected_versions: String? (free text or structured version range)
//   linked_vulnerabilities: Set<Vulnerability>
//   linked_findings: Set<Finding>
//   is_suspected_malicious: Boolean (required by Article 14(4)(a))
//   status: detected | early_warning_submitted | notification_submitted | 
//           final_report_submitted | closed
//   early_warning_due_at: Timestamp   // detected_at + 24h
//   notification_due_at: Timestamp    // detected_at + 72h
//   final_report_due_at: Timestamp    // notification_submitted_at + 30 days
//   affected_member_states: Set<String>  // ISO 3166-1 alpha-2
//   root_cause: String?
//   mitigation_measures_taken: CLOB?
//   mitigation_measures_available_to_users: CLOB?
//   comments: SevereIncidentComment with incident = this
```

**Step 2 — Incident lifecycle rules.** Wire to the existing `TaskScheduler` for deadline escalation (same pattern as `CraReportingObligation` from GAP 2).

**Step 3 — CSIRT/ENISA notification integration.** Add a new `CsirtNotificationPublisher.java`. When an incident reaches `early_warning_submitted` status, the publisher:
- Formats the report per Article 14(4)(a) structure
- POSTs to the configured CSIRT endpoint (configurable via `application.properties`: `cra.csirt.endpoint`, `cra.enisa.endpoint`)
- Records the submission timestamp and response

This is structurally identical to the existing `AbstractWebhookPublisher` but with CRA-structured payload.

**Step 4 — Automatic incident creation from KEV hits.** When `is_actively_exploited` transitions to `true` for a vulnerability affecting a project (from GAP 2 KEV mirror), automatically draft a `SevereIncident` with status `detected`. The analyst confirms or dismisses it. This prevents the 24-hour deadline from being missed due to analyst not noticing the notification.

**Step 5 — REST API.** New `resources/v1/SevereIncidentResource.java` with full CRUD + lifecycle transitions.

---

## GAP 12 — Product Identification (Batch/Serial Number)

### CRA requirement

**Article 13(15):** "Manufacturers shall ensure that their products with digital elements bear a **type, batch or serial number** or other element allowing their identification, or... that that information is provided on their packaging or in a document accompanying the product."

### Current DT state

`Project` has: `name`, `version`, `group`, `purl`, `cpe`, `swidTagId`. These are sufficient for software products distributed as packages (purl or CPE uniquely identify them). However, for hardware products or embedded firmware where batch/serial numbers matter, there is no model support.

### The gap

Minor gap for software-only use cases (purl covers identification) but meaningful for firmware, embedded systems, and IoT products which the CRA explicitly covers. No `batch_number`, `serial_number`, or `hardware_revision` fields on `Project`.

### Implementation approach

**Step 1 — Add identification fields to `Project`:**

```java
@Persistent
@Column(name = "BATCH_NUMBER", jdbcType = "VARCHAR", length = 255, allowsNull = "true")
private String batchNumber;

@Persistent
@Column(name = "HARDWARE_REVISION", jdbcType = "VARCHAR", length = 255, allowsNull = "true")
private String hardwareRevision;
```

These are optional fields. For software products, the existing `purl`/`cpe`/`swidTagId` remain the primary identifiers. For hardware/firmware projects, these provide the CRA Article 13(15) identification mechanism.

**Step 2 — Add to `ProjectResource` API and BOM import.** When importing a CycloneDX BOM for a hardware/firmware project, map `metadata.component.bom-ref` to `batchNumber` and any hardware-specific properties to `hardwareRevision`.

---

## GAP 13 — Security Update Retention Policy (10-Year Requirement)

### CRA requirement

**Article 13(9):** "Each security update... which has been made available to users during the support period, shall remain available after it has been issued for a **minimum of 10 years** or for the remainder of the support period, whichever is longer."

### Current DT state

DT tracks findings and their analysis states but has no concept of "security updates" as discrete artifacts. It does not track which patch version fixed which finding, nor does it track the distribution or retention of security updates.

### The gap

DT has no mechanism to track that a security update was published, what it contained, when it was made available, and how long it must be retained. The 10-year retention obligation is not enforceable via DT's current model.

### Implementation approach

**Step 1 — Add a `SecurityUpdate` entity:**

```java
// New model/SecurityUpdate.java
// Fields:
//   project: Project
//   version: String (the version that contains the fix)
//   release_date: Timestamp
//   update_type: security_only | combined (CRA Annex I Part II(2) prefers security_only)
//   is_free_of_charge: Boolean (required by Annex I Part II(8))
//   download_url: String?
//   advisory_url: String?
//   addressed_vulnerabilities: Set<Vulnerability>
//   addressed_findings: Set<Finding>
//   retain_until: Timestamp  // release_date + max(10 years, support_period_remaining)
//   description: CLOB
//   linked_bom: Bom?  // the BOM uploaded for this updated version
```

**Step 2 — Link to existing BOM upload flow.** When a BOM is uploaded and `BomUploadProcessingTask` completes, if the new version has fewer findings than the previous (i.e., vulns were fixed), automatically suggest creating a `SecurityUpdate` record. The analyst confirms with the release date and advisory URL.

**Step 3 — Retention warning.** Add to `TaskScheduler` a monthly check that warns (`SecurityUpdateRetentionDue`) when a `SecurityUpdate.retain_until` is within 90 days. This gives operators time to ensure the update remains accessible.

**Step 4 — REST endpoint.** `GET /api/v1/project/{uuid}/security-updates` returns the update history. This is the "public software archive" per CRA Article 13(11).

---

## GAP 14 — EU Declaration of Conformity (DoC) Management

### CRA requirement

**Article 28, Annex V:** Manufacturers must draw up an EU Declaration of Conformity for each product. It must contain: product identification, manufacturer details, statement that it meets CRA requirements, references to applied harmonised standards/certifications.

**Article 13(20):** Manufacturers shall provide a copy of the EU DoC (or simplified DoC with URL to full version) with the product.

**Article 13(13):** Manufacturers shall keep the DoC "at the disposal of the market surveillance authorities for at **least 10 years**."

### Current DT state

No DoC entity, no conformity management, no EU regulatory document management of any kind.

### The gap

Dependency-Track has no concept of conformity declarations. This is the most "compliance document management" oriented gap. However, since DT is already the system of record for security posture, it is the natural place to generate and store the DoC — populated from existing DT data.

### Implementation approach

**Step 1 — Add a `DeclarationOfConformity` entity:**

```java
// New model/DeclarationOfConformity.java
// Fields:
//   project: Project
//   doc_version: String
//   issued_at: Timestamp
//   issued_by: User
//   manufacturer_name: String
//   manufacturer_address: String
//   manufacturer_contact: String
//   applied_standards: Set<String> (e.g. "ETSI EN 303 645", "ISO/IEC 27001")
//   applied_certifications: Set<String>
//   csaf_provider_url: String? (DT's own CSAF feed URL)
//   status: draft | issued | superseded | withdrawn
//   retain_until: Timestamp  // issued_at + 10 years
//   linked_risk_assessment: CybersecurityRiskAssessment
//   signature: String? (digital signature)
```

**Step 2 — DoC generation endpoint.** `POST /api/v1/project/{uuid}/declaration-of-conformity` auto-populates from:
- Project metadata (name, version, purl)
- Current approved `CybersecurityRiskAssessment`
- Linked CVD policy
- Support period data
- Linked standards/certifications (manually entered)

Returns a PDF or structured JSON conforming to Annex V structure.

**Step 3 — Public DoC URL.** Each issued DoC gets a public permalink: `GET /api/v1/doc/{uuid}` (no auth). This is the URL included in product documentation per Article 13(20). Implements the "internet address at which the EU declaration of conformity can be accessed" per Annex II(6).

---

## Summary Table

| # | Gap | CRA Reference | Priority | Effort |
|---|-----|--------------|----------|--------|
| 1 | Support period tracking | Art 13(8,9,19) | **Critical** | Medium |
| 2 | Actively exploited vuln flagging + CISA KEV | Art 14(1,2) | **Critical** | Medium |
| 3 | CSAF structured advisory output | Art 14(8), Annex I Part II(4) | **Critical** | High |
| 4 | CVD policy management | Annex I Part II(5), Annex VII(2b) | **Critical** | Medium |
| 5 | External vuln report intake | Annex I Part II(6), Art 13(17) | **Critical** | High |
| 6 | Patch/fix availability tracking | Annex I Part II(2,4,8) | **High** | Medium |
| 7 | Cybersecurity risk assessment per product | Art 13(2,3,4), Annex VII(3) | **High** | High |
| 8 | End-of-support notification | Art 13(19,11) | **High** | Low |
| 9 | Machine-readable user notification | Art 14(8) | **High** | Medium |
| 10 | SBOM completeness + CRA-format export | Annex I Part II(1), Annex VII(2b) | **High** | Medium |
| 11 | Severe incident tracking + CSIRT reporting | Art 14(3,4,5) | **High** | High |
| 12 | Product identification (batch/serial) | Art 13(15) | **Medium** | Low |
| 13 | Security update retention (10-year) | Art 13(9) | **Medium** | Low |
| 14 | EU Declaration of Conformity | Art 28, Annex V | **Medium** | Medium |

---

## Recommended implementation order

**Phase 1 — Foundational data model (prerequisite for everything else)**
1. GAP 1: support period fields on `Project`
2. GAP 2 Step 1: `is_actively_exploited` on `Vulnerability` + CISA KEV mirror task
3. GAP 6 Step 1: `patchedVersions` on `Vulnerability`, wire parsers

**Phase 2 — Regulatory lifecycle entities**
4. GAP 4: `CvdPolicy` entity + security.txt endpoint
5. GAP 5: `InboundVulnerabilityReport` entity + public intake endpoint
6. GAP 2 Steps 2-6: `CraReportingObligation` + 24h/72h/14-day tracking
7. GAP 11: `SevereIncident` entity + timeline tracking

**Phase 3 — Output and advisory**
8. GAP 3: CSAF publisher + `SecurityAdvisory` entity + advisory feed endpoint
9. GAP 9: `NotificationSubscriber` registry + CSAF distribution
10. GAP 10: enriched SBOM export with vulns + VEX + signing

**Phase 4 — Compliance documentation**
11. GAP 7: `CybersecurityRiskAssessment` entity + Annex I checklist
12. GAP 8: EOL risk policy evaluator + endoflife.date mirror
13. GAP 13: `SecurityUpdate` entity + retention tracking
14. GAP 14: `DeclarationOfConformity` entity + PDF generation
15. GAP 12: batch/serial number fields (trivial, can be done any time)
