# BDD Test Suite — Piattaforma CRA/NIS2
## Scenari End-to-End in formato Gherkin

**Framework:** Cucumber (Java) + REST Assured + Testcontainers  
**Scope:** Copertura completa di tutte le funzionalità del sistema (CSV step4_1INPUT)  
**Convenzioni:**
- `Given` → stato precondizione
- `When` → azione utente/sistema
- `Then` → asserzione verificabile
- `And` → continuazione di uno dei tre precedenti

---

## Feature: M1.1 — Catalogo Modelli Macchina

```gherkin
Feature: Catalogo prodotti e versioning modelli

  Background:
    Given un utente con ruolo "ProductManager" è autenticato
    And il sistema è operativo con Dependency-Track configurato

  Scenario: Creazione nuovo modello macchina con classificazione CRA
    Given non esiste nessun prodotto con codice "PLC-X100"
    When l'utente invia una richiesta POST a "/api/products" con body:
      """json
      {
        "name": "PLC Serie X100",
        "code": "PLC-X100",
        "variants": ["Modello base", "Modello espanso"],
        "classification_cra": "class_i"
      }
      """
    Then la risposta ha status 201
    And la risposta contiene il campo "id" non nullo
    And il prodotto "PLC-X100" è presente nel database con "classification_cra" = "class_i"
    And un evento "PRODUCT_CREATED" è registrato nell'audit trail

  Scenario: Versioning hardware/firmware/software per modello
    Given esiste un prodotto con id "prod-001"
    When l'utente crea una versione con POST a "/api/products/prod-001/versions" con body:
      """json
      {
        "hw_version": "rev-B",
        "fw_version": "2.3.1",
        "sw_version": "5.1.0",
        "market_date": "2024-01-15"
      }
      """
    Then la risposta ha status 201
    And la versione contiene "dt_project_id" non nullo
    And un project-version con nome "PLC Serie X100 5.1.0" esiste in Dependency-Track

  Scenario: Validazione periodo di supporto minimo CRA (5 anni)
    Given esiste un prodotto con id "prod-001" e versione "vers-001" con market_date "2024-01-15"
    When l'utente imposta "eos_date" = "2027-01-15" (3 anni dalla market_date)
    Then la risposta ha status 422
    And la risposta contiene errore "EOS_DATE_BELOW_CRA_MINIMUM"
    And il messaggio indica "La data di fine supporto deve essere almeno 5 anni dopo la data di immissione sul mercato"

  Scenario: Classificazione CRA determina requisiti CVD policy
    Given esiste un prodotto con id "prod-001" classificato "class_ii"
    And non esiste nessuna CVD policy per il prodotto
    When l'utente richiede GET a "/api/products/prod-001"
    Then la risposta contiene "warnings": ["NO_CVD_POLICY_REQUIRED_FOR_CLASS_II"]
    And il warning indica che la CVD policy è obbligatoria per prodotti Classe II

  Scenario: Lista prodotti con filtro per classificazione
    Given esistono 3 prodotti: 2 classificati "class_i" e 1 "default"
    When l'utente richiede GET a "/api/products?classification_cra=class_i"
    Then la risposta contiene esattamente 2 prodotti
    And tutti i prodotti nella risposta hanno "classification_cra" = "class_i"
```

---

## Feature: M1.2 — CVD Policy e Canale Inbound

```gherkin
Feature: CVD Policy e ricezione segnalazioni vulnerabilità esterne

  Scenario: Creazione e pubblicazione CVD policy per prodotto
    Given esiste un prodotto con id "prod-001"
    And l'utente ha ruolo "SecurityManager"
    When l'utente crea una CVD policy con POST a "/api/cvdpolicies" con body:
      """json
      {
        "product_id": "prod-001",
        "policy_text": "La nostra politica CVD prevede...",
        "policy_url": "https://example.com/security/cvd",
        "contact_email": "security@example.com",
        "disclosure_deadline_days": 90
      }
      """
    Then la risposta ha status 201
    And la policy ha "version" = "1.0"
    And la policy ha "is_published" = false

    When l'utente esegue POST a "/api/cvdpolicies/{policyId}/publish"
    Then la risposta ha status 200
    And la policy ha "is_published" = true
    And un record storico è creato in "cvd_policy_revision" per la versione "1.0"

  Scenario: Versionamento automatico CVD policy su modifica
    Given esiste una CVD policy pubblicata alla versione "1.0"
    When l'utente aggiorna il testo con PUT a "/api/cvdpolicies/{policyId}"
    Then la risposta ha status 200
    And la nuova versione ha "version" = "1.1"
    And la versione precedente "1.0" è conservata in storico
    And l'audit trail contiene due record: vecchio e nuovo valore del campo "policy_text"

  Scenario: Ereditarietà policy CVD a livello organizzativo
    Given esiste una CVD policy organizzativa (product_id = null)
    And esiste un prodotto "prod-002" senza CVD policy specifica
    When l'utente richiede GET a "/api/products/prod-002/cvdpolicy"
    Then la risposta ha status 200
    And la risposta contiene la policy organizzativa con campo "inherited" = true

  Scenario: Ricezione segnalazione vulnerabilità esterna (CVD inbound)
    Given l'endpoint pubblico "/api/vulnerability-reports" è attivo senza autenticazione
    When un ricercatore esterno invia POST con body:
      """json
      {
        "product_code": "PLC-X100",
        "reporter_name": "Mario Rossi",
        "reporter_contact": "mario@example.com",
        "report_body": "Ho trovato una vulnerabilità di buffer overflow nel modulo di rete...",
        "cvss_reporter_score": 8.5
      }
      """
    Then la risposta ha status 201
    And la risposta contiene "tracking_id" non nullo
    And un alert "NEW_EXTERNAL_VULNERABILITY_REPORT" è inviato al team sicurezza via Slack
    And il record "InboundVulnerabilityReport" è in stato "received"

  Scenario: Verifica stato segnalazione via tracking ID (pubblico, no auth)
    Given esiste una segnalazione con tracking_id "TRK-2024-001" in stato "triaging"
    When il ricercatore richiede GET a "/api/vulnerability-reports/TRK-2024-001/status" senza autenticazione
    Then la risposta ha status 200
    And la risposta contiene "status" = "triaging"
    And la risposta NON contiene dati interni (nomi analisti, note interne, ecc.)

  Scenario: Rate limiting sul canale inbound pubblico
    Given l'endpoint pubblico è attivo
    When lo stesso IP invia 11 richieste POST in 60 secondi
    Then la 11esima richiesta riceve status 429
    And il header "Retry-After" è presente nella risposta
```

---

## Feature: M1.3 — Registro Clienti e Installed Base

