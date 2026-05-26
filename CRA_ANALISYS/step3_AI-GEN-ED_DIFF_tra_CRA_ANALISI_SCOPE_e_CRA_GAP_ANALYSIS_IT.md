 ---
  M1 — Registro Prodotti e Installed Base

  ❌ Non coperto da GAP analysis

  ┌─────┬─────────────────────────────────────────────────────────────┬─────────────────────────────────────────────────────────────────────────────────────────────┐
  │ ID  │                        Funzionalità                         │                                           Motivo                                            │
  ├─────┼─────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────┤
  │ 1   │ Catalogo modelli macchina (nome, versione, varianti)        │ GAP analysis estende Project DT, non crea catalogo prodotti commercializzati separato       │
  ├─────┼─────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────┤
  │ 4   │ Classificazione CRA prodotto (default / Classe I / Classe   │ Nessun GAP aggiunge campo classificazione normativa a Project                               │
  │     │ II)                                                         │                                                                                             │
  ├─────┼─────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────┤
  │ 7   │ Gestione sedi/impianti multipli per cliente                 │ Concetto "cliente" assente da DT e da tutti i 14 GAP                                        │
  ├─────┼─────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────┤
  │ 9   │ Anagrafica clienti B2B con referenti tecnici e sicurezza    │ Mai introdotta nei GAP                                                                      │
  ├─────┼─────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────┤
  │ 10  │ Installed base: cliente × prodotto × versione × sede        │ Prerequisito operativo critico; i GAP non aggiungono mai entità cliente                     │
  ├─────┼─────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────┤
  │ 11  │ Data installazione e stato contratto di supporto            │ Idem                                                                                        │
  ├─────┼─────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────┤
  │ 12  │ Storico completo comunicazioni per cliente                  │ Idem                                                                                        │
  ├─────┼─────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────┤
  │ 13  │ Canali notifica per cliente (email, referente               │ GAP 9 aggiunge NotificationSubscriber ma è abbonamento tecnico al feed, non anagrafica B2B  │
  │     │ tecnico/sicurezza)                                          │ cliente                                                                                     │
  ├─────┼─────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────┤
  │ 14  │ Import installed base da ERP/CRM                            │ Idem — no concetto installed base                                                           │
  ├─────┼─────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────┤
  │ 8   │ Import prodotti da PLM/ERP                                  │ Nessun GAP tocca integrazione PLM/ERP                                                       │
  └─────┴─────────────────────────────────────────────────────────────┴─────────────────────────────────────────────────────────────────────────────────────────────┘

  ---
  M2 — Gestione SBOM

  ❌ Non coperto

  ┌─────┬───────────────────────────────────────────────────────────────────────────────────┬───────────────────────────────────────────────────────────────────────┐
  │ ID  │                                   Funzionalità                                    │                                Motivo                                 │
  ├─────┼───────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ 16  │ Inserimento manuale componenti con form strutturato (campi obbligatori custom,    │ GAP 10 aggiunge completeness validator ma non form manuale guidato    │
  │     │ validazione PURL strict, note contesto OT)                                        │ per OT                                                                │
  ├─────┼───────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ 17  │ Modalità ibrida: import scanner + delta manuale tracciato come state machine      │ Nessun GAP implementa questa orchestrazione                           │
  ├─────┼───────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ 21  │ Versioning automatico SBOM (major.minor.patch) a ogni modifica                    │ GAP 10 Step 1 aggiunge solo flag is_current + serial_number; nessuna  │
  │     │                                                                                   │ numerazione semantica automatica                                      │
  ├─────┼───────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ 22  │ Freeze SBOM per versioni rilasciate (immutabilità + annotazione)                  │ GAP 10 non aggiunge lock/immutabilità formale — is_current è flag di  │
  │     │                                                                                   │ navigazione, non freeze                                               │
  ├─────┼───────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ 23  │ Diff tra versioni SBOM (componenti aggiunti/rimossi/aggiornati)                   │ Nessun GAP                                                            │
  ├─────┼───────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ 25  │ Build-time: integrazione CI/CD per generazione SBOM automatica (Syft/Trivy)       │ Nessun GAP (DT accetta push da CI/CD ma il trigger pipeline è         │
  │     │                                                                                   │ esterno)                                                              │
  ├─────┼───────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ 26  │ Deploy-time: raccolta SBOM al momento installazione/collaudo macchinario          │ Nessun GAP                                                            │
  ├─────┼───────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ 27  │ Run-time: agent/script periodici su macchinario per verifica continua             │ Nessun GAP                                                            │
  ├─────┼───────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ 29  │ VEX workflow con giustificazione obbligatoria per not_affected                    │ Nessun GAP aggiunge giustificazione obbligatoria + workflow           │
  │     │                                                                                   │ approvativo sul VEX                                                   │
  ├─────┼───────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ 31  │ Supporto componenti hardware in SBOM (proto-HBOM UI e gestione avanzata)          │ GAP 12 aggiunge solo batchNumber/hardwareRevision su Project; nessuna │
  │     │                                                                                   │  UI HBOM                                                              │
  └─────┴───────────────────────────────────────────────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────┘

  ---
  M3 — Vulnerability Intelligence Feed

  ❌ Non coperto

  ┌─────┬──────────────────────────────────────────────────────────┬────────────────────────────────────────┐
  │ ID  │                       Funzionalità                       │                 Motivo                 │
  ├─────┼──────────────────────────────────────────────────────────┼────────────────────────────────────────┤
  │ 36  │ CISA ICS-CERT Advisories (OT/SCADA/PLC/HMI)              │ Nessun GAP — fonte OT/ICS non trattata │
  ├─────┼──────────────────────────────────────────────────────────┼────────────────────────────────────────┤
  │ 38  │ CERT-EU Security Advisories                              │ Nessun GAP                             │
  ├─────┼──────────────────────────────────────────────────────────┼────────────────────────────────────────┤
  │ 39  │ ACN (Agenzia Cybersicurezza Nazionale) advisory italiani │ Nessun GAP                             │
  ├─────┼──────────────────────────────────────────────────────────┼────────────────────────────────────────┤
  │ 43  │ Score di confidenza del match (alta/media/bassa)         │ Nessun GAP                             │
  ├─────┼──────────────────────────────────────────────────────────┼────────────────────────────────────────┤
  │ 45  │ Exploit availability tracking (PoC su GitHub/ExploitDB)  │ Nessun GAP                             │
  └─────┴──────────────────────────────────────────────────────────┴────────────────────────────────────────┘

  ---
  M4 — Risk Assessment e Triage

  ❌ Non coperto

  ┌─────┬──────────────────────────────────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────┐
  │ ID  │                               Funzionalità                               │                                     Motivo                                     │
  ├─────┼──────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
  │ 47  │ Impact analysis automatica: CVE → componenti → prodotti → clienti        │ I GAP non aggiungono mai il livello cliente; DT arriva a Project ma non a      │
  │     │ installati                                                               │ installed base                                                                 │
  ├─────┼──────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
  │ 48  │ Lista prioritizzata cliente × prodotto × versione × severità × contatto  │ Dipende da installed base — non coperta                                        │
  │     │ notifica                                                                 │                                                                                │
  ├─────┼──────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
  │ 50  │ Prioritizzazione per criticità cliente (NIS2/infrastruttura critica)     │ No concetto cliente nei GAP                                                    │
  ├─────┼──────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
  │ 51  │ Coda triage con stati normativi CRA (new / under_investigation /         │ GAP 2 aggiunge CraReportingObligation ma non rimappa gli stati di triage DT    │
  │     │ vex_assessed / notification_required / patch_available / closed)         │ agli stati normativi CRA                                                       │
  ├─────┼──────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
  │ 52  │ Assegnazione owner e tracking responsabile per ogni voce triage          │ Nessun GAP estende il tracking owner                                           │
  ├─────┼──────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
  │ 53  │ Timer SLA visibili con countdown 24h/72h                                 │ GAP 2 aggiunge early_warning_due_at/notification_due_at ma non                 │
  │     │                                                                          │ un'interfaccia/logica di countdown visibile operativamente                     │
  ├─────┼──────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
  │ 55  │ Risk score composito: CVSS + EPSS + KEV ponderato                        │ Nessun GAP                                                                     │
  ├─────┼──────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
  │ 56  │ VEX assessment workflow con giustificazione documentata obbligatoria     │ Idem punto ID 29                                                               │
  │     │ (nel contesto coda triage M4)                                            │                                                                                │
  ├─────┼──────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
  │ 57  │ Scoring contestualizzato per deployment type (internet-exposed vs. rete  │ Nessun GAP — richiede metadati installazione                                   │
  │     │ isolata)                                                                 │                                                                                │
  ├─────┼──────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
  │ 58  │ Remediation plan con data prevista e milestone                           │ Nessun GAP — tracciato CRA obbligo sì, piano correzione con milestone no       │
  └─────┴──────────────────────────────────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────┘

  ---
  M5 — Notifica e Disclosure Workflow

  ❌ Non coperto o solo parzialmente

  ┌───────┬───────────────────────────────────────────────────────────────────────────┬─────────────────────────────────────────────────────────────────────────────┐
  │  ID   │                               Funzionalità                                │                                Stato nei GAP                                │
  ├───────┼───────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
  │ 60    │ Trigger automatico KEV su prodotto commercializzato (→ clienti impattati) │ GAP 2 triggera su Project DT, non su installed base/clienti                 │
  ├───────┼───────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
  │ 61    │ Early Warning 24h: template pre-compilato per ACN                         │ GAP 2 traccia la scadenza; nessun GAP genera il template regolatorio ACN    │
  ├───────┼───────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
  │ 62    │ Notifica Formale 72h: report strutturato con componente SBOM, CVSS,       │ GAP 2 traccia l'obbligo; nessun GAP genera il documento formale 72h         │
  │       │ clienti impattati, piano remediation                                      │                                                                             │
  ├───────┼───────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
  │ 63    │ Report Finale 14 giorni: azioni intraprese, patch rilasciata              │ Idem                                                                        │
  ├───────┼───────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
  │ 64    │ Audit trail comunicazioni ENISA/ACN (registro immutabile segnalazioni)    │ GAP 11 registra timestamp invio CSIRT ma non un registro immutabile         │
  │       │                                                                           │ orientato a ispezione ACN                                                   │
  ├───────┼───────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
  │ 65    │ Distinzione chiara UI tra reporting regolatorio e gestione interna        │ Nessun GAP                                                                  │
  │       │ vulnerabilità                                                             │                                                                             │
  ├───────┼───────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
  │ 67    │ Email notification ai clienti B2B impattati                               │ GAP 9 aggiunge NotificationSubscriber (webhook/feed); non email             │
  │       │                                                                           │ marketing/SMTP verso clienti B2B con lista da installed base                │
  ├───────┼───────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
  │ 68    │ Template email parametrici per clienti (cliente, prodotto, versione, CVE, │ Nessun GAP                                                                  │
  │       │  gravità, azioni raccomandate)                                            │                                                                             │
  ├───────┼───────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
  │ 69–72 │ Tipologie comunicazione cliente (advisory informativo / intervento remoto │ Nessun GAP                                                                  │
  │       │  / aggiornamento programmato / blocco emergenziale)                       │                                                                             │
  ├───────┼───────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
  │ 73    │ Approvazione interna pre-invio comunicazione (1–2 livelli)                │ Nessun GAP                                                                  │
  ├───────┼───────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
  │ 74    │ Tracking invio + acknowledgment cliente (link conferma lettura)           │ Nessun GAP                                                                  │
  ├───────┼───────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
  │ 75    │ Escalation automatica su mancata risposta cliente                         │ Nessun GAP                                                                  │
  ├───────┼───────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────┤
  │ 76–79 │ Patch campaign management su installed base (campagna, maintenance        │ Nessun GAP — presuppongono installed base                                   │
  │       │ windows, dipendenze, tracciamento adozione)                               │                                                                             │
  └───────┴───────────────────────────────────────────────────────────────────────────┴─────────────────────────────────────────────────────────────────────────────┘

  ---
  M6 — Audit Trail, Alert e Compliance Evidence

  ❌ Non coperto

  ┌─────┬──────────────────────────────────────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────┐
  │ ID  │                                 Funzionalità                                 │                                   Motivo                                   │
  ├─────┼──────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
  │ 81  │ Audit log immutabile append-only con timestamp                               │ Nessun GAP aggiunge log immutabile proprietario; DT ha log base non        │
  │     │                                                                              │ orientato a ispezione CRA                                                  │
  ├─────┼──────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
  │ 82  │ Granularità per campo (chi, cosa, quando, da/a quale valore)                 │ Nessun GAP                                                                 │
  ├─────┼──────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
  │ 83  │ Export audit log per verifiche esterne (ACN, organismo notificato)           │ Nessun GAP                                                                 │
  ├─────┼──────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
  │ 84  │ Firma crittografica log (non-repudiation)                                    │ Nessun GAP                                                                 │
  ├─────┼──────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
  │ 87  │ Alert variazioni CVSS/severity su CVE già note                               │ Nessun GAP                                                                 │
  ├─────┼──────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
  │ 88  │ Alert SLA triage in scadenza (24h/72h imminenti)                             │ GAP 2 aggiunge TaskScheduler per overdue ma non alert proattivo            │
  │     │                                                                              │ pre-scadenza                                                               │
  ├─────┼──────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
  │ 89  │ Alert clienti critici non ancora notificati dopo X ore                       │ No concetto cliente nei GAP                                                │
  ├─────┼──────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
  │ 90  │ Alert patch non applicate su installazioni ad alto rischio                   │ No concetto installazione cliente nei GAP                                  │
  ├─────┼──────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
  │ 95  │ Digest periodici per il management (settimanale/mensile)                     │ Nessun GAP                                                                 │
  ├─────┼──────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
  │ 96  │ Compliance dashboard CRA (SLA compliance %, SBOM coverage %)                 │ GAP 2 aggiunge endpoint /cra/reporting-obligations ma non dashboard KPI    │
  │     │                                                                              │ CRA                                                                        │
  ├─────┼──────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
  │ 97  │ KPI direzionali (MTTR, % clienti aggiornati, stato notifiche regolatorie)    │ Nessun GAP                                                                 │
  ├─────┼──────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
  │ 98  │ Trend storico KPI nel tempo                                                  │ Nessun GAP                                                                 │
  ├─────┼──────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
  │ 99  │ Report Allegato VII CRA strutturato                                          │ GAP 10 Step 5 produce ZIP tecnico; non il report strutturato Allegato VII  │
  │     │                                                                              │ per valutatori                                                             │
  ├─────┼──────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
  │ 100 │ Evidence pack per valutatori Classe I/II (SBOM versionata, log triage, proof │ GAP 10 Step 5 produce ZIP parziale; mancano proof of notification, log     │
  │     │  of notification, CVD policy, test reports)                                  │ triage formattato, evidence pack completo                                  │
  └─────┴──────────────────────────────────────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────┘

  ---
  ADD-ON — Customer Portal B2B

  ❌ Interamente non coperto

  | ID 101–105 | Vista installed base, stato vulnerabilità real-time, download SBOM, acknowledgment notifiche, storico comunicazioni | Dipende tutto da concetto cliente
   — assente dai GAP |

  ---
  Sintesi per macro-aree mancanti

  GAP analysis copre: DT come motore tecnico (modello dati, API, parser, notifiche interne)
  GAP analysis NON copre:

  1. STRATO CLIENTE — Anagrafica B2B, installed base, canali notifica per cliente,
     acknowledgment, campagne remediation → zero copertura in tutti i 14 GAP

  2. WORKFLOW NOTIFICA REGOLATORIA — Template ACN/ENISA pre-compilati, stati
     approvazione interna, report formali 72h/14gg strutturati → GAP 2/11 tracciano
     scadenze ma non generano i documenti

  3. SBOM LIFECYCLE AVANZATO — Semantic versioning automatico, freeze/immutabilità,
     diff, CI/CD trigger, deploy-time/run-time collection → GAP 10 copre export
     arricchito ma non gestione lifecycle completa

  4. AUDIT IMMUTABILE — Log append-only field-level, export per ACN, firma
     crittografica → nessun GAP

  5. FEED OT/SETTORIALI — CISA ICS-CERT, CERT-EU, ACN → nessun GAP

  6. DASHBOARD/KPI CRA — Compliance dashboard, MTTR, trend storico, evidence
     pack Classe I/II → nessun GAP
