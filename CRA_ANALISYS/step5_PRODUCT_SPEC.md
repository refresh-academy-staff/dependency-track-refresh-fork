# Piattaforma di Compliance CRA/NIS2 per Produttori Industriali
## Specifica di Prodotto (Product Requirements Document — Livello Alto)

**Versione:** 1.0  
**Data:** 2026-05-24  
**Riferimenti normativi:**
- Regolamento (UE) 2024/2847 — Cyber Resilience Act (CRA)
- Direttiva (UE) 2022/2555 — NIS2 (Network and Information Security Directive 2)

---

## 1. Visione del Prodotto

### 1.1 Descrizione sintetica

La piattaforma è un **sistema informativo di compliance CRA/NIS2 per produttori di macchinari industriali e sistemi embedded**. Consente al produttore di gestire l'intero ciclo di vita della sicurezza informatica dei propri prodotti — dalla composizione software (SBOM) al monitoraggio delle vulnerabilità, dall'analisi dell'impatto sui clienti installati alla notifica obbligatoria alle autorità (ACN/ENISA) e ai clienti B2B.

Il sistema si fonda su **Dependency-Track** (OWASP) come motore di intelligence sulle vulnerabilità, esteso da un layer applicativo proprietario che aggiunge:
- Registro prodotti e gestione dell'installed base clienti
- Workflow di triage normativo con timer SLA CRA
- Notifica strutturata verso autorità regolatorie e clienti
- Audit trail immutabile per ispezioni

### 1.2 Proposta di valore

| Beneficiario | Problema risolto | Valore fornito |
|-------------|-----------------|----------------|
| **Produttore (fabbricante CRA)** | Obbligo CRA Art. 13/14: notifiche 24h/72h/14gg, SBOM, CVD policy | Workflow automatizzato che guida l'operatore step-by-step nel rispetto dei deadline normativi |
| **Team sicurezza del produttore** | Frammentazione dati: SBOM in CI/CD, CVE in scanner separati, clienti in CRM | Unica piattaforma che aggrega SBOM, vulnerabilità, clienti impattati e storico notifiche |
| **Clienti B2B (soggetti NIS2)** | Art. 21(2)(d) NIS2: sicurezza catena di approvvigionamento; devono tracciare la sicurezza dei prodotti installati | Ricevono notifiche strutturate, possono scaricare SBOM e consultare lo stato vulnerabilità dei propri asset |
| **Autorità di sorveglianza (ACN, ENISA)** | Verifica conformità CRA Art. 13(22): documentazione tecnica su richiesta | Evidence pack esportabile (SBOM versionata, log triage, proof of notification, CVD policy) |

---

## 2. Parti Coinvolte (Stakeholder Map)

### 2.1 Attori interni al produttore

| Ruolo | Utilizzo della piattaforma |
|-------|--------------------------|
| **Product Security Manager** | Supervisione dashboard KPI, approvazione notifiche regolatorie |
| **Security Analyst** | Triage vulnerabilità, VEX assessment, gestione segnalazioni inbound |
| **Product Manager** | Gestione catalogo prodotti, ciclo di vita versioni, classificazione CRA |
| **Customer Success / Sales** | Consultazione installed base, tracking acknowledgment clienti |
| **CISO / Legale** | Export audit trail, evidence pack per autorità, revisione CVD policy |
| **DevOps / R&D** | Upload SBOM da pipeline CI/CD, gestione versioni SBOM |

### 2.2 Entità esterne

| Soggetto | Tipologia | Interazione con la piattaforma |
|---------|-----------|-------------------------------|
| **ACN** (Agenzia Cybersicurezza Nazionale) | Autorità competente NIS2/CRA Italia | Riceve notifiche Early Warning 24h e Notifica Formale 72h via endpoint ENISA SRP o email strutturata |
| **ENISA** | Agenzia EU cybersecurity | Destinataria notifiche CRA Art. 14; fornisce linee guida formato |
| **CSIRT Italia (ACN)** | Coordinatore divulgazione coordinata vulnerabilità | Riceve segnalazioni incidenti gravi e vulnerabilità attivamente sfruttate |
| **Clienti B2B — Soggetti essenziali NIS2** | Es. utility energetiche, gestori autostrade, ospedali, banche | Ricevono notifiche di vulnerabilità sui prodotti installati; soggetti agli obblighi NIS2 Art. 21(2)(d) sulla sicurezza della supply chain |
| **Clienti B2B — Soggetti importanti NIS2** | Es. industria manifatturiera, fornitori di servizi digitali | Idem, con requisiti NIS2 proporzionalmente ridotti |
| **Clienti B2B — Non NIS2** | PMI, enti locali, privati | Ricevono notifiche tramite canali standard (email, portale) |
| **Ricercatori di sicurezza** | Terze parti esterne | Inviano segnalazioni vulnerabilità tramite endpoint pubblico CVD inbound |
| **Fornitori componenti** | Upstream dei componenti software/hardware | Fonte indiretta: i loro advisory alimentano il repository vulnerabilità |
| **Organismi notificati (NB)** | Certificatori per prodotti Classe I/II CRA | Richiedono evidence pack per valutazione conformità CE |