```gherkin
Feature: Anagrafica clienti B2B e installed base

  Background:
    Given l'utente ha ruolo "CustomerSuccess" o superiore

  Scenario: Creazione anagrafica cliente B2B con classificazione NIS2
    When l'utente crea un cliente con POST a "/api/customers" con body:
      """json
      {
        "company_name": "Autostrade per l'Italia S.p.A.",
        "vat_number": "IT01067090589",
        "sector": "TRANSPORT",
        "nis2_classification": "essential",
        "country": "IT"
      }
      """
    Then la risposta ha status 201
    And il cliente ha "nis2_classification" = "essential"

  Scenario: Aggiunta referente sicurezza al cliente
    Given esiste un cliente con id "cust-001"
    When l'utente crea un contatto con POST a "/api/customers/cust-001/contacts" con body:
      """json
      {
        "name": "Giuseppe Verdi",
        "email": "g.verdi@autostrade.it",
        "role": "security",
        "is_primary_security_contact": true,
        "notification_channel": "email"
      }
      """
    Then la risposta ha status 201
    And il contatto è "is_primary_security_contact" = true

  Scenario: Registrazione installazione (installed base)
    Given esiste un cliente "cust-001" e una versione prodotto "vers-001"
    When l'utente crea un'installazione con POST a "/api/installations" con body:
      """json
      {
        "customer_id": "cust-001",
        "product_version_id": "vers-001",
        "site_name": "Sede Milano Lambrate",
        "site_address": "Via Test 1, Milano",
        "install_date": "2023-06-01",
        "support_contract_status": "active",
        "support_contract_expiry": "2028-06-01"
      }
      """
    Then la risposta ha status 201
    And l'installazione è visibile nella GET a "/api/customers/cust-001/installations"

  Scenario: Vista installazioni per cliente con stato contratto
    Given il cliente "cust-001" ha 3 installazioni: 2 active e 1 expired
    When l'utente richiede GET a "/api/customers/cust-001/installations"
    Then la risposta contiene 3 installazioni
    And ogni installazione mostra "support_contract_status"
    And le installazioni expired hanno un warning visibile nel response

  Scenario: Gestione sedi multiple per cliente
    Given il cliente "cust-001" ha sede a "Milano" e sede a "Roma"
    When l'utente richiede GET a "/api/customers/cust-001/installations?group_by=site"
    Then la risposta mostra le installazioni raggruppate per sede geografica
    And ogni sede mostra il numero di prodotti installati

  Scenario: Storico comunicazioni per cliente
    Given il cliente "cust-001" ha ricevuto 3 notifiche di sicurezza
    When l'utente richiede GET a "/api/customers/cust-001/communications"
    Then la risposta contiene 3 comunicazioni in ordine cronologico decrescente
    And ogni comunicazione mostra: data, tipologia, prodotto, CVE, stato acknowledgment
```

---

## Feature: M2.1 — Acquisizione SBOM

```gherkin
Feature: Import e validazione SBOM

  Background:
    Given esiste una versione prodotto "PLC-X100 v5.1.0" con id "vers-001"
    And l'utente ha ruolo "DevOps" o superiore

  Scenario: Import SBOM CycloneDX valida da file
    When l'utente carica un file CycloneDX valido con POST a "/api/products/prod-001/versions/vers-001/sbom"
    And il file contiene 25 componenti tutti con PURL valido
    Then la risposta ha status 202
    And dopo polling, lo stato SBOM è "synced_to_dt"
    And in DT il project "PLC-X100 5.1.0" mostra 25 componenti
    And un record "SbomImport" è creato con "source" = "MANUAL_UPLOAD"
    And il "file_hash" SHA-256 del file è salvato nel record
    And l'audit trail contiene "SBOM_IMPORTED" con operatore e timestamp

  Scenario: Import SBOM da pipeline CI/CD con API key
    When la pipeline CI/CD carica una SBOM con autenticazione API key (no JWT utente)
    Then la risposta ha status 202
    And il record "SbomImport" ha "source" = "CI_CD"
    And il campo "ci_commit_sha" è presente se passato nel body

  Scenario: Blocco import per componenti senza PURL/CPE
    When l'utente carica una SBOM con 2 componenti privi di PURL e CPE
    Then la risposta ha status 422
    And la risposta contiene lista "non_conformant_components" con i 2 componenti
    And ogni voce nella lista mostra nome, versione del componente
    And NESSUN dato è stato inviato a Dependency-Track
    And nessun record "SbomImport" è creato

  Scenario: Inserimento manuale singolo componente
    Given la SBOM di "vers-001" è in stato "synced_to_dt"
    When l'utente crea un componente manuale con POST a "/api/products/prod-001/versions/vers-001/components" con body:
      """json
      {
        "purl": "pkg:maven/org.openssl/openssl@3.0.7",
        "name": "OpenSSL",
        "version": "3.0.7",
        "supplier": "OpenSSL Foundation",
        "type": "library",
        "notes": "Libreria TLS per comunicazione SCADA"
      }
      """
    Then la risposta ha status 201
    And un record "SbomDelta" è creato con "operation" = "INSERT"
    And il record delta contiene "operator" e "timestamp"
    And DT viene aggiornato con il nuovo componente

  Scenario: Modalità ibrida — delta manuale richiede motivazione
    Given la SBOM di "vers-001" è stata importata da scanner (source = CI_CD)
    When l'utente tenta di modificare la versione di un componente scanner-rilevato SENZA nota
    Then la risposta ha status 422
    And la risposta contiene errore "DELTA_NOTE_REQUIRED_FOR_SCANNER_COMPONENTS"

  Scenario: Modalità ibrida — delta con motivazione accettato
    Given la SBOM di "vers-001" è stata importata da scanner
    When l'utente modifica la versione di un componente con nota "Aggiornamento per patch CVE-2024-0001"
    Then la risposta ha status 200
    And il record "SbomDelta" contiene la nota nel campo "reason"
    And il versioning SBOM incrementa il patch number

  Scenario: Validazione formato PURL e range di versione
    When l'utente invia un componente con PURL malformato "pkg:maven/openssl-3.0.7"
    Then la risposta ha status 422
    And la risposta contiene errore "INVALID_PURL_FORMAT"
```

---

## Feature: M2.2 — Versioning e Freeze SBOM

