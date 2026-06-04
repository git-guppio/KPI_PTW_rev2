#Requires AutoHotkey v2.0

class SAP_Transactions {

    ; Funzione: IW49N
    ; Descrizione: Estrae le operazioni relative agli OdM indicati
    ; Parametri:
    ;   lista_OdM:  lista degli Odm di cui ricavare la lista delle operazioni
    ; Restituisce: Copia la tabella nella clipboard
    static IW49N(listaOdM) {
        session := SAPConnection.GetSession()
        if (session) {
            try {
                ; copio il contenuto della lista nella clipboard
                Temp_Clipboard := A_Clipboard ; memorizzo il contenuto della clipboard
                sleep 250
                A_Clipboard := listaOdM                
                ; avvio la transazione
                session.findById("wnd[0]/tbar[0]/okcd").text := "/nIW49N"
                session.findById("wnd[0]/tbar[0]/btn[0]").press
                session.findById("wnd[0]/usr/chkSP_OFN").selected := True
                session.findById("wnd[0]/usr/chkSP_IAR").selected := True
                session.findById("wnd[0]/usr/chkSP_MAB").selected := True
                session.findById("wnd[0]/usr/chkSP_HIS").selected := True
                ; incollo la lista dalla clipboard
                session.findById("wnd[0]/usr/tabsTABSTRIP_TABBLOCK1/tabpS_TAB1/ssub%_SUBSCREEN_TABBLOCK1:RI_ORDER_OPERATION_LIST:1100/btn%_S_AUFNR_%_APP_%-VALU_PUSH").press
                sleep 500
                session.findById("wnd[1]/tbar[0]/btn[24]").press
                session.findById("wnd[1]/tbar[0]/btn[8]").press  
                ; elimino i valori dal campo periodo e dalla sede tecnica              
                session.findById("wnd[0]/usr/tabsTABSTRIP_TABBLOCK1/tabpS_TAB1/ssub%_SUBSCREEN_TABBLOCK1:RI_ORDER_OPERATION_LIST:1100/ctxtS_STRNO-LOW").text := ""
                session.findById("wnd[0]/usr/tabsTABSTRIP_TABBLOCK1/tabpS_TAB1/ssub%_SUBSCREEN_TABBLOCK1:RI_ORDER_OPERATION_LIST:1100/ctxtS_DATUM-LOW").text := ""
                ; tolgo impostazioni di data inizio e fine cardine
                session.findById("wnd[0]/usr/tabsTABSTRIP_TABBLOCK1/tabpS_TAB2").select
                sleep 500
                session.findById("wnd[0]/usr/tabsTABSTRIP_TABBLOCK1/tabpS_TAB2/ssub%_SUBSCREEN_TABBLOCK1:RI_ORDER_OPERATION_LIST:1200/ctxtS_GSTRP-LOW").text := ""
                session.findById("wnd[0]/usr/tabsTABSTRIP_TABBLOCK1/tabpS_TAB2/ssub%_SUBSCREEN_TABBLOCK1:RI_ORDER_OPERATION_LIST:1200/ctxtS_GSTRP-HIGH").text := ""
                ; seleziono il layout
                session.findById("wnd[0]/usr/tabsTABSTRIP_TABBLOCK1/tabpS_TAB9").select
                sleep 500
                session.findById("wnd[0]/usr/tabsTABSTRIP_TABBLOCK1/tabpS_TAB9/ssub%_SUBSCREEN_TABBLOCK1:RI_ORDER_OPERATION_LIST:1900/ctxtSP_VARI").text := "/KPI_PTW"
                ; avvio la transazione
                session.findById("wnd[0]/tbar[1]/btn[8]").press
                while session.Busy()
                    {
                        sleep 500
                        OutputDebug("SAP is busy" . "`n")
                    }
                ; esporto i valori nella clipboard
                sleep 500          
                session.findById("wnd[0]/mbar/menu[0]/menu[10]/menu[2]").select
                while session.Busy()
                    {
                        sleep 500
                        OutputDebug("SAP is busy" . "`n")
                    }    
                sleep 1000
                session.findById("wnd[1]/usr/subSUBSCREEN_STEPLOOP:SAPLSPO5:0150/sub:SAPLSPO5:0150/radSPOPLI-SELFLAG[4,0]").select
                A_Clipboard := ""
                session.findById("wnd[1]/tbar[0]/btn[0]").press
                while session.Busy()
                    {
                        sleep 500
                        OutputDebug("SAP is busy" . "`n")
                    }
                ; Impostiamo un timeout per evitare loop infiniti
                maxWaitTime := 10000  ; millisecondi (2 secondi)
                startTime := A_TickCount

                ; Ciclo che attende che la clipboard contenga dati
                while (A_Clipboard = "") {
                    if (A_TickCount - startTime > maxWaitTime) {
                        MsgBox("Timeout: La clipboard non è stata riempita entro " . maxWaitTime . " ms")
                        OutputDebug("Timeout: La clipboard non è stata riempita entro " . maxWaitTime . " ms")
                        return false
                    }
                    Sleep(100)  ; Pausa per non sovraccaricare la CPU
                }
                OutputDebug("Clipboard riempita con successo!`n")
                
                ; memorizzo il contenuto della clipboard in un' array
                rawData := true
                resultArray := ArrayTools.CreaArrayDaClipboard(rawData) ; raw data
                ; scrivo il contenuto della clipboard su file
                try {
                    OutputDebug("Scrivo il contenuto della clipboard su file: " . G_CONSTANTS.EXPORT_IW49N_RAW_FILE . "`n")
                    ArrayTools.WriteArrayToFile(resultArray, G_CONSTANTS.EXPORT_IW49N_RAW_FILE, true, true)  ;  sovrascrive file, utilizza raw data
                } catch Error as err {        
                    MsgBox("Errore: " . err.Message, "Errore", 16)
                }
                ; genero un file CSV a partire dal contenuto della clipboard e lo scrivo su file
                try {
                    OutputDebug("Scrivo il contenuto della clipboard su file: " . G_CONSTANTS.EXPORT_IW49N_CSV_FILE . "`n")
                    ArrayTools.WriteArrayToFile(ArrayTools.CreaArrayDaClipboard(false), G_CONSTANTS.EXPORT_IW49N_CSV_FILE, true, false)  ;  sovrascrive file, utilizza raw data
                } catch Error as err {        
                    MsgBox("Errore: " . err.Message, "Errore", 16)
                }                
                ; ripristino il contenuto della Clipboard
                A_Clipboard := Temp_Clipboard
                ; Conta le righe dati (pipe-delimited) escludendo l'intestazione.
                ; Approccio dinamico: compatibile con vecchio formato SAP (sep+header+sep)
                ; e nuovo formato SAP (titolo+sep+sep+header+sep) senza dipendere da un offset fisso.
                headerFound := false
                numeroDiElementArray := 0
                for line in resultArray {
                    if !headerFound {
                        if RegExMatch(line, "^\|.*\|$")
                            headerFound := true
                    } else {
                        if RegExMatch(line, "^\|.*\|$")
                            numeroDiElementArray++
                    }
                }
                numeroDiElementArray++ ; include la riga di intestazione come fa grid.RowCount + 1
                grid := session.findById("wnd[0]/usr/cntlGRID1/shellcont/shell")
                ; verifico il numero di risultati ottenuti
                tableRowCount := grid.RowCount + 1 ; aggiungo la riga di intestazione che non viene conteggiata
                OutputDebug("Numero di elementi array: " . numeroDiElementArray . "`n")
                OutputDebug("Numero di righe tabella SAP: " . tableRowCount . "`n")
                if (numeroDiElementArray != tableRowCount)
                    throw Error("Errore nell'estrazione dei dati.")
                else
                    return resultArray
            } catch as err {
                MsgBox("Errore nell'esecuzione dell'azione SAP: " err.Message, "Errore", 4112)
                return false
            } finally {
                SAPConnection.Disconnect()
            }
        }
        else {
            MsgBox("Impossibile ottenere una sessione SAP valida.", "Errore", 4112)
            return false
        }
    }

