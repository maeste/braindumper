# PRD: Sistema di Cattura e Organizzazione Idee

## 📋 Panoramica

Un sistema in due parti per catturare automaticamente tutto ciò che l'utente copia in Gnome e organizzarlo successivamente tramite CLI.

**Target**: Utenti Linux/Gnome che lavorano principalmente da terminale e vogliono catturare idee/contenuti senza interrompere il flusso di lavoro.

---

## 🎯 Obiettivi

### Obiettivo Primario
Catturare **automaticamente** ogni operazione di copia (Ctrl+C) in Gnome, salvando il contenuto con timestamp in un file strutturato.

### Obiettivo Secondario
Fornire strumenti CLI per organizzare, cercare ed esportare i contenuti catturati.

---

## 🏗️ Architettura del Sistema

### Fase 1: Cattura Base
```
┌─────────────────────────────────────┐
│    UTENTE LAVORA IN GNOME           │
│    (copia testo, comandi, URL...)   │
└─────────────┬───────────────────────┘
              │ Ctrl+C
              ▼
┌─────────────────────────────────────┐
│   DAEMON (background)                │
│   • Monitora clipboard               │
│   • Salva ogni copia con timestamp   │
│   • Filtra duplicati consecutivi     │
└─────────────┬───────────────────────┘
              │ Scrive in
              ▼
┌─────────────────────────────────────┐
│   FILE clips.jsonl                   │
│   (ogni riga = 1 clip con metadata)  │
└─────────────┬───────────────────────┘
              │ Letto da
              ▼
┌─────────────────────────────────────┐
│   CLI TOOL                           │
│   • List / Search                    │
│   • Export (MD, TXT, JSON)           │
│   • Delete / Archive                 │
└─────────────────────────────────────┘
```

### Fase 2: Quick-Tagging
```
┌─────────────────────────────────────┐
│         UTENTE IN GNOME             │
└────┬──────────────────────┬─────────┘
     │ Ctrl+C               │ Ctrl+[1-9]
     │                      │ (entro 500ms)
     ▼                      ▼
┌──────────────────┐  ┌──────────────────┐
│ Clipboard        │  │ Keyboard         │
│ Monitor          │  │ Listener         │
│ (GTK)            │  │ (pynput)         │
└────┬─────────────┘  └────┬─────────────┘
     │                     │
     │ 1. Salva clip       │ 2. Aggiorna tag
     │    tags: []         │    tags: ["url"]
     ▼                     ▼
┌─────────────────────────────────────┐
│   clips.jsonl (with tags)            │
│   {"timestamp": "...",               │
│    "content": "...",                 │
│    "tags": ["url", "important"]}     │
└─────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────┐
│   CLI TOOL (tag-aware)               │
│   • List --tag code                  │
│   • Stats --tags                     │
│   • Config tag mappings              │
└─────────────────────────────────────┘
```

---

## 🔧 Componente 1: Daemon di Monitoraggio

### Funzionalità Core

#### 1.1 Monitoraggio Clipboard
- **Tecnologia**: GTK3 (nativo Gnome) con fallback a `xclip`
- **Frequenza polling**: 500ms (configurabile)
- **Modalità**: Daemon background o foreground (debug)

#### 1.2 Salvataggio Automatico
Ogni volta che la clipboard cambia, salva:

```json
{
  "timestamp": "2025-11-03T14:32:15.123456",
  "content": "testo copiato dall'utente",
  "length": 156,
  "source_app": "firefox",  // opzionale, v2
  "preview": "primi 100 caratteri..."
}
```

#### 1.3 Filtri Intelligenti
- **No duplicati consecutivi**: se copi 2 volte la stessa cosa, salva solo una volta
- **No contenuti vuoti**: ignora copie di stringhe vuote o solo whitespace
- **Limite dimensione** (opzionale): non salvare contenuti > 10MB

#### 1.4 Gestione Daemon
```bash
# Comandi principali
clipboard-monitor start    # Avvia daemon in background
clipboard-monitor stop     # Ferma daemon
clipboard-monitor status   # Mostra se è attivo + statistiche
clipboard-monitor run      # Foreground mode (per debug)
```