```gherkin
Feature: Versioning automatico e freeze SBOM

  Scenario: Versioning automatico a ogni import
    Given la SBOM corrente di "vers-001" è alla versione "1.2.4"
    When l'utente carica una SBOM con 3 componenti in più rispetto alla precedente
    Then la nuova versione SBOM è "1.3.0" (minor bump per componenti aggiunti)
    And entrambe le versioni SBOM sono accessibili tramite GET

  Scenario: Versioning patch su cambio versione componente
    Given la SBOM corrente è alla versione "1.3.0"
    When l'utente aggiorna un componente da versione "1.2.3" a "1.2.4"
    Then la nuova versione SBOM è "1.3.1" (patch bump)

  Scenario: Freeze SBOM per versione rilasciata
    Given la SBOM di "vers-001" è alla versione "1.3.1"
    And l'utente ha ruolo "SecurityManager"
    When l'utente esegue POST a "/api/products/prod-001/versions/vers-001/sbom/freeze"
    Then la risposta ha status 200
    And la SBOM ha "is_frozen" = true
    And l'audit trail registra "SBOM_FROZEN" con operatore e timestamp

  Scenario: Blocco modifica su SBOM frozen
    Given la SBOM di "vers-001" è frozen
    When qualsiasi utente tenta di caricare una nuova SBOM o aggiungere componenti
    Then la risposta ha status 403
    And la risposta contiene errore "SBOM_IS_FROZEN"
    And il tentativo è registrato nell'audit trail come "SBOM_MODIFICATION_BLOCKED_FROZEN"

  Scenario: Unfreeze richiede doppia autorizzazione
    Given la SBOM di "vers-001" è frozen
    When un utente con ruolo "Admin" richiede unfreeze SENZA nota motivazione
    Then la risposta ha status 422
    And la risposta contiene errore "UNFREEZE_NOTE_REQUIRED"

    When l'Admin richiede unfreeze con nota "Correzione errore in componente HW"
    Then la risposta ha status 200
    And la SBOM ha "is_frozen" = false
    And l'audit trail contiene "SBOM_UNFROZEN" con nota

  Scenario: Diff tra versioni SBOM
    Given la SBOM ha versione "1.2.4" (25 componenti) e versione "1.3.0" (27 componenti)
    When l'utente richiede GET a "/api/.../sbom/diff?from=1.2.4&to=1.3.0"
    Then la risposta contiene:
      | campo    | conteggio |
      | added    | 3         |
      | removed  | 1         |
      | updated  | 0         |
    And ogni componente nella lista "added" mostra PURL e versione
    And l'endpoint di export CSV funziona restituendo il diff in formato tabellare

  Scenario: Recupero versione SBOM specifica (storico)
    Given la SBOM ha 5 versioni storiche
    When l'utente richiede GET a "/api/.../sbom/versions/1.2.4"
    Then la risposta restituisce la SBOM CycloneDX esatta di quella versione
    And l'hash SHA-256 del file corrisponde a quello archiviato al momento dell'import
```

---

## Feature: M2.3 — VEX Workflow

```gherkin
Feature: VEX assessment con giustificazione obbligatoria

  Background:
    Given esiste un finding (CVE-2021-44228 su Log4j) per il progetto "PLC-X100 5.1.0"

  Scenario: Creazione VEX "not_affected" con giustificazione obbligatoria
    Given l'utente ha ruolo "SecurityAnalyst"
    When l'utente crea una decisione VEX con POST a "/api/findings/{findingId}/vex":
      """json
      {
        "state": "not_affected",
        "justification": "vulnerable_code_not_present",
        "notes": "Il modulo Log4j è incluso come dipendenza transitiva ma non viene mai inizializzato nell'applicazione"
      }
      """
    Then la risposta ha status 201
    And la decisione VEX ha "status" = "draft"
    And in DT il finding mostra stato "NOT_AFFECTED" (draft)

  Scenario: Blocco VEX "not_affected" senza giustificazione
    When l'utente invia VEX "not_affected" SENZA campo "justification"
    Then la risposta ha status 422
    And la risposta contiene errore "JUSTIFICATION_REQUIRED_FOR_NOT_AFFECTED"

  Scenario: Approvazione VEX da parte del Security Manager
    Given esiste una decisione VEX in stato "draft"
    And l'utente ha ruolo "SecurityManager"
    When l'utente esegue POST a "/api/findings/{findingId}/vex/{vexId}/approve"
    Then la risposta ha status 200
    And la decisione VEX ha "status" = "approved"
    And in DT il finding viene soppresso (stato SUPPRESSED o NOT_AFFECTED)
    And l'audit trail contiene "VEX_APPROVED" con approvatore e timestamp

  Scenario: Export VEX integrato nel CycloneDX output
    Given esistono 3 decisioni VEX approvate per il prodotto "PLC-X100 5.1.0"
    When l'utente richiede GET a "/api/products/prod-001/versions/vers-001/sbom?include_vex=true"
    Then la risposta è un documento CycloneDX valido
    And il documento contiene una sezione "vulnerabilities" con le 3 decisioni VEX
    And ogni decisione VEX include "analysis.state", "analysis.justification" e "analysis.detail"

  Scenario: Validazione giustificazioni VEX accettate
    When l'utente invia VEX "not_affected" con justification "invalid_reason"
    Then la risposta ha status 422
    And la risposta elenca le giustificazioni valide disponibili
```

---

## Feature: M3 — Vulnerability Intelligence

