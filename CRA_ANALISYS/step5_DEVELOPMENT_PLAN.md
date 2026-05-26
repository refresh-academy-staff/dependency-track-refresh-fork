# Piano di Sviluppo — Piattaforma CRA/NIS2
## 55 Giorni Lavorativi · 2 Sviluppatori Senior

**Data inizio prevista:** Giorno 1 (da definire con il cliente)  
**Data fine prevista:** Giorno 55 (11 settimane lavorative)  
**Capacità totale:** 110 persona-giorni  
**Metodologia:** Kanban settimanale con milestone settimanali; daily standup 15 min; review + retro ogni fine settimana

---

## Team e Ruoli

| Persona | Ruolo | Focus principale |
|---------|-------|-----------------|
| **Dev A** | Senior Backend (Java/DT) | DT integration layer, estensioni DT, backend Java, API REST |
| **Dev B** | Senior Full-stack | Backend proprietario (moduli M1/M4/M5/M6), Vue frontend, integrations |

**Stack tecnologico assunto:**
- Backend proprietario: Java 17 + Spring Boot 3 (o framework compatibile con DT)
- DT: fork esistente (Java 17 + Jersey + JDO/DataNucleus)
- Database: PostgreSQL 15 (shared tra DT e backend proprietario tramite schema separati)
- Frontend: Vue 3 + Vite (coerente con DT frontend esistente)
- Infrastruttura: Docker Compose, NGINX reverse proxy
- Notifiche email: SMTP + template Thymeleaf
- CI/CD: GitLab CI o GitHub Actions

---

## Struttura delle Milestone

| Milestone | Settimana | Giorni | Descrizione |
|-----------|-----------|--------|-------------|
| M1 | 1 | 1–5 | Infrastruttura, DT setup, scaffolding backend |
| M2 | 2 | 6–10 | Catalogo prodotti, versioning prodotto, sincronizzazione DT |
| M3 | 3 | 11–15 | SBOM acquisition (import, validazione, manuale) |
| M4 | 4 | 16–20 | SBOM lifecycle (versioning, freeze, diff) + VEX workflow |
| M5 | 5 | 21–25 | Vulnerability intelligence (fonti, matching, KEV, ICS-CERT) |
| M6 | 6 | 26–30 | Registro clienti, installed base, impact analysis |
| M7 | 7 | 31–35 | Triage queue, SLA timers, risk scoring |
| M8 | 8 | 36–40 | Sub-workflow A: Notifica ACN/ENISA 24h/72h/14gg |
| M9 | 9 | 41–45 | Sub-workflow B: Notifica clienti B2B + Patch Campaign |
| M10 | 10 | 46–50 | Audit trail, alert system, dashboard KPI, compliance docs |
| M11 | 11 | 51–55 | Integration testing E2E, hardening, deployment, go-live |

---

## EPIC 1 — Infrastruttura e DT Integration Layer
**Milestone:** M1 (Giorni 1–5)  
**Owner primario:** Dev A  
**Obiettivo:** Ambiente funzionante con DT deployato e layer di integrazione attivo

### Story 1.1 — Deployment Dependency-Track (Task 115)
**Dev:** A | **Stima:** 1.0 gg
- Setup Docker Compose: DT API server, DT frontend, PostgreSQL, NGINX reverse proxy
- Configurazione variabili d'ambiente, volumi persistenti, healthcheck
- Script di backup PostgreSQL giornaliero
- Verifica: DT UI accessibile, API REST risponde, healthcheck verde
- DoD: `docker compose up` funziona da zero su macchina pulita; SBOM di test caricabile via UI

### Story 1.2 — Configurazione sorgenti vulnerability intelligence (Task 116)
**Dev:** A | **Stima:** 1.0 gg
- Registrazione NVD API key, configurazione OSV, CISA KEV, EPSS (FIRST.org), GitHub Advisory in DT
- Avvio sincronizzazione iniziale; verifica completamento mirror NVD
- Test: CVE nota (es. Log4Shell CVE-2021-44228) appare in DT dopo sync
- DoD: tutte le 5 sorgenti attive e sincronizzate; nessun errore nei log DT

### Story 1.3 — Scaffolding backend proprietario
**Dev:** B | **Stima:** 1.5 gg
- Inizializzazione progetto Spring Boot: struttura package (controller, service, repository, model), configurazione PostgreSQL (schema `cra_platform` separato da DT), Flyway migration, security config (JWT, RBAC base)
- Setup Docker Compose per backend proprietario (affianca DT)
- Configurazione logging strutturato (JSON), Actuator endpoints
- DoD: backend avviabile, endpoint `/health` risponde, autenticazione JWT funzionante

### Story 1.4 — API client REST verso DT (Task 117)
**Dev:** A | **Stima:** 1.5 gg
- Implementazione `DependencyTrackClient`: autenticazione API-key, retry con backoff esponenziale, rate limiting, gestione errori (4xx/5xx → eccezioni tipizzate)
- Metodi: `createProject`, `uploadBom`, `getFindings`, `getVulnerabilities`, `getComponents`
- Test unitari con WireMock per tutti i metodi
- DoD: 100% metodi testati; retry funzionante su 503 simulato