### File e Percorsi
```
~/.local/share/clipboard-monitor/
├── clips.jsonl           # Database clips (1 JSON per riga)
├── daemon.pid            # PID del daemon
└── daemon.log            # Log eventi
```

### Requisiti Sistema
- **OS**: Linux con Gnome 3.x+
- **Dipendenze Python**: 
  - `pygobject` (per GTK)
  - `xclip` (fallback, se pygobject non disponibile)
- **Python**: 3.8+

---

## 🛠️ Componente 2: CLI Tool per Organizzazione

### Funzionalità Core

#### 2.1 Visualizzazione
```bash
# Mostra ultime N clip
clips list --last 20

# Mostra tutte le clip di oggi
clips list --today

# Mostra clip in un range di date
clips list --from 2025-11-01 --to 2025-11-03
```

Output esempio:
```
📋 Clip #1234
🕐 2025-11-03 14:32:15
📏 156 caratteri

testo copiato dall'utente con preview dei primi
100 caratteri se troppo lungo...

────────────────────────────────────────
```

#### 2.2 Ricerca
```bash
# Ricerca full-text
clips search "parola chiave"

# Ricerca regex
clips search --regex "http.*github\.com"

# Ricerca per lunghezza
clips search --min-length 500
```

#### 2.3 Tagging e Organizzazione *(Fase 2+)*
```bash
# Aggiungi tag manualmente a una clip (dopo Fase 2.1)
clips tag 1234 python,snippet,utils

# Cerca per tag
clips list --tag python

# Rimuovi tag
clips untag 1234 utils

# Configura quick-tag mapping (Fase 2.1+)
clips config tag 3 links  # Ctrl+3 → "links" invece di "url"
```

**Quick-Tagging in azione** (Fase 2):
1. Utente copia → Ctrl+C
2. Entro 500ms → Ctrl+3 (tag automatico "url")
3. Conferma → Notifica desktop "✓ Tag 'url' aggiunto"

#### 2.4 Export
```bash
# Export in Markdown
clips export --format md --output ideas.md

# Export solo clip taggate
clips export --tag important --format md

# Export JSON (per backup/processing)
clips export --format json --output backup.json
```

#### 2.5 Gestione
```bash
# Elimina clip
clips delete 1234

# Elimina clip più vecchie di N giorni
clips clean --older-than 90

# Statistiche
clips stats
```

Output stats:
```
📊 Statistiche Clipboard

Totale clip: 3,456
Dimensione totale: 2.3 MB
Prima clip: 2025-08-15
Ultima clip: 2025-11-03

Top 5 giorni più attivi:
  2025-11-01: 89 clip
  2025-10-28: 67 clip
  ...

Tag più usati:
  #python: 234
  #url: 189
  #snippet: 156
```

---

## 📐 Formato Dati

### File: clips.jsonl
Ogni riga è un JSON completo (JSONL = JSON Lines):

```json
{"timestamp": "2025-11-03T14:32:15.123456", "content": "print('hello')", "length": 15, "preview": "print('hello')", "tags": ["code"]}
{"timestamp": "2025-11-03T14:35:22.789012", "content": "https://github.com/...", "length": 45, "preview": "https://github.com/...", "tags": ["url", "important"]}
```

**Schema completo**:
- `timestamp`: ISO 8601 format
- `content`: Testo copiato (full)
- `length`: Numero caratteri
- `preview`: Primi 100 char (per display rapido)
- `tags`: Array di stringhe (vuoto in Fase 1, popolato in Fase 2+)

**Vantaggi JSONL**:
- Append-only (performante)
- Facile da parsare riga per riga
- Robusto (se una riga è corrotta, le altre sono ok)
- Grep-friendly per ricerche rapide

---

## 🎨 User Experience

### Flusso d'Uso Tipico

1. **Setup iniziale**
```bash
# Installa
pip install clipboard-monitor

# Avvia daemon (una volta)
clipboard-monitor start

# Opzionale: aggiungi a startup di Gnome
clipboard-monitor install-autostart
```

2. **Lavoro quotidiano**
   - L'utente lavora normalmente
   - Copia comandi, snippet, URL, note
   - **Tutto viene salvato automaticamente** in background
   - Zero interruzioni del flusso