```gherkin
Feature: Vulnerability intelligence feed e matching

  Scenario: Match CVE tramite PURL esatto
    Given il componente "pkg:maven/org.openssl/openssl@3.0.7" è in SBOM di "vers-001"
    And il feed NVD contiene CVE-2023-0286 che affligge openssl < 3.0.8
    When DT esegue il matching
    Then il finding CVE-2023-0286 appare per il progetto "PLC-X100 5.1.0"
    And il finding ha "match_confidence" = "HIGH"

  Scenario: Score di confidenza LOW per match per nome senza versione
    Given un componente in SBOM ha solo nome "libssl" senza PURL e senza versione
    When DT trova una CVE che menziona "libssl" per nome
    Then il finding ha "match_confidence" = "LOW"
    And un alert "LOW_CONFIDENCE_MATCH" è inviato al team sicurezza

  Scenario: Flag CISA KEV su CVE matchata
    Given CVE-2021-44228 è nel catalogo CISA KEV
    And il componente Log4j 2.14.1 è in SBOM di "vers-001"
    When DT completa il matching
    Then il finding CVE-2021-44228 ha "is_kev" = true
    And un alert "KEV_MATCH_DETECTED" è inviato con priorità "CRITICAL"
    And un TriageItem è creato automaticamente con countdown 24h attivo

  Scenario: Parser CISA ICS-CERT Advisories
    Given il feed ICS-CERT contiene un advisory per "Siemens SCALANCE W700" con CVE-2024-12345
    When il scheduled task "IcsAdvMirrorTask" esegue
    Then CVE-2024-12345 è presente nel repository DT con tag "ics_cert=true" e "ot_relevant=true"
    And il campo "advisory_url" punta all'advisory originale CISA ICS-CERT

  Scenario: Match ICS-CERT su componente OT in SBOM
    Given CVE-2024-12345 (ICS-CERT) è in DT
    And il componente "Siemens SCALANCE W700 fw v4.1" è in SBOM di "vers-001"
    When DT esegue il matching
    Then il finding CVE-2024-12345 appare con tag "ics_cert=true"
    And il finding è visualizzato con badge "OT/ICS" nell'interfaccia di triage

  Scenario: End-of-support tracking componente senza CVE
    Given il task "EndOfLifeMirrorTask" ha caricato i dati da endoflife.date
    And il componente "pkg:npm/node@16" è in SBOM di "vers-001"
    And Node.js 16 è EOL dal 2023-09-11
    When il task di EoS check esegue
    Then una voce triage di tipo "EOL_RISK" è creata per "vers-001"
    And la voce ha "cve_id" = null e "eos_date" = "2023-09-11"
    And un alert "COMPONENT_EOL_DETECTED" è inviato

  Scenario: Alert variazione CVSS su CVE già nota
    Given il finding CVE-2023-0286 è in coda triage con CVSS = 7.5
    When NVD aggiorna il CVSS di CVE-2023-0286 a 9.1
    Then il finding nella coda mostra CVSS aggiornato = 9.1
    And un alert "CVSS_SCORE_INCREASED" è inviato al owner del triage item
    And l'audit trail registra la variazione con vecchio e nuovo valore
```

---

## Feature: M4.1 — Impact Analysis

```gherkin
Feature: Impact analysis automatica su installazioni clienti

  Background:
    Given esiste un prodotto "PLC-X100" con versione "v5.1.0"
    And la versione è installata in 12 siti: 4 clienti diversi
    And 2 clienti sono classificati "NIS2 essential"

  Scenario: Impact analysis automatica su webhook DT
    When DT rileva CVE-2021-44228 (KEV) su un componente della SBOM di "PLC-X100 v5.1.0"
    And invia il webhook al backend proprietario
    Then il backend crea automaticamente un "ImpactAnalysisResult" entro 30 secondi
    And il risultato contiene 12 installazioni impattate
    And le 2 installazioni NIS2 essential sono in cima alla lista (priority_rank 1 e 2)

  Scenario: Priorità NIS2 nella lista impatti
    Given il risultato impact analysis contiene installazioni NIS2 e non-NIS2
    When l'utente richiede GET a "/api/findings/{findingId}/impact"
    Then i clienti NIS2 essential appaiono prima dei clienti non-NIS2
    And ogni riga mostra: customer_name, product_version, site_name, nis2_flag, cvss_score, priority_rank

  Scenario: Performance impact analysis
    Given il sistema ha 5.000 installazioni distribuite su 200 versioni prodotto
    When un webhook DT arriva per un componente presente in 300 installazioni
    Then il "ImpactAnalysisResult" è disponibile entro 30 secondi
    And l'endpoint GET restituisce la lista paginata in < 2 secondi

  Scenario: Propagazione su componente condiviso cross-prodotto
    Given il componente "openssl@3.0.7" è presente in SBOM di "PLC-X100 v5.1.0" e "PLC-Y200 v3.0.0"
    When DT rileva CVE-2023-0286 su "openssl@3.0.7"
    Then l'impact analysis include installazioni di ENTRAMBE le versioni prodotto
    And il totale installazioni impattate è la somma delle installazioni di entrambi i prodotti

  Scenario: Export CSV lista prioritizzata
    Given esiste un impact analysis result con 25 installazioni
    When l'utente richiede GET a "/api/findings/{findingId}/impact?format=csv"
    Then la risposta è un file CSV con header: customer_name, product_version, site_name, install_date, nis2_flag, cvss_score, priority_rank, contact_name, contact_email
```

---

## Feature: M4.2 — Coda di Triage e SLA Timers

```gherkin
Feature: Coda triage normativa con timer SLA CRA

  Scenario: Creazione automatica TriageItem su KEV match
    When CVE-2021-44228 (KEV) è rilevata su "PLC-X100 v5.1.0"
    Then un TriageItem è creato automaticamente con:
      | campo          | valore                          |
      | state          | new                             |
      | is_kev         | true                            |
      | sla_24h_due    | ora_creazione + 24h             |
      | sla_72h_due    | ora_creazione + 72h             |
    And l'utente "unassigned" appare come owner (nessuno assegnato)

  Scenario: Alert SLA in scadenza — Early Warning
    Given un TriageItem KEV con sla_24h_due tra 5 ore
    When il scheduled task SLA check esegue
    Then un alert "SLA_24H_EXPIRING_SOON" è inviato a Slack con countdown visibile
    And l'alert indica il nome prodotto, CVE, e ore rimanenti

  Scenario: Alert SLA superata
    Given un TriageItem KEV con sla_24h_due superata da 1 ora
    And nessun Early Warning è stato inviato
    When il scheduled task SLA check esegue
    Then un alert "SLA_24H_MISSED" è inviato con priorità CRITICAL
    And il TriageItem è marcato con "sla_24h_missed" = true
    And un record è aggiunto nell'audit trail

  Scenario: Transizione di stato della coda triage
    Given un TriageItem in stato "new"
    When un SecurityAnalyst lo prende in carico (POST /api/triage/{id}/assign a se stesso)
    Then lo stato transita a "under_investigation"
    And il campo "owner_user_id" è impostato all'utente corrente
    And la transizione è registrata in "triage_item_history"

  Scenario: Blocco transizione di stato non valida
    Given un TriageItem in stato "new"
    When l'utente tenta di transitare direttamente a "notification_required"
    Then la risposta ha status 422
    And la risposta contiene "INVALID_STATE_TRANSITION: new → notification_required"

  Scenario: Risk score composito ordinamento coda
    Given la coda contiene 3 TriageItem:
      - Item A: CVSS=9.0, EPSS=0.50, KEV=true  → risk_score = (0.9×0.40)+(0.50×0.40)+(1×0.20) = 0.76
      - Item B: CVSS=9.8, EPSS=0.95, KEV=false → risk_score = (0.98×0.40)+(0.95×0.40)+(0×0.20) = 0.77
      - Item C: CVSS=7.0, EPSS=0.10, KEV=true  → risk_score = (0.7×0.40)+(0.10×0.40)+(1×0.20) = 0.52
    When l'utente richiede GET a "/api/triage?sort=risk_score"
    Then l'ordine è: Item B, Item A, Item C

  Scenario: Remediation plan con milestone
    Given un TriageItem in stato "notification_required"
    When l'utente crea un RemediationPlan con POST a "/api/triage/{id}/remediation-plan":
      """json
      {
        "expected_patch_date": "2024-03-15",
        "milestones": [
          {"title": "Patch disponibile in test", "date": "2024-03-01"},
          {"title": "Patch in produzione", "date": "2024-03-15"}
        ],
        "responsible_user_id": "user-123"
      }
      """
    Then la risposta ha status 201
    And il RemediationPlan è associato al TriageItem
    And le milestone sono ordinate per data

  Scenario: Alert TriageItem unassigned per più di 1 ora (KEV)
    Given un TriageItem KEV è creato e rimane unassigned per 61 minuti
    When il scheduled task esegue
    Then un alert "KEV_ITEM_UNASSIGNED" è inviato al SecurityManager
    And l'alert indica il TriageItem, il prodotto, e le ore trascorse
```

