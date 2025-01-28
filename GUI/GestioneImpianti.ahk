#Requires AutoHotkey v2.0
#Include ..\GlobalConstants.ahk
#Include ..\Utils\ArrayTools.ahk

; ======================================================================================================================
; AHK Settings
; ======================================================================================================================
#SingleInstance Force
SetWorkingDir(A_ScriptDir)
SetTitleMatchMode(2)

class ImpiantiManager {
    ; dati condivisi
        static defaultImpianti := Map()
        static  configFile := ""
    
    static __new() {
        ImpiantiManager.configFile := G_CONSTANTS.IMPIANTI_CONFIG_FILE
        ImpiantiManager.defaultImpianti := Map(
            "COAL", ["BS", "FS", "SU", "TN"],
            "GAS", ["LC", "MC", "PC", "PE", "PF", "PG", "SB", "TI"],
            "ImpFuture", ["RO", "FSP", "0E", "0F"]
        )
    }

    static GetImpianti() {
        
/*         if (!ImpiantiManager.configFile)  ; Se non è stato inizializzato
            ImpiantiManager.Initialize()     */    
        
        if !FileExist(ImpiantiManager.configFile) {
            ImpiantiManager.InitializeDefaultValues()
        }
        return ImpiantiManager.LoadFromIni()
    }
    
    static InitializeDefaultValues() {
        for categoria, impianti in ImpiantiManager.defaultImpianti {
                IniWrite(ArrayTools.Join(impianti), ImpiantiManager.configFile, categoria, "impianti")
        }
    }
    
    static LoadFromIni() {
        impiantiMap := Map()
        for categoria, _ in ImpiantiManager.defaultImpianti {
            try {
                impiantiStr := IniRead(ImpiantiManager.configFile, categoria, "impianti")
                impiantiMap[categoria] := StrSplit(impiantiStr, ";", " ")
            }
        }
        return impiantiMap
    }

    ; Legge tutti gli impianti di una categoria
    static LeggiImpianti(categoria) {
        try {
            impiantiStr := IniRead(ImpiantiManager.configFile, categoria, "impianti")
            return StrSplit(impiantiStr, ";", " ")  ; Converte la stringa in array
        } catch Error as err {
            MsgBox("Errore nella lettura degli impianti: " err.Message)
            return []
        }
    }

    ; Aggiunge un nuovo impianto a una categoria
    static AggiungiImpianto(categoria, nuovoImpianto) {
        try {
            impianti := ImpiantiManager.LeggiImpianti(categoria)
            
            ; Verifica se l'impianto esiste già
            if (ArrayTools.HasElement(impianti, nuovoImpianto))
                return "Impianto già esistente"
                
            impianti.Push(nuovoImpianto)
            IniWrite(ArrayTools.Join(impianti), ImpiantiManager.configFile, categoria, "impianti")
            return "Impianto aggiunto con successo"
        } catch Error as err {
            return "Errore nell'aggiunta dell'impianto: " err.Message
        }
    }    
    
    ; Rimuove un impianto da una categoria
    static RimuoviImpianto(categoria, impiantoDaRimuovere) {
        try {
            impianti := ImpiantiManager.LeggiImpianti(categoria)
            
            ; Cerca e rimuove l'impianto
            for index, impianto in impianti {
                if (impianto = impiantoDaRimuovere) {
                    impianti.RemoveAt(index)
                    IniWrite(ArrayTools.Join(impianti), ImpiantiManager.configFile, categoria, "impianti")
                    return "Impianto rimosso con successo"
                }
            }
            return "Impianto non trovato"
        } catch Error as err {
            return "Errore nella rimozione dell'impianto: " err.Message
        }
    }
    
    ; Legge tutte le categorie disponibili
    static LeggiCategorie() {
        try {
            return StrSplit(IniRead(ImpiantiManager.configFile), '`n') 
        } catch Error as err {
            return ["COAL", "GAS", "ImpFuture"]
        }
    }
}

class ImpiantiGUI {
    __New(mainApp) {
        ; Salva il riferimento all'app principale
        this.mainApp := mainApp
        ImpiantiManager.GetImpianti()
        
        ; Crea la finestra principale
        this.gui := Gui("+ToolWindow", "Gestione Impianti")
        
        ; Dropdown per selezionare la categoria
        this.gui.Add("Text",, "Categoria:")
        categorie := ImpiantiManager.LeggiCategorie()
        this.gui.Add("DropDownList", "vCategoria w200", categorie).OnEvent("Change", this.AggiornaLista.Bind(this))
        this.gui["Categoria"].Choose(1)
        
        ; ListBox per mostrare gli impianti
        this.gui.Add("Text", "y+10", "Impianti:")
        this.gui.Add("ListBox", "vImpianti w200 h200")
        
        ; Controlli per aggiungere/rimuovere impianti
        this.gui.Add("Text", "y+10", "Nuovo Impianto:")
        this.gui.Add("Edit", "vNuovoImpianto w200")
        this.gui.Add("Button", "y+5 w95", "Aggiungi").OnEvent("Click", this.AggiungiClick.Bind(this))
        this.gui.Add("Button", "x+10 w95", "Rimuovi").OnEvent("Click", this.RimuoviClick.Bind(this))

        ; evento per la chiusura della finestra
        this.gui.OnEvent("Close", (*) => this.HandleCloseButtonClick())
        this.gui.OnEvent("Escape", (*) => this.HandleCloseButtonClick())

        ; Mostra la GUI e aggiorna la lista iniziale
        this.AggiornaLista()
        this.gui.Show()
    }

    HandleCloseButtonClick(*) {
        this.mainApp.EnableMainGui()
        this.mainApp.UpdateImpianti()
        this.gui.Destroy()
        this.mainApp.ImpiantiGui := "" ; Rimuovi il riferimento
    }
    
    AggiornaLista(*) {
        categoria := this.gui["Categoria"].Text
        impianti := ImpiantiManager.LeggiImpianti(categoria)
        this.gui["Impianti"].Delete()
        this.gui["Impianti"].Add(impianti)
    }
    
    AggiungiClick(*) {
        categoria := this.gui["Categoria"].Text
        nuovoImpianto := this.gui["NuovoImpianto"].Text
        
        if (nuovoImpianto = "") {
            MsgBox("Inserire un nome per il nuovo impianto")
            return
        }
        if ((StrLen(nuovoImpianto) < 2) or (StrLen(nuovoImpianto) > 2))  {
            MsgBox("Lunghezza nome impianto non valido")
            return
        }        
        
        risultato := ImpiantiManager.AggiungiImpianto(categoria, nuovoImpianto)
        MsgBox(risultato)
        this.AggiornaLista()
        this.gui["NuovoImpianto"].Text := ""
    }
    
    RimuoviClick(*) {
        categoria := this.gui["Categoria"].Text
        impiantoSelezionato := this.gui["Impianti"].Text
        
        if (impiantoSelezionato = "") {
            MsgBox("Selezionare un impianto da rimuovere")
            return
        }
        
        risultato := ImpiantiManager.RimuoviImpianto(categoria, impiantoSelezionato)
        MsgBox(risultato)
        this.AggiornaLista()
    }
}