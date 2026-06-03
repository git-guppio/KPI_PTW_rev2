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
    ; Nuovi stati per il calcolo del KPI 2026, escludendo quelli che non sono più rilevanti:
    STATI_PTW: ["WIP", "POP", "PH", "TEST", "WPHB", "WOC", "INOP"],
    TABLE_NAME_ODM_LIST: "IW39",
    TABLE_NAME_RAW_DATA: "IW49N",
    TABLE_NAME_CLEAN_DATA: "CleanData",
    TABLE_NAME_ODM_PTW_DATA: "OdMPTW",
    VIEW_NAME_ODM_PTW_DATA: "ViewOdMPTW",
    TABLE_NAME_PTW_PIVOT: "Pivot",
    TABLE_NAME_ODM_SENZA_PTW: "OdMSenzaPTW",
    DEBUG_MODE: false,
    TARGET_KPI: 85,
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
    ),
    ; Mapping FieldName SAP -> nome canonico + tutti i possibili titoli per la tabella IW39.
    ; canonical: nome con cui la colonna viene salvata nel DB (coincide con i nomi usati nelle query SQL).
    ; titles:    tutti i titoli che SAP può esportare per quel campo (vecchio e nuovo formato).
    ; NOTA: KTEXT ha "Tsto br." come canonical per compatibilità con la query createPTWPivot.
    IW39_FIELD_MAP: Map(
        "AEDAT", {canonical: "Data mod.",                      titles: ["Data modifica anagr. ordine", "Data modifica",          "Data mod.",    "Data mod."                    ]},
        "AUART", {canonical: "Tp.",                            titles: ["Tipo di ordine",              "Tipo di ordine",          "Tipo ord.",    "Tp."                          ]},
        "AUFNR", {canonical: "Ordine",                         titles: ["Ordine",                      "Ordine",                  "Ordine",       "Ordine"                       ]},
        "EQFNR", {canonical: "Campo sort",                     titles: ["Campo sort",                  "Campo sort",              "Campo cl.",    "Campo sort"                   ]},
        "ERDAT", {canonical: "Data acq.",                      titles: ["Data di acquisizione",         "Data acquis.",            "Data acq.",    "Data acq."                    ]},
        "ERNAM", {canonical: "Autore",                         titles: ["Autore",                      "Autore",                  "Autore",       "Autore"                       ]},
        "GEWRK", {canonical: "CLavResp",                       titles: ["Centro lav. respons.",         "Centro LavResp.",         "CLavResp",     "CLavResp"                     ]},
        "GKSTI", {canonical: "CstTotEff.",                     titles: ["Costi tot. effettivi",         "Costi tot. eff.",         "CstTotEff.",   "CstTotEff."                   ]},
        "GKSTP", {canonical: "Cst.tot.p.",                     titles: ["Costi totali pian.",           "Costi tot.pian.",         "Tot.cst.m.",   "Cst.tot.p."                   ]},
        "GLTRP", {canonical: "Fine card.",                      titles: ["Data di fine di base",         "Data fine base",          "Fine base",    "Data di fine di base",  "Fine card."]},
        "GLTRS", {canonical: "Fine sched",                     titles: ["Fine schedulata",              "Fine schedulata",         "Fine sched",   "Fine schedulata"              ]},
        "GSTRP", {canonical: "In. card.",                      titles: ["Data inizio cardine",          "Data in. card.",          "In. card.",    "Data inizio cardine"          ]},
        "ILART", {canonical: "TAM",                            titles: ["Tipo di att. di man.",         "Tp. attività PM",         "Tp.att.PM",    "TAM"                          ]},
        "INGPR", {canonical: "GRP",                            titles: ["Gr. resp. pian. man.",         "GrRespPianManut",         "GrRespPian",   "GRP"                          ]},
        "IWERK", {canonical: "DivP",                           titles: ["Divisione pian.",              "Divisione pian.",         "Div. pian.",   "DivP"                         ]},
        "KTEXT", {canonical: "Tsto br.",                       titles: ["Descrizione",                  "Descrizione",             "Descr.",       "Descrizione",       "Tsto br." ]},
        "PLGRP", {canonical: "GRPM CMan.",                     titles: ["GrRespPianMan CicMan",         "GrRspPian CicMn",         "GRPM CMan.",   "Grp.resp.pian.man. ciclo man."]},
        "PLKNZ", {canonical: "CPO",                            titles: ["Cd.pianif.ordini",             "Cd.pian.ord.",            "CdPianOrd.",   "CPO"                          ]},
        "PLNAL", {canonical: "CGC",                            titles: ["Cont. gruppi cicli",           "Cont.grp.cicli",          "CGC",          "CGC"                          ]},
        "PLNNR", {canonical: "Gruppo",                         titles: ["Gruppo",                       "Gruppo",                  "Gruppo",       "Gruppo"                       ]},
        "PLTXT", {canonical: "Definizione della sede tecnica", titles: ["Def. sede tecnica",            "Definizione",             "Def.",         "Definizione della sede tecnica"]},
        "QMNUM", {canonical: "Avviso",                         titles: ["Avviso",                       "Avviso",                  "Avviso",       "Avviso"                       ]},
        "REVNR", {canonical: "Revis.",                         titles: ["Revisione",                    "Revisione",               "Revisione",    "Revis."                       ]},
        "STTXT", {canonical: "Stato sistema",                  titles: ["Stato sistema",                "Stato sistema",           "St.sist.",     "Stato sistema"                ]},
        "SWERK", {canonical: "Div.",                           titles: ["Divis. ubic.",                 "Divis. ubic.",            "Div.ubic.",    "Div."                         ]},
        "TPLNR", {canonical: "Sede tecnica",                   titles: ["Sede tecnica",                 "Sede tecnica",            "Sede tecn.",   "Sede tecnica"                 ]},
        "USTXT", {canonical: "St.utente",                      titles: ["Stato utente",                 "Stato utente",            "St.utente",    "Stato utente"                 ]},
        "WARPL", {canonical: "Progr. man.",                    titles: ["Progr. manutenzione",          "Progr. manut.",           "ProgrMan",     "Progr. man."                  ]}
    ),
    ; Mapping FieldName SAP -> nome canonico + tutti i possibili titoli per la tabella IW49N.
    ; canonical: nome con cui la colonna viene salvata nel DB (coincide con i nomi usati nelle query SQL).
    ; titles:    tutti i titoli che SAP può esportare per quel campo (vecchio e nuovo formato).
    ; NOTA: GLTRP ha "Fine card." come canonical (nome vecchio formato usato in createFilteredTable);
    ;       "Fine base" (nuovo formato SAP) è incluso nei titles e viene normalizzato al canonical.
    IW49N_FIELD_MAP: Map(
        "AUFNR", {canonical: "Ordine",                 titles: ["Ordine",                "Ordine",              "Ordine",       "Ordine"                          ]},
        "GEWRK", {canonical: "CLavResp",               titles: ["Centro lav. respons.",   "Centro LavResp.",     "CLavResp",     "CLavResp"                        ]},
        "GLTRP", {canonical: "Fine card.",             titles: ["Data di fine di base",   "Data fine base",      "Fine base",    "Data di fine di base",  "Fine card."]},
        "GSTRP", {canonical: "In. card.",              titles: ["Data inizio cardine",    "Data in. card.",      "In. card.",    "Data inizio cardine"             ]},
        "KTSCH", {canonical: "ChTstStd",               titles: ["Ch. testo standard",     "Ch.testo std",        "ChTestoStd",   "ChTstStd"                        ]},
        "LTXA1", {canonical: "Operazione testo breve", titles: ["Oper. testo breve",      "Oper. tsto br.",      "Oper.Tbr.",    "Operazione testo breve"          ]},
        "STTXT", {canonical: "Stato sistema",          titles: ["Stato sistema",          "Stato sistema",       "St.sist.",     "Stato sistema"                   ]},
        "USTXT", {canonical: "St.utente",              titles: ["Stato utente",           "Stato utente",        "St.utente",    "Stato utente"                    ]},
        "VORNR", {canonical: "Op.",                    titles: ["Operazione",             "Operazione",          "Operazione",   "Op."                             ]}
    )
    }

        /* 
        Esempio di utilizzo:
        G_CONSTANTS.test
        */