### 2.3 Settori NIS2 rilevanti per i clienti B2B

I clienti B2B del produttore appartengono tipicamente ai settori ad alta criticità (Allegato I NIS2):
- **Energia** (distribuzione elettrica, gas, oleodotti)
- **Trasporti** (ferroviario, stradale — es. gestori autostrade)
- **Acque** (gestori reti idriche)
- **Infrastrutture digitali** (data center, cloud provider)
- **Settore sanitario** (ospedali, laboratori diagnostici)

Questi soggetti hanno l'obbligo NIS2 Art. 21(2)(d) di gestire la sicurezza della **catena di approvvigionamento**, inclusi i prodotti digitali dei propri fornitori. La piattaforma li supporta in questo obbligo fornendo informazioni strutturate sullo stato di sicurezza dei prodotti acquistati.

---

## 3. Architettura Funzionale ad Alto Livello

```
┌─────────────────────────────────────────────────────────────┐
│                    PIATTAFORMA CRA/NIS2                      │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  M1          │  │  M2/M3       │  │  M4              │  │
│  │  Registro    │  │  SBOM +      │  │  Risk Assessment │  │
│  │  Prodotti &  │◄─┤  Vulnerability│◄─┤  & Triage       │  │
│  │  Installed   │  │  Intelligence│  │  Queue           │  │
│  │  Base        │  │  (DT-powered)│  │                  │  │
│  └──────┬───────┘  └──────────────┘  └────────┬─────────┘  │
│         │                                      │            │
│  ┌──────▼──────────────────────────────────────▼─────────┐  │
│  │                     M5                                │  │
│  │         Notification & Disclosure Workflow            │  │
│  │  ┌─────────────────────┐  ┌──────────────────────┐   │  │
│  │  │  Sub-workflow A     │  │  Sub-workflow B       │   │  │
│  │  │  Notifica ACN/ENISA │  │  Notifica Clienti B2B│   │  │
│  │  │  24h / 72h / 14gg   │  │  Email + Template    │   │  │
│  │  └─────────────────────┘  └──────────────────────┘   │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                     M6                                │  │
│  │   Audit Trail • Alert System • Dashboard KPI          │  │
│  │   Evidence Pack • Report Allegato VII CRA             │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┤
              │               │
   ┌──────────▼──────┐  ┌─────▼──────────┐
   │ Dependency-Track │  │  ADD-ON        │
   │ (OWASP, DT fork) │  │  Customer      │
   │ Vulnerability    │  │  Portal B2B    │
   │ Intelligence     │  │  (self-service)│
   └──────────────────┘  └────────────────┘
```

---

## 4. Descrizione Funzionale per Modulo

### M1 — Registro Prodotti e Installed Base

**Scopo:** Sistema di record per i prodotti commercializzati dal fabbricante e per il parco installato presso i clienti B2B.

#### M1.1 — Catalogo Prodotti (Product Registry)

Il catalogo modelli è il punto di partenza di tutto il sistema. Ogni **modello di prodotto** rappresenta una famiglia (es. "PLC Serie X") con le sue varianti hardware/firmware/software versionate.

Funzionalità:
- Creazione e gestione di modelli macchina con nome, codice prodotto, varianti, foto/scheda tecnica
- Versioning strutturato: ogni modello ha versioni hardware (revisione scheda), versioni firmware e versioni software applicativo — tracciate separatamente con relazioni di compatibilità
- Ciclo di vita per versione: date di introduzione sul mercato, fine supporto (EoS) e fine vita (EoL) — campo obbligatorio per conformità CRA Art. 13(8)
- Classificazione CRA: ogni prodotto classificato come "default", "Classe I" o "Classe II" — determina il percorso di conformità e la documentazione richiesta
- Hosting e versionamento della CVD policy pubblica: testo della policy, URL pubblico, storico revisioni, link al canale di ricezione segnalazioni

**Nota:** Il catalogo prodotti è distinto dai `Project` di Dependency-Track. Ogni versione prodotto viene sincronizzata con un project-version DT per l'analisi SBOM/CVE. La sincronizzazione è automatica tramite il layer di integrazione DT (task 118).