---

## Feature: M5-A — Notifica ACN/ENISA

```gherkin
Feature: Workflow notifica regolamentare ACN/ENISA

  Background:
    Given esiste un CraReportingObligation in stato "pending" per CVE-2021-44228
    And la sla_24h_due è tra 8 ore

  Scenario: Trigger automatico CraReportingObligation su KEV match
    When un TriageItem transita in stato "notification_required" con is_kev=true
    Then un CraReportingObligation è creato automaticamente con:
      | campo              | valore                     |
      | early_warning_due  | detected_at + 24h          |
      | notification_due   | detected_at + 72h          |
      | status             | pending                    |
    And il SecurityManager riceve un alert "CRA_OBLIGATION_CREATED"

  Scenario: Generazione e preview Early Warning 24h
    Given l'utente ha ruolo "SecurityManager"
    When l'utente richiede GET a "/api/cra-obligations/{id}/early-warning/preview"
    Then la risposta contiene un documento pre-compilato con:
      - nome prodotto e versione
      - CVE-ID e CVSS score
      - numero installazioni impattate
      - misure cautelari in corso (da RemediationPlan)
    And il documento NON è ancora inviato (solo preview)

  Scenario: Invio Early Warning 24h richiede approvazione
    Given l'utente ha ruolo "SecurityAnalyst" (non SecurityManager)
    When l'analista tenta POST a "/api/cra-obligations/{id}/early-warning/send"
    Then la risposta ha status 403
    And la risposta indica "APPROVAL_REQUIRED: SECURITY_MANAGER"

  Scenario: Invio Early Warning approvato da SecurityManager
    Given l'utente ha ruolo "SecurityManager"
    When l'utente approva e invia l'Early Warning
    Then la risposta ha status 200
    And il documento è inviato all'endpoint ACN configurato
    And "early_warning_sent_at" è impostato nel CraReportingObligation
    And il documento e il suo hash SHA-256 sono archiviati nel "regulatory_notification_log"
    And lo status nel log è "sent" con http_response_code dell'endpoint ACN

  Scenario: Notifica Formale 72h — contenuto strutturato
    Given l'Early Warning è stato inviato
    And il RemediationPlan contiene date e milestone
    When l'utente genera la Notifica Formale 72h
    Then il documento contiene:
      - PURL del componente vulnerabile
      - hash SHA-256 del componente
      - CVSS vettore completo e score
      - numero installazioni impattate divise per settore NIS2
      - piano di remediation con date
    And il documento è esportabile in formato JSON strutturato (CSAF-compatible)

  Scenario: Report Finale 14 giorni
    Given la Notifica Formale è stata inviata
    And la patch è stata rilasciata e le installazioni sono state aggiornate
    When l'utente invia il Report Finale con POST a "/api/cra-obligations/{id}/final-report/send"
    Then il report contiene: azioni intraprese, versione patch rilasciata, N/tot installazioni aggiornate
    And "final_report_sent_at" è impostato
    And lo status del CraReportingObligation transita a "completed"
    And il TriageItem associato transita a "closed"

  Scenario: Audit trail immutabile comunicazioni ACN/ENISA
    Given sono stati inviati 3 documenti ACN (EW + NF + RF)
    When l'utente richiede GET a "/api/cra-obligations/{id}/audit-log"
    Then la risposta mostra 3 record in ordine cronologico
    And ogni record contiene: sent_at, recipient, document_hash, http_response_code
    And nessun record può essere modificato o cancellato (verifica con tentativo DELETE → 405)

  Scenario: Distinzione visiva reporting regolatorio vs gestione interna
    When l'utente apre la scheda di un TriageItem con un CraReportingObligation attivo
    Then le azioni regolatorie (invio Early Warning, Notifica Formale, Report Finale) sono in sezione separata con badge "REGOLATORIO"
    And le azioni interne (VEX, assegnazione owner, note interne) sono in sezione distinta
    And un'azione interna (es. nota) NON è mai inviabile come comunicazione regolamentare

  Scenario: Export audit log con firma digitale
    When l'utente con ruolo CISO richiede export audit log per il prodotto "PLC-X100" nell'ultimo anno
    Then la risposta è un file CSV con ultima riga contenente l'hash SHA-256 dell'intero file
    And il file può essere verificato indipendentemente confrontando l'hash
```

---

## Feature: M5-B — Notifica Clienti B2B