---

## EPIC 2 — Catalogo Prodotti e Sincronizzazione DT
**Milestone:** M2 (Giorni 6–10)  
**Owner primario:** Dev B (model + API) / Dev A (sync DT)  
**Obiettivo:** Prodotti e versioni gestibili con sincronizzazione automatica a DT

### Story 2.1 — Entità Product e ProductVersion
**Dev:** B | **Stima:** 1.5 gg
- Schema DB: tabelle `product` (id, name, code, variants JSONB, classification_cra ENUM, created_at), `product_version` (id, product_id, hw_version, fw_version, sw_version, market_date, eos_date, eol_date, status ENUM, dt_project_id, dt_project_version)
- Flyway migration
- JPA entities + repositories
- Validazione: `eos_date` ≥ `market_date + 5 anni` (CRA Art. 13(8))

### Story 2.2 — REST API Catalogo Prodotti (CRUD)
**Dev:** B | **Stima:** 1.0 gg
- `POST /api/products`, `GET /api/products`, `GET /api/products/{id}`, `PUT /api/products/{id}`
- `POST /api/products/{id}/versions`, `GET /api/products/{id}/versions`, `PUT /api/products/{id}/versions/{versionId}`
- Paginazione, filtro per status/classification
- RBAC: Product Manager e Admin possono creare/modificare; Analyst e altri solo lettura

### Story 2.3 — Classificazione CRA prodotto
**Dev:** B | **Stima:** 0.5 gg
- Campo `classification_cra` ENUM: `default | class_i | class_ii`
- Validazione: Class I e II richiedono CVD policy attiva (warning se assente)
- API: GET/PUT classification; storico modifiche in audit trail

### Story 2.4 — Sincronizzazione DT ↔ ProductVersion (Task 118)
**Dev:** A | **Stima:** 2.0 gg
- Service `DtSyncService`: per ogni `ProductVersion` crea o recupera project+version in DT
- Mapping: `product.name + " " + version.sw_version` → DT project name; `version.hw_version + "-" + version.fw_version` → DT project version
- Sync bidirezionale IDs: salva `dt_project_id` e `dt_project_version_id` in `product_version`
- Sync schedulata ogni ora + trigger manuale via API
- DoD: nuova ProductVersion → project DT creato automaticamente; test di idempotenza

### Story 2.5 — Ciclo di vita prodotto e CVD policy link
**Dev:** B | **Stima:** 1.0 gg
- Endpoint `GET /api/products/{id}/lifecycle`: stato corrente (active/approaching_eos/eos/eol), giorni rimanenti a EoS
- Entità `CvdPolicy` (id, product_id nullable, policy_text, policy_url, contact_email, version, is_published, created_at)
- API CRUD CVD policy + endpoint `GET /api/products/{id}/cvdpolicy`
- Logica ereditarietà: se `product_id = null` → policy a livello organizzazione (fallback)

---

## EPIC 3 — SBOM Acquisition
**Milestone:** M3 (Giorni 11–15)  
**Owner primario:** Dev A (DT push) / Dev B (validation layer)  
**Obiettivo:** Import SBOM via file, manuale e da CI/CD con validazione completa

### Story 3.1 — Import SBOM CycloneDX da file
**Dev:** A | **Stima:** 1.5 gg
- Endpoint `POST /api/products/{id}/versions/{versionId}/sbom` (multipart/form-data, file CycloneDX JSON/XML)
- Validazione schema CycloneDX (libreria `cyclonedx-java`)
- Calcolo SHA-256 del file originale, archiviazione in storage (filesystem o S3-compatible)
- Push a DT via `DependencyTrackClient.uploadBom()`
- Record `SbomImport` nel DB: operatore, timestamp, file_hash, source (MANUAL_UPLOAD / CI_CD / DEPLOY_TIME), status
- DoD: SBOM di test caricata → componenti visibili in DT

### Story 3.2 — Validazione PURL/CPE obbligatori
**Dev:** A | **Stima:** 1.0 gg
- Parsing CycloneDX pre-upload: per ogni componente verifica presenza PURL o CPE
- Se mancanti: blocco upload + risposta JSON con lista componenti non conformi (nome, versione)
- Modalità warning (non bloccante) per `is_internal = true`
- Test: SBOM con 3 componenti senza PURL → risposta 422 con lista dettagliata

### Story 3.3 — Inserimento manuale componenti
**Dev:** B | **Stima:** 1.5 gg
- Endpoint `POST /api/products/{id}/versions/{versionId}/components` con body strutturato (purl, cpe, name, version, supplier, type ENUM hardware/firmware/software/library, is_internal, license_id, hashes JSONB, notes)
- Validazione: `purl` o `cpe` obbligatorio; `version` obbligatoria
- Sync verso DT: aggiornamento BOM DT con nuovo componente (tramite API DT o rigenerazione BOM completa)
- Record delta in `SbomDelta` (component_id, operation INSERT/UPDATE/DELETE, operator, timestamp, note)