    ; Funzione: IW39
    ; Descrizione: Estrae la lista degli OdM relativi all'intervallo specificato in data inizio cardine
    ; Parametri: Nessuno
    ; Restituisce: Copia la tabella nella clipboard
    static IW39(plant, dataInizio, dataFine) {

        ; *** Tabella di mapping per gestire le sedi tecniche GAS ***
        if (plant = "FS") {
            plant := "FS-7*"
        }

        session := SAPConnection.GetSession()
        if (session) {
            try {
                Temp_Clipboard := A_Clipboard ; memorizzo il contenuto della clipboard
                session.findById("wnd[0]/tbar[0]/okcd").text := "/nIW39"
                session.findById("wnd[0]").sendVKey(0)
                session.findById("wnd[0]/usr/chkDY_OFN").selected := True
                session.findById("wnd[0]/usr/chkDY_IAR").selected := True
                session.findById("wnd[0]/usr/chkDY_MAB").selected := True
                session.findById("wnd[0]/usr/chkDY_HIS").selected := True
                ; imposto il valore della sede tecnica
                session.findById("wnd[0]/usr/ctxtSTRNO-LOW").text := plant . "*"
                ; rimuovo i valori di default dalle date periodo
                session.findById("wnd[0]/usr/ctxtDATUV").text := ""
                session.findById("wnd[0]/usr/ctxtDATUB").text := ""
                session.findById("wnd[0]/usr/ctxtGSTRP-LOW").text := dataInizio
                session.findById("wnd[0]/usr/ctxtGSTRP-HIGH").text := dataFine
                session.findById("wnd[0]/usr/ctxtVARIANT").text := "/KPIODMPOOL"
                session.findById("wnd[0]/usr/ctxtVARIANT").setFocus
                session.findById("wnd[0]/usr/ctxtVARIANT").caretPosition := 10
                ; avvio transazione
                session.findById("wnd[0]/tbar[1]/btn[8]").press
                while session.Busy()
                    {
                        sleep 500
                        OutputDebug("SAP is busy" . "`n")
                    }
                ; esporto i valori nella clipboard
                sleep 500                
                ; esporto i dati nella clipboard
                session.findById("wnd[0]/mbar/menu[0]/menu[11]/menu[2]").select         
                while session.Busy()
                    {
                        sleep 500
                        OutputDebug("SAP is busy" . "`n")
                    }    
                sleep 1000
                session.findById("wnd[1]/usr/subSUBSCREEN_STEPLOOP:SAPLSPO5:0150/sub:SAPLSPO5:0150/radSPOPLI-SELFLAG[4,0]").select
                A_Clipboard := ""
                session.findById("wnd[1]/tbar[0]/btn[0]").press
                while session.Busy()
                    {
                        sleep 500
                        OutputDebug("SAP is busy" . "`n")
                    }
                ; Impostiamo un timeout per evitare loop infiniti
                maxWaitTime := 10000  ; millisecondi (2 secondi)
                startTime := A_TickCount

                ; Ciclo che attende che la clipboard contenga dati
                while (A_Clipboard = "") {
                    if (A_TickCount - startTime > maxWaitTime) {
                        MsgBox("Timeout: La clipboard non è stata riempita entro " . maxWaitTime . " ms")
                        OutputDebug("Timeout: La clipboard non è stata riempita entro " . maxWaitTime . " ms")
                        return false
                    }
                    Sleep(100)  ; Pausa per non sovraccaricare la CPU
                }
                OutputDebug("Clipboard riempita con successo!`n")
                
                ; memorizzo il contenuto della clipboard in un' array
                rawData := true
                resultArray := ArrayTools.CreaArrayDaClipboard(rawData) ; raw data
                ; scrivo il contenuto della clipboard su file
                try {
                    OutputDebug("Scrivo il contenuto della clipboard su file: " . G_CONSTANTS.EXPORT_IW39_RAW_FILE . "`n")
                    ArrayTools.WriteArrayToFile(resultArray, G_CONSTANTS.EXPORT_IW39_RAW_FILE, true, true)  ;  sovrascrive file, utilizza raw data
                } catch Error as err {        
                    MsgBox("Errore: " . err.Message, "Errore", 16)
                }
                ; genero un file CSV a partire dal contenuto della clipboard e lo scrivo su file
                try {
                    OutputDebug("Scrivo il contenuto della clipboard su file: " . G_CONSTANTS.EXPORT_IW39_CSV_FILE . "`n")
                    ArrayTools.WriteArrayToFile(ArrayTools.CreaArrayDaClipboard(false), G_CONSTANTS.EXPORT_IW39_CSV_FILE, true, false)  ;  sovrascrive file, utilizza raw data
                } catch Error as err {        
                    MsgBox("Errore: " . err.Message, "Errore", 16)
                }                
                ; ripristino il contenuto della Clipboard
                A_Clipboard := Temp_Clipboard
                ; Conta le righe dati (pipe-delimited) escludendo l'intestazione.
                ; Approccio dinamico: compatibile con vecchio formato SAP (sep+header+sep)
                ; e nuovo formato SAP (titolo+sep+sep+header+sep) senza dipendere da un offset fisso.
                headerFound := false
                numeroDiElementArray := 0
                for line in resultArray {
                    if !headerFound {
                        if RegExMatch(line, "^\|.*\|$")
                            headerFound := true
                    } else {
                        if RegExMatch(line, "^\|.*\|$")
                            numeroDiElementArray++
                    }
                }
                numeroDiElementArray++ ; include la riga di intestazione come fa grid.RowCount + 1
                grid := session.findById("wnd[0]/usr/cntlGRID1/shellcont/shell")
                ; verifico il numero di risultati ottenuti
                tableRowCount := grid.RowCount + 1 ; aggiungo la riga di intestazione che non viene conteggiata
                OutputDebug("Numero di elementi array: " . numeroDiElementArray . "`n")
                OutputDebug("Numero di righe tabella SAP: " . tableRowCount . "`n")
                if (numeroDiElementArray != tableRowCount)
                    throw Error("Errore nell'estrazione dei dati.")
                else
                    return resultArray
            } catch as err {
                MsgBox("Errore nell'esecuzione dell'azione SAP: " err.Message, "Errore", 4112)
                return false
            } finally {
                SAPConnection.Disconnect()
            }
        }
        else {
            MsgBox("Impossibile ottenere una sessione SAP valida.", "Errore", 4112)
            return false
        }
    }