```gherkin
Feature: Notifica clienti B2B con template e tracking

  Background:
    Given esiste un impact analysis result con 12 installazioni in 4 clienti
    And 2 clienti sono NIS2 essential, 2 non-NIS2

  Scenario: Creazione bozza notifica "advisory informativo" per tutti i clienti impattati
    Given l'utente ha ruolo "SecurityAnalyst"
    When l'utente crea bozze di notifica con POST a "/api/notifications/draft":
      """json
      {
        "triage_item_id": "item-001",
        "template_type": "advisory_informativo",
        "customer_ids": ["cust-001", "cust-002", "cust-003", "cust-004"]
      }
      """
    Then 4 CustomerNotification sono create in stato "draft"
    And ogni notifica è pre-compilata con i dati specifici del cliente e del prodotto installato

  Scenario: Preview template parametrico per cliente specifico
    Given esiste una bozza di notifica per il cliente "Autostrade per l'Italia"
    When l'utente richiede il preview
    Then il documento mostra: ragione sociale, nome referente, prodotto installato, versione, CVE, CVSS, azioni raccomandate
    And nessun altro cliente è menzionato nel documento

  Scenario: Workflow approvazione notifica 2 livelli
    Given una bozza di notifica in stato "draft"
    When l'analista esegue "submit-for-approval"
    Then lo stato diventa "pending_approval"
    And il SecurityManager riceve alert via Slack con link alla notifica

    When il SecurityManager approva
    Then lo stato diventa "approved"
    And l'email è inviata immediatamente al referente di sicurezza del cliente

  Scenario: Tracking invio e link acknowledgment
    Given una notifica è stata inviata al cliente
    When l'email raggiunge il destinatario e il referente clicca il link "Ho letto e compreso"
    Then il sistema registra: customer_notification_id, acked_at, ip_address del click
    And lo stato della notifica aggiorna "ack_received" = true
    And la dashboard mostra la notifica come "acknowledged"

  Scenario: Reminder automatico per mancato acknowledgment
    Given una notifica "advisory_informativo" è stata inviata 6 giorni fa
    And nessun acknowledgment è stato ricevuto (soglia configurata: 5 giorni)
    When il scheduled task reminder esegue
    Then una reminder email è inviata automaticamente
    And il log mostra "REMINDER_SENT" con timestamp

  Scenario: Notifica "blocco emergenziale" — percorso fast-track
    Given la CVE è KEV con CVSS 9.8 e sfruttamento attivo confermato
    When l'analista crea una notifica di tipo "blocco_emergenziale" e la flagga "is_emergency=true"
    Then il workflow di approvazione richiede solo firma del SecurityManager (non CISO)
    And dopo approvazione l'email è inviata entro 5 minuti (non batch)
    And l'audit trail registra "FAST_TRACK_EMERGENCY_NOTIFICATION"

  Scenario: Priorità NIS2 nella notifica — clienti essenziali ricevono entro 4 ore
    Given l'impact analysis mostra clienti NIS2 essential e non-NIS2
    When l'utente approva le notifiche per tutti i 4 clienti contemporaneamente
    Then le 2 notifiche per clienti NIS2 essential sono inviate per prime
    And un alert conferma l'invio ai clienti NIS2 essential entro 4 ore dall'approvazione

  Scenario: Storico comunicazioni per cliente
    Given il cliente "cust-001" ha ricevuto 5 notifiche negli ultimi 12 mesi
    When l'utente richiede GET a "/api/customers/cust-001/communications"
    Then la risposta mostra 5 comunicazioni ordinate per data decrescente
    And ogni comunicazione mostra: data, tipo, CVE, stato (draft/sent/acked/no_response)
```

---

## Feature: M5-C — Patch Campaign Management

```gherkin
Feature: Gestione campagne di remediation su installed base

  Scenario: Creazione campagna di remediation
    Given un TriageItem "item-001" con 12 installazioni impattate
    When l'utente crea una campagna con POST a "/api/campaigns":
      """json
      {
        "triage_item_id": "item-001",
        "title": "Patch OpenSSL CVE-2023-0286 — PLC-X100",
        "description": "Aggiornamento a OpenSSL 3.0.8 per tutte le installazioni",
        "target_patch_date": "2024-03-30"
      }
      """
    Then una PatchCampaign è creata con tutte le 12 installazioni in stato "pending"

  Scenario: Schedulazione finestra di intervento per installazione
    Given la campagna "camp-001" ha un'installazione nel sito "Roma Fiumicino" (cliente NIS2)
    When l'utente pianifica un intervento con PUT a "/api/campaigns/camp-001/installations/{instId}":
      """json
      {
        "status": "scheduled",
        "scheduled_date": "2024-03-15",
        "technician_name": "Luigi Bianchi",
        "maintenance_window_start": "08:00",
        "maintenance_window_end": "10:00"
      }
      """
    Then l'installazione mostra "status" = "scheduled" con dati tecnico e finestra

  Scenario: Tracciamento avanzamento campagna
    Given una campagna con 12 installazioni: 8 completed, 3 scheduled, 1 pending
    When l'utente richiede GET a "/api/campaigns/{id}/progress"
    Then la risposta mostra:
      | campo                | valore |
      | total_installations  | 12     |
      | completed            | 8      |
      | scheduled            | 3      |
      | pending              | 1      |
      | completion_pct       | 66.7   |
    And esiste un grafico/barchart dello stato per sede cliente

  Scenario: Alert patch non applicate su installazioni ad alto rischio
    Given una campagna ha un'installazione NIS2 essential in "pending" da 10 giorni
    And il threshold configurato è 7 giorni per NIS2 essential
    When il scheduled alert check esegue
    Then un alert "HIGH_RISK_INSTALLATION_PATCH_DELAYED" è inviato al SecurityManager
    And l'alert contiene: nome cliente, sito, prodotto, giorni trascorsi dall'inizio campagna
```

---

## Feature: M6 — Audit Trail, Alert System, Dashboard