### Story 3.4 — Modalità ibrida (import + delta manuale)
**Dev:** B | **Stima:** 1.5 gg
- Stato macchina per SBOM: `draft → validated → synced_to_dt`
- Ogni modifica post-import genera un `SbomDelta` separato con autore e motivazione (campo obbligatorio per delta manuali su componenti scanner-rilevati)
- Endpoint `GET /api/products/{id}/versions/{versionId}/sbom/deltas` — lista delta con paginazione
- UI: visualizzazione timeline delle modifiche

### Story 3.5 — API upload da CI/CD (Build-time)
**Dev:** A | **Stima:** 0.5 gg
- Endpoint identico a Story 3.1 ma con autenticazione via API-key di servizio (non JWT utente)
- `source = CI_CD`, `ci_pipeline_id` e `ci_commit_sha` opzionali nel body
- Rate limiting: max 10 upload/minuto per API key
- Documentazione snippet GitLab CI / GitHub Actions

---

## EPIC 4 — SBOM Lifecycle e VEX
**Milestone:** M4 (Giorni 16–20)  
**Owner primario:** Dev B  
**Obiettivo:** Versioning automatico, freeze, diff e VEX con giustificazione

### Story 4.1 — Versioning automatico SBOM
**Dev:** B | **Stima:** 1.5 gg
- Tabella `sbom_version` (id, product_version_id, major, minor, patch, build_number, triggered_by ENUM, created_at, created_by, is_frozen)
- Logica bump automatico: major su cambio `sw_version` prodotto, minor su aggiunta/rimozione componente, patch su cambio versione componente
- Endpoint `GET /api/products/{id}/versions/{versionId}/sbom/versions` — lista versioni SBOM
- `GET /api/products/{id}/versions/{versionId}/sbom/versions/{sbomVersionId}` — scarica SBOM specifica versione

### Story 4.2 — Freeze SBOM per versioni rilasciate
**Dev:** B | **Stima:** 1.0 gg
- Endpoint `POST /api/products/{id}/versions/{versionId}/sbom/freeze` — richiede approvazione dual (security_manager role)
- Una volta frozen: qualsiasi tentata modifica → 403 con messaggio "SBOM frozen per versione rilasciata"; tentativo loggato in audit trail
- Endpoint `POST /api/products/{id}/versions/{versionId}/sbom/unfreeze` — solo Admin + nota obbligatoria
- Flag `is_frozen` visibile in tutte le API che restituiscono SBOM info

### Story 4.3 — Diff tra versioni SBOM
**Dev:** B | **Stima:** 1.0 gg
- Endpoint `GET /api/products/{id}/versions/{versionId}/sbom/diff?from={sbomV1}&to={sbomV2}`
- Response: `{ added: [...components], removed: [...components], updated: [{ component, old_version, new_version }] }`
- Export CSV del diff
- Algoritmo: confronto per PURL primary key

### Story 4.4 — VEX workflow con giustificazione obbligatoria
**Dev:** B | **Stima:** 2.0 gg
- Endpoint `POST /api/findings/{findingId}/vex` con body: `{ state: "not_affected", justification: ENUM, notes: "...", evidence_links: [...] }`
- Giustificazioni ENUM: `component_not_present | vulnerable_code_not_present | vulnerable_code_cannot_be_controlled_by_adversary | inline_mitigations_already_exist`
- Workflow approvazione: Analyst crea VEX in stato `draft`; Security Manager approva → stato `approved`; approvazione registrata in audit trail
- Stato `not_affected` approved → sopprime il finding in DT (via DT API analysis endpoint)
- Export VEX integrato nel CycloneDX output (endpoint `GET /api/products/.../sbom?include_vex=true`)

### Story 4.5 — Libreria componenti condivisa (config DT)
**Dev:** A | **Stima:** 0.5 gg
- DT gestisce nativamante la component library; questo story configura le policy DT per la propagazione automatica
- Verifica: modifica CVSS su componente condiviso tra due ProjectVersion → finding aggiornato in entrambi
- Documentazione: come aggiungere componenti alla libreria condivisa

---

## EPIC 5 — Vulnerability Intelligence
**Milestone:** M5 (Giorni 21–25)  
**Owner primario:** Dev A  
**Obiettivo:** Fonti normalizzate attive, matching PURL/CPE/alias, KEV flag, ICS-CERT, EoS tracking

### Story 5.1 — Configurazione e test policy engine DT (Task 119)
**Dev:** A | **Stima:** 1.0 gg
- Configurazione policy DT via API: regola "KEV match" → severity CRITICAL → notifica webhook; regola "CVSS ≥ 9.0" → notifica webhook; regola "EoL component" → notifica webhook
- Endpoint webhook nel backend proprietario: `POST /api/webhooks/dt-alert`
- Parsing payload DT webhook → evento interno `VulnerabilityAlertEvent`
- Test: SBOM con Log4Shell → webhook ricevuto entro 60 secondi

