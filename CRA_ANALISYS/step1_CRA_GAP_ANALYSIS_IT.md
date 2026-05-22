# Analisi dei Gap CRA: Dependency-Track v4.14 vs Regolamento UE 2024/2847 (Cyber Resilience Act - il documento preso dalla gazzetta ufficiale)

**Regolamento:** REGOLAMENTO (UE) 2024/2847 DEL PARLAMENTO EUROPEO E DEL CONSIGLIO del 23 ottobre 2024
**Titolo completo:** Requisiti orizzontali di cybersicurezza per i prodotti con elementi digitali (Cyber Resilience Act — CRA)
**Pubblicato:** Gazzetta Ufficiale dell'UE, serie L 2024/2847, 20.11.2024
**Specifica di riferimento:** `dependency-track.allium` (distillata da DT v4.14.0)

---

## Come leggere questo documento

Dependency-Track è una piattaforma di intelligence per la supply chain del software utilizzata dai **fabbricanti** di prodotti con elementi digitali per adempiere agli obblighi previsti dal CRA. I gap elencati di seguito sono raggruppati in due categorie:

- **Gap in cui DT è il mezzo di implementazione** — DT necessita di nuove funzionalità affinché i propri utenti (i fabbricanti) possano soddisfare gli obblighi CRA tramite la piattaforma.
- **Gap nella postura CRA di DT stesso** — DT è a sua volta un prodotto con elementi digitali; la propria conformità è una questione distinta.

Entrambe le categorie sono trattate. Ogni sezione comprende:
1. **Il requisito CRA** — citazione esatta di articolo/allegato
2. **Stato attuale di DT** — cosa esiste oggi
3. **Il gap** — cosa manca o è insufficiente
4. **Approccio implementativo** — passi specifici e concreti per colmarlo
5. **Stima** — costi in giorni per singola voce

**Ipotesi per le stime:** un singolo sviluppatore Java esperto con conoscenza dei pattern di DT; i giorni sono da 8 ore lavorative; ogni step include la scrittura di test unitari e di integrazione secondo le convenzioni di DT; sono escluse le modifiche al frontend Vue, le iterazioni di code review, i test QA/accettazione e la redazione della documentazione.

---

## GAP 1 — Tracciamento del Periodo di Supporto

### Requisito CRA

**Articolo 13(8):** I fabbricanti devono garantire la gestione efficace delle vulnerabilità per l'intero **periodo di supporto**. Il periodo di supporto deve essere di almeno **cinque anni** (o il tempo di utilizzo previsto, se inferiore). I fabbricanti devono documentare la motivazione alla base del periodo scelto.

**Articolo 13(9):** Ogni aggiornamento di sicurezza deve restare disponibile per almeno **10 anni** o per la durata residua del periodo di supporto, se superiore.

**Articolo 13(19):** La data di fine del periodo di supporto, **inclusi almeno mese e anno**, deve essere chiaramente indicata al momento dell'acquisto e visualizzata sul prodotto o sulla sua confezione. Ove tecnicamente fattibile, i fabbricanti devono notificare agli utenti quando il prodotto raggiunge la fine del supporto.

**Allegato VII(4):** La documentazione tecnica deve includere le informazioni utilizzate per determinare il periodo di supporto.

### Stato attuale di DT

L'entità `Project` dispone di:
- `name`, `version`, flag `is_latest`, `is_active`
- Nessun campo data che indichi quando il prodotto è stato immesso sul mercato
- Nessun concetto di periodo di supporto o data di fine
- Nessun flusso di notifica per la fine del supporto

### Il gap

Dependency-Track non dispone di un modello per il ciclo di vita del prodotto come definito dal CRA. Non è in grado di rispondere alla domanda: "Quando termina il supporto per questa versione del prodotto?" Non può avvisare utenti o operatori quando un progetto si avvicina o supera la data di fine supporto. Non può applicare il minimo di 5 anni né rendere visibile il requisito di conservazione degli aggiornamenti per 10 anni.

### Approccio implementativo

**Step 1 — Estendere l'entità `Project` con campi del ciclo di vita:**

```java
// In model/Project.java — aggiungere:
@Persistent
@Column(name = "FIRST_MARKET_DATE", jdbcType = "TIMESTAMP", allowsNull = "true")
private Date firstMarketDate;           // data di prima immissione sul mercato

@Persistent
@Column(name = "SUPPORT_PERIOD_END_DATE", jdbcType = "TIMESTAMP", allowsNull = "true")
private Date supportPeriodEndDate;      // minimo CRA: firstMarketDate + 5 anni

@Persistent
@Column(name = "SUPPORT_PERIOD_RATIONALE", jdbcType = "CLOB", allowsNull = "true")
private String supportPeriodRationale;  // requisito documentale Allegato VII(4)
```

**Step 2 — Aggiungere una regola di validazione** che avverta quando `supportPeriodEndDate` è impostata a meno di 5 anni dopo `firstMarketDate`. Può risiedere in `model/validation/` come vincolo Bean Validation personalizzato.

**Step 3 — Aggiungere eventi del ciclo di vita di fine supporto.** Creare due nuovi eventi:
- `ProjectApproachingEndOfSupportEvent` — scattato quando `now > supportPeriodEndDate - 90 giorni`
- `ProjectEndOfSupportReachedEvent` — scattato quando `now >= supportPeriodEndDate`

Collegare al `TaskScheduler` come check schedulati (giornalieri). Ognuno innesca notifiche tramite la macchina `NotificationRule` esistente — aggiungere due nuovi valori all'enum `NotificationGroup`: `PROJECT_APPROACHING_END_OF_SUPPORT` e `PROJECT_END_OF_SUPPORT_REACHED`.

**Step 4 — Estensione REST API.** Aggiungere i campi del ciclo di vita a `ProjectResource` GET/PUT. Aggiungere un nuovo endpoint `GET /api/v1/project/{uuid}/lifecycle` che restituisce lo stato del ciclo di vita in formato JSON strutturato per il CRA.

**Step 5 — Migrazione di upgrade.** Aggiungere una nuova classe in `upgrade/v4140/` (o in una nuova cartella di versione) che esegua il back-fill di `firstMarketDate = null` e `supportPeriodEndDate = null` per i progetti esistenti, e aggiunga un avviso UI per i progetti con date del ciclo di vita nulle.

**Step 6 — Aggiornamento specifica Allium.** Estendere l'entità `Project` con `first_market_date`, `support_period_end_date`, `support_period_rationale`. Aggiungere le regole `WarnApproachingEndOfSupport` e `NotifyEndOfSupportReached`.

### Stima

| Voce | Giorni |
|------|--------|
| Step 1: 3 campi JDO su `Project` + classe di migrazione DB | 1,0 |
| Step 2: Vincolo Bean Validation personalizzato (`@MinSupportPeriod`) | 0,5 |
| Step 3: 2 nuovi eventi + check giornaliero in `TaskScheduler` + 2 nuovi valori `NotificationGroup` | 1,5 |
| Step 4: Estensione GET/PUT `ProjectResource` + endpoint `/lifecycle` | 1,0 |
| Step 5: Migrazione di upgrade (back-fill null + logica avviso progetti esistenti) | 0,5 |
| Step 6: Aggiornamento specifica Allium | 0,5 |
| **Totale** | **5,0** |

---

## GAP 2 — Segnalazione delle Vulnerabilità Attivamente Sfruttate (Integrazione CISA KEV)

### Requisito CRA

**Articolo 14(1):** Un fabbricante deve notificare simultaneamente al CSIRT designato come coordinatore e all'ENISA qualsiasi **vulnerabilità attivamente sfruttata**, entro:
- **24 ore**: notifica di allerta precoce
- **72 ore**: notifica completa della vulnerabilità
- **14 giorni** dall'adozione della misura correttiva: relazione finale

**Articolo 14(8):** Dopo essere venuto a conoscenza di una vulnerabilità attivamente sfruttata, il fabbricante deve informare gli utenti interessati **in un formato strutturato e leggibile dalle macchine, facilmente processabile in modo automatico**.

### Stato attuale di DT

DT traccia punteggi EPSS (`epssScore`, `epssPercentile`) che prevedono la probabilità di sfruttamento. Traccia la severità (CRITICAL/HIGH/MEDIUM/LOW). Non dispone di un flag distinto "è attivamente sfruttata" sulle vulnerabilità.

L'EPSS è un punteggio di probabilità, non uno stato di sfruttamento confermato. Il CRA distingue specificamente "attivamente sfruttata" come trigger distinto per l'obbligo di notifica entro 24 ore — questo corrisponde a fonti quali il **catalogo CISA Known Exploited Vulnerabilities (KEV)** o intelligence equivalente di livello ENISA/CERT.

### Il gap

DT non dispone di:
- Campo booleano `is_actively_exploited` su `Vulnerability`
- Integrazione con CISA KEV o feed equivalenti di intelligence sullo sfruttamento attivo
- Tracciamento delle tempistiche di notifica 24h/72h/14 giorni
- Meccanismo per distinguere eventi di vulnerabilità soggetti a notifica CRA da quelli non soggetti