3. **Review serale/settimanale**
```bash
# Cosa ho copiato oggi?
clips list --today

# Trova quel comando git che avevo copiato
clips search "git rebase"

# Salva snippet interessanti
clips tag 4567 git,useful
clips export --tag useful --output snippets.md
```

### Feedback Utente

**Daemon attivo**:
- Nessun feedback (silenzioso)
- Opzionale: notifica desktop al primo clip del giorno

**CLI interattivo**:
- Progress bar per operazioni lunghe
- Colori per leggibilità
- Conferme per operazioni distruttive

---

## 🔒 Privacy e Sicurezza

### Considerazioni

⚠️ **Il sistema salva TUTTO ciò che viene copiato**, incluso:
- Password (se copiate)
- Token di autenticazione
- Dati sensibili

### Mitigazioni

#### Filtri Automatici (Opzionali)
```python
# Non salvare contenuti che matchano pattern
IGNORE_PATTERNS = [
    r'^[A-Za-z0-9+/]{40,}={0,2}$',  # Token base64
    r'Bearer\s+[A-Za-z0-9\-._~+/]+=*',  # Bearer tokens
]
```

#### Encryption at Rest (v2)
- Opzione per cifrare clips.jsonl con password
- Sblocco automatico all'avvio della sessione Gnome

#### File Permissions
```bash
# clips.jsonl dovrebbe essere 600 (solo utente)
chmod 600 ~/.local/share/clipboard-monitor/clips.jsonl
```

---

## 🚀 Piano di Sviluppo

### Timeline Visuale

```
Fase 1 (MVP)          Fase 2 (Quick-Tag)    Fase 3 (CLI Adv)    Fase 4 (Advanced)
   1-2 giorni            1 settimana          3-5 giorni          1-2 settimane
      │                      │                     │                    │
      ▼                      ▼                     ▼                    ▼
┌──────────┐          ┌──────────┐          ┌──────────┐         ┌──────────┐
│ Cattura  │  ───────▶│ Tagging  │  ───────▶│ Export & │ ──────▶│ ML, Sync │
│ Base     │          │ Hotkey   │          │ Advanced │         │ Encrypt  │
│          │          │          │          │ Search   │         │          │
│ • GTK    │          │ • pynput │          │ • Export │         │ • OCR    │
│ • JSONL  │          │ • Ctrl+N │          │ • Stats  │         │ • Cloud  │
│ • CLI    │          │ • Config │          │ • Regex  │         │ • Web UI │
└──────────┘          └──────────┘          └──────────┘         └──────────┘
    CORE              PRODUCTIVITY          ORGANIZATION          INNOVATION
   (Must)               (Should)              (Nice)               (Future)
```

### Fase 1: MVP (Minimo Prodotto Funzionante)
**Timeframe**: 1-2 giorni

**Obiettivo**: Cattura automatica funzionante e visualizzazione base

- ✅ Daemon che monitora clipboard (GTK)
- ✅ Salvataggio in clips.jsonl (con campo `tags: []` vuoto)
- ✅ Comandi base: start/stop/status/run
- ✅ CLI: list (con filtri data), search (full-text semplice)
- ✅ Filtro duplicati consecutivi
- ✅ Gestione PID e log
- ✅ File permissions corretti (600)

**Output Fase 1**: Sistema funzionante che cattura e salva tutto, pronto per aggiungere tagging in Fase 2.

### Fase 2: Quick-Tagging con Hotkey 🏷️
**Timeframe**: 1 settimana

Sistema di tagging rapido che permette di categorizzare le clip **immediatamente dopo la copia** senza interrompere il flusso di lavoro.

#### Concetto
Dopo aver fatto Ctrl+C, l'utente ha **500ms** (configurabile) per premere Ctrl+[1-9] e applicare un tag predefinito alla clip appena salvata.

#### Implementazione Tecnica
- **Keyboard Listener Globale** con libreria `pynput`
- Monitora eventi tastiera a livello sistema
- Intercetta combinazioni Ctrl+[1-9] nella finestra temporale
- Aggiorna in-place l'ultima clip in `clips.jsonl`