#### M1.2 — Registro Clienti e Installed Base

Anagrafica B2B dei clienti del produttore e mappatura di quali prodotti/versioni/sedi ciascuno ha installato.

Funzionalità:
- Anagrafica clienti B2B: ragione sociale, P.IVA, settore di appartenenza (con flag NIS2 "soggetto essenziale" / "soggetto importante" / "altro"), referente tecnico e referente per le notifiche di sicurezza
- Installed base: relazione N:M tra clienti, prodotti-versioni e sedi di installazione — ogni installazione ha data di messa in servizio e stato contratto di supporto (attivo/scaduto)
- Storico comunicazioni per cliente: registro di tutte le notifiche inviate, con data, tipologia, stato acknowledgment
- Canali di notifica per cliente: email referente tecnico, email referente sicurezza, eventuale endpoint webhook per clienti enterprise
- Gestione sedi/impianti multipli: un cliente può avere più sedi geografiche, ognuna con il proprio parco installato

**Integrazione NIS2:** Il flag "soggetto essenziale NIS2" determina la priorità nella coda di notifica (Art. 21(2)(d) NIS2 — sicurezza supply chain). I clienti NIS2 ricevono notifiche urgenti entro 4 ore dalla decisione di notifica, prima degli altri.

---

### M2 — Gestione SBOM

**Scopo:** Acquisizione, versionamento e validazione delle Software Bill of Materials per ogni versione di prodotto.

#### M2.1 — Acquisizione SBOM

- **Import da file CycloneDX** (formato primario, JSON/XML): la SBOM è caricata via UI o API REST; ogni import è tracciato con operatore, timestamp e hash SHA-256 del file originale
- **Inserimento manuale componenti** con form strutturato: campi obbligatori (PURL o CPE, versione, nome, fornitore), campi opzionali (hash, licenza), note di contesto OT; adatto per componenti hardware e firmware non rilevabili da scanner automatici
- **Modalità ibrida** (import scanner + delta manuale): la SBOM base è importata da CI/CD o da scanner; le modifiche manuali successive sono tracciate come delta separati con autore e motivazione
- **Validazione formato in ingresso**: verifica schema CycloneDX, presenza PURL o CPE per ogni componente, range di versione validi; gli errori di validazione bloccano l'import con lista dettagliata delle voci non conformi
- **PURL e/o CPE obbligatori** per tutti i componenti: i componenti privi di entrambi gli identificatori generano un warning bloccante che richiede risoluzione manuale prima del push a Dependency-Track

#### M2.2 — Versioning e Ciclo di Vita SBOM

- **Versioning automatico SBOM**: ogni modifica alla SBOM (import nuovo, delta manuale, aggiornamento componente) genera automaticamente una nuova versione con numerazione major.minor.patch; la logica di bump è: major = cambio versione prodotto, minor = aggiunta/rimozione componente, patch = aggiornamento versione componente
- **Freeze SBOM per versioni rilasciate**: quando una versione prodotto è marcata come "released", la SBOM associata viene congelata — nessuna modifica è possibile senza esplicita operazione di "unfreeze" con doppia approvazione; tutte le tentate modifiche post-freeze sono loggate nell'audit trail
- **Diff tra versioni SBOM**: visualizzazione side-by-side delle differenze tra due versioni SBOM (componenti aggiunti, rimossi, aggiornati di versione) con evidenziazione visiva e export CSV del diff
- **Libreria componenti condivisa cross-prodotto**: i componenti condivisi tra più prodotti sono gestiti una sola volta; una vulnerabilità su un componente condiviso si propaga automaticamente a tutti i prodotti che lo includono (funzionalità nativa DT)

#### M2.3 — Architettura SBOM Multi-Livello

- **Build-time**: integrazione con pipeline CI/CD (GitLab CI / GitHub Actions) tramite API REST; la pipeline chiama l'endpoint di upload SBOM al termine di ogni build; il progetto DT corrispondente viene aggiornato automaticamente
- **Deploy-time**: raccolta SBOM al momento dell'installazione in campo; uno script/agente di collaudo genera o aggiorna la SBOM "as-deployed" e la carica tramite API (diversa dalla SBOM "as-built" della CI/CD)

#### M2.4 — VEX e Qualità del Dato