### Story 5.2 — CISA ICS-CERT Advisory parser (custom feed)
**Dev:** A | **Stima:** 2.0 gg
- Scheduled task: fetch feed CISA ICS-CERT (RSS + CSAF advisory) ogni 6 ore
- Parser: estrae CVE-ID, vendor, product, affected_versions, CVSS, advisory_url
- Normalizzazione verso formato DT vulnerability + upsert nel repository DT
- Tag `ics_cert = true` e `ot_relevant = true` per distinguere da advisory generici
- Test: advisory ICS-CERT noto (es. Siemens SCALANCE) → vulnerability visibile in DT con tag OT

### Story 5.3 — Score di confidenza matching
**Dev:** A | **Stima:** 1.0 gg
- Calcolo `match_confidence` per ogni finding: HIGH (PURL esatto + versione), MEDIUM (CPE con version range), LOW (nome componente senza versione o versione fuori range)
- Campo aggiunto alla tabella `finding_enrichment` (id, dt_finding_id, match_confidence ENUM, computed_at)
- API: `GET /api/findings?confidence=low` — lista finding a bassa confidenza per revisione
- Alert: finding LOW confidence inviati a Slack con label "Richiede revisione manuale"

### Story 5.4 — End-of-Support tracking componenti
**Dev:** A | **Stima:** 1.0 gg
- Scheduled task `EndOfLifeMirrorTask`: fetch da `https://endoflife.date/api/` per ecosistemi comuni (nodejs, python, java, linux, debian, ubuntu, openssl, nginx, postgresql)
- Tabella `component_eol_record` (purl_prefix, eol_date, lts_date, source_url, updated_at)
- Logica match: confronto prefisso PURL dei componenti in SBOM con `component_eol_record`
- Alert: componente EoS senza CVE associata → voce in coda triage con tipo `EOL_RISK` (non CVE)
- Task schedulato: giornaliero

### Story 5.5 — Test integrazione E2E DT (Task 120)
**Dev:** A | **Stima:** 0.5 gg
- Scenario test automatizzato: upload SBOM con Log4Shell → attesa matching DT → ricezione webhook → verifica impact analysis → verifica voce in coda triage
- Script eseguibile come parte della CI pipeline
- DoD: scenario E2E verde su ambiente di staging

---

## EPIC 6 — Registro Clienti e Installed Base
**Milestone:** M6 (Giorni 26–30)  
**Owner primario:** Dev B  
**Obiettivo:** Anagrafica B2B completa con installed base e impact analysis operativa

### Story 6.1 — Entità Customer e ContactPerson
**Dev:** B | **Stima:** 1.0 gg
- Schema: `customer` (id, company_name, vat_number, sector ENUM, nis2_classification ENUM none/important/essential, country, created_at)
- `contact_person` (id, customer_id, name, email, role ENUM technical/security/management, is_primary_security_contact, notification_channel ENUM email/webhook/portal)
- API CRUD: `POST/GET/PUT /api/customers`, `POST/GET /api/customers/{id}/contacts`
- RBAC: Customer Success e Admin possono creare; Analyst e Security Manager solo lettura

### Story 6.2 — Installed Base
**Dev:** B | **Stima:** 1.5 gg
- Schema: `installation` (id, customer_id, product_version_id, site_name, site_address, install_date, support_contract_status ENUM active/expired/none, support_contract_expiry, notes)
- API: `POST /api/installations`, `GET /api/installations?customer_id=&product_id=`, `PUT /api/installations/{id}`
- Import CSV installazioni (opzionale ma utile per onboarding iniziale)
- Endpoint `GET /api/customers/{id}/installations` — tutti gli impianti di un cliente con stato corrente

### Story 6.3 — Impact Analysis Engine
**Dev:** B | **Stima:** 2.0 gg
- Service `ImpactAnalysisService.analyze(dtFindingId)`:
  1. Recupera finding da DT → componente vulnerabile + CVE
  2. Trova ProductVersion che contengono il componente (tramite DT API o cache locale)
  3. Trova installazioni di quelle ProductVersion
  4. Recupera clienti + contatti di sicurezza
  5. Calcola priorità: KEV score (×3) + CVSS score + NIS2_essential flag (×2)
  6. Crea `ImpactAnalysisResult` con lista prioritizzata
- Trigger: chiamato ad ogni `VulnerabilityAlertEvent` (webhook DT)
- Tabella `impact_analysis_result` (finding_id, computed_at, affected_installations_count, priority_score, result_json JSONB)
- Performance target: < 30 secondi per ≤ 5.000 installazioni

### Story 6.4 — Lista prioritizzata impatti
**Dev:** B | **Stima:** 0.5 gg
- Endpoint `GET /api/findings/{findingId}/impact` — lista installazioni impattate ordinate per priorità, con per ogni riga: customer_name, product_version, site_name, install_date, nis2_flag, cvss_score, priority_rank, contatto_sicurezza
- Export CSV della lista
- Filtri: per customer, per NIS2 classification, per priority_score > X

