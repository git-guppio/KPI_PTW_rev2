#Requires AutoHotkey v2.0
 
global G_CONSTANTS := {
    ;file_Country: A_ScriptDir . "\Config\country.csv",
    DIRECTORY_CONFIG_FILE: A_ScriptDir "\directories.ini",
    IMPIANTI_CONFIG_FILE: A_ScriptDir "\impianti.ini",
    EXPORT_IW39_RAW_FILE: A_ScriptDir "\Export\Export_IW39_raw.txt",
    EXPORT_IW39_CSV_FILE: A_ScriptDir "\Export\Export_IW39_csv.txt",    
    EXPORT_IW49N_RAW_FILE: A_ScriptDir "\Export\Export_IW49N_raw.txt",
    EXPORT_IW49N_CSV_FILE: A_ScriptDir "\Export\Export_IW49N_csv.txt",
    ESTRAZIONI_SAP: ["AdM", "OdM", "SicuAmbi", "Ptw"],
    DB_FILENAME: A_ScriptDir . "\PTW.DB",
    ;STATI_PTW: ["WAHO", "WIP", "PH", "TEST", "WOC", "WPHB", "INOP", "OP", "IP", "WRELI", "WREL", "POP"],
    STATI_PTW: ["WIP", "PH", "TEST", "WOC", "WPHB", "INOP", "POP"],
    STATI_PTW_2026: ["WAHO", "OP", "IP", "WRELI", "WREL"],
    TABLE_NAME_ODM_LIST: "IW39",
    TABLE_NAME_RAW_DATA: "IW49N",
    TABLE_NAME_CLEAN_DATA: "CleanData",
    TABLE_NAME_ODM_PTW_DATA: "OdMPTW",
    VIEW_NAME_ODM_PTW_DATA: "ViewOdMPTW",
    TABLE_NAME_PTW_PIVOT: "Pivot",
    TABLE_NAME_ODM_SENZA_PTW: "OdMSenzaPTW",
    DEBUG_MODE: false,
    TARGET_KPI: 80,
    COLOR : Map(
        "SOFT_BLUE", 0xE1B094,     ; Azzurro medio
        "SAGE", 0x9CDBB2,          ; Verde salvia
        "DUSTY_ROSE", 0xC5AAE0,    ; Rosa antico
        "PEACH", 0xB4C4FF,         ; Pesca
        "MUTED_YELLOW", 0xBCE5DA,  ; Giallo smorzato
        "MAUVE", 0xC9B4DD,         ; Malva
        "MOSS", 0xB2D8A7,          ; Verde muschio
        "POWDER_BLUE", 0xE6C5A7,   ; Azzurro polvere
        "SALMON", 0xB4C8E6,        ; Salmone
        "WISTERIA", 0xE6C4D8,      ; Glicine
        "DUSTY_CORAL", 0xB4C8FF,   ; Corallo polveroso
        "BUFF", 0xC9DDE6,          ; Beige rosato
        "PERIWINKLE", 0xE6C5B4,    ; Pervinca
        "SAGE_GREEN", 0xB9D5C9,    ; Verde salvia medio
        "ROSE_QUARTZ", 0xD4BCD2    ; Quarzo rosa
    )
    }

        /* 
        Esempio di utilizzo:
        G_CONSTANTS.test
        */