- **Supporto VEX completo**: stati `not_affected` / `affected` / `fixed` / `under_investigation` per ogni coppia componente × vulnerabilità
- **Workflow VEX con giustificazione obbligatoria**: lo stato `not_affected` richiede obbligatoriamente la selezione di una delle giustificazioni standardizzate (component_not_present, vulnerable_code_not_present, vulnerable_code_cannot_be_controlled_by_adversary, inline_mitigations_already_exist) più un campo note libero; la giustificazione è l'evidenza normativa per ispezioni CRA
- **Export VEX integrato** nel CycloneDX output: le decisioni VEX sono incluse nell'export SBOM standard, compatibile con CycloneDX 1.4+

---

### M3 — Vulnerability Intelligence Feed

**Scopo:** Alimentazione e normalizzazione del repository interno di vulnerabilità da fonti multiple; Dependency-Track gestisce il core, il layer proprietario aggiunge sorgenti specializzate.

#### M3.1 — Fonti Integrate

| Fonte | Gestione | Coverage |
|-------|---------|---------|
| NVD (NIST) — CVE API 2.0 | DT nativo (task 116) | CVE generiche, CVSS, CPE |
| OSV.dev (Google) | DT nativo (task 116) | Open source, matching per PURL |
| CISA KEV | DT nativo + estensione flag (task 116 + GAP 2) | Vulnerabilità attivamente sfruttate |
| CISA ICS-CERT Advisories | Sviluppo custom | OT/SCADA/PLC/HMI — advisory specifici per sistemi di controllo industriale |
| GitHub Advisory Database | DT nativo (task 116) | npm, Maven, Go, PyPI, NuGet |
| Repository normalizzato interno | DT core (aggregazione automatica) | Fonte unica queryable per triage e alert |

**CISA ICS-CERT Advisories** (sviluppo custom): i feed ICS-CERT contengono advisory per sistemi OT/ICS di fornitori come Siemens, Schneider Electric, Rockwell, ABB — di diretta rilevanza per produttori di macchinari industriali. Il parser custom scarica i feed CSAF/RSS, li normalizza nel formato DT e li arricchisce con il vendor e il tipo di sistema interessato (PLC, HMI, SCADA).

#### M3.2 — Matching e Arricchimento

- **Matching CVE tramite PURL + CPE + alias**: matching primario per PURL (precisione massima), secondario per CPE, con de-duplicazione cross-sorgente tramite alias CVE-ID/GHSA/OSV-ID
- **Flag CISA KEV** su ogni CVE matchata: campo `isKev` visibile in triage, trigger per il timer SLA 24h CRA Art. 14
- **Score di confidenza del match**: high (PURL esatto), medium (CPE con version range), low (nome componente senza versione); i match low-confidence richiedono revisione manuale
- **EPSS score** (FIRST.org): aggiornato periodicamente per ogni CVE; usato nel risk score composito
- **End-of-support tracking componenti**: integrazione con endoflife.date API per componenti comuni (OS, runtime, framework); un componente EoS senza CVE genera ugualmente un alert normativo CRA

---

### M4 — Risk Assessment e Triage

**Scopo:** Analisi automatica dell'impatto di ogni vulnerabilità sui prodotti commercializzati e sui clienti installati; coda di lavoro per il team di sicurezza con timer SLA normativi.

#### M4.1 — Impact Analysis

Il motore di impact analysis esegue la catena completa:

```
CVE rilevata da DT
    ↓
Componenti matchati (quelli vulnerabili nella SBOM)
    ↓
Versioni prodotto contenenti quei componenti
    ↓
Installazioni in campo (installed base) di quelle versioni
    ↓
Clienti impattati con referente di notifica
    ↓
Lista prioritizzata (KEV first, poi CVSS×EPSS, poi NIS2 flag)
```

Funzionalità:
- **Impact analysis automatica** eseguita ad ogni nuovo alert DT (webhook da policy engine, task 119)
- **Lista prioritizzata**: cliente × prodotto × versione × severità × contatto notifica — ordinata per: (1) KEV flag, (2) CVSS score, (3) flag NIS2 "soggetto essenziale"
- **Propagazione su libreria condivisa**: una CVE su componente shared si propaga automaticamente a tutti i prodotti che lo includono (DT nativo + integrazione installed base)
- **Prioritizzazione NIS2**: i clienti classificati come soggetti essenziali NIS2 (energia, trasporti, sanità, etc.) vengono messi in cima alla lista di notifica per rispettare gli obblighi NIS2 Art. 21(2)(d) della supply chain

#### M4.2 — Coda di Triage e Scoring

La coda di triage è l'interfaccia di lavoro quotidiana del team di sicurezza. Ogni elemento della coda rappresenta una coppia (versione-prodotto × CVE) con il relativo stato normativo.

**Stati della coda (ciclo di vita normativo CRA):**
```
new → under_investigation → vex_assessed → notification_required → patch_available → closed
```

