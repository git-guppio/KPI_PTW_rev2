#Requires AutoHotkey v2.0

; ==========================================================
; SAP Field Inspector
; Ispeziona le colonne di una tabella GridControl SAP
; e genera la mappa: FieldName -> tutti i Title della colonna
;
; Avvio: Ctrl+Shift+F12 con SAP aperto su una tabella
; ==========================================================

^+F12:: InspezionaGriglia()

InspezionaGriglia() {
    ; --- Connessione SAP via COM (stessa logica di SAP_Connection.ahk) ---
    if !WinExist("ahk_class SAP_FRONTEND_SESSION") {
        MsgBox("SAP non è aperto.`nAprire SAP e portarsi sulla tabella da ispezionare.", "SAP Field Inspector", 48)
        return
    }
    try {
        application := ComObjGet("SAPGUI").GetScriptingEngine
        session     := application.Activesession
    } catch Error as err {
        MsgBox("Impossibile connettersi a SAP.`n" . err.Message, "SAP Field Inspector", 48)
        return
    }

    ; --- Rileva GridControl: tenta percorso standard, poi chiede all'utente ---
    gridId   := "wnd[0]/usr/cntlGRID1/shellcont/shell"
    gridView := ""
    try {
        gridView := session.findById(gridId)
    } catch {
        gridView := ""
    }

    if !IsObject(gridView) {
        dlg := InputBox(
            "Percorso GridControl non trovato automaticamente.`n"
            . "Inserire il percorso completo del controllo:",
            "SAP Field Inspector",
            "w620 h130",
            "wnd[0]/usr/cntlGRID1/shellcont/shell"
        )
        if (dlg.Result = "Cancel" || Trim(dlg.Value) = "")
            return
        gridId := Trim(dlg.Value)
        try {
            gridView := session.findById(gridId)
        } catch Error as err {
            MsgBox("Elemento non trovato:`n" . gridId . "`n`n" . err.Message, "SAP Field Inspector", 48)
            return
        }
    }

    ; --- Costruisce mappa FieldName -> titoli ---
    fieldMap := Map_FieldNames(gridView)
    if (fieldMap.Count = 0) {
        MsgBox("Nessun campo trovato nel GridControl.", "SAP Field Inspector", 48)
        return
    }

    ; --- Formatta output in ordine alfabetico (coerente col riferimento) ---
    keys := []
    for k in fieldMap
        keys.Push(k)
    OrdinaArray(keys)

    output := ""
    for k in keys {
        line := k . " - |"
        for title in fieldMap[k]
            line .= title . "|"
        output .= line . "`n"
    }

    MostraRisultati(output, gridId)
}

; Costruisce Map: FieldName -> COM collection di Title
; Compatibile con qualsiasi transazione SAP che espone un GridControl
Map_FieldNames(gridView) {
    fieldMap := Map()
    try {
        columnsFieldNames := gridView.ColumnOrder()
        for nome in columnsFieldNames {
            try {
                fieldMap[nome] := gridView.GetColumnTitles(nome)
            } catch {
                fieldMap[nome] := []
            }
        }
    } catch Error as err {
        MsgBox("Errore nella lettura dei campi: " . err.Message, "SAP Field Inspector", 48)
    }
    return fieldMap
}

; Ordina in-place un array di stringhe in ordine alfabetico (case-insensitive, bubble sort)
OrdinaArray(arr) {
    n := arr.Length
    loop n - 1 {
        i := A_Index
        loop n - i {
            j := A_Index
            if (StrCompare(arr[j], arr[j + 1]) > 0) {
                tmp        := arr[j]
                arr[j]     := arr[j + 1]
                arr[j + 1] := tmp
            }
        }
    }
}

; Mostra i risultati in una finestra ridimensionabile con copia negli appunti
MostraRisultati(testo, gridId) {
    rGui := Gui("+Resize +MinSize420x320", "SAP Field Inspector — Risultati")
    rGui.SetFont("s9", "Courier New")

    lblPath  := rGui.Add("Text",   "x10 y10 w780 r2",                        "Percorso: " . gridId)
    editCtrl := rGui.Add("Edit",   "x10 y50 w780 h430 +ReadOnly +VScroll +HScroll", testo)
    btnCopia  := rGui.Add("Button", "x10 y490 w160 h28",                      "Copia negli appunti")
    btnChiudi := rGui.Add("Button", "x630 y490 w160 h28",                     "Chiudi")

    btnCopia.OnEvent("Click",  CopiaClick)
    btnChiudi.OnEvent("Click", (*) => rGui.Destroy())
    rGui.OnEvent("Close", (*) => rGui.Destroy())
    rGui.OnEvent("Size",  RiDimensiona)

    rGui.Show("w800 h540")

    CopiaClick(*) {
        A_Clipboard := testo
        ToolTip("Copiato negli appunti!")
        SetTimer(() => ToolTip(), -2000)
    }

    RiDimensiona(thisGui, minMax, w, h) {
        if (minMax = -1)  ; finestra minimizzata: nessun ridimensionamento
            return
        lblPath.Move(,  , w - 20)
        editCtrl.Move(, , w - 20, h - 110)
        btnCopia.Move(,  h - 50)
        btnChiudi.Move(w - 170, h - 50)
    }
}
