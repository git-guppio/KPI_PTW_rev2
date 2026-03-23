# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KPI_PTW_rev2 is a Windows desktop application built in **AutoHotkey v2.0** that tracks KPI (Key Performance Indicator) metrics for PTW (Permit to Work) procedures at Enel's power generation plants. It extracts data from SAP ERP, stores it in SQLite, and displays a dashboard with PTW coverage statistics (target: 80%).

**All code, comments, variable names, and UI labels are in Italian.**

## Running the Application

- **Development**: Open `Main.ahk` in AutoHotkey v2.0 and run it directly (requires AHK v2.0 installed)
- **Compiled**: Run `DashBoard_KPI_PTW.exe` (pre-compiled x86-64 Windows executable)
- **Requirements**: `sqlite3.dll` must be in the same directory as the script/executable; SAP GUI must be installed and accessible for SAP data extraction

There is no build system or test framework — AHK scripts run directly.

## Architecture

### Entry Point and Module Structure

`Main.ahk` is the entry point. It `#Include`s all modules and instantiates the main GUI:

```
Main.ahk
├── GlobalConstants.ahk     ← All global config: table names, states, colors, paths
├── Class_SQLiteDB.ahk      ← SQLite3 wrapper (DllCall into sqlite3.dll)
├── Class_LV_Colors.ahk     ← ListView row coloring
├── RichEdit.ahk            ← Windows RichEdit control wrapper
├── MakeDB.ahk              ← Database management + SAP data import pipeline
├── Utils/ArrayTools.ahk    ← Pipe/tab-delimited data parsing utilities
├── GUI/ButtonIconManager.ahk
├── GUI/GestioneImpianti.ahk ← Plant (impianto) configuration UI + INI management
├── GUI/GUI_NO_Response.ahk  ← Main dashboard GUI (1513 lines)
└── SAP/SAP_Connection.ahk  ← SAP COM automation
    SAP/SAP_Transactions.ahk ← IW39 and IW49N transaction scrapers
```

### Data Flow

```
SAP GUI (IW39/IW49N transactions)
  → clipboard extraction (SAP_Transactions.ahk)
  → Export/*.txt raw files
  → DataParser.parseFile() (tab-delimited → objects)
  → DBManager: createTable() → createFilteredTable() → CreateNewTableWithPTWColumn() → createPTWPivot()
  → SQLite PTW.DB
  → DataView.PopulateListView() → GUI dashboard
```

### Key Classes

**`MakeDB.ahk`**
- `DBManager` — creates/manages SQLite tables; key methods: `createFilteredTable()` (excludes APER/FCAN/BLOC states), `CreateNewTableWithPTWColumn()` (adds PTW/POP boolean flags), `createPTWPivot()` (aggregates per order), `getPTWStats()`
- `DataParser` — parses pipe-delimited export files into AHK arrays; `ManageDB_File()` orchestrates the full import
- `DataView` — populates a ListView from a DB table dynamically

**`GUI/GUI_NO_Response.ahk`** — Responsive 4-panel dashboard:
- Left: ListView of OdM (maintenance orders) with status icons from shell32.dll (OK=295, Alert=236, NOK=132)
- Top-right: OdM detail (RichEdit, read-only)
- Middle-right: KPI details
- Bottom-right: SAP extraction controls + date editing

**`SAP/SAP_Connection.ahk`** — Connects via COM (`SapROTWrapper`); targets system `"0116 E4E - R4P - Power Generation"`

**`SAP/SAP_Transactions.ahk`** — Automates `IW49N` (operations list, layout `/KPI_PTW`) and `IW39` (order list, layout `/KPIODMPOOL`) to extract data to clipboard, then saves to `Export/`

### Database Schema (PTW.DB)

| Table | Description |
|---|---|
| `IW39` | Raw order list from SAP IW39 |
| `IW49N` | Raw operations list from SAP IW49N |
| `CleanData` | IW49N filtered to active states (excludes APER, FCAN, BLOC) |
| `OdMPTW` | CleanData enriched with PTW and POP boolean columns |
| `ViewOdMPTW` | SQL view over OdMPTW |
| `Pivot` | Aggregated KPI stats per order (COUNT ops, PTW coverage %, POP count) |
| `OdMSenzaPTW` | Orders with no PTW procedures |

PTW detection: a row has PTW=1 if `ChTstStd` contains PTW-related codes. POP=1 if `ChTstStd` = `SF_POP`.

### Configuration

**`GlobalConstants.ahk`** — Single source of truth for:
- DB file paths and export file paths
- All table/view names (constants like `TABLE_IW39`, `TABLE_PIVOT`, etc.)
- `STATI_PTW`: valid PTW states (`WIP`, `PH`, `TEST`, `WOC`, `WPHB`, `INOP`, `POP`)
- `STATI_PTW_2026`: new states for 2026 (`WAHO`, `OP`, `IP`, `WRELI`, `WREL`)
- `STATI_ESCLUSIONE`: system states to exclude from CleanData
- KPI target: 80%
- 16-color soft palette for UI row coloring
- Plant categories: `COAL`, `GAS`, `ImpFuture`

**`impianti.ini`** — Plant codes per category (e.g., COAL: BS, TN, FS, SU; GAS: LC, MC, PC, PE, SB, TI). Managed at runtime via `GestioneImpianti.ahk`.

### Important Conventions

- AHK v2.0 syntax throughout (not v1.1 — they are not compatible)
- Class methods use `.Bind(this)` for event callbacks
- SQL queries use `COALESCE` on nullable state fields (added recently)
- `Class_SQLiteDB.ahk` handles all SQLite via `DllCall` into `sqlite3.dll` — use its API, not raw DLL calls
- `ArrayTools.ahk`'s `CreaArrayDaClipboard()` parses tab-separated clipboard content from SAP into a 2D AHK array