    ; Funzione: IW32
    ; Descrizione: Modifica la data di inizio e fine cardine di un OdM
    ; Parametri: La lista degli OdM da modificare, selezionati nella LV <Sposta OdM>
    ; Restituisce: Il numero di OdM modificati
    static IW32(Lista_OdM, dataInizio, dataFine, ProgressBar, SB) {
        OdMTotali := Lista_OdM.Length
        ProgressBar.Value := 0 ; resetto lo stato della progress bar
        ProgressBar.Opt("+Range0-" . OdMTotali)
        if (OdMTotali > 0) { ; Verifico che la lista contenga elementi
            ; *** Creo una connessione SAP
            SB.SetText("Attivo connessione SAP")
            session := SAPConnection.GetSession()
            if (session) {
                try {						
                        for OdM in Lista_OdM {
                            OutputDebug(OdM . "`n")
                            session.findById("wnd[0]/tbar[0]/okcd").text := "/nIW32"
                            session.findById("wnd[0]").sendVKey(0)
                            while session.Busy()
                            {
                                sleep 500
                                OutputDebug("Busy" . "`n")
                            }
                            session.findById("wnd[0]/usr/ctxtCAUFVD-AUFNR").text := OdM
                            session.findById("wnd[0]/usr/ctxtCAUFVD-AUFNR").caretPosition := 11
                            session.findById("wnd[0]").sendVKey(0)
                            SB.SetText("Analizzo OdM " . OdM)
                            while session.Busy()
                            {
                                sleep 500
                                OutputDebug("Busy - Caricamento OdM" . "`n")
                            }
                            ; verifico che l'OdM sia RIL o APER
                            StatoSistema := session.findById("wnd[0]/usr/subSUB_ALL:SAPLCOIH:3001/ssubSUB_LEVEL:SAPLCOIH:1100/subSUB_KOPF:SAPLCOIH:1102/txtCAUFVD-STTXT").text
                            if !(InStr(StatoSistema, "RIL")) {
                                OutputDebug("OdM " . OdM . " in stato " . StatoSistema . "`n")
                                SB.SetText("OdM " . OdM . " in stato " . StatoSistema)
                                continue
                            }
                            ; modifico direttamente la data inizio e fine cardine dell'OdM
                            SB.SetText("Modifico date...")
                            session.findById("wnd[0]/usr/subSUB_ALL:SAPLCOIH:3001/ssubSUB_LEVEL:SAPLCOIH:1100/tabsTS_1100/tabpIHKZ/ssubSUB_AUFTRAG:SAPLCOIH:1120/subTERM:SAPLCOIH:7300/ctxtCAUFVD-GSTRP").text := dataInizio
                            session.findById("wnd[0]/usr/subSUB_ALL:SAPLCOIH:3001/ssubSUB_LEVEL:SAPLCOIH:1100/tabsTS_1100/tabpIHKZ/ssubSUB_AUFTRAG:SAPLCOIH:1120/subTERM:SAPLCOIH:7300/ctxtCAUFVD-GLTRP").text := dataFine
                            session.findById("wnd[0]").sendVKey(0)
                            ; verifico la presenza di errori
                            while session.Busy()
                                {
                                    sleep 500
                                    OutputDebug("Busy - Caricamento OdM" . "`n")
                                }
                            sleep 1000
                            loop 10 {
                                sleep 500
                                errMsg := session.findById("wnd[0]/sbar").Text
                                iconType := session.findById("wnd[0]/sbar").MessageType
                                OutputDebug("errMsg: " . errMsg . " - iconType: " . iconType . "`n")
                                
                                if (iconType = "W") {
                                    SB.SetText(errMsg)
                                    try {
                                        session.findById("wnd[0]").sendVKey(0)
                                        sleep(250)
                                    }
                                }
                                else if ((iconType = "") and (errMsg = "")) {
                                    OutputDebug("Interrompo il ciclo`n")
                                    break 
                                }
                            }
                            ; salvo
                            session.findById("wnd[0]/tbar[0]/btn[11]").press
                            OutputDebug("Salvo OdM...`n")
                            SB.SetText("Salvo OdM...")
                            sleep 500
                            while session.Busy()
                                {
                                sleep 500
                                OutputDebug("Busy Salvo OdM" . "`n")
                            }
                            ;sleep 500
                            loop 10 {
                                sleep 500
                                ; verifico msg di errore <Determ. costi>
                                if WinExist("Determ. costi") {
                                    WinActivate ; Use the window found by WinExist.
                                    session.findById("wnd[1]/usr/btnSPOP-OPTION1").press
                                    Sleep 500  ; Attendi prima di controllare di nuovo
                                    while session.Busy()
                                    {
                                        sleep 500
                                        OutputDebug("Busy Determ. costi" . "`n")
                                    }
                                }
                                ; verifico msg di errore <Determ. costi>
                                ; Modificato da "Informazione" a "Informazioni"
                                else if WinExist("Informazioni") {
                                    WinActivate ; Use the window found by WinExist.
                                    session.findById("wnd[1]/tbar[0]/btn[0]").press
                                    Sleep 500  ; Attendi prima di controllare di nuovo
                                    while session.Busy()
                                    {
                                        sleep 500
                                        OutputDebug("Busy Informazione 1" . "`n")
                                    }
                                }
                                ; verifico se l'OdM è stato salvato
                                errMessage := session.findById("wnd[0]/sbar").Text
                                if (InStr(errMessage, "Ordine salvato con il numero")) {
                                    OutputDebug("OdM salvato!")
                                    SB.SetText("OdM salvato")
                                    break ; termino il loop
                                }
                            } ; Fine ciclo loop
                            ProgressBar.Value := A_Index
                        } ; Fine ciclo for
                        MsgBox("Elaborazione terminata.", "Info")
                    } catch as err {
                        MsgBox(
                            "Errore SAP`n" 
                            . "Linea: " . err.Line . "`n"
                            . "Comando: " . err.What . "`n"
                            . "Errore: " . err.Message,
                            "Errore SAP",
                            16 + 4096
                        )
                        SB.SetText(err.Message)
                        ProgressBar.Value := 0
                        return 0
                    } finally {
                        SAPConnection.Disconnect()
                    }
            } else {
                MsgBox("Impossibile ottenere una sessione SAP valida.", "Errore SAP", 16 + 4096)
                return 0
            }
        }
        else {
            MsgBox("Inserire elementi validi", "Errore", 16 + 4096)
            return 0
        }
    }
}