#### File di Configurazione
```yaml
# ~/.config/clipboard-monitor/config.yaml
tagging:
  enabled: true
  timeout_ms: 500  # finestra temporale
  feedback: true   # notifiche desktop
  
  quick_tags:
    1: "important"
    2: "code"
    3: "url"
    4: "todo"
    5: "reference"
    6: "personal"
    7: "work"
    8: "temp"
    9: "archive"
```

#### User Experience Flow
```
1. Utente: Ctrl+C (copia testo)
   → Daemon: Salva clip con tags: []

2. Utente: Ctrl+3 (entro 500ms)
   → Daemon: Aggiorna tags: ["url"]
   → Sistema: Notifica "✓ Tag 'url' aggiunto"

3. Utente: Ctrl+1 (entro altri 300ms dalla copia)
   → Daemon: Aggiorna tags: ["url", "important"]
   → Sistema: Notifica "✓ Tag 'important' aggiunto"
```

#### Sotto-fasi Implementazione

**Fase 2.1: Single Tag (MVP)** - 2 giorni
- ✅ Keyboard listener funzionante
- ✅ Intercetta Ctrl+[1-9]
- ✅ Applica 1 solo tag per clip
- ✅ Configurazione base

**Fase 2.2: Multi-Tag** - 2 giorni
- ✅ Supporto tag multipli nella finestra temporale
- ✅ Update efficiente di clips.jsonl (no riscrittura completa)
- ✅ Gestione edge cases (timeout, clip successive)

**Fase 2.3: UX Polish** - 2 giorni
- ✅ Notifiche desktop eleganti
- ✅ Sound feedback (opzionale)
- ✅ Visual indicator (system tray icon?)
- ✅ Statistiche tag nel CLI

#### Nuovi Comandi CLI
```bash
# Lista clip per tag
clips list --tag code

# Modifica mapping tag
clips config tag 3 links  # cambia tag 3 da "url" a "links"

# Statistiche tag usage
clips stats --tags
```

#### Requisiti Aggiuntivi
- **Dipendenza**: `pynput>=1.7.0`
- **Permessi**: Accesso a `/dev/input/` (gestito da pynput)
- **Testing**: Virtual keyboard per test automatici

#### Considerazioni Tecniche

**Performance**:
- Keyboard listener deve avere latenza < 50ms
- Update clips.jsonl tramite seek/write in-place (no full rewrite)

**Sicurezza**:
- Listener filtra solo Ctrl+[1-9], ignora tutto il resto
- Nessun keylogging di altri tasti

**Fallback**:
- Se pynput non disponibile/permessi negati → fase 2 disabilitata automaticamente
- Warning all'avvio + suggerimento fix

---

### Fase 3: CLI Organizzazione Avanzata
**Timeframe**: 3-5 giorni

- 🔲 Export (Markdown, JSON, HTML)
- 🔲 Statistiche dettagliate
- 🔲 Ricerca avanzata (regex, date range, fuzzy search)
- 🔲 Autostart Gnome
- 🔲 Gestione (delete, clean, archive)
- 🔲 Import da altri clipboard managers

### Fase 4: Features Avanzate
**Timeframe**: 1-2 settimane

- 🔲 Detect source app (quale app ha generato la copia?)
- 🔲 Filtri privacy automatici (pattern-based)
- 🔲 Smart auto-tagging (ML-based, opzionale)
- 🔲 Sync tra macchine (Git-based o Syncthing)
- 🔲 Web UI per browsing (opzionale)
- 🔲 OCR per immagini copiate (tesseract integration)
- 🔲 Encryption at rest

---

## 🧪 Testing

### Test Daemon
```bash
# Test 1: Copia testo semplice → salvato
# Test 2: Copia 2 volte stesso testo → salvato 1 volta
# Test 3: Copia stringa vuota → non salvato
# Test 4: Stop daemon → non salva più
# Test 5: Start già attivo → errore "già in esecuzione"
```

### Test CLI
```bash
# Test 1: list con file vuoto → messaggio appropriato
# Test 2: search con 0 risultati → messaggio chiaro
# Test 3: export con formato invalido → errore
# Test 4: tag su ID inesistente → errore
```

---

## 📦 Installazione e Distribution