### Approccio implementativo

**Step 1 — Aggiungere il flag `is_actively_exploited` a `Vulnerability`:**

```java
// In model/Vulnerability.java
@Persistent(defaultFetchGroup = "true")
@Column(name = "IS_ACTIVELY_EXPLOITED", allowsNull = "true")
private Boolean activelyExploited;

@Persistent(defaultFetchGroup = "true")
@Column(name = "ACTIVELY_EXPLOITED_SINCE", jdbcType = "TIMESTAMP", allowsNull = "true")
private Date activelyExploitedSince;    // quando lo sfruttamento è stato confermato per la prima volta
```

**Step 2 — Nuovo task di mirroring KEV.** Creare `tasks/CisaKevMirrorTask.java` implementando il pattern esistente `AbstractNistMirrorTask`. Il CISA KEV è un catalogo JSON pubblico disponibile all'indirizzo `https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json`. Il task:
- Scarica il catalogo secondo uno schedule configurabile (default: ogni 6 ore)
- Per ogni voce KEV, recupera la `Vulnerability` corrispondente tramite `vulnId` (CVE ID)
- Imposta `activelyExploited = true`, `activelyExploitedSince = dateAdded` dal KEV
- Azzera `activelyExploited` per le vuln rimosse dal KEV (non richiesto dal CRA ma utile operativamente)

Aggiungere `CisaKevMirrorEvent.java` e `KevMirrorTask` al `TaskScheduler`.

**Step 3 — Aggiungere una nuova entità `CraReportingObligation`** per tracciare il ciclo di vita della notifica regolamentare:

```
entity CraReportingObligation {
    project: Project
    vulnerability: Vulnerability
    detected_at: Timestamp          // quando DT ha rilevato per la prima volta lo sfruttamento attivo
    early_warning_due_at: Timestamp // detected_at + 24 ore
    notification_due_at: Timestamp  // detected_at + 72 ore
    final_report_due_at: Timestamp? // impostato quando è disponibile la misura correttiva
    early_warning_submitted_at: Timestamp?
    notification_submitted_at: Timestamp?
    final_report_submitted_at: Timestamp?
    status: pending | early_warning_overdue | notification_overdue |
            final_report_overdue | completed
}
```

**Step 4 — Collegare al sistema di notifiche esistente.** Quando `activelyExploited` transita da `false` a `true` su una vulnerabilità che interessa un progetto attivo, scattare `ActivelyExploitedVulnerabilityDetectedEvent`. Questo crea un record `CraReportingObligation` e invia notifiche tramite il sistema `NotificationRule` esistente (aggiungere `ACTIVELY_EXPLOITED_VULNERABILITY` a `NotificationGroup`).

**Step 5 — Aggiungere un job in TaskScheduler** che controlla i record `CraReportingObligation` per gli step scaduti e li escalate con notifiche aggiuntive.

**Step 6 — Endpoint REST** `GET /api/v1/cra/reporting-obligations` che restituisce gli obblighi aperti, filtrabile per progetto, ordinati per urgenza. Fornisce agli operatori una dashboard di conformità.

### Stima

| Voce | Giorni |
|------|--------|
| Step 1: 2 campi su `Vulnerability` + migrazione DB | 0,5 |
| Step 2: `CisaKevMirrorTask` — fetch HTTP, parsing JSON, bulk upsert, evento + wiring `TaskScheduler` | 2,0 |
| Step 3: Entità `CraReportingObligation` + macchina a stati + metodi `QueryManager` | 2,0 |
| Step 4: `ActivelyExploitedVulnerabilityDetectedEvent` + wiring `NotificationGroup` + hook creazione obbligo | 1,0 |
| Step 5: Job di escalation scaduti in `TaskScheduler` | 0,5 |
| Step 6: `GET /api/v1/cra/reporting-obligations` con filtro progetto + ordinamento urgenza | 1,0 |
| **Totale** | **7,0** |

---

## GAP 3 — Output Strutturato di Advisory sulle Vulnerabilità Conforme al CRA (CSAF)

### Requisito CRA

**Articolo 14(8):** I fabbricanti devono informare gli utenti interessati delle vulnerabilità attivamente sfruttate "in un **formato strutturato e leggibile dalle macchine, facilmente processabile in modo automatico**."

**Allegato I Parte II(4):** Una volta disponibile un aggiornamento di sicurezza, i fabbricanti devono rendere pubblici: la descrizione della vulnerabilità, l'identificazione del prodotto interessato, l'impatto, la severità e "informazioni chiare e accessibili che aiutino gli utenti a rimediare alle vulnerabilità."

Lo standard industriale per questo formato strutturato è **CSAF (Common Security Advisory Framework)** — ISO/IEC 29147 / OASIS CSAF 2.0 — già citato nelle linee guida UE sulla divulgazione delle vulnerabilità.

### Stato attuale di DT

Il sistema di notifiche di DT invia messaggi a canali Slack/Email/Teams/Mattermost/Webhook. Si tratta di messaggi leggibili dagli esseri umani, renderizzati tramite template Pebble. DT consuma e produce anche documenti CycloneDX VEX (sebbene la generazione VEX non sia completamente esposta nella specifica).

Non esiste un publisher di output CSAF. Non esiste un formato JSON strutturato di advisory allineato all'articolo 14(8) del CRA. Non esiste un flusso di lavoro per "pubblicare un advisory su security.txt o su un feed CSAF".

### Il gap

DT non è in grado di produrre advisory di sicurezza leggibili dalle macchine e conformi al CRA. Non può generare documenti CSAF 2.0. Non può servire un feed di advisory CSAF a cui le parti interessate possano abbonarsi programmaticamente.

### Approccio implementativo