---

## EPIC 7 — Triage Queue e SLA Timers
**Milestone:** M7 (Giorni 31–35)  
**Owner primario:** Dev B (UI + logic) / Dev A (scheduler + alerts)  
**Obiettivo:** Coda triage operativa con countdown normativi e scoring

### Story 7.1 — Entità TriageItem e macchina a stati
**Dev:** B | **Stima:** 1.5 gg
- Schema: `triage_item` (id, dt_finding_id, cve_id, product_version_id, state ENUM, owner_user_id, priority_score, is_kev, cvss_score, epss_score, created_at, state_changed_at, sla_24h_due, sla_72h_due, closed_at)
- Transizioni di stato valide: new→under_investigation, under_investigation→vex_assessed, vex_assessed→notification_required, vex_assessed→closed, notification_required→patch_available, notification_required→closed, patch_available→closed
- Ogni transizione registrata in `triage_item_history` (item_id, from_state, to_state, operator, timestamp, note)

### Story 7.2 — SLA Timer e countdown
**Dev:** A | **Stima:** 1.0 gg
- Al momento della creazione `TriageItem` con `is_kev = true`: calcola `sla_24h_due = created_at + 24h`, `sla_72h_due = created_at + 72h`
- Scheduled task ogni 15 minuti: controlla item in scadenza
  - `sla_24h_due - now < 6h AND early_warning_not_sent` → alert "URGENTE: Early Warning scade in ${h}h"
  - `sla_24h_due < now AND early_warning_not_sent` → alert "SCADUTO: Early Warning non inviato"
  - Idem per 72h e final report 14gg
- API: `GET /api/triage/overdue` — tutti gli item con SLA scaduto

### Story 7.3 — Assegnazione owner e tracking
**Dev:** B | **Stima:** 0.5 gg
- Endpoint `POST /api/triage/{itemId}/assign` — assegna a user_id (o a se stessi)
- Endpoint `POST /api/triage/{itemId}/unassign`
- Audit trail: ogni cambio owner loggato con timestamp
- Alert a Slack/Teams quando item KEV rimane unassigned per più di 1 ora

### Story 7.4 — Risk score composito
**Dev:** A | **Stima:** 0.5 gg
- Formula: `risk_score = (cvss / 10 × 0.40) + (epss × 0.40) + (kev_flag × 0.20)`
- Calcolato al momento della creazione e aggiornato se EPSS o CVSS cambiano
- Ordinamento default della coda: DESC risk_score, poi ASC sla_24h_due

### Story 7.5 — Remediation Plan
**Dev:** B | **Stima:** 1.0 gg
- Entità `RemediationPlan` (id, triage_item_id, expected_patch_date, milestones JSONB `[{title, date, status}]`, responsible_user_id, notes, created_at, updated_at)
- API: `POST /api/triage/{itemId}/remediation-plan`, `PUT /api/triage/{itemId}/remediation-plan`
- `GET /api/triage/{itemId}/remediation-plan` — stato corrente con milestone
- Usato nel Report Finale 14 giorni (M8)

### Story 7.6 — VEX assessment in coda triage
**Dev:** B | **Stima:** 0.5 gg
- Integrazione Story 4.4 nella coda triage: da `TriageItem` si può aprire il form VEX
- Transizione `under_investigation → vex_assessed` disponibile solo dopo VEX approvato
- Vista "pending VEX approval" per Security Manager

---

## EPIC 8 — Sub-workflow A: Notifica ACN/ENISA
**Milestone:** M8 (Giorni 36–40)  
**Owner primario:** Dev B (workflow) / Dev A (template engine + invio)  
**Obiettivo:** Workflow completo 24h/72h/14gg con template, approvazione e audit

### Story 8.1 — CraReportingObligation entity
**Dev:** B | **Stima:** 1.0 gg
- Schema: `cra_reporting_obligation` (id, triage_item_id, detected_at, early_warning_due, notification_due, final_report_due, early_warning_sent_at, notification_sent_at, final_report_sent_at, status ENUM, created_at)
- Creata automaticamente quando `TriageItem` transita a `notification_required`
- API: `GET /api/cra-obligations` — lista obblighi aperti ordinati per urgenza
- `GET /api/cra-obligations/{id}` — dettaglio con countdown residui

### Story 8.2 — Template Early Warning 24h per ACN
**Dev:** A | **Stima:** 1.0 gg
- Template Thymeleaf (o FreeMarker) per Early Warning con variabili: `${productName}`, `${productVersion}`, `${cveId}`, `${cvssScore}`, `${affectedInstallationsCount}`, `${impactSummary}`, `${mitigationMeasures}`
- Endpoint `GET /api/cra-obligations/{id}/early-warning/preview` — anteprima compilata con dati reali
- Endpoint `POST /api/cra-obligations/{id}/early-warning/send` — invia a endpoint ACN configurato
- Prima dell'invio: approvazione Security Manager obbligatoria (workflow a 1 step)