- `new`: CVE appena rilevata, non ancora analizzata
- `under_investigation`: un analista ha preso in carico, timer SLA attivo
- `vex_assessed`: VEX completato (not_affected / affected con giustificazione)
- `notification_required`: se KEV o CVSS ≥ 9.0, richiede notifica ACN/clienti
- `patch_available`: il vendor del componente ha rilasciato una fix
- `closed`: remediation completata o VEX `not_affected` accettato

**Funzionalità coda:**
- **Assegnazione owner**: ogni voce può essere assegnata a un analista specifico; lo storico delle assegnazioni è nell'audit trail
- **Timer SLA visibili**: se la CVE è in CISA KEV, il countdown 24h CRA Art. 14 è mostrato con colore (verde > 12h, arancio 6-12h, rosso < 6h); per la notifica formale 72h, countdown separato; la scadenza mancata genera alert escalation automatico
- **CVSS base score**: visualizzato per ogni CVE con sorgente (NVD / OSV / ICS-CERT)
- **Risk score composito**: punteggio combinato CVSS (peso 40%) + EPSS (peso 40%) + KEV flag (peso 20%); usato per l'ordinamento della coda in mancanza di KEV
- **VEX assessment workflow**: apertura scheda VEX con giustificazione obbligatoria, nota libera, e link alle evidenze tecniche; workflow a 1 livello di approvazione (analista → security manager) per stato `not_affected`
- **Remediation plan**: campo strutturato con data prevista di rilascio della fix, milestone intermedie (es. "patch disponibile in test", "patch in produzione"), responsabile; aggiornabile nel tempo e collegato al report finale 14 giorni CRA
- **Tracking disponibilità patch**: monitoraggio automatico del campo `patchedVersions` (da DT/GAP 6); alert automatico quando una fix upstream diventa disponibile per un componente in triage

---

### M5 — Notification & Disclosure Workflow

**Scopo:** Workflow strutturato e tracciato per le due tipologie di notifica obbligatoria: verso le autorità regolatorie (ACN/ENISA) e verso i clienti B2B impattati.

#### M5-A — Sub-workflow Notifica ACN/ENISA