```gherkin
Feature: Audit trail immutabile e granulare

  Scenario: Ogni operazione di scrittura genera record audit
    Given l'utente "analyst@example.com" modifica lo stato di un TriageItem
    Then nell'audit_log appare un record con:
      | campo       | valore                      |
      | user_id     | id dell'analyst             |
      | user_ip     | IP della richiesta          |
      | action      | TRIAGE_STATE_CHANGED        |
      | entity_type | TriageItem                  |
      | entity_id   | id del TriageItem           |
      | field_name  | state                       |
      | old_value   | new                         |
      | new_value   | under_investigation         |
      | timestamp   | UTC timestamp               |

  Scenario: Immutabilità del log — tentativo di UPDATE bloccato
    Given esiste un record audit_log con id "log-001"
    When qualsiasi utente (incluso Admin) tenta una UPDATE SQL diretta su "log-001"
    Then il database rifiuta con errore (rule o trigger PostgreSQL)
    And nessun record può essere cancellato dalla tabella audit_log

  Scenario: Export audit log con firma digitale per verifica esterna
    Given esistono 500 record audit log per il prodotto "PLC-X100" nell'ultimo anno
    When un utente CISO richiede export con GET a "/api/audit-log/export?product_id=prod-001&from=2023-01-01&to=2023-12-31"
    Then la risposta è un file CSV con 500 righe di dati
    And l'ultima riga del CSV è "HASH: {sha256_dell_intero_file}"
    And il file può essere verificato calcolando SHA-256 delle prime 499 righe

  Scenario: Alert nuova CVE su componente SBOM — canali multipli
    Given il sistema è configurato con Slack webhook e email SMTP per il team sicurezza
    When DT rileva una nuova CVE CRITICAL su un componente in produzione
    Then entro 5 minuti:
      - Un messaggio Slack arriva nel canale "#product-security"
      - Una email arriva ai destinatari configurati
      - Un webhook JSON è inviato all'endpoint ITSM configurato (se presente)

  Scenario: Integrazione Teams/Slack per alert real-time
    Given il sistema è configurato con Microsoft Teams webhook
    When qualsiasi alert di severity CRITICAL o HIGH è generato
    Then un messaggio Teams arriva nel channel configurato entro 2 minuti
    And il messaggio contiene: tipo alert, prodotto, CVE (se applicabile), link alla dashboard

  Scenario: Digest periodico management
    Given il sistema è configurato per digest settimanale al CISO
    When il lunedì mattina alle 08:00 il scheduler esegue
    Then una email di digest è inviata al CISO con:
      - N nuove CVE rilevate nella settimana
      - SLA compliance % (Early Warning 24h)
      - N installazioni vulnerabili ancora non patched
      - N notifiche clienti inviate
      - Top 3 finding più critici aperti

  Scenario: Compliance dashboard — SLA compliance %
    Given nelle ultime 30 settimane ci sono stati 10 CraReportingObligation KEV
    And 8 sono stati risolti entro 24h, 2 no
    When l'utente apre la compliance dashboard
    Then il KPI "sla_24h_compliance" mostra 80%
    And il trend mostra l'evoluzione settimanale dell'indicatore

  Scenario: KPI MTTR per severity
    Given negli ultimi 90 giorni:
      - 5 finding CRITICAL chiusi con tempi: 3, 7, 2, 5, 4 giorni → MTTR = 4.2
      - 10 finding HIGH chiusi con tempi medi = 12 giorni
    When l'utente apre il pannello KPI direzionali
    Then mostra MTTR CRITICAL = 4.2 giorni e MTTR HIGH = 12 giorni

  Scenario: Alert componente EoS senza CVE
    Given il componente "Ubuntu 18.04 LTS" è EOL dal 2023-04-30
    And è presente in SBOM di "vers-001"
    When il task EoS check esegue
    Then un alert "COMPONENT_EOL_NO_CVE" è inviato con: componente, data EOL, prodotto interessato
    And una voce triage di tipo EOL_RISK è presente nella coda

  Scenario: Alert variazione CVSS su CVE già in triage
    Given CVE-2023-0286 è in coda triage con CVSS 7.5 assegnata all'analista "analyst@example.com"
    When NVD aggiorna il CVSS a 9.1
    Then un alert "CVSS_INCREASED: 7.5 → 9.1" è inviato all'analista owner
    And il risk_score del TriageItem è ricalcolato automaticamente
    And la posizione del TriageItem nella coda è aggiornata
```

---

## Feature: M6.4 — Compliance Documentation

```gherkin
Feature: Report Allegato VII CRA e Evidence Pack

  Scenario: Generazione Report Allegato VII CRA per versione prodotto
    Given la versione "PLC-X100 v5.1.0" ha:
      - SBOM frozen alla versione 1.3.1
      - 3 CVE gestite (2 chiuse, 1 in triage)
      - CVD policy pubblicata
      - eos_date impostata
    When l'utente richiede POST a "/api/products/prod-001/versions/vers-001/cra-report"
    Then la risposta ha status 200
    And il report JSON contiene:
      | sezione                    | contenuto                           |
      | sbom_reference             | hash SHA-256 della SBOM frozen      |
      | lifecycle.eos_date         | data fine supporto                  |
      | lifecycle.market_date      | data immissione mercato             |
      | classification_cra         | "class_i"                           |
      | cvd_policy.url             | URL policy pubblicata               |
      | vulnerabilities_summary    | {total: 3, closed: 2, open: 1}      |

  Scenario: Evidence Pack per valutatori Classe I/II — contenuto ZIP
    Given la versione "PLC-X100 v5.1.0" è classificata "class_i"
    And esistono notifiche ACN inviate e acknowledge clienti
    When l'utente CISO richiede POST a "/api/products/prod-001/versions/vers-001/evidence-pack"
    Then la risposta ha status 200
    And il download è un file ZIP contenente esattamente questi file:
      - "sbom_current.cdx.json" (SBOM con VEX incluso)
      - "triage_log.csv" (firmato con SHA-256 in ultima riga)
      - "regulatory_notifications.csv" (EW+NF+RF inviati con hash documento)
      - "customer_notifications.csv" (clienti notificati con acked_at)
      - "cvd_policy.txt" (testo policy + versione + URL)
      - "cra_report_annexVII.json"
    And l'evento "EVIDENCE_PACK_GENERATED" è nell'audit trail con hash dello ZIP

  Scenario: Accesso Evidence Pack — solo CISO e Admin
    Given un utente con ruolo "SecurityAnalyst" tenta di generare l'evidence pack
    When esegue POST a "/api/products/prod-001/versions/vers-001/evidence-pack"
    Then la risposta ha status 403
    And la risposta contiene "INSUFFICIENT_ROLE: CISO or ADMIN required"
```

---

## Feature: ADD-ON — Customer Portal B2B

```gherkin
Feature: Portale self-service B2B per clienti del produttore

  Background:
    Given un utente con ruolo "customer" appartenente al cliente "cust-001" è autenticato sul portale

  Scenario: Vista stato vulnerabilità per asset installati in tempo reale
    Given il cliente "cust-001" ha 3 installazioni: 2 PLC-X100 v5.1.0 e 1 PLC-Y200 v3.0.0
    When l'utente accede alla dashboard del portale
    Then vede le 3 installazioni con per ognuna:
      - Versione prodotto installata
      - N vulnerabilità CRITICAL/HIGH/MEDIUM aperte
      - Data ultimo aggiornamento SBOM
      - Badge "AGGIORNAMENTO DISPONIBILE" se esiste una patch

  Scenario: Download SBOM dal portale clienti
    Given la versione "PLC-X100 v5.1.0" ha una SBOM frozen con VEX incluso
    When l'utente del portale clicca "Scarica SBOM" per la sua installazione
    Then il download è un file CycloneDX JSON valido
    And il file include la sezione "vulnerabilities" con i VEX approvati
    And il download è registrato nell'audit trail del produttore

  Scenario: Ricezione e acknowledgment notifica nel portale
    Given il produttore ha inviato una notifica "advisory_informativo" al cliente "cust-001"
    When l'utente del portale accede alla sezione "Notifiche"
    Then vede la notifica con stato "non letto" (badge rosso)
    
    When l'utente clicca "Ho letto e compreso"
    Then la notifica cambia stato a "letto"
    And il sistema del produttore registra l'acknowledgment con timestamp
    And la dashboard del produttore mostra il cliente come "acked"

  Scenario: Storico comunicazioni di sicurezza nel portale
    Given il produttore ha inviato 12 comunicazioni al cliente nell'ultimo anno
    When l'utente del portale accede a "Storico comunicazioni"
    Then vede 12 comunicazioni ordinate per data decrescente
    And può filtrare per prodotto, anno, tipologia (advisory/aggiornamento/emergenza)
    And ogni comunicazione è scaricabile come PDF

  Scenario: Accesso portale limitato ai propri dati
    Given l'utente del portale "cust-001" è autenticato
    When l'utente tenta di accedere ai dati del cliente "cust-002"
    Then la risposta ha status 403
    And nessun dato del cliente "cust-002" è visibile
```