### Story 8.3 — Template Notifica Formale 72h
**Dev:** A | **Stima:** 1.5 gg
- Report strutturato: identificazione SBOM componente (PURL, versione, hash), CVSS v3 dettagliato (vettore + score), numero installazioni impattate per settore NIS2, descrizione vulnerabilità, piano remediation (da `RemediationPlan`)
- Export in formato JSON strutturato (CSAF-compatible) + PDF opzionale
- Endpoint `POST /api/cra-obligations/{id}/formal-notification/send`
- Record `NotificationSent` (obligation_id, type ENUM, sent_at, recipient, document_hash, response_status)

### Story 8.4 — Report Finale 14 giorni
**Dev:** B | **Stima:** 1.0 gg
- Template: azioni intraprese, patch rilasciata/programmata con data, installazioni aggiornate (N/tot), lezioni apprese
- Triggered manualmente da Security Manager quando remediation completata
- Endpoint `POST /api/cra-obligations/{id}/final-report/send`
- Chiude `CraReportingObligation` con status `completed`

### Story 8.5 — Audit trail comunicazioni ACN/ENISA
**Dev:** A | **Stima:** 0.5 gg
- Tabella `regulatory_notification_log` (id, obligation_id, type, sent_at, recipient, document_json, document_hash, http_response_code, http_response_body, created_by)
- Immutabile: nessun UPDATE o DELETE permesso sulla tabella (constraint DB + application layer)
- Endpoint `GET /api/cra-obligations/{id}/audit-log` — registro cronologico per obbligo
- Export CSV firmato digitalmente

---

## EPIC 9 — Sub-workflow B: Notifica Clienti B2B + Patch Campaign
**Milestone:** M9 (Giorni 41–45)  
**Owner primario:** Dev B  
**Obiettivo:** Email B2B con template parametrici, approvazione, tracking, campagne remediation

### Story 9.1 — Template email parametrici per clienti
**Dev:** B | **Stima:** 1.5 gg
- 4 template Thymeleaf (advisory_informativo, intervento_remoto, aggiornamento_programmato, blocco_emergenziale) con variabili: customer_name, contact_name, product, version, cve_id, cvss_score, action_required, deadline, contact_support
- Endpoint `POST /api/notifications/preview` — anteprima compilata per cliente specifico
- Admin UI per modifica template (WYSIWYG o Markdown)
- Template versionati con storico

### Story 9.2 — Workflow notifica clienti con approvazione
**Dev:** B | **Stima:** 1.5 gg
- Entità `CustomerNotification` (id, triage_item_id, customer_id, template_type ENUM, status ENUM draft/pending_approval/approved/sent/failed, created_by, approved_by, sent_at)
- Endpoint `POST /api/notifications/draft` — crea bozza per N clienti dall'impact analysis
- Endpoint `POST /api/notifications/{id}/submit-for-approval` — notifica Security Manager via Slack/email
- Endpoint `POST /api/notifications/{id}/approve` — Security Manager approva → invio immediato
- Endpoint `POST /api/notifications/{id}/reject` — con nota motivazione
- Percorso emergenza (blocco_emergenziale): flag `is_emergency = true` → approvazione a firma singola Security Manager + log audit "fast-track"

### Story 9.3 — Invio email e tracking acknowledgment
**Dev:** A | **Stima:** 1.0 gg
- SMTP relay configurabile; invio tramite JavaMailSender
- Ogni email include un link univoco di conferma lettura (`/api/notifications/ack/{token}`)
- Endpoint `GET /api/notifications/ack/{token}` — registra click (customer_notification_id, acked_at, ip_address)
- Reminder automatico: se nessun ack entro N giorni (configurabile per template type) → reminder email automatica
- Dashboard: lista notifiche con stato (sent/opened/acked/no_response)

### Story 9.4 — Patch Campaign Management
**Dev:** B | **Stima:** 1.0 gg
- Entità `PatchCampaign` (id, triage_item_id, title, description, target_patch_date, status ENUM planning/active/completed)
- `CampaignInstallation` (campaign_id, installation_id, status ENUM pending/scheduled/in_progress/completed/failed/deferred, scheduled_date, technician_name, maintenance_window_start, maintenance_window_end, notes)
- API: `POST /api/campaigns` (crea da lista installazioni impattate), `GET /api/campaigns/{id}/progress`
- Dashboard campagna: progress bar con % completamento, lista installazioni per stato

---

## EPIC 10 — Audit Trail, Alert System, Dashboard, Compliance Docs
**Milestone:** M10 (Giorni 46–50)  
**Owner primario:** Dev A (audit + alerts) / Dev B (dashboard + docs)  
**Obiettivo:** Audit immutabile, alert completi, dashboard KPI, evidence pack