**Step 1 — Aggiungere un publisher CSAF in `notification/publisher/`.** Creare `CsafAdvisoryPublisher.java` che implementa l'interfaccia `Publisher`. Questo publisher:
- Accetta un contesto `Finding` + `Vulnerability` + `Project`
- Produce un documento JSON CSAF 2.0 (cfr. https://docs.oasis-open.org/csaf/csaf/v2.0/csaf-v2.0.html)
- Lo archivia come entità `SecurityAdvisory` (v. step 2)

Campi CSAF principali da popolare con i dati di DT:
- `document.title` ← da `vulnerability.vulnId` + `project.name`
- `document.tracking.id` ← UUID dell'advisory
- `document.tracking.status` ← `draft` | `interim` | `final`
- `vulnerabilities[].cve` ← `vulnerability.vulnId`
- `vulnerabilities[].scores` ← CVSS v3/v4 da `vulnerability.cvss`
- `product_tree.branches` ← da `component.coordinates.purl` / `project.name`
- `vulnerabilities[].remediations` ← da `Analysis.response` + `Analysis.details`

**Step 2 — Aggiungere un'entità `SecurityAdvisory`:**

```java
// Nuovo model/SecurityAdvisory.java
// Mappa un Finding a un documento di advisory pubblicato
// Campi: uuid, finding (FK), project, format (CSAF|VEX), document_json (CLOB),
//        status (draft|interim|final), published_at, revised_at
```

**Step 3 — Aggiungere un endpoint feed di advisory CSAF.** Nuovo resource `resources/v1/AdvisoryResource.java`:
- `GET /api/v1/project/{uuid}/advisories` — lista advisory per un progetto (CSAF Provider Metadata)
- `GET /api/v1/advisories/{advisoryUuid}` — recupera un singolo documento CSAF
- `GET /.well-known/csaf/provider-metadata.json` — documento CSAF provider metadata (richiesto dalla specifica CSAF)

**Step 4 — Esposizione dell'export VEX.** DT consuma già VEX ma il percorso di export è nascosto. Aggiungere un esplicito `GET /api/v1/project/{uuid}/vex` che restituisce un documento CycloneDX VEX popolato dagli stati `Analysis` correnti. Soddisfa i requisiti CRA per comunicare gli stati "non interessato" agli integratori downstream.

**Step 5 — Integrare la generazione CSAF in `BomUploadProcessingTask` post-analisi.** Quando viene rilevato un finding con `is_actively_exploited = true`, generare automaticamente una bozza di advisory CSAF (status: draft). Gli analisti la promuovono a `interim` / `final` tramite la superficie di triage.

### Stima

| Voce | Giorni |
|------|--------|
| Step 1: `CsafAdvisoryPublisher` — generazione completa JSON CSAF 2.0 (sezioni document, product_tree, vulnerabilities) | 4,0 |
| Step 2: Entità `SecurityAdvisory` + `QueryManager` + migrazione DB | 1,5 |
| Step 3: `AdvisoryResource` — 3 endpoint REST + provider-metadata.json CSAF | 1,5 |
| Step 4: `GET /api/v1/project/{uuid}/vex` — CycloneDX VEX dagli stati Analysis correnti | 1,5 |
| Step 5: Auto-bozza CSAF nel hook post-analisi di `BomUploadProcessingTask` | 1,0 |
| **Totale** | **9,5** |

---

## GAP 4 — Gestione della Policy di Divulgazione Coordinata delle Vulnerabilità (CVD)

### Requisito CRA

**Allegato I Parte II(5):** I fabbricanti devono "definire e applicare una **policy sulla divulgazione coordinata delle vulnerabilità**."

**Allegato VII(2)(b):** La documentazione tecnica deve includere "la **policy di divulgazione coordinata delle vulnerabilità**."

**Articolo 13(8):** I fabbricanti devono disporre di "politiche e procedure appropriate, incluse le **politiche di divulgazione coordinata delle vulnerabilità**... per elaborare e rimediare alle potenziali vulnerabilità... segnalate da fonti interne o esterne."

### Stato attuale di DT

DT non dispone di un'entità per la policy CVD. Non ha modo di archiviare, versionare o pubblicare un documento di policy CVD per un prodotto o fabbricante. Non esiste la generazione di `security.txt` (RFC 9116), che è il meccanismo standard per pubblicare l'URL di una policy CVD.

### Il gap

I fabbricanti che usano DT per gestire i propri prodotti non hanno in piattaforma dove allegare una policy CVD formale. Non esiste supporto di piattaforma per l'intero ciclo di vita CVD: definizione della policy → pubblicazione → ricezione dei report in ingresso → triage → coordinamento della divulgazione.

### Approccio implementativo

**Step 1 — Aggiungere un'entità `CvdPolicy`:**

```java
// Nuovo model/CvdPolicy.java
// Campi:
//   name: String
//   project: Project? (null = a livello organizzativo)
//   policy_text: CLOB (testo completo della policy, markdown o HTML)
//   policy_url: String? (URL pubblico dove la policy è pubblicata)
//   contact_email: String (obbligatorio - Allegato I Parte II(6))
//   contact_url: String? (contatto alternativo)
//   disclosure_deadline_days: Integer (default: 90 - finestra CVD tipica)
//   is_published: Boolean
//   created_at: Timestamp
//   updated_at: Timestamp
//   version: String
```

**Step 2 — Collegare la policy CVD al progetto e al livello portfolio.** Un progetto eredita la policy CVD a livello portfolio se non ne ha una specifica. Aggiungere `cvd_policy: CvdPolicy?` FK a `Project`.

**Step 3 — Endpoint di generazione security.txt.** CRA Allegato I Parte II(6) + RFC 9116. Aggiungere l'endpoint `GET /api/v1/project/{uuid}/security.txt` che genera un file `security.txt` per progetto:

```
Contact: mailto:{policy.contact_email}
Expires: {project.support_period_end_date}
Policy: {policy.policy_url}
Preferred-Languages: it, en
Canonical: https://{host}/.well-known/security.txt
```

Aggiungere anche `GET /.well-known/security.txt` per la policy a livello piattaforma.

**Step 4 — REST API per la policy CVD.** Nuovo `resources/v1/CvdPolicyResource.java`:
- `POST /api/v1/cvdpolicy` — crea policy
- `GET /api/v1/cvdpolicy/{uuid}` — recupera policy
- `PUT /api/v1/cvdpolicy/{uuid}` — aggiorna policy (versiona quella precedente)
- `GET /api/v1/project/{uuid}/cvdpolicy` — recupera la policy CVD effettiva per un progetto

**Step 5 — Storico delle versioni della policy.** Ogni aggiornamento a `CvdPolicy` crea un record `CvdPolicyRevision` (analogo alla traccia di audit `AnalysisComment`). Soddisfa il requisito di "documentazione" dell'Allegato VII.

### Stima

| Voce | Giorni |
|------|--------|
| Step 1: Entità `CvdPolicy` + migrazione DB | 1,0 |
| Step 2: FK `Project` + logica di ereditarietà a livello portfolio | 0,5 |
| Step 3: Endpoint `security.txt` — per-progetto + `/.well-known/security.txt` | 1,0 |
| Step 4: `CvdPolicyResource` — 4 endpoint REST + controlli permessi | 1,5 |
| Step 5: Entità `CvdPolicyRevision` audit trail + auto-versionamento su aggiornamento | 0,5 |
| **Totale** | **4,5** |

---

## GAP 5 — Ricezione di Segnalazioni Esterne di Vulnerabilità

### Requisito CRA

**Allegato I Parte II(6):** I fabbricanti devono "adottare misure per facilitare la condivisione di informazioni sulle potenziali vulnerabilità... anche fornendo un **indirizzo di contatto per la segnalazione delle vulnerabilità** scoperte nel prodotto."

**Articolo 13(17):** I fabbricanti devono designare un **punto di contatto unico** per consentire agli utenti di "comunicare direttamente e rapidamente", anche per la **segnalazione di vulnerabilità**. Il contatto non deve "limitare tali mezzi a strumenti automatizzati."

### Stato attuale di DT

DT gestisce le vulnerabilità rilevate da scanner automatici (NVD, OSS Index, Snyk, ecc.) e consente agli analisti di effettuarne il triage. Non dispone di meccanismi per ricevere, registrare, tracciare o gestire **vulnerabilità segnalate esternamente** — ossia vulnerabilità scoperte e segnalate da ricercatori di sicurezza, clienti o terze parti nel prodotto del fabbricante.

### Il gap

DT è interamente guidato dagli scanner in ingresso. Non esiste:
- Modulo o API di ricezione per segnalazioni esterne di vulnerabilità
- Entità `InboundVulnerabilityReport` per il tracciamento delle divulgazioni esterne
- Flusso di lavoro per il triage delle segnalazioni ricevute da soggetti esterni
- Collegamento tra una segnalazione esterna e un processo di risposta CVD
- Macchina a stati di coordinamento (ricevuto → in triage → confermato → patch_in_lavorazione → patch_rilasciata → divulgato)

### Approccio implementativo

**Step 1 — Aggiungere un'entità `InboundVulnerabilityReport`:**

```java
// Nuovo model/InboundVulnerabilityReport.java
// Campi:
//   project: Project
//   reporter_name: String? (può essere anonimo)
//   reporter_contact: String?
//   report_body: CLOB
//   received_at: Timestamp
//   status: received | triaging | confirmed | invalid | patch_in_progress |
//           patch_released | disclosed | rejected
//   assigned_to: User? (FK all'analista)
//   linked_vulnerability: Vulnerability? (FK, impostato quando confermato)
//   linked_finding: Finding? (FK, impostato quando abbinato a un componente)
//   disclosure_target_date: Timestamp?  // scadenza CVD
//   disclosure_actual_date: Timestamp?
//   cvss_reporter_score: BigDecimal?
//   severity_reporter: Severity?
//   is_anonymous: Boolean
//   notes: InboundReportComment con report = this (traccia di audit)
```

**Step 2 — Endpoint pubblico di ricezione** (senza autenticazione, o con API-key opzionale):
- `POST /api/v1/vulnerability/report` — accetta JSON della segnalazione con identificativo del prodotto, descrizione, vettore CVSS opzionale
- Rate-limited (prevenire spam). Restituisce un ID di tracciamento che il segnalante può usare per controllare lo stato.
- `GET /api/v1/vulnerability/report/{trackingId}/status` — endpoint pubblico di verifica stato

**Step 3 — Superficie di triage per gli analisti.** Estendere la superficie `FindingTriage` esistente o crearne una nuova `InboundReportTriage`. Gli analisti possono:
- Confermare o rifiutare la segnalazione
- Collegarla a un finding (o creare un nuovo record di vulnerabilità `INTERNAL`)
- Assegnare una scadenza di divulgazione CVD
- Rispondere al segnalante (genera un `InboundReportComment` visibile al segnalante tramite tracking ID)

**Step 4 — Notifiche.** Quando arriva un nuovo `InboundVulnerabilityReport`, scattare `InboundVulnerabilityReportReceivedEvent`. Collegare a `NotificationGroup.NEW_EXTERNAL_VULNERABILITY_REPORT`. Avverte immediatamente il team di sicurezza.

**Step 5 — Tracciamento della scadenza CVD.** Quando un `InboundVulnerabilityReport` raggiunge lo stato `confirmed`, impostare `disclosure_target_date = confirmed_at + policy.disclosure_deadline_days`. Aggiungere al `TaskScheduler` un check giornaliero che scatta `CvdDeadlineApproachingEvent` quando la scadenza è entro 14 giorni e `CvdDeadlineExceededEvent` quando è superata.

**Step 6 — Integrazione con `CraReportingObligation`.** Se una segnalazione confermata corrisponde a una vulnerabilità con `is_actively_exploited = true`, creare automaticamente un `CraReportingObligation` per la catena di notifica CRA 24h/72h/14 giorni.

### Stima

| Voce | Giorni |
|------|--------|
| Step 1: Entità `InboundVulnerabilityReport` + macchina a stati + `QueryManager` + migrazione DB | 2,0 |
| Step 2: Endpoint pubblico di ricezione — rate limiting, generazione tracking ID, supporto anonimo, endpoint di stato | 2,5 |
| Step 3: Resource di triage analista — conferma/rifiuto, collegamento a finding/vuln, risposta al segnalante via tracking ID | 2,0 |
| Step 4: `InboundVulnerabilityReportReceivedEvent` + wiring `NotificationGroup` | 0,5 |
| Step 5: Check giornaliero `TaskScheduler` scadenza CVD + due nuovi eventi di escalation | 1,0 |
| Step 6: Hook creazione `CraReportingObligation` alla transizione `confirmed` | 0,5 |
| **Totale** | **8,5** |

---

## GAP 6 — Tracciamento della Disponibilità di Patch e Correzioni

### Requisito CRA

**Allegato I Parte II(2):** I fabbricanti devono "affrontare e rimediare le vulnerabilità **senza indugio**, anche fornendo aggiornamenti di sicurezza; ove tecnicamente fattibile, i nuovi aggiornamenti di sicurezza devono essere forniti **separatamente dagli aggiornamenti funzionali**."

**Allegato I Parte II(4):** Una volta disponibile un aggiornamento di sicurezza: condividere descrizione, identificativo del prodotto interessato, impatti, severità e "**informazioni chiare e accessibili che aiutino gli utenti a rimediare alle vulnerabilità**."

**Allegato I Parte II(8):** Gli aggiornamenti di sicurezza devono essere "diffusi **senza indugio**... gratuitamente, accompagnati da **messaggi di advisory** che forniscano agli utenti le informazioni pertinenti."

### Stato attuale di DT

DT recupera i metadati della "versione più recente" dai registri dei pacchetti tramite `RepositoryMetaEvent`. I task di repository (`tasks/repositories/`) e la `ComponentAnalysisCache` lo recuperano. Tuttavia:
- Non esiste un campo "risolto nella versione X" su `Vulnerability`
- Non esiste un flag "patch disponibile" su `Finding`
- `Analysis.response` può includere note di rimedio in testo libero, ma è manuale e non strutturato
- Non esiste una cross-reference automatica tra "versione più recente dal registry" e "versione che risolve questo CVE"

### Il gap

DT non può comunicare automaticamente all'utente: "La vulnerabilità CVE-XXXX-YYYY nel componente `foo:bar:1.2.3` è risolta nella versione `1.2.5` — aggiornamento disponibile." Non può tracciare se una patch raccomandata è stata applicata (ossia se il BOM è stato aggiornato con la versione corretta). Non può generare automaticamente il contenuto dei messaggi di advisory richiesti dal CRA.

### Approccio implementativo

**Step 1 — Aggiungere dati sulla versione corretta a `Vulnerability`:**

```java
// In model/Vulnerability.java
@Persistent
@Column(name = "PATCHED_VERSIONS", jdbcType = "CLOB", allowsNull = "true")
private String patchedVersions; // array JSON di intervalli di versioni interessate/corrette per ecosistema PURL

// Esempio: [{"purl_type": "maven", "affected": "<1.2.5", "fixed": "1.2.5"}]
```

Questi dati sono già disponibili nelle sorgenti di vulnerabilità upstream (OSV li fornisce, NVD tramite le CPE Applicability Statements, Snyk li fornisce). Aggiornare i parser esistenti (`parser/nvd/`, `parser/osv/`, `parser/snyk/`) per popolare questo campo.

**Step 2 — Aggiungere un campo derivato `recommended_upgrade_version` su `Finding`:**

È un campo calcolato, non archiviato. Quando `Finding` è restituito da `FindingResource`, calcolare:
- Confrontare `component.coordinates.purl` + `finding.vulnerability.patchedVersions`
- Cross-reference con `RepositoryMetaResult` (versione più recente dal registry)
- Restituire `recommendedVersion` = prima versione corretta ≥ versione corrente del componente

**Step 3 — Aggiungere il tracciamento `is_patch_applied`.** Quando un BOM viene ricaricato e la riconciliazione rileva che la versione di un componente è stata aggiornata oltre una versione precedentemente vulnerabile:
- Scattare `PatchAppliedEvent(project, component, vulnerability, old_version, new_version)`
- Aggiornare automaticamente `Finding.analysis.state = RESOLVED` con `analysis.response = "Componente aggiornato a {new_version} che include la correzione per {vuln_id}"`
- Abilita la verifica automatica "closed loop" dell'applicazione della patch

**Step 4 — Generazione advisory per la patch.** Estendere l'entità `SecurityAdvisory` (da GAP 3) per includere `remediation_steps` auto-popolati dai dati `patchedVersions`. L'output CSAF li recepisce automaticamente.

**Step 5 — Estensione API `FindingResource`.** Aggiungere `recommendedVersion`, `patchedVersions`, `isPatchApplied` al JSON di risposta dei Finding. Consente alle pipeline CI/CD di sapere programmaticamente cosa aggiornare.

### Stima

| Voce | Giorni |
|------|--------|
| Step 1: CLOB `patchedVersions` su `Vulnerability` + aggiornamento parser NVD, OSV e Snyk per popolarlo | 3,0 |
| Step 2: `recommendedVersion` calcolato in `FindingResource` — parsing purl + logica comparazione versioni | 1,0 |
| Step 3: Rilevamento `is_patch_applied` in riconciliazione `BomUploadProcessingTask` + `PatchAppliedEvent` + transizione auto-RESOLVED | 2,0 |
| Step 4: Auto-popolamento `SecurityAdvisory.remediationSteps` da `patchedVersions` (dipende da GAP 3) | 0,5 |
| Step 5: Estensione JSON `FindingResource` — 3 nuovi campi | 0,5 |
| **Totale** | **7,0** |

---

## GAP 7 — Valutazione del Rischio di Cybersicurezza per Prodotto

### Requisito CRA

**Articolo 13(2):** I fabbricanti devono eseguire una **valutazione dei rischi di cybersicurezza** associati a ciascun prodotto e tenerne conto in tutte le fasi (pianificazione, progettazione, sviluppo, produzione, consegna, manutenzione).

**Articolo 13(3):** La valutazione deve essere documentata e aggiornata durante il periodo di supporto. Deve almeno:
- Analizzare i rischi di cybersicurezza in base allo scopo previsto e all'uso ragionevolmente prevedibile
- Indicare quali requisiti dell'Allegato I Parte I si applicano e come vengono implementati
- Affrontare l'ambiente operativo previsto

**Articolo 13(4):** La valutazione deve essere inclusa nella **documentazione tecnica** ai sensi dell'Allegato VII.

**Allegato VII(3):** La documentazione tecnica deve includere "una valutazione dei rischi di cybersicurezza rispetto ai quali il prodotto... è progettato, sviluppato, prodotto, consegnato e mantenuto."

### Stato attuale di DT

DT calcola metriche di rischio (conteggi di vulnerabilità critical/high/medium/low, punteggio di rischio ereditato, punteggi EPSS, violazioni di policy). Questi sono indicatori di rischio operativo — istantanee delle vulnerabilità scoperte. Non equivalgono alla **valutazione del rischio pre-mercato** richiesta dal CRA, che documenta le minacce alla progettazione del prodotto.

DT non dispone di:
- Entità `CybersecurityRiskAssessment`
- Storico/versionamento della valutazione del rischio (il CRA richiede aggiornamenti durante il periodo di supporto)
- Valutazione dei requisiti dell'Allegato I Parte I (sicuro per impostazione predefinita, nessuna vulnerabilità nota sfruttabile, ecc.) rispetto a un prodotto
- Mapping delle condizioni di policy a specifici requisiti CRA

### Il gap

DT è uno strumento reattivo (rileva problemi in ciò che esiste). Il CRA richiede un **processo documentato proattivo** (valutazione dei rischi in fase di progettazione). DT deve colmare questo gap fornendo un registro strutturato della valutazione del rischio che sfrutti i dati esistenti su vulnerabilità e policy.

### Approccio implementativo

**Step 1 — Aggiungere un'entità `CybersecurityRiskAssessment`:**

```java
// Nuovo model/CybersecurityRiskAssessment.java
// Campi:
//   project: Project
//   version: String (versione della valutazione, es. "1.0", "1.1")
//   assessment_date: Timestamp
//   assessor: User
//   intended_purpose: CLOB
//   operational_environment: CLOB
//   expected_use_duration: Duration (informa il periodo di supporto)
//   status: draft | under_review | approved | superseded
//   cra_annex1_part1_analysis: CLOB (JSON strutturato che mappa ogni punto dell'Allegato I)
//   cra_annex1_part2_process: CLOB (descrizione del processo di gestione delle vulnerabilità)
//   approved_by: User?
//   approved_at: Timestamp?
//   revision_notes: CLOB?
//   linked_policy_violations: Set<PolicyViolation> (evidenze)
//   snapshot_metrics: ProjectMetrics (FK alle metriche al momento della valutazione)
```

**Step 2 — Template di valutazione.** Pre-popolare `cra_annex1_part1_analysis` con un template JSON contenente tutti i 13 requisiti dell'Allegato I Parte I come voci di checklist:

```json
{
  "annex_i_part1": [
    {"point": "2a", "text": "Nessuna vulnerabilità nota sfruttabile", "applicable": null, "implementation": null, "evidence_from_dt": "auto"},
    {"point": "2b", "text": "Configurazione sicura per impostazione predefinita", "applicable": null, "implementation": null},
    {"point": "2c", "text": "Le vulnerabilità possono essere risolte tramite aggiornamenti di sicurezza", "applicable": null, "implementation": null},
    ...
  ]
}
```

Per le voci con `"evidence_from_dt": "auto"`, popolare automaticamente le evidenze dai dati DT:
- Punto 2a → conteggio corrente di finding `critical` + `high` per il progetto
- Punto 2l → verificare se le condizioni di policy per logging/monitoring sono configurate

**Step 3 — Flusso di lavoro del ciclo di vita della valutazione.** Aggiungere endpoint REST in un nuovo `resources/v1/CybersecurityRiskAssessmentResource.java`:
- `POST /api/v1/project/{uuid}/risk-assessment` — crea nuova bozza di valutazione
- `PUT /api/v1/project/{uuid}/risk-assessment/{assessmentId}` — aggiorna
- `POST /api/v1/project/{uuid}/risk-assessment/{assessmentId}/approve` — segna come approvata
- `GET /api/v1/project/{uuid}/risk-assessment` — elenca tutte (storico versioni)
- `GET /api/v1/project/{uuid}/risk-assessment/current` — recupera l'ultima approvata

**Step 4 — Collegare la valutazione del rischio al periodo di supporto.** Quando si crea una valutazione, il campo `expected_use_duration` calcola automaticamente il minimo `supportPeriodEndDate` (first_market_date + max(5 anni, expected_use_duration)).

**Step 5 — Notifica.** Quando `ProjectMetrics` cambia significativamente (es. nuovo finding CRITICAL), inviare una raccomandazione di aggiornamento della valutazione del rischio. Aggiungere al `TaskScheduler` un check trimestrale che avverta se non esiste una valutazione approvata o se l'ultima è più vecchia di 12 mesi.

### Stima

| Voce | Giorni |
|------|--------|
| Step 1: Entità `CybersecurityRiskAssessment` — campi complessi, macchina a stati, `QueryManager`, migrazione DB | 2,0 |
| Step 2: Generazione template JSON Allegato I Parte I + auto-popolamento evidenze da `ProjectMetrics` e `PolicyViolation` | 2,5 |
| Step 3: `CybersecurityRiskAssessmentResource` — 5 endpoint REST + ciclo di vita approva/sostituisce | 2,0 |
| Step 4: Collegamento calcolo automatico periodo di supporto | 0,5 |
| Step 5: Hook notifica finding critico + check trimestrale `TaskScheduler` per obsolescenza | 1,0 |
| **Totale** | **8,0** |

---

## GAP 8 — Notifica di Fine Supporto agli Utenti

### Requisito CRA

**Articolo 13(19):** "Ove tecnicamente fattibile... i fabbricanti devono **visualizzare una notifica agli utenti informandoli che il loro prodotto con elementi digitali ha raggiunto la fine del periodo di supporto**."

**Articolo 13(11):** Nel mantenimento di archivi pubblici di software con versioni storiche, "gli utenti devono essere chiaramente informati in modo facilmente accessibile dei **rischi associati all'uso di software non supportato**."

### Stato attuale di DT

DT ha il flag `is_active` su `Project` e `isLatest` per contrassegnare le versioni correnti. Non esiste una data di fine supporto, nessun flusso di notifica EOL e nessun meccanismo di advisory per il "rischio del software non supportato".

### Il gap

Nessun campo per la data di fine supporto, nessun rilevamento automatico EOL, nessun percorso di notifica agli utenti per eventi EOL.

### Approccio implementativo

Questo gap è parzialmente coperto dal GAP 1 (aggiunta di `supportPeriodEndDate` a `Project`). Le voci implementative aggiuntive specifiche per la notifica EOL:

**Step 1 — Aggiungere un valutatore di policy per il rischio EOL.** Creare `EolRiskPolicyEvaluator.java` in `policy/`:
- Condizione: `COMPONENT_EOL` — valuta se il `Project` di un componente (o il componente stesso se è una libreria esterna) ha raggiunto la fine del supporto
- Sorgenti: consumare i dati di fine vita da `https://endoflife.date/api/` (API pubblica) per gli ecosistemi comuni
- Tipo di violazione: `OPERATIONAL`

**Step 2 — Task di mirroring dati EOL.** Creare `EndOfLifeMirrorTask.java` che recupera le date EOL dall'API endoflife.date. Archiviare come nuova entità `ComponentEolRecord` (prefisso purl componente + eol_date). Includere nel `TaskScheduler`.

**Step 3 — Banner di avviso nell'API.** Quando `GET /api/v1/project/{uuid}` viene chiamato e `supportPeriodEndDate < now`, aggiungere un campo `cra_warnings: ["END_OF_SUPPORT_REACHED"]` alla risposta. Le pipeline CI/CD che interrogano DT possono usarlo per bloccare i deployment.

**Step 4 — Advisory pubblico EOL.** Quando un progetto raggiunge l'EOL, generare automaticamente una bozza di advisory CSAF (da GAP 3) con `document.tracking.status = "final"` e `vulnerabilities[].remediations[].category = "no_fix_planned"`. È il meccanismo dell'Articolo 13(11) per "informare chiaramente gli utenti dei rischi".

### Stima

| Voce | Giorni |
|------|--------|
| Step 1: `EolRiskPolicyEvaluator` + integrazione API endoflife.date + corrispondenza prefisso purl | 1,5 |
| Step 2: `EndOfLifeMirrorTask` + entità `ComponentEolRecord` + wiring `TaskScheduler` | 2,0 |
| Step 3: Campo `cra_warnings` nella risposta GET di `ProjectResource` | 0,5 |
| Step 4: Auto-bozza advisory CSAF EOL all'evento di raggiungimento EOL (dipende da GAP 3) | 0,5 |
| **Totale** | **4,5** |

---

## GAP 9 — Notifica Leggibile dalle Macchine agli Utenti Interessati

### Requisito CRA

**Articolo 14(8):** Dopo essere venuto a conoscenza di una vulnerabilità attivamente sfruttata o di un incidente grave, il fabbricante deve informare gli utenti interessati "in un **formato strutturato e leggibile dalle macchine**, facilmente processabile in modo automatico."

### Stato attuale di DT

I publisher di notifiche di DT (Slack, Email, Teams, Mattermost, Webex, Webhook, Jira) inviano tutti testo renderizzato leggibile dagli esseri umani tramite template Pebble. Il publisher Webhook invia JSON, ma si tratta di un schema interno di DT, non di un formato standardizzato.

### Il gap

Nessuno dei publisher di DT produce:
- Formato CSAF 2.0 (lo standard UE/OASIS)
- Formato STIX 2.1
- Formato CVRF (predecessore di CSAF)
- CycloneDX VEX (per comunicazioni "non interessato")

Nessun publisher instrada le notifiche agli "utenti del prodotto" (consumatori downstream del prodotto) — solo ai membri interni del team della piattaforma.

### Approccio implementativo

**Step 1 — Publisher Webhook Advisory CRA.** Creare `CraAdvisoryWebhookPublisher.java` in `notification/publisher/`. A differenza del webhook generico esistente, questo:
- Produce un documento JSON CSAF 2.0 come corpo della notifica
- È attivato solo per i gruppi di notifica `ACTIVELY_EXPLOITED_VULNERABILITY` e `SEVERE_INCIDENT`
- Include i campi strutturati richiesti dall'Articolo 14(2) e 14(4) (allerta precoce, notifica, relazione finale)
- Imposta `Content-Type: application/csaf+json`

**Step 2 — Registro degli abbonati alle notifiche.** Aggiungere un'entità `NotificationSubscriber`:

```java
// Nuovo model/NotificationSubscriber.java
// Rappresenta una parte esterna (utente del prodotto del fabbricante) che
// deve ricevere le notifiche obbligatorie CRA.
// Campi:
//   project: Project
//   name: String
//   contact_type: email | webhook | csaf_feed
//   contact_address: String
//   subscribed_groups: Set<NotificationGroup>
//   is_verified: Boolean
//   subscribed_at: Timestamp
```

Il routing di `NotificationRule` viene esteso per inviare anche ai record `NotificationSubscriber` quando il gruppo è in un insieme obbligatorio per il CRA (`ACTIVELY_EXPLOITED_VULNERABILITY`, `SEVERE_INCIDENT`).

**Step 3 — Endpoint feed di distribuzione CSAF.** Ogni progetto ottiene un feed pubblico di distribuzione CSAF: `GET /api/v1/project/{uuid}/csaf-feed` che restituisce un elenco di advisory pubblicati. Gli abbonati interrogano questo feed. È il meccanismo di diffusione "automatica" ai sensi dell'Allegato I Parte II(7).

**Step 4 — Indice Provider CSAF.** Secondo le specifiche CSAF, aggiungere `GET /.well-known/csaf/provider-metadata.json` che restituisce il documento provider CSAF a livello piattaforma, così che i consumatori automatizzati (aggregatori CERT/CC) possano scoprire il feed e abbonarsi.

### Stima

| Voce | Giorni |
|------|--------|
| Step 1: `CraAdvisoryWebhookPublisher` — corpo JSON CSAF 2.0, payload strutturato CRA per Art 14(2)/(4) | 2,0 |
| Step 2: Entità `NotificationSubscriber` + `QueryManager` + migrazione DB + estensione routing in dispatch `NotificationRule` | 1,5 |
| Step 3: `GET /api/v1/project/{uuid}/csaf-feed` + dispatch consapevole degli abbonamenti | 1,0 |
| Step 4: Endpoint `/.well-known/csaf/provider-metadata.json` | 0,5 |
| **Totale** | **5,0** |

---

## GAP 10 — Completezza SBOM ed Export in Formato CRA

### Requisito CRA

**Allegato I Parte II(1):** "redigere una **distinta base dei componenti software** in un **formato comunemente usato e leggibile dalle macchine** che copra almeno le **dipendenze di primo livello** dei prodotti."

**Articolo 13(24):** La Commissione può specificare "il formato e gli elementi della distinta base dei componenti software."

**Allegato VII(2)(b):** L'SBOM deve essere inclusa nella documentazione tecnica.

**Allegato VII(8):** L'SBOM deve essere disponibile alle autorità di sorveglianza del mercato "su richiesta motivata."

**Allegato II(9):** Se il fabbricante decide di rendere l'SBOM disponibile agli utenti, devono essere fornite informazioni su dove è accessibile.

### Stato attuale di DT

DT consuma SBOM (CycloneDX, SPDX). Può esportare BOM CycloneDX tramite `BomResource`. L'entità `Bom` registra l'evento di importazione, ma DT tratta il BOM come un trigger di analisi, non come un **artefatto autorevole mantenuto**.

Gap nell'implementazione SBOM attuale:
- L'"SBOM corrente" per un progetto è l'importazione più recente — non è mantenuta esplicitamente come artefatto versionato
- Nessuna pipeline di arricchimento che aggiunga i dati di vulnerabilità scoperti all'SBOM esportato (ossia BOM CycloneDX con il componente `vulnerabilities` compilato)
- Nessuna firma dell'SBOM (garanzia di integrità richiesta per la presentazione regolamentare)
- Nessuna validazione della completezza dell'SBOM (il CRA richiede almeno le dipendenze di primo livello; non esistono controlli)

### Approccio implementativo

**Step 1 — SBOM come artefatto versionato.** Modificare `Bom` da registro di eventi ad artefatto versionato:
- Aggiungere `Bom.is_current: Boolean` — solo un Bom per progetto è `is_current = true`
- Aggiungere `Bom.serial_number` (UUID serial number CycloneDX) come identità canonica
- Quando viene caricato un nuovo BOM, il precedente `is_current` transita a `is_current = false`

**Step 2 — Endpoint di export SBOM arricchito.** Migliorare `GET /api/v1/bom/cyclonedx/project/{uuid}`:
- Includere tutti i componenti con i set completi di coordinate (purl, cpe, hash)
- Includere l'array `vulnerabilities` nell'output CycloneDX popolato dai finding di DT
- Includere le dichiarazioni VEX dalle analisi correnti (sopprimere i finding dove `is_suppressed = true` o `state = NOT_AFFECTED`)
- Includere `metadata.supplier` dall'entità organizzativa del progetto
- Includere `metadata.lifecycles` che riflettono `project.firstMarketDate` e `project.supportPeriodEndDate`

**Step 3 — Firma SBOM.** Aggiungere firma opzionale dell'SBOM tramite JCA (Java Cryptography Architecture). Quando `SBOM_SIGNING_KEY_PATH` è configurato, l'endpoint di export firma il documento JSON CycloneDX usando il campo `signature` di CycloneDX (supporta RSA/ECDSA). Prova l'integrità dell'SBOM per le presentazioni regolamentari.

**Step 4 — Condizione di policy per la completezza SBOM.** Aggiungere `SbomCompletenessEvaluator.java` a `policy/`:
- Verifica che tutti i componenti abbiano almeno uno di: purl valido, cpe o hash
- Verifica che tutti i componenti abbiano una `version` (i componenti senza versione non possono essere abbinati alle vulnerabilità)
- Segnala i componenti con `is_internal = false` che non hanno `license_id`
- Le violazioni sono di tipo `OPERATIONAL`, attivando il flusso di policy esistente

**Step 5 — Export per le autorità di sorveglianza del mercato.** Aggiungere un endpoint `GET /api/v1/project/{uuid}/cra-technical-documentation` che raggruppa:
- SBOM corrente (CycloneDX con vulnerabilità e VEX)
- `CybersecurityRiskAssessment` approvato corrente (da GAP 7)
- Documento di policy CVD (da GAP 4)
- Record `CraReportingObligation` attivi (da GAP 2)
- Informazioni sul periodo di supporto (da GAP 1)

Restituisce un archivio ZIP. Soddisfa direttamente l'Articolo 13(22) ("fornire... tutte le informazioni e la documentazione... necessarie a dimostrare la conformità").

### Stima

| Voce | Giorni |
|------|--------|
| Step 1: Flag `Bom.is_current` + semantica artefatto versionato in `BomUploadProcessingTask` + migrazione DB | 1,0 |
| Step 2: Export SBOM arricchito — array `vulnerabilities`, dichiarazioni VEX, `metadata.lifecycles`, `metadata.supplier` | 3,0 |
| Step 3: Firma SBOM tramite JCA — configurazione chiave, firma RSA/ECDSA, iniezione campo `signature` CycloneDX | 2,0 |
| Step 4: Valutatore policy `SbomCompletenessEvaluator` (3 check di completezza + violazioni `OPERATIONAL`) | 1,5 |
| Step 5: Endpoint ZIP `/cra-technical-documentation` (aggrega output da GAP 1,2,4,7) | 1,0 |
| **Totale** | **8,5** |

---

## GAP 11 — Tracciamento degli Incidenti Gravi e Notifica al CSIRT

### Requisito CRA

**Articolo 14(3)-(5):** I fabbricanti devono segnalare gli **incidenti gravi** (incidenti che incidono negativamente sulla disponibilità/autenticità/integrità/riservatezza dei dati sensibili o portano all'esecuzione di codice malevolo) entro:
- **24 ore**: allerta precoce
- **72 ore**: notifica completa dell'incidente
- **1 mese**: relazione finale

Un incidente grave deve essere segnalato simultaneamente al CSIRT designato come coordinatore e all'ENISA.

### Stato attuale di DT

DT ha `PolicyViolation` con tipi `SECURITY / LICENSE / OPERATIONAL`. Ha `Analysis` per il tracciamento per singolo finding di vulnerabilità. Non ha un concetto di "incidente grave" come definito dal CRA. Non esiste un ciclo di vita degli incidenti distinto dal triage delle vulnerabilità.

### Il gap

Nessuna entità `SevereIncident`, nessun tracciamento della tempistica dell'incidente, nessuna integrazione di notifica al CSIRT/ENISA, nessun flusso di segnalazione strutturato dell'incidente distinto dal triage dei finding.

### Approccio implementativo

**Step 1 — Aggiungere un'entità `SevereIncident`:**

```java
// Nuovo model/SevereIncident.java
// Campi:
//   project: Project
//   title: String
//   description: CLOB
//   incident_type: malicious_code_introduced | availability_impacted |
//                  integrity_violated | confidentiality_violated | other
//   detected_at: Timestamp
//   severity: Severity
//   affected_versions: String? (testo libero o intervallo di versioni strutturato)
//   linked_vulnerabilities: Set<Vulnerability>
//   linked_findings: Set<Finding>
//   is_suspected_malicious: Boolean (richiesto dall'Articolo 14(4)(a))
//   status: detected | early_warning_submitted | notification_submitted |
//           final_report_submitted | closed
//   early_warning_due_at: Timestamp   // detected_at + 24h
//   notification_due_at: Timestamp    // detected_at + 72h
//   final_report_due_at: Timestamp    // notification_submitted_at + 30 giorni
//   affected_member_states: Set<String>  // ISO 3166-1 alpha-2
//   root_cause: String?
//   mitigation_measures_taken: CLOB?
//   mitigation_measures_available_to_users: CLOB?
//   comments: SevereIncidentComment con incident = this
```

**Step 2 — Regole del ciclo di vita dell'incidente.** Collegare al `TaskScheduler` esistente per l'escalation delle scadenze (stesso pattern di `CraReportingObligation` da GAP 2).

**Step 3 — Integrazione notifica CSIRT/ENISA.** Aggiungere un nuovo `CsirtNotificationPublisher.java`. Quando un incidente raggiunge lo stato `early_warning_submitted`, il publisher:
- Formatta la segnalazione secondo la struttura dell'Articolo 14(4)(a)
- Invia via POST all'endpoint CSIRT configurato (configurabile tramite `application.properties`: `cra.csirt.endpoint`, `cra.enisa.endpoint`)
- Registra il timestamp di invio e la risposta

È strutturalmente identico all'`AbstractWebhookPublisher` esistente ma con payload strutturato per il CRA.

**Step 4 — Creazione automatica degli incidenti da hit KEV.** Quando `is_actively_exploited` transita a `true` per una vulnerabilità che interessa un progetto (da GAP 2 mirror KEV), creare automaticamente una bozza di `SevereIncident` con stato `detected`. L'analista conferma o scarta. Previene che la scadenza delle 24 ore venga mancata perché l'analista non ha notato la notifica.

**Step 5 — REST API.** Nuovo `resources/v1/SevereIncidentResource.java` con CRUD completo + transizioni del ciclo di vita.

### Stima

| Voce | Giorni |
|------|--------|
| Step 1: Entità `SevereIncident` — campi complessi, macchina a stati, collezioni collegate, `QueryManager`, migrazione DB | 2,0 |
| Step 2: Job di escalation scadenze `TaskScheduler` per soglie 24h/72h/30 giorni | 1,0 |
| Step 3: `CsirtNotificationPublisher` — payload strutturato Art 14(4), webhook CSIRT/ENISA, registrazione risposta | 1,5 |
| Step 4: Auto-bozza `SevereIncident` alla transizione `activelyExploited` KEV + azione analista conferma/scarta | 0,5 |
| Step 5: `SevereIncidentResource` — CRUD completo + endpoint di transizione ciclo di vita | 1,5 |
| **Totale** | **6,5** |

---

## GAP 12 — Identificazione del Prodotto (Numero di Lotto/Seriale)

### Requisito CRA

**Articolo 13(15):** "I fabbricanti devono garantire che i loro prodotti con elementi digitali rechino un **tipo, numero di lotto o di serie** o altro elemento che ne consenta l'identificazione, oppure... che tali informazioni siano fornite sulla confezione o in un documento allegato al prodotto."

### Stato attuale di DT

`Project` ha: `name`, `version`, `group`, `purl`, `cpe`, `swidTagId`. Questi sono sufficienti per i prodotti software distribuiti come pacchetti (purl o CPE li identificano univocamente). Tuttavia, per i prodotti hardware o firmware embedded dove i numeri di lotto/seriale sono rilevanti, non esiste supporto nel modello.

### Il gap

Gap minore per i casi d'uso puramente software (purl copre l'identificazione), ma significativo per firmware, sistemi embedded e prodotti IoT che il CRA copre esplicitamente. Nessun campo `batch_number`, `serial_number` o `hardware_revision` su `Project`.

### Approccio implementativo

**Step 1 — Aggiungere campi di identificazione a `Project`:**

```java
@Persistent
@Column(name = "BATCH_NUMBER", jdbcType = "VARCHAR", length = 255, allowsNull = "true")
private String batchNumber;

@Persistent
@Column(name = "HARDWARE_REVISION", jdbcType = "VARCHAR", length = 255, allowsNull = "true")
private String hardwareRevision;
```

Questi sono campi opzionali. Per i prodotti software, gli identificatori primari restano `purl`/`cpe`/`swidTagId` esistenti. Per i progetti hardware/firmware, forniscono il meccanismo di identificazione dell'Articolo 13(15) del CRA.

**Step 2 — Aggiungere all'API `ProjectResource` e all'importazione BOM.** Quando si importa un BOM CycloneDX per un progetto hardware/firmware, mappare `metadata.component.bom-ref` a `batchNumber` e qualsiasi proprietà specifica hardware a `hardwareRevision`.

### Stima

| Voce | Giorni |
|------|--------|
| Step 1: 2 campi opzionali su `Project` + migrazione DB | 0,5 |
| Step 2: Estensione GET/PUT `ProjectResource` + mapping importazione BOM CycloneDX | 0,5 |
| **Totale** | **1,0** |

---

## GAP 13 — Policy di Conservazione degli Aggiornamenti di Sicurezza (Requisito 10 Anni)

### Requisito CRA

**Articolo 13(9):** "Ciascun aggiornamento di sicurezza... reso disponibile agli utenti durante il periodo di supporto, resta disponibile dopo la sua pubblicazione per un **minimo di 10 anni** o per la durata residua del periodo di supporto, se superiore."

### Stato attuale di DT

DT traccia i finding e i loro stati di analisi, ma non ha il concetto di "aggiornamenti di sicurezza" come artefatti discreti. Non traccia quale versione di patch ha risolto quale finding, né la distribuzione o la conservazione degli aggiornamenti di sicurezza.

### Il gap

DT non dispone di un meccanismo per tracciare che un aggiornamento di sicurezza è stato pubblicato, cosa conteneva, quando è stato reso disponibile e per quanto tempo deve essere conservato. L'obbligo di conservazione decennale non è applicabile tramite il modello attuale di DT.

### Approccio implementativo

**Step 1 — Aggiungere un'entità `SecurityUpdate`:**

```java
// Nuovo model/SecurityUpdate.java
// Campi:
//   project: Project
//   version: String (la versione che contiene la correzione)
//   release_date: Timestamp
//   update_type: security_only | combined (CRA Allegato I Parte II(2) preferisce security_only)
//   is_free_of_charge: Boolean (richiesto dall'Allegato I Parte II(8))
//   download_url: String?
//   advisory_url: String?
//   addressed_vulnerabilities: Set<Vulnerability>
//   addressed_findings: Set<Finding>
//   retain_until: Timestamp  // release_date + max(10 anni, durata_residua_periodo_supporto)
//   description: CLOB
//   linked_bom: Bom?  // il BOM caricato per questa versione aggiornata
```

**Step 2 — Collegare al flusso di caricamento BOM esistente.** Quando viene caricato un BOM e `BomUploadProcessingTask` termina, se la nuova versione ha meno finding della precedente (ossia alcune vuln sono state corrette), suggerire automaticamente la creazione di un record `SecurityUpdate`. L'analista conferma con la data di rilascio e l'URL dell'advisory.

**Step 3 — Avviso di conservazione.** Aggiungere al `TaskScheduler` un check mensile che avverta (`SecurityUpdateRetentionDue`) quando `SecurityUpdate.retain_until` è entro 90 giorni. Dà agli operatori il tempo di garantire che l'aggiornamento rimanga accessibile.

**Step 4 — Endpoint REST.** `GET /api/v1/project/{uuid}/security-updates` restituisce lo storico degli aggiornamenti. È l'"archivio pubblico del software" ai sensi dell'Articolo 13(11) del CRA.

### Stima

| Voce | Giorni |
|------|--------|
| Step 1: Entità `SecurityUpdate` + calcolo `retain_until` + `QueryManager` + migrazione DB | 1,0 |
| Step 2: Integrazione flusso upload BOM — rilevamento delta finding + suggerimento creazione `SecurityUpdate` | 1,5 |
| Step 3: Job mensile `TaskScheduler` per avviso conservazione + notifica `SecurityUpdateRetentionDue` | 0,5 |
| Step 4: Endpoint `GET /api/v1/project/{uuid}/security-updates` | 0,5 |
| **Totale** | **3,5** |

---

## GAP 14 — Gestione della Dichiarazione di Conformità UE (DoC)

### Requisito CRA

**Articolo 28, Allegato V:** I fabbricanti devono redigere una Dichiarazione di Conformità UE per ciascun prodotto. Deve contenere: identificazione del prodotto, dati del fabbricante, dichiarazione di rispetto dei requisiti CRA, riferimenti agli standard armonizzati/certificazioni applicati.

**Articolo 13(20):** I fabbricanti devono fornire con il prodotto una copia della DoC UE (o una DoC semplificata con URL alla versione completa).

**Articolo 13(13):** I fabbricanti devono tenere la DoC "a disposizione delle autorità di sorveglianza del mercato per almeno **10 anni**."

### Stato attuale di DT

Nessuna entità DoC, nessuna gestione della conformità, nessuna gestione di documenti regolamentari UE di alcun tipo.

### Il gap

Dependency-Track non ha un concetto di dichiarazioni di conformità. Questo è il gap più orientato alla "gestione documentale di conformità". Tuttavia, poiché DT è già il sistema di riferimento per la postura di sicurezza, è il luogo naturale per generare e archiviare la DoC — popolata dai dati DT esistenti.

### Approccio implementativo

**Step 1 — Aggiungere un'entità `DeclarationOfConformity`:**

```java
// Nuovo model/DeclarationOfConformity.java
// Campi:
//   project: Project
//   doc_version: String
//   issued_at: Timestamp
//   issued_by: User
//   manufacturer_name: String
//   manufacturer_address: String
//   manufacturer_contact: String
//   applied_standards: Set<String> (es. "ETSI EN 303 645", "ISO/IEC 27001")
//   applied_certifications: Set<String>
//   csaf_provider_url: String? (URL del feed CSAF di DT)
//   status: draft | issued | superseded | withdrawn
//   retain_until: Timestamp  // issued_at + 10 anni
//   linked_risk_assessment: CybersecurityRiskAssessment
//   signature: String? (firma digitale)
```

**Step 2 — Endpoint di generazione DoC.** `POST /api/v1/project/{uuid}/declaration-of-conformity` auto-popola da:
- Metadati del progetto (name, version, purl)
- `CybersecurityRiskAssessment` approvato corrente
- Policy CVD collegata
- Dati del periodo di supporto
- Standard/certificazioni collegati (inseriti manualmente)

Restituisce un PDF o JSON strutturato conforme alla struttura dell'Allegato V.

**Step 3 — URL pubblico della DoC.** Ogni DoC emessa ottiene un permalink pubblico: `GET /api/v1/doc/{uuid}` (senza autenticazione). È l'URL incluso nella documentazione del prodotto ai sensi dell'Articolo 13(20). Implementa l'"indirizzo internet al quale si può accedere alla dichiarazione di conformità UE" ai sensi dell'Allegato II(6).

### Stima

| Voce | Giorni |
|------|--------|
| Step 1: Entità `DeclarationOfConformity` + calcolo `retain_until` + `QueryManager` + migrazione DB | 1,0 |
| Step 2: Endpoint generazione DoC — JSON struttura Allegato V + rendering PDF (Apache PDFBox o iText) | 2,5 |
| Step 3: Endpoint permalink pubblico senza autenticazione | 0,5 |
| **Totale** | **4,0** |

---

## Tabella Riepilogativa

| # | Gap | Riferimento CRA | Priorità | Sforzo |
|---|-----|----------------|----------|--------|
| 1 | Tracciamento del periodo di supporto | Art 13(8,9,19) | **Critica** | Medio |
| 2 | Segnalazione vuln attivamente sfruttate + CISA KEV | Art 14(1,2) | **Critica** | Medio |
| 3 | Output advisory strutturato CSAF | Art 14(8), Allegato I Parte II(4) | **Critica** | Alto |
| 4 | Gestione policy CVD | Allegato I Parte II(5), Allegato VII(2b) | **Critica** | Medio |
| 5 | Ricezione segnalazioni vuln esterne | Allegato I Parte II(6), Art 13(17) | **Critica** | Alto |
| 6 | Tracciamento disponibilità patch/correzioni | Allegato I Parte II(2,4,8) | **Alta** | Medio |
| 7 | Valutazione rischio cybersicurezza per prodotto | Art 13(2,3,4), Allegato VII(3) | **Alta** | Alto |
| 8 | Notifica fine supporto | Art 13(19,11) | **Alta** | Basso |
| 9 | Notifica leggibile dalle macchine agli utenti | Art 14(8) | **Alta** | Medio |
| 10 | Completezza SBOM + export formato CRA | Allegato I Parte II(1), Allegato VII(2b) | **Alta** | Medio |
| 11 | Tracciamento incidenti gravi + notifica CSIRT | Art 14(3,4,5) | **Alta** | Alto |
| 12 | Identificazione prodotto (lotto/seriale) | Art 13(15) | **Media** | Basso |
| 13 | Conservazione aggiornamenti sicurezza (10 anni) | Art 13(9) | **Media** | Basso |
| 14 | Dichiarazione di Conformità UE | Art 28, Allegato V | **Media** | Medio |

---

## Ordine di implementazione raccomandato

**Fase 1 — Modello dati fondamentale (prerequisito per tutto il resto)**
1. GAP 1: campi del periodo di supporto su `Project`
2. GAP 2 Step 1: `is_actively_exploited` su `Vulnerability` + task mirror CISA KEV
3. GAP 6 Step 1: `patchedVersions` su `Vulnerability`, aggiornamento parser

**Fase 2 — Entità del ciclo di vita regolamentare**
4. GAP 4: entità `CvdPolicy` + endpoint security.txt
5. GAP 5: entità `InboundVulnerabilityReport` + endpoint pubblico di ricezione
6. GAP 2 Step 2-6: `CraReportingObligation` + tracciamento 24h/72h/14 giorni
7. GAP 11: entità `SevereIncident` + tracciamento tempistiche

**Fase 3 — Output e advisory**
8. GAP 3: publisher CSAF + entità `SecurityAdvisory` + endpoint feed advisory
9. GAP 9: registro `NotificationSubscriber` + distribuzione CSAF
10. GAP 10: export SBOM arricchito con vuln + VEX + firma

**Fase 4 — Documentazione di conformità**
11. GAP 7: entità `CybersecurityRiskAssessment` + checklist Allegato I
12. GAP 8: valutatore policy rischio EOL + mirror endoflife.date
13. GAP 13: entità `SecurityUpdate` + tracciamento conservazione
14. GAP 14: entità `DeclarationOfConformity` + generazione PDF
15. GAP 12: campi numero lotto/seriale (banale, può essere fatto in qualsiasi momento)

---

## Riepilogo delle Stime

### Riepilogo per gap

| Gap | Titolo | Giorni |
|-----|--------|-------:|
| GAP 1 | Tracciamento del periodo di supporto | 5,0 |
| GAP 2 | Segnalazione vuln attivamente sfruttate + CISA KEV | 7,0 |
| GAP 3 | Output advisory strutturato CSAF | 9,5 |
| GAP 4 | Gestione policy CVD | 4,5 |
| GAP 5 | Ricezione segnalazioni vuln esterne | 8,5 |
| GAP 6 | Tracciamento disponibilità patch/correzioni | 7,0 |
| GAP 7 | Valutazione rischio cybersicurezza per prodotto | 8,0 |
| GAP 8 | Notifica fine supporto | 4,5 |
| GAP 9 | Notifica leggibile dalle macchine agli utenti | 5,0 |
| GAP 10 | Completezza SBOM + export formato CRA | 8,5 |
| GAP 11 | Tracciamento incidenti gravi + notifica CSIRT | 6,5 |
| GAP 12 | Identificazione prodotto (lotto/seriale) | 1,0 |
| GAP 13 | Conservazione aggiornamenti sicurezza (10 anni) | 3,5 |
| GAP 14 | Dichiarazione di Conformità UE | 4,0 |
| **Totale grezzo** | | **82,5** |

### Suddivisione per fase

| Fase | Gap | Giorni |
|------|-----|-------:|
| Fase 1 — Modello dati fondamentale | GAP 1, GAP 2 (Step 1-2), GAP 6 (Step 1) | ~11,5 |
| Fase 2 — Entità ciclo di vita regolamentare | GAP 4, GAP 5, GAP 2 (Step 3-6), GAP 11 | ~24,5 |
| Fase 3 — Output e advisory | GAP 3, GAP 9, GAP 10 | ~23,0 |
| Fase 4 — Documentazione di conformità | GAP 7, GAP 8, GAP 13, GAP 14, GAP 12 | ~21,0 |
| **Subtotale** | | **80,0** |

> I subtotali per fase differiscono leggermente dai totali per gap perché alcuni step sono suddivisi tra più fasi.

### Contingenza

Una contingenza del 15% è applicata per: imprevisti con la bytecode enhancement JDO di DataNucleus, casi limite delle migrazioni di schema sui quattro database supportati (H2, PostgreSQL, MySQL, MSSQL), complessità di integrazione cross-gap emersa durante l'implementazione e cicli di revisione del codice.

| | Giorni |
|-|-------:|
| Totale grezzo | 82,5 |
| Contingenza (15%) | 12,5 |
| **Totale rettificato** | **95,0** |

### Conversione in calendario (singolo sviluppatore)

| Scenario | Giorni lavorativi | Tempo calendario approssimativo |
|----------|------------------|---------------------------------|
| Stima grezza, 1 sviluppatore | 82,5 | ~4,1 mesi |
| Stima rettificata, 1 sviluppatore | 95,0 | ~4,8 mesi |
| 2 sviluppatori in parallelo (Fasi 1+2 ‖ Fasi 3+4) | 95,0 ÷ 1,7\* | ~2,8 mesi |
| 3 sviluppatori in parallelo (suddivisi per fase) | 95,0 ÷ 2,4\* | ~2,0 mesi |

\* Il fattore di parallelizzazione è sub-lineare per via delle dipendenze tra entità condivise (l'output CSAF GAP 3 è dipendenza per GAP 8, 9, 10; i dati KEV GAP 2 sono consumati da GAP 11 e GAP 5).

### Cosa è escluso dalle stime

- Modifiche al frontend Vue (UI ciclo di vita progetto, superfici di triage, visualizzatore advisory, visualizzatore DoC)
- Aggiornamenti documentazione OpenAPI/Swagger
- Test QA e di accettazione end-to-end
- Tempo di code review per le PR
- Deployment, configurazione infrastrutturale e gestione delle chiavi per la firma SBOM
- Test di integrazione endpoint CSIRT/ENISA (richiede un ambiente di test CSIRT reale)
- Documentazione utente e guide per gli operatori