---

## Feature: DT Integration Layer — Test E2E

```gherkin
Feature: Integrazione Dependency-Track end-to-end

  Scenario: Scenario E2E completo — dalla SBOM alla chiusura dell'obbligo CRA
    Given il sistema DT è operativo e configurato con KEV feed attivo
    And esiste il prodotto "PLC-X100 v5.1.0" con 3 installazioni clienti
    And il cliente "Autostrade" è NIS2 essential con contatto security "g.verdi@autostrade.it"

    # Step 1: Upload SBOM
    When un DevOps carica la SBOM di "PLC-X100 v5.1.0" contenente Log4j 2.14.1

    # Step 2: DT matching
    Then entro 5 minuti DT trova CVE-2021-44228 (KEV) su Log4j 2.14.1
    And DT invia webhook al backend proprietario

    # Step 3: Impact analysis
    And entro 30 secondi il backend crea un ImpactAnalysisResult con 3 installazioni
    And la prima installazione nella lista è "Autostrade" (NIS2 essential)

    # Step 4: Triage item
    And un TriageItem è creato con is_kev=true e countdown 24h attivo
    And un alert Slack raggiunge il canale "#product-security"

    # Step 5: Triage
    When il SecurityAnalyst prende in carico il TriageItem e crea un VEX "affected"
    And il TriageItem transita a "notification_required"
    And un CraReportingObligation è creato automaticamente

    # Step 6: Early Warning
    When il SecurityManager approva e invia l'Early Warning
    Then il documento è archiviato con hash nel regulatory_notification_log
    And "early_warning_sent_at" è impostato

    # Step 7: Notifica cliente
    When l'analista crea e approva una notifica "piano_aggiornamento_programmato" per "Autostrade"
    Then la notifica email è inviata a "g.verdi@autostrade.it"
    And il link di acknowledgment è incluso nell'email

    # Step 8: Acknowledgment cliente
    When "g.verdi@autostrade.it" clicca il link di conferma
    Then il sistema registra l'ack con timestamp e IP

    # Step 9: Chiusura
    When il SecurityManager invia il Report Finale (patch applicata)
    Then CraReportingObligation ha status "completed"
    And TriageItem ha stato "closed"
    And la compliance dashboard mostra SLA compliance = 100% per questo obbligo

    # Step 10: Evidence pack
    When il CISO genera l'evidence pack per "PLC-X100 v5.1.0"
    Then il ZIP contiene tutti i documenti previsti
    And il file triage_log.csv contiene tutte le transizioni di stato dell'intero workflow

  Scenario: Setup DT e configurazione sorgenti
    When il sistema è avviato con "docker compose up" su macchina pulita
    Then DT è accessibile all'URL configurato entro 60 secondi
    And il backend proprietario è accessibile e il healthcheck risponde 200
    And la sincronizzazione NVD è completata senza errori entro 24 ore
    And OSV, CISA KEV e EPSS mostrano "last_sync" aggiornato nelle ultime 6 ore
    And un progetto di test in DT può ricevere una SBOM via API

  Scenario: Resilienza — webhook DT non raggiunge il backend
    Given il backend proprietario è temporaneamente non disponibile
    When DT tenta di inviare un webhook per un nuovo finding KEV
    Then DT esegue retry con backoff esponenziale (configurato in DT policy)
    When il backend torna disponibile entro 10 minuti
    Then il webhook è recapitato
    And il TriageItem è creato correttamente con il timestamp originale di rilevamento
    And nessun obbligo CRA è perso

  Scenario: RBAC — matrice completa permessi
    Given sono definiti i ruoli: Admin, CISO, SecurityManager, SecurityAnalyst, ProductManager, CustomerSuccess, ReadOnly

    # Admin
    When un "Admin" accede a qualsiasi endpoint
    Then la risposta ha status 200 (o 201 per creazioni)

    # SecurityAnalyst — no invio notifiche regolatorie
    When un "SecurityAnalyst" tenta POST a "/api/cra-obligations/{id}/early-warning/send"
    Then la risposta ha status 403

    # ProductManager — no accesso triage
    When un "ProductManager" tenta GET a "/api/triage"
    Then la risposta ha status 403

    # ReadOnly — solo GET
    When un "ReadOnly" tenta POST a "/api/products"
    Then la risposta ha status 403
    When un "ReadOnly" tenta GET a "/api/products"
    Then la risposta ha status 200

    # CustomerSuccess — no accesso audit log
    When un "CustomerSuccess" tenta GET a "/api/audit-log"
    Then la risposta ha status 403
```

---

## Feature: Sicurezza e Hardening

```gherkin
Feature: Sicurezza sistema — OWASP Top 10 e autenticazione

  Scenario: SQL Injection prevenuta
    When un attaccante invia GET a "/api/products?name='; DROP TABLE product;--"
    Then la risposta ha status 400 o 200 con lista vuota
    And la tabella "product" esiste ancora nel database
    And nessuna query non parametrizzata è stata eseguita

  Scenario: Autenticazione JWT obbligatoria su tutti gli endpoint protetti
    When una richiesta GET a "/api/products" è inviata senza header Authorization
    Then la risposta ha status 401
    And il corpo contiene "UNAUTHORIZED"

  Scenario: Token JWT scaduto rifiutato
    Given un token JWT scaduto da 1 ora
    When viene usato in una richiesta
    Then la risposta ha status 401
    And il corpo contiene "TOKEN_EXPIRED"

  Scenario: MFA obbligatoria per ruoli critici
    Given un utente con ruolo "SecurityManager" ha solo password configurata (no MFA)
    When tenta di autenticarsi
    Then la risposta rimanda alla configurazione MFA obbligatoria
    And nessuna operazione è consentita fino al completamento della configurazione MFA

  Scenario: Rate limiting endpoint pubblico CVD inbound
    When 11 richieste POST arrivano dallo stesso IP in 60 secondi
    Then le prime 10 rispondono 201 o 400 (secondo validazione)
    And la richiesta 11 riceve status 429 con header "Retry-After"

  Scenario: Content-Security-Policy headers
    When qualsiasi pagina del frontend è richiesta
    Then la risposta HTTP include header "Content-Security-Policy"
    And include "X-Content-Type-Options: nosniff"
    And include "X-Frame-Options: DENY"
```