### Story 10.1 — Audit log immutabile append-only
**Dev:** A | **Stima:** 1.5 gg
- Tabella `audit_log` su schema separato o con trigger PostgreSQL che impedisce UPDATE/DELETE
- Record: (id UUID, timestamp TIMESTAMPTZ, user_id, user_ip, action ENUM, entity_type, entity_id, field_name nullable, old_value TEXT nullable, new_value TEXT nullable, session_id)
- Aspect Spring `@Auditable` per annotare tutti i service method che richiedono logging
- Evento: ogni scrittura al DB passa attraverso `AuditService.log()` — non bypassabile
- Test: tentativo di UPDATE sul log → PostgreSQL error (rule o trigger)

### Story 10.2 — Granularità per campo e export
**Dev:** A | **Stima:** 1.0 gg
- Field-level tracking: per UPDATE su entità critiche (TriageItem, CustomerNotification, VexDecision, ProductVersion) log separato per ogni campo modificato con old/new value
- Endpoint `GET /api/audit-log?entity_type=&entity_id=&from=&to=&user_id=` — paginato
- Export CSV + firma digitale SHA-256 del file esportato (incluso nel file come ultima riga)
- RBAC: solo Admin e CISO possono esportare audit log

### Story 10.3 — Alert system completo
**Dev:** A | **Stima:** 1.5 gg
- Service `AlertService` con configurazione per destinatario/canale per tipo alert
- Implementazione canali: Slack webhook, Microsoft Teams webhook, email SMTP, webhook generico JSON
- Tabella `alert_config` (alert_type ENUM, channel ENUM, destination, is_enabled, created_by)
- Tutti gli alert previsti nella specifica (nuova CVE, KEV match, variazione CVSS, SLA scadenza, clienti NIS2 non notificati, patch non applicate, EoS componente, digest management)
- Digest settimanale/mensile: aggregazione KPI in email formattata a CISO/Security Manager

### Story 10.4 — Compliance dashboard base
**Dev:** B | **Stima:** 1.0 gg
- Endpoint API `GET /api/kpi/compliance`:
  - `sla_compliance_pct`: % notifiche 24h KEV rispettate (ultimi 30/90 gg)
  - `sbom_coverage_pct`: % product versions rilasciate con SBOM frozen completa
  - `open_triage_count`: item in coda non ancora vex_assessed o closed per severity
  - `installations_at_risk`: count installazioni con CVE CRITICAL/HIGH aperta
- Vue component per dashboard base (cards + traffic light)
- Aggiornamento ogni 5 minuti (polling o SSE)

### Story 10.5 — KPI direzionali e trend
**Dev:** B | **Stima:** 1.0 gg
- Endpoint `GET /api/kpi/executive` con: prodotti esposti per severity, vuln aperte per severity, MTTR per severity (calcolato da triage history), % clienti aggiornati per campagna attiva, stato notifiche regolatorie (aperte/in ritardo/completate)
- Endpoint `GET /api/kpi/trend?metric=sla_compliance&from=&to=&granularity=weekly` — dati storici
- Vue charts (Chart.js o ECharts): line chart trend, bar chart per severity

### Story 10.6 — Report Allegato VII CRA e Evidence Pack
**Dev:** B | **Stima:** 1.0 gg
- Endpoint `POST /api/products/{id}/versions/{versionId}/cra-report` — genera report Allegato VII
- Report JSON/PDF: SBOM versionata con hash, ciclo di vita, classificazione CRA, CVD policy, storico vulnerabilità gestite per il prodotto
- Endpoint `POST /api/products/{id}/versions/{versionId}/evidence-pack` — genera ZIP
  - `sbom_current.cdx.json` (con VEX)
  - `triage_log.csv` (filtrato per prodotto, firmato)
  - `notifications_sent.csv` (proof of notification ACN + clienti)
  - `cvd_policy.pdf`
  - `cra_report_annexVII.json`
- RBAC: solo CISO e Admin

---

## EPIC 11 — Integration Testing, Hardening, Deployment, Go-Live
**Milestone:** M11 (Giorni 51–55)  
**Owner primario:** entrambi  
**Obiettivo:** Sistema production-ready, test E2E completi, deployment documentato

### Story 11.1 — Test E2E automatizzati (scenario principale)
**Dev:** A+B | **Stima:** 2.0 gg
- Suite test E2E (REST Assured + Testcontainers) per scenario completo:
  1. Setup prodotto + versione + SBOM con componente vulnerabile
  2. Trigger KEV match via DT webhook simulato
  3. Verifica creazione TriageItem con countdown SLA
  4. Esecuzione VEX assessment
  5. Approvazione notifica ACN (Early Warning)
  6. Invio notifica clienti B2B (mock SMTP)
  7. Acknowledgment cliente
  8. Chiusura TriageItem + CraReportingObligation
  9. Generazione evidence pack
  10. Verifica audit trail completo
- Target: scenario completo verde in < 5 minuti