### Struttura Package
```
clipboard-monitor/
├── setup.py
├── README.md
├── LICENSE
├── clipboard_monitor/
│   ├── __init__.py
│   ├── daemon.py       # Daemon code
│   ├── cli.py          # CLI commands
│   ├── storage.py      # JSONL handling
│   └── utils.py
└── tests/
    └── ...
```

### Installazione
```bash
# Da PyPI (futuro)
pip install clipboard-monitor

# Da source
git clone https://github.com/user/clipboard-monitor
cd clipboard-monitor
pip install -e .
```

### Dipendenze

**Fase 1 (Core)**:
```txt
# requirements-core.txt
pygobject>=3.42.0      # GTK clipboard access
click>=8.0.0           # CLI framework
python-dateutil>=2.8.0 # Date parsing
```

**Fase 2 (Quick-Tagging)**:
```txt
# requirements-tagging.txt
pynput>=1.7.0          # Keyboard listener globale
pyyaml>=6.0            # Config file parsing
```

**Installazione**:
```bash
# Installazione completa (tutte le fasi)
pip install clipboard-monitor[all]

# Solo core (Fase 1)
pip install clipboard-monitor

# Aggiungi quick-tagging dopo
pip install clipboard-monitor[tagging]
```

---

## 🎯 Success Metrics

### Metriche di Successo

1. **Affidabilità**
   - Uptime daemon > 99%
   - Zero perdite di clip durante sessione di 8h

2. **Performance**
   - Latenza salvataggio < 100ms
   - Memory footprint < 50MB
   - CPU usage < 1% (idle)

3. **Usabilità**
   - Setup completo in < 2 minuti
   - Ricerca su 10k clip in < 1 secondo

---

## 🤔 Decisioni Tecniche

### Perché JSONL invece di SQLite?

| Criterio | JSONL | SQLite |
|----------|-------|--------|
| Semplicità | ✅ Zero setup | ⚠️ Richiede schema |
| Performance write | ✅ Append-only veloce | ⚠️ Overhead transazioni |
| Grep-friendly | ✅ Sì | ❌ No |
| Ricerca complessa | ⚠️ Limitata | ✅ SQL potente |
| Corruption risk | ✅ Isolata per riga | ⚠️ File intero |

**Decisione**: JSONL per MVP, possibile migrazione a SQLite in v2 se necessario.

### Perché GTK invece di solo xclip?

- GTK è **nativo** per Gnome
- Supporto migliore per clipboard manager complessi
- xclip come fallback per flessibilità

---

## 📚 Riferimenti e Ispirazione

### Tool Simili
- **Clipman** (Gnome extension): manager clipboard, ma solo in memoria
- **CopyQ**: clipboard manager con GUI, ma non salva tutto automaticamente
- **Ditto** (Windows): clipboard manager esteso

### Innovazione del Progetto
Combinazione unica di:
- Cattura automatica passiva (no interazione)
- Storage permanente con timestamp
- CLI-first per utenti terminal-oriented

---

## 🎨 Future Visions (v3+)

### Idee per il Futuro

1. **AI-Powered Organization**
   - Auto-tagging con ML
   - "Trova quella cosa che ho copiato su Python e API"
   - Clustering automatico per argomento

2. **Collaboration**
   - Condividi collezioni di clip con team
   - Sync P2P tra dispositivi

3. **Smart Recall**
   - "Riapri tutte le URL che ho copiato oggi"
   - "Copia di nuovo il comando di 3 giorni fa"

4. **Multi-Format Support**
   - OCR per immagini
   - Extract text da PDF copiati
   - Audio transcription

---

## ✅ Checklist Pre-Launch

- [ ] Daemon funziona 8h senza crash
- [ ] Test su fresh Gnome install
- [ ] README con esempi chiari
- [ ] Gestione errori graceful (clipboard busy, permission denied...)
- [ ] Log rotation per daemon.log
- [ ] Uninstall pulito (rimuove file e autostart)

---

**Documento creato**: 2025-11-03  
**Versione**: 1.0  
**Owner**: Tu 😊  
**Next step**: Review del PRD → Decisione go/no-go → Sviluppo Fase 1