**Trigger:** Rilevamento automatico di CVE nel CISA KEV su versione prodotto commercializzata (con installazioni attive nell'installed base).

**Flusso:**

```
T+0  Rilevamento KEV → crea CraReportingObligation → avvia countdown
T+4h Alert "Early Warning imminente" a Security Manager
T+24h SCADENZA Early Warning → template pre-compilato per ACN
      [Operatore: revisione + invio o giustificazione ritardo]
T+72h SCADENZA Notifica Formale → report strutturato
T+14gg dalla patch SCADENZA Report Finale
```

**Early Warning 24h:**
Template pre-compilato con: nome prodotto, versione, CVE-ID, CVSS score, stima clienti impattati (N installazioni), misure cautelari in corso. L'operatore può integrare il testo prima dell'invio. Il sistema registra data/ora di invio, destinatario (ACN endpoint), e hash del documento inviato.

**Notifica Formale 72h:**
Report strutturato obbligatorio contenente: identificazione SBOM del componente vulnerabile (PURL, versione, hash), CVSS dettagliato, numero e tipologia di clienti impattati (senza nominativi individuali), descrizione della vulnerabilità, piano di remediation con date previste. Il report può essere inviato in formato CSAF 2.0 (standard ENISA preferito) o JSON strutturato.

**Report Finale 14 giorni:**
Documenta: azioni intraprese, patch rilasciata o programmata, clienti notificati (con prova di invio), clienti che hanno applicato la patch (se verificabile), lezioni apprese. Chiude il `CraReportingObligation`.

**Audit trail ENISA/ACN:**
Ogni documento inviato è archiviato con: timestamp, hash SHA-256, destinatario, stato (sent/acknowledged/failed), response code. Il registro è append-only e non modificabile.

**Distinzione reporting regolatorio vs. gestione interna:**
L'interfaccia separa visivamente le azioni "per autorità" (sfondo blu, label "REGOLATORIO") da quelle interne di triage. Un operatore sotto pressione temporale non può confondere una nota interna con una notifica formale.

#### M5-B — Sub-workflow Notifica Clienti B2B

**Tipologie di comunicazione:**

| Tipologia | Trigger tipico | Contenuto | SLA target |
|-----------|---------------|-----------|-----------|
| **Advisory informativo** | CVE CVSS < 7.0, nessuna azione immediata | Info CVE, impatto teorico, monitoraggio raccomandato | 5 giorni lavorativi |
| **Richiesta intervento remoto** | Patch disponibile, applicabile da remoto (OTA/SSH) | Istruzioni patch, link download, procedura applicazione | 2 giorni lavorativi |
| **Piano aggiornamento programmato** | Patch richiede presenza tecnico in loco | Proposta finestra di intervento, procedura, contatto assistenza | 10 giorni lavorativi |
| **Blocco funzione critica** | CVE attivamente sfruttata, rischio immediato | Istruzioni disabilitazione funzione, workaround immediato, contatto emergenza | 4 ore |

**Flusso di approvazione:**
Tutte le comunicazioni ai clienti passano attraverso un workflow di approvazione configurabile (1 livello: analista → security manager; 2 livelli: analista → security manager → CISO). L'invio senza approvazione è bloccato tecnicamente. In caso di emergenza ("Blocco funzione critica"), è disponibile un percorso accelerato con approvazione a firma singola del security manager.

**Template parametrici:**
I template email sono precompilati automaticamente con: ragione sociale cliente, referente, prodotto installato, versione, CVE-ID, CVSS, azioni raccomandate. Il testo è personalizzabile prima dell'invio. I template sono versionati e modificabili dall'amministratore.

**Tracking invio e acknowledgment:**
Ogni email include un link univoco di conferma lettura (tracking pixel + link click). Il sistema registra: data/ora invio, data/ora apertura email (se disponibile), data/ora click conferma. I clienti che non confermano entro N giorni (configurabile) ricevono un reminder automatico. Lo stato di acknowledgment è visibile nella dashboard.

#### M5-C — Patch Campaign Management

Per vulnerabilità che richiedono interventi su molte installazioni:
- **Campagna di remediation**: raggruppamento di tutte le installazioni impattate in una campagna con titolo, descrizione, patch target, data obiettivo
- **Maintenance windows**: per ogni installazione cliente in sito produttivo, è possibile registrare la finestra di intervento programmata (data, ora, durata, tecnico assegnato)
- **Dipendenze campagna**: gestione delle dipendenze (es. "patch richiede upgrade firmware prima"; "cliente A ha priorità sul cliente B perché NIS2 essenziale")
- **Tracciamento adozione patch**: per ogni installazione, stato aggiornamento (pending / scheduled / in_progress / completed / failed / deferred); dashboard di avanzamento campagna con % completamento

---

### M6 — Audit Trail, Alert e Compliance Evidence

**Scopo:** Traccia immutabile di tutte le operazioni per ispezioni normative; sistema di alert proattivo; dashboard KPI; produzione di documentazione CRA-ready.

#### M6.1 — Audit Trail

- **Log immutabile append-only**: ogni operazione sul sistema genera un record immutabile con: timestamp UTC, operatore (user ID + IP), tipo operazione, oggetto interessato, valore precedente e nuovo (granularità per singolo campo)
- **Copertura completa**: tutte le scritture del sistema sono loggate — creazione/modifica prodotti, upload SBOM, decisioni VEX, invio notifiche, approvazioni, login/logout
- **Export per verifiche esterne**: endpoint autenticato che esporta l'audit log in formato CSV o JSON, filtrabile per prodotto, periodo, operatore, tipo operazione; il file di export include firma digitale per garantire integrità (hash SHA-256 + timestamp)

#### M6.2 — Sistema di Alert

| Alert | Trigger | Destinatari |
|-------|---------|------------|
| Nuove CVE che matchano componenti SBOM | DT webhook (task 119) | Team sicurezza (Slack/Teams/email) |
| Nuova entry CISA KEV che matcha prodotto commercializzato | DT policy engine | Security Manager (priorità massima) |
| Variazione CVSS/severity su CVE già nota | Delta monitoring sul repository DT | Security Analyst (owner CVE) |
| SLA triage in scadenza (24h/72h imminenti) | TaskScheduler interno | Security Manager + analista owner |
| Clienti NIS2-critici non ancora notificati dopo X ore | Scheduler notifica | Customer Success + Security Manager |
| Patch non applicate su installazioni ad alto rischio dopo X giorni | Scheduler campagna | Account Manager + Security Manager |
| Vulnerabilità senza fix vendor disponibile | Monitor patchedVersions | Security Analyst |
| Componente EoS senza CVE associata | EndOfLife mirror task | Product Manager + Security Analyst |
| Webhook ITSM (Jira/ServiceNow/Azure DevOps) | Tutti gli alert sopra | Configurabile per destinazione |
| Integrazione Teams/Slack | Tutti gli alert sopra | Configurabile per canale |
| Digest periodici management | Scheduler settimanale/mensile | CISO + Product Security Manager |

#### M6.3 — Dashboard e KPI

**Compliance dashboard base:**
- SLA compliance %: percentuale di CVE KEV notificate entro 24h negli ultimi 30/90 giorni
- SBOM coverage %: percentuale di versioni prodotto rilasciate con SBOM completa e conforme
- Installazioni vulnerabili: numero di installazioni clienti con almeno una CVE CRITICAL/HIGH aperta
- Open triage items: numero di voci in coda non ancora in `vex_assessed` o `closed`

**KPI direzionali:**
- Prodotti esposti per severità (CRITICAL/HIGH/MEDIUM/LOW)
- Vulnerabilità aperte per severità e per modulo prodotto
- MTTR (Mean Time To Remediate): giorni medi dalla rilevazione alla chiusura per severità
- % clienti aggiornati per campagna di remediation attiva
- Stato notifiche regolatorie: Early Warning / Notifica Formale / Report Finale — inviati/in ritardo/in scadenza
- Trend storico KPI: grafici temporali (30/90/365 giorni) per ogni KPI

#### M6.4 — Compliance Documentation

**Report Allegato VII CRA:**
Documento strutturato generabile per ogni versione prodotto rilasciata, contenente (Art. 13(22)):
- SBOM versionata con hash di integrità
- Ciclo di vita prodotto (date EoS/EoL)
- Classificazione CRA e percorso di conformità seguito
- CVD policy attiva
- Storico vulnerabilità gestite (stato, tempistiche, remediation)
- Risk assessment summary

**Evidence pack per valutatori (Classe I/II):**
Bundle ZIP contenente:
- SBOM versionata (CycloneDX con VEX integrato)
- Log triage filtrato per prodotto/periodo (con firma digitale)
- Proof of notification: log invii ACN/ENISA + log invii clienti B2B con acknowledgment
- CVD policy attiva al momento della valutazione
- Report Allegato VII CRA

---

### ADD-ON — Customer Portal B2B

**Scopo:** Portale self-service per i clienti B2B del produttore — accesso alla propria vista dell'installed base e alle comunicazioni di sicurezza ricevute.

- **Stato vulnerabilità per asset in tempo reale**: il cliente vede lo stato di sicurezza dei prodotti che ha installato (versione, CVE aperte, severità, stato VEX)
- **Download SBOM**: i clienti possono scaricare la SBOM dei prodotti in uso, completa di VEX
- **Ricezione e acknowledgment notifiche nel portale**: alternativa/complemento all'email; notifiche strutturate con pulsante "Ho letto e compreso"
- **Storico comunicazioni**: archivio completo delle comunicazioni di sicurezza ricevute dal fornitore, filtrabile per prodotto/periodo

**Valore NIS2 per i clienti B2B:** Il portale aiuta i soggetti NIS2 a documentare la propria gestione della sicurezza supply chain (Art. 21(2)(d)) — possono scaricare le SBOM dei fornitori e dimostrare di aver ricevuto e gestito le notifiche di vulnerabilità.

---

### DT — Setup & Integrazione Dependency-Track

Dependency-Track è il motore di vulnerability intelligence. La sua integrazione comprende:

- **Deployment** (task 115): Docker Compose con API server + frontend + PostgreSQL + NGINX reverse proxy; backup automatico; health check
- **Configurazione sorgenti** (task 116): NVD API key, OSV, CISA KEV, EPSS (FIRST.org), GitHub Advisory — sincronizzazione iniziale e aggiornamento periodico
- **API client REST** (task 117): wrapper backend verso DT con autenticazione JWT/API-key, gestione errori, retry, rate limiting; mapping response DT → modello dati proprietario
- **Sincronizzazione progetti** (task 118): ogni versione prodotto nel registro proprietario ↔ project-version in DT; sincronizzazione bidirezionale IDs e stato SBOM
- **Policy engine** (task 119): regole DT configurate per KEV match, CVSS ≥ 7.0, CVSS ≥ 9.0, componenti EoL; webhook verso backend proprietario che avvia impact analysis (M4) e workflow di notifica (M5)
- **Test integrazione E2E** (task 120): scenario completo upload SBOM → matching CVE DT → ricezione alert webhook → trigger M4 impact analysis

---

## 5. Flusso Operativo Tipico (Happy Path)

```
1. R&D carica SBOM v2.1.3 del prodotto "PLC-X" tramite pipeline CI/CD
   → Sistema valida PURL per tutti i componenti
   → SBOM inviata a DT (project "PLC-X v2.1.3")
   → Versioning automatico: SBOM v2.1.3 build.47

2. DT rileva che il componente OpenSSL 3.0.7 ha una nuova CVE KEV
   → Webhook da DT policy engine → backend proprietario
   → Impact analysis: PLC-X v2.1.3 installato in 12 sedi di 4 clienti
   → 2 clienti classificati NIS2 essenziale (utility energetica + gestore autostrada)
   → Voce creata in coda triage: stato "new", countdown 24h avviato

3. Security Analyst riceve alert (Slack + email)
   → Apre la coda triage
   → Analizza: OpenSSL 3.0.7 — CVE attivamente sfruttata — CVSS 9.8
   → Imposta stato "under_investigation", si auto-assegna

4. Analyst esegue VEX assessment
   → Il PLC-X v2.1.3 usa OpenSSL per TLS nella comunicazione SCADA
   → Stato VEX: "affected"
   → Risk score composito: 9.6 (CVSS 9.8 + KEV + EPSS 0.94)
   → Sistema imposta stato: "notification_required"

5. Security Manager riceve alert "Early Warning scadenza in 6 ore"
   → Apre template Early Warning pre-compilato
   → Integra note operative, approva
   → Sistema invia a ACN (endpoint configurato), archivia documento con hash

6. Entro 72h: Notifica Formale inviata ad ACN
   → Documento include: SBOM del componente, lista installazioni (anonimizzata), piano remediation

7. Parallelo: Notifica Clienti B2B
   → 2 clienti NIS2 ricevono "Piano aggiornamento programmato" con priorità alta
   → Tecnico assegnato a ciascun sito; finestre di intervento concordate
   → 2 clienti non-NIS2 ricevono "Advisory informativo"
   → Tracking acknowledgment attivato

8. R&D rilascia patch OpenSSL → nuova SBOM v2.1.4 caricata
   → Sistema rileva fix per CVE in questione
   → Voce triage aggiornata: "patch_available"
   → Campagna remediation creata per i 12 siti ancora su v2.1.3

9. Entro 14 giorni: Report Finale inviato ad ACN
   → Include: 10/12 siti aggiornati, 2 in manutenzione programmata
   → CraReportingObligation chiusa

10. Dashboard aggiornata: MTTR = 11 giorni, SLA compliance = 100%
    → Evidence pack generabile per organismo notificato
```

---

## 6. Vincoli e Requisiti Non Funzionali

| Area | Requisito |
|------|-----------|
| **Disponibilità** | 99.5% uptime (sistema interno; non SaaS pubblico) |
| **Scalabilità** | Fino a 500 modelli prodotto, 10.000 installazioni, 50 utenti concorrenti |
| **Sicurezza** | Autenticazione MFA, RBAC (ruoli: admin, security_manager, analyst, readonly, customer), tutte le comunicazioni TLS 1.2+ |
| **Audit trail** | Immutabilità garantita: log append-only su storage separato; nessun admin può modificare log precedenti |
| **Ritenzione dati** | Audit log e SBOM versionate conservati 10 anni (CRA Art. 13(9)) |
| **Integrazioni** | API REST JSON; webhook outbound; SMTP per email; Jira/ServiceNow/Azure DevOps webhook |
| **Deployment** | On-premise (Docker Compose) o cloud privato; no SaaS pubblico per v1 |
| **Performance** | Impact analysis completata entro 30 secondi dal webhook DT per installed base ≤ 5.000 installazioni |

---

## 7. Dipendenze Normative Chiave

| Funzionalità | Norma | Obbligatorio entro |
|-------------|-------|-------------------|
| SBOM per ogni prodotto | CRA Allegato I Parte II(1) | 11 dicembre 2027 |
| CVD policy pubblica | CRA Allegato I Parte II(5) | 11 dicembre 2027 |
| Notifica 24h per CVE KEV | CRA Art. 14(1) | In vigore |
| Gestione vulnerabilità documentata | CRA Art. 13(8) | 11 dicembre 2027 |
| Sicurezza supply chain | NIS2 Art. 21(2)(d) | Recepita (D.Lgs 138/2024) |
| Notifica incidenti significativi | NIS2 Art. 23 | Recepita |
| Obblighi reporting supply chain | NIS2 Art. 21(3) | Recepita |

---

## 8. Fuori Scope (Won't Have per v1)

- Distribuzione OTA aggiornamenti firmware (overlap ingegneria prodotto)
- Architettura multi-tenant SaaS
- License compliance module (FOSSA/Black Duck più adatti)
- SAST/DAST integration nel ciclo di sviluppo
- Threat modeling tool
- Supply chain risk scoring sui fornitori del fabbricante
- SLSA attestation
- Integrazione PLM (Teamcenter/Windchill)
- Feed threat intelligence commerciali (Shodan, Recorded Future)