### Story 11.2 — Security hardening
**Dev:** A | **Stima:** 1.0 gg
- OWASP Top 10 review: injection SQL (JPA parameterized), XSS (Content-Security-Policy headers), CSRF (token), autenticazione MFA forzata per ruoli Security Manager/CISO/Admin
- Rate limiting su tutti gli endpoint pubblici (upload SBOM, CVD inbound)
- Revisione dipendenze con DT stesso: generare SBOM del progetto + scan iniziale
- Test RBAC: matrice permessi vs ruoli verificata con test parametrizzati

### Story 11.3 — Performance testing
**Dev:** B | **Stima:** 0.5 gg
- Load test `ImpactAnalysisService` con 5.000 installazioni: target < 30 secondi
- Load test upload SBOM 500 componenti: target < 10 secondi
- Verifica memory footprint DT + backend con 50 utenti concorrenti

### Story 11.4 — Deployment documentation e runbook
**Dev:** A+B | **Stima:** 1.0 gg
- `docker-compose.prod.yml` con tutte le variabili d'ambiente documentate
- Script di migrazione DB (Flyway) idempotente e reversibile
- Runbook operativo: avvio, stop, backup, restore, aggiornamento DT, aggiornamento backend
- Procedure di disaster recovery

### Story 11.5 — Go-live checklist e handover
**Dev:** A+B | **Stima:** 0.5 gg
- Checklist go-live (NVD API key, SMTP, Slack webhook, endpoint ACN, backup schedulato, monitoring)
- Sessione di handover con il cliente (walkthrough del sistema)
- Identificazione backlog tecnico post-go-live (ADD-ON Customer Portal, diff avanzato, integrazioni PLM)

---

## Distribuzione Carico (Gantt semplificato)

```
Settimana  Dev A (Backend/DT)              Dev B (Platform/FE)
─────────────────────────────────────────────────────────────────
W1        DT Setup + API client            Scaffolding backend
W2        DT Sync (Story 2.4)              Catalogo Prodotti (2.1-2.3+2.5)
W3        SBOM import/push a DT (3.1-3.2) SBOM manuale+ibrida (3.3-3.4-3.5)
W4        VEX in DT (Story 4.4 backend)   SBOM versioning+freeze+diff (4.1-4.3)
W5        ICS-CERT parser (5.2)            Confid. score+EoS (5.3-5.4)
          DT policy engine (5.1)
W6        Impact analysis engine (6.3)     Customer+Installed base (6.1-6.2+6.4)
W7        SLA timers+scheduler (7.2-7.3)  Triage queue (7.1+7.4-7.6)
W8        Template 24h+72h+invio (8.2-8.3) CraObligation+audit ENISA (8.1+8.4-8.5)
W9        SMTP+tracking ack (9.3)          Notifiche B2B+Campaign (9.1-9.2+9.4)
W10       Audit log+alerts (10.1-10.3)    Dashboard+KPI+Evidence pack (10.4-10.6)
W11       E2E testing+security (11.1-11.2) Perf test+deployment+GO LIVE (11.3-11.5)
```

---

## Rischi e Mitigazioni

| Rischio | Probabilità | Impatto | Mitigazione |
|---------|-------------|---------|------------|
| DT API non espone alcuni dati necessari | Media | Alto | Mock/workaround identificati in W1; escalation immediata |
| DataNucleus enhancement friction (DT fork) | Alta | Medio | Dev A dedicato; buffer 2gg nel piano |
| CISA ICS-CERT feed format cambia | Bassa | Medio | Parser modulare; test snapshot del feed |
| Performance impact analysis oltre 30s | Media | Medio | Cache layer Redis se necessario (W6 review) |
| Cliente non fornisce dati installed base per test | Alta | Alto | Dataset di test sintetico preparato in W1 |

---

## Definition of Done (DoD) Globale

Ogni story è "Done" quando:
- [ ] Funzionalità implementata come da acceptance criteria
- [ ] Test unitari scritti e verdi (coverage ≥ 80% per service layer)
- [ ] Test di integrazione scritti con Testcontainers
- [ ] OpenAPI spec aggiornata (Swagger)
- [ ] Audit trail verificato per ogni operazione di scrittura
- [ ] RBAC verificato per tutti gli endpoint della story
- [ ] Review del codice completata (cross-review tra Dev A e Dev B)
- [ ] Merge su branch principale senza conflict

---

## Budget Temporale per Modulo

| Modulo | Persona-giorni | % del totale |
|--------|---------------|-------------|
| Infrastruttura + DT integration | 12 | 11% |
| M1 Catalogo Prodotti + Installed Base | 16 | 15% |
| M2 SBOM Acquisition + Lifecycle | 16 | 15% |
| M3 Vulnerability Intelligence | 10 | 9% |
| M4 Risk Assessment + Triage | 12 | 11% |
| M5 Notification Workflow | 16 | 15% |
| M6 Audit + Dashboard + Docs | 12 | 11% |
| Testing + Hardening + Deploy | 10 | 9% |
| Buffer contingenza (incluso) | 6 | 5% |
| **Totale** | **110** | **100%** |
