#Requires AutoHotkey v2.0

class MainGUI {

    static MARGINS := {x: 10, y: 10}
    static PADDING := 10
    static FIX_GROUP := {x:0, y:0, w:0, h:0, d_h:0, d_w:0}
    static BUTTON_H := 40
    static BUTTON_W := 100
            ; Array con i mesi
    static MESI := ["Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno", "Luglio", "Agosto", "Settembre", "Ottobre", "Novembre", "Dicembre"]

    ; variabili per memorizzare i controlli presenti nel gruppo guiGroupControl
    static CTRL_PREFIX_LV := "LV_Contr_"
    static CTRL_PREFIX_SAP := "SAP_Contr_"
    static CTRL_PREFIX_DATE_SAP := "SAP_date_Contr_"

    static controlsMap_LV := Map()
    static controlsMap_SAP := Map()    
    static controlsMap_CambiaDateSAP := Map()

    MyDB := ""

    ;static STATUS_BAR := 40

    __New() {
        this.CreateGUI()
        this.SetControlsState(MainGUI.controlsMap_LV, false)
    }

    CreateGUI() {
        this.gui := Gui("+Resize +MinimizeBox +MaximizeBox")
        this.gui.Title := "Dashboard KPI PTW"

        ; imposto i margini
        this.gui.MarginX := MainGUI.MARGINS.x
        this.gui.MarginY := MainGUI.MARGINS.y

        ; Calcola le dimensioni iniziali
        screenWidth := A_ScreenWidth
        screenHeight := A_ScreenHeight

/*         ; Imposta dimensioni come percentuale dello schermo
        guiWidth := Floor(screenWidth * 0.5)
        guiHeight := Floor(screenHeight * 0.4) */

        ; Imposta dimensioni come percentuale dello schermo
        guiWidth := 1200
        guiHeight := 600

        this.gui.Opt("+MinSize" . guiWidth . "x" . guiHeight) 
        this.CreateResponsiveLayout(guiWidth, guiHeight)     

        ; Crea una imagelist
        this.imageListID := IL_Create(3)
        this.gui.LV.SetImageList(this.imageListID)

        icons := [295, 236, 132, 4] ; [OK, Allert, NOK, File]
        for icon in icons {
            IL_Add(this.imageListID, "shell32.dll", icon)
        }
        ; crea un menu
        this.CreateMenus()

        this.gui.OnEvent("Size", this.OnSize.Bind(this))
    }

    CreateMenus() {
        ; Creazione della barra dei menu
        this.MyMenuBar := MenuBar() 
        ; Menu File
        this.FileMenu := Menu()
        this.MyMenuBar.Add("&File", this.FileMenu)
        this.FileMenu.Add("Esporta dati", (*) => this.ExportListViewToCSV(this.gui.LV))
        this.FileMenu.Add()
        this.FileMenu.Add("Esci", (*) => this.CloseApp())

        ; Menu Modifica
        this.EditMenu := Menu()
        this.EditMenu.Add("Seleziona tutto", (*) => this.SelezionaTutto())
        this.EditMenu.Add("Deseleziona tutto", (*) => this.DeSelezionaTutto())           
        this.EditMenu.Add()
        this.EditMenu.Add("Copia", (*) => this.CopySelectedText())
        this.EditMenu.Add()        
        this.EditMenu.Add("Check All ☒", (*) => this.CheckAll())
        this.EditMenu.Add("UnCheck All ☐", (*) => this.UnCheckAll())
        this.MyMenuBar.Add("&Modifica", this.EditMenu)

        ; Menu Help
        this.HelpMenu := Menu()
        this.HelpMenu.Add("Help", this.ShowAbout)
        this.HelpMenu.Add("About Me", this.ShowInfo)
        this.MyMenuBar.Add("&Help", this.HelpMenu)

        ; disattivo i menu che devono ancora essere implementati
        this.HelpMenu.Disable("Help")
        this.HelpMenu.Disable("About Me")

        ; imposto i menu che non devono essere attivi, devono attivarsi solo dopo l'estrazione dei dati
        this.FileMenu.Disable("Esporta dati")
        this.EditMenu.Disable("Seleziona tutto")
        this.EditMenu.Disable("Deseleziona tutto")
        this.EditMenu.Disable("Copia")
        this.EditMenu.Disable("Check All ☒")
        this.EditMenu.Disable("UnCheck All ☐")        

        ; Assegnamento della barra dei menu alla GUI
        this.gui.MenuBar := this.MyMenuBar
    }

    ; Funzione da chiamare quando cambia la selezione della ListView e modificare i menu da rendere attivi
    OnSelectionChange(*)
    {
        ; verifico se ci sono elementi nella LV
        if(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].GetCount() > 0) { ; se la LV contiene elementi
            OutputDebug("Ci sono elementi nell LV`n")
            this.FileMenu.Enable("Esporta dati")
            this.EditMenu.Enable("Seleziona tutto")
            ; verifico se è selezionata la vista <Sposta OdM>
            if (!this.gui[MainGUI.CTRL_PREFIX_LV "btnSpostaOdM"].Enabled) { ; se questo tasto è disabilitato
                    ; verifica se ci sono elementi con check attivo
                    if(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].GetNext(0, "Checked") != 0) {
                        this.EditMenu.Enable("Check All ☒")
                        this.EditMenu.Enable("UnCheck All ☐")
                    }
                    else {
                        this.EditMenu.Enable("Check All ☒")
                        this.EditMenu.Disable("UnCheck All ☐")
                    }
            } else {
                this.EditMenu.Disable("Check All ☒")
                this.EditMenu.Disable("UnCheck All ☐")                
            }

            ; Verifica se c'è almeno una riga selezionata
            if (this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].GetNext() = 0) { ; se non ci sono righe selezionate
                OutputDebug("NON ci sono righe selezionate`n")                
                this.EditMenu.Disable("Copia")
                this.EditMenu.Disable("Deseleziona tutto")
            } else {
                this.EditMenu.Enable("Copia")
                this.EditMenu.Enable("Deseleziona tutto")
                OutputDebug("Ci sono righe selezionate`n")            
            }            
        }
        else {
            OutputDebug("NON ci sono elementi nell LV`n")
            this.EditMenu.Disable("Seleziona tutto")
            this.EditMenu.Disable("Deseleziona tutto")
            this.FileMenu.Disable("Esporta dati")
            this.EditMenu.Disable("Copia")
        }
    }

    ; Funzione per abilitare la GUI principale
    EnableMainGui() {
        this.gui.Opt("-Disabled")  ; Riabilita la GUI principale
    }


    CreateResponsiveLayout(guiWidth, guiHeight) {
        ; voglio creare un GUI responsive che abbia la parte sinistra relativa alla LV in cui verranno visualizzati i dati di tipo responsive
        ; mentre la parte destra di grandezza fissa, dove saranno visualizzati i dettagli relativi al KPI e all'odm selezionato.
        
        ; Inserisco un gruppo per la lista degli OdM
        this.GroupListaOdM := this.gui.Add("GroupBox",
        "xm ym " .
        " w" . Floor(guiWidth * 2/3) .
        " h" . (guiHeight) . 
        " vGroupListaOdM",
        "Lista OdM" )  ; identificativo del group

        ; inserisco controlli all' interno del gruppo
        this.ShowControl_LV(this.GroupListaOdM)

        this.GroupListaOdM.GetPos(&x, &y, &w, &h)
        ; Inserisco un gruppo per i dettagli OdM
        this.GroupDettagliOdM := this.gui.Add("GroupBox",
        "x" . x + w + MainGUI.PADDING .
        " ym" .
        " w" . guiWidth - w - MainGUI.PADDING - 2*MainGUI.MARGINS.x .
        " h" . floor(1/3*(h - 2*MainGUI.PADDING)), "Dettagli OdM") ; uso 2*pad per distanziare i group
        this.Edit_DettagliOdM := RichEdit(this.gui,
        "xp+" . MainGUI.MARGINS.x .
        " yp+" . 2*MainGUI.MARGINS.y .
        " wp-" . 2* MainGUI.MARGINS.x .
        " hp-" . 3* MainGUI.MARGINS.y . 
        " -VScroll -HScroll" )
        this.Edit_DettagliOdM.WordWrap(true)
        this.Edit_DettagliOdM.SetOptions(["READONLY"])
        ;this.Edit_DettagliOdM.ShowScrollBar(0, false)
        ;this.Edit_DettagliOdM.ShowScrollBar(1, false)       

/*             this.Edit_DettagliOdM := this.gui.Add("Edit",
            "xp+" . MainGUI.MARGINS.x .
            " yp+" . 2*MainGUI.MARGINS.y .
            " wp-" . 2* MainGUI.MARGINS.x .
            " hp-" . 3* MainGUI.MARGINS.y . 
            " -VScroll" )  */
        
        ; memorizzo i dati relativi ad un elemento (dettagli OdM)
        ; e li utilizzo quando ridimensiono la finestra
        this.GroupDettagliOdM.GetPos(&default_x, &default_y, &default_w, &default_h)
        MainGUI.FIX_GROUP.x := default_x
        MainGUI.FIX_GROUP.y := default_y
        MainGUI.FIX_GROUP.w := default_w
        MainGUI.FIX_GROUP.h := default_h

         ; Inserisco un gruppo per i dettagli KPI
        this.GroupDettagliKPI := this.gui.Add("GroupBox",
        "x" . default_x .
        " y" . (MainGUI.MARGINS.y + default_h + 1*MainGUI.PADDING) . 
        " w" . default_w .
        " h" . default_h, "Dettagli KPI")
            this.Edit_DettagliKPI := RichEdit(this.gui,
            "xp+" . MainGUI.MARGINS.x .
            " yp+" . 2*MainGUI.MARGINS.y .
            " wp-" . 2* MainGUI.MARGINS.x .
            " hp-" . 3* MainGUI.MARGINS.y . 
            " vDettagliKPI" . 
            " -VScroll -HScroll" )
            this.Edit_DettagliKPI.SetOptions(["READONLY"])

        ; calcolo il delta da aggiungere per allineare le finestre
        MainGUI.FIX_GROUP.d_h :=  Floor(h - 3*default_h - 2*MainGUI.PADDING)
        ; Inserisco un gruppo per estrarre i dati
        test_w := floor((MainGUI.FIX_GROUP.w - MainGUI.PADDING)/2)
        this.GroupEstraiDatiSAP := this.gui.Add("GroupBox",
        "x" . default_x .
        " y" . (MainGUI.MARGINS.y + 2*default_h + 2*MainGUI.PADDING + MainGUI.FIX_GROUP.d_h) . 
        " w" . Floor((MainGUI.FIX_GROUP.w - MainGUI.PADDING)/2) .
        " h" . default_h,  "Estrai dati SAP")
        ; inserisco controlli all' interno del gruppo
        this.ShowControl_EstraiDatiSAP(this.GroupEstraiDatiSAP)

        this.GroupEstraiDatiSAP.GetPos(&x, &y, &w, &h)
        ; calcolo il delta da aggiungere per allineare le finestre
        MainGUI.FIX_GROUP.d_w :=  MainGUI.FIX_GROUP.w - 2*(Floor((MainGUI.FIX_GROUP.w - MainGUI.PADDING)/2)) - MainGUI.PADDING
        
        ; Inserisco un gruppo per modificare le date cardine
        this.GroupModificaDateCardine := this.gui.Add("GroupBox",
        "x" . x + w + MainGUI.PADDING + MainGUI.FIX_GROUP.d_w .
        " y" . (MainGUI.MARGINS.y + 2*default_h + 2*MainGUI.PADDING + MainGUI.FIX_GROUP.d_h) . 
        " w" . w .
        " h" . default_h,  "Modifica date cardine")
        ; inserisco controlli all' interno del gruppo
        this.ShowControl_ModificaDateSAP(this.GroupModificaDateCardine)        

        this.SB := this.gui.Add("StatusBar",, "Ready!")
        this.SB.SetParts(guiWidth-100)
        this.SB.SetText("By Luca Abrusci", 2, "+2")
    }    

     OnSize(thisGui, minMax, width, height) {
        if (minMax = -1)
            return
    
        ; Disabilita il ridisegno
        DllCall("SendMessage", "Ptr", this.gui.Hwnd, "UInt", 0x000B, "Ptr", 0, "Ptr", 0)  ; WM_SETREDRAW = 0x000B
       
        this.SB.SetParts(width-100)
         ; considero le dimensioni della SB
        this.SB.GetPos(&SB_x, &SB_y, &SB_w, &SB_h)

         ; Muovo gruppo per la lista degli OdM
        this.GroupListaOdM.Move(
            MainGUI.MARGINS.x, 
            MainGUI.MARGINS.y,
            width - MainGUI.FIX_GROUP.w - 2*MainGUI.MARGINS.x - MainGUI.PADDING,
            ;Floor(width * 2/3),
            height - SB_h - 2*MainGUI.MARGINS.y)

            this.ShowControl_LV(this.GroupListaOdM)

        this.GroupListaOdM.GetPos(&x_GroupListaOdM, &y_GroupListaOdM, &w_GroupListaOdM, &h_GroupListaOdM)
        
         ; Muovo gruppo per i dettagli OdM --> voglio mantenere le stesse dimensioni iniziali
        ; devo in pratica spostare solo la x
        this.GroupDettagliOdM.Move(
            x_GroupListaOdM  + w_GroupListaOdM + MainGUI.PADDING,
            y_GroupListaOdM, 
            MainGUI.FIX_GROUP.w, 
            MainGUI.FIX_GROUP.h)
            this.Edit_DettagliOdM.move(
                x_GroupListaOdM + w_GroupListaOdM + MainGUI.PADDING + MainGUI.MARGINS.x,
                MainGUI.FIX_GROUP.y + 2*MainGUI.MARGINS.y,
                MainGUI.FIX_GROUP.w - 2*MainGUI.MARGINS.x,
                MainGUI.FIX_GROUP.h - 3*MainGUI.MARGINS.y)
       
        ; Muovo gruppo per i dettagli KPI
        this.GroupDettagliKPI.move(
            x_GroupListaOdM  + w_GroupListaOdM + MainGUI.PADDING,
            y_GroupListaOdM + MainGUI.FIX_GROUP.h + MainGUI.PADDING, 
            MainGUI.FIX_GROUP.w,
            MainGUI.FIX_GROUP.h)
            this.Edit_DettagliKPI.move(
                x_GroupListaOdM + w_GroupListaOdM + MainGUI.PADDING + MainGUI.MARGINS.x,
                y_GroupListaOdM + MainGUI.FIX_GROUP.h + 2*MainGUI.PADDING + MainGUI.MARGINS.y,
                MainGUI.FIX_GROUP.w - 2*MainGUI.MARGINS.x,
                MainGUI.FIX_GROUP.h - 3*MainGUI.PADDING)           
                
        this.GroupDettagliKPI.GetPos(&x_GroupDettagliKPI, &y_GroupDettagliKPI, &w_GroupDettagliKPI, &h_GroupDettagliKPI)
        ; Muovo gruppo per estrarre i dati
        Group_w := floor((MainGUI.FIX_GROUP.w - MainGUI.PADDING)/2)
        this.GroupEstraiDatiSAP.Move(
            x_GroupListaOdM  + w_GroupListaOdM + MainGUI.PADDING,
            y_GroupListaOdM + 2*MainGUI.FIX_GROUP.h + 2*MainGUI.PADDING + MainGUI.FIX_GROUP.d_h,
            Group_w,
            MainGUI.FIX_GROUP.h)
        
            this.ShowControl_EstraiDatiSAP(this.GroupEstraiDatiSAP)

        ; Muovo gruppo per modificare le date cardine
        this.GroupModificaDateCardine.Move(
            x_GroupListaOdM  + w_GroupListaOdM + 2*MainGUI.PADDING + Group_w + MainGUI.FIX_GROUP.d_w,
            y_GroupListaOdM + 2*MainGUI.FIX_GROUP.h + 2*MainGUI.PADDING + MainGUI.FIX_GROUP.d_h,
            Group_w,
            MainGUI.FIX_GROUP.h)            
        
            this.ShowControl_ModificaDateSAP(this.GroupModificaDateCardine)
                    

        ; Riabilita il ridisegno e forza un aggiornamento
        DllCall("SendMessage", "Ptr", this.gui.Hwnd, "UInt", 0x000B, "Ptr", 1, "Ptr", 0)
        DllCall("RedrawWindow", "Ptr", this.gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0087)  ; RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN            

    }

    ShowControl_LV(guiGroupControl) {

        guiGroupControl.GetPos(&x, &y, &w, &h)

        if (MainGUI.controlsMap_LV.Count = 0) {  ; Prima creazione dei controlli
            this.CreateControls_LV(x, y, w, h)
        } else {  ; Riposizionamento dei controlli esistenti
            this.UpdateControlsPosition(x, y, w, h, MainGUI.controlsMap_LV)
        }
    }        

    ShowControl_EstraiDatiSAP(guiGroupControl) {

        ; Inizializza ImpiantiManager per assicurarsi che il file di configurazione esista
        ImpiantiManager.GetImpianti()

        guiGroupControl.GetPos(&x, &y, &w, &h)
    
        ; Array con gli anni (ultimi 10 anni)
        anni := []
        annoCorrente := Integer(FormatTime(A_Now, "yyyy"))
        Loop 5 {
            anni.Push(annoCorrente + A_Index - 2) ; -2 per iniziare dall'anno precedente
        }

        if (MainGUI.controlsMap_SAP.Count = 0) {  ; Prima creazione dei controlli
            this.CreateControls_SAP(x, y, w, h, MainGUI.MESI, anni)
        } else {  ; Riposizionamento dei controlli esistenti
            this.UpdateControlsPosition(x, y, w, h, MainGUI.controlsMap_SAP)
        }
    }

    ShowControl_ModificaDateSAP(guiGroupControl) {        

        guiGroupControl.GetPos(&x, &y, &w, &h)

        if (MainGUI.controlsMap_CambiaDateSAP.Count = 0) {  ; Prima creazione dei controlli
            this.CreateControls_CambiaDateSAP(x, y, w, h)
        } else {  ; Riposizionamento dei controlli esistenti
            this.UpdateControlsPosition(x, y, w, h, MainGUI.controlsMap_CambiaDateSAP)
        }
    }

    ; crea controlli per il gruppo <Estrai dati SAP>
    CreateControls_LV(x, y, w, h) {
/*         ; LV per visualizzare contenuto DB
        this.GroupListaOdM.GetPos(&x, &y, &w, &h) */
        ; Elemento LV interno al Groupbox
            this.gui.LV := this.gui.Add("ListView",
            "x" . 2*MainGUI.MARGINS.x .
            " y" . 3*MainGUI.MARGINS.y .
            " w" . (w - 2* MainGUI.MARGINS.x) .
            " h" . (h - 80) . ; spazio per inserire button
            " v" MainGUI.CTRL_PREFIX_LV "ListView" .  ; identificativo della LV
            " Grid")
        ; Aggiungi il menu contestuale
        this.gui.LV.OnEvent("ContextMenu", (*) => this.ShowContextMenu())
        ; evento per selezione checkbox
        this.gui.LV.OnEvent("ItemCheck", this.OnItemCheck.Bind(this))
        this.gui.LV.OnEvent("ItemFocus", this.OnItemFocus.Bind(this))
        this.gui.LV.OnEvent("ItemSelect", this.OnSelectionChange.Bind(this)) ; evento per gestire la selezione di un item    

        ; Aggiunge un pulsante per visualizzare i raw data
        btnRawData := this.gui.Add("Button", Format("x{} y{} w{} h{} v" MainGUI.CTRL_PREFIX_LV "btnRawData", x + MainGUI.MARGINS.x, y + h - MainGUI.MARGINS.y - MainGUI.BUTTON_H, MainGUI.BUTTON_W, MainGUI.BUTTON_H), "Raw data")            
        ; Gestore eventi per il pulsante Conferma
        btnRawData.OnEvent("Click", this.ShowRawData.Bind(this))
        
        ; Aggiunge un pulsante per visualizzare i cleande data
        btnCleanedData := this.gui.Add("Button", Format("x{} y{} w{} h{} v" MainGUI.CTRL_PREFIX_LV "btnCleanedData", x + MainGUI.MARGINS.x + MainGUI.BUTTON_W + MainGUI.PADDING, y + h - MainGUI.MARGINS.y - MainGUI.BUTTON_H, MainGUI.BUTTON_W, MainGUI.BUTTON_H), "Cleaned data")            
        ; Gestore eventi per il pulsante Conferma
        btnCleanedData.OnEvent("Click", this.ShowCleanedData.Bind(this))

        ; Aggiunge un pulsante per visualizzare i dati relativi agli OdM con ptw
        btnPivot := this.gui.Add("Button", Format("x{} y{} w{} h{} v" MainGUI.CTRL_PREFIX_LV "btnPivot", x + MainGUI.MARGINS.x + 2*(MainGUI.BUTTON_W + MainGUI.PADDING), y + h - MainGUI.MARGINS.y - MainGUI.BUTTON_H, MainGUI.BUTTON_W, MainGUI.BUTTON_H), "Pivot Ptw")            
        ; Gestore eventi per il pulsante Conferma
        btnPivot.OnEvent("Click", this.ShowPivot.Bind(this))

        ; Aggiunge un pulsante per visualizzare la pivot dei ptw
        btnSpostaOdM := this.gui.Add("Button", Format("x{} y{} w{} h{} v" MainGUI.CTRL_PREFIX_LV "btnSpostaOdM", x + MainGUI.MARGINS.x + 3*(MainGUI.BUTTON_W + MainGUI.PADDING), y + h - MainGUI.MARGINS.y - MainGUI.BUTTON_H, MainGUI.BUTTON_W, MainGUI.BUTTON_H), "Sposta OdM")            
        ; Gestore eventi per il pulsante Conferma
        btnSpostaOdM.OnEvent("Click", this.ShowSpostaOdM.Bind(this))        

/*      ; Funzione aggiunta nel menu contestuale
        ; Aggiunge un pulsante per estarre i dati che sono visualizzati su un file csv
        btnExtractData := this.gui.Add("Button", Format("x{} y{} w{} h{} v" MainGUI.CTRL_PREFIX_LV "btnExtractData", x + MainGUI.MARGINS.x + 4*(MainGUI.BUTTON_W + MainGUI.PADDING), y + h - MainGUI.MARGINS.y - MainGUI.BUTTON_H, MainGUI.BUTTON_W, MainGUI.BUTTON_H), "Extract data")            
        ; Gestore eventi per il pulsante Conferma
        btnExtractData.OnEvent("Click", (*) => this.ExportListViewToCSV(this.gui.LV)) */

        ; Genera automaticamente la mappa dei controlli
        MainGUI.controlsMap_LV := this.GeneratecontrolsMap(MainGUI.CTRL_PREFIX_LV, x, y)
    }  

    ; crea controlli per il gruppo <Estrai dati SAP>
    CreateControls_SAP(x, y, w, h, mesi, anni) {    
            ; Dropdown per la tecnologia
            txtTecnologia := this.gui.Add("Text", Format("x{} y{} w80 h20 v" MainGUI.CTRL_PREFIX_SAP "txtTecnologia", x + MainGUI.MARGINS.x, y + 2*MainGUI.MARGINS.y), "Tecnologia:")
            txtTecnologia.GetPos(&xp, &yp, &wp, &hp)
            ddlTecnologia := this.gui.Add("DropDownList", Format("x{} y{} w80 v" MainGUI.CTRL_PREFIX_SAP "ddlTecnologia", x + MainGUI.MARGINS.x, yp + 2*MainGUI.PADDING), ImpiantiManager.LeggiCategorie())
            ddlTecnologia.GetPos(&xp, &yp, &wp, &hp)          
            ddlTecnologia.OnEvent("Change", this.OnTecnologiaChange.Bind(this))
            ; Dropdown per gli impianti
            txtImpianto := this.gui.Add("Text", Format("x{} y{} h20 v" MainGUI.CTRL_PREFIX_SAP "txtImpianto", xp + MainGUI.PADDING + wp, y + 2*MainGUI.MARGINS.y), "Impianto:")
            txtImpianto.GetPos(&xp, &yp, &wp, &hp)
            ddlImpianto := this.gui.Add("DropDownList", Format("x{} y{} w50 v" MainGUI.CTRL_PREFIX_SAP "ddlImpianto", xp, yp + 2*MainGUI.PADDING), [])
        
            ; Seleziona la prima tecnologia e popola gli impianti
            this.gui[MainGUI.CTRL_PREFIX_SAP . "ddlTecnologia"].Choose(1)
            this.OnTecnologiaChange()     
            ddlImpianto.GetPos(&xp, &yp, &wp, &hp)                  
            ; Aggiunge i controlli per il calendario
            txtMese := this.gui.Add("Text", Format("x{} y{} w80 h20 v" MainGUI.CTRL_PREFIX_SAP "txtMese", x + MainGUI.MARGINS.x, yp + 3*MainGUI.PADDING), "Mese:")
            txtMese.GetPos(&xp, &yp, &wp, &hp)
            txtAnno := this.gui.Add("Text", Format("x{} y{} w50 h20 v" MainGUI.CTRL_PREFIX_SAP "txtAnno", xp + MainGUI.PADDING + wp, yp), "Anno:")
            ddlMese := this.gui.Add("DropDownList", Format("x{} y{} w80 v" MainGUI.CTRL_PREFIX_SAP "ddlMese", xp, yp + 2*MainGUI.PADDING), mesi)
            ddlAnno := this.gui.Add("DropDownList", Format("x{} y{} w50 v" MainGUI.CTRL_PREFIX_SAP "ddlAnno", xp + MainGUI.PADDING + wp, yp + 2*MainGUI.PADDING), anni)
            ddlAnno.GetPos(&xp, &yp, &wp, &hp)

            
            ; Aggiunge un pulsante per confermare la selezione
            btnEstraiDati := this.gui.Add("Button", Format("x{} y{} w{} h{} v" MainGUI.CTRL_PREFIX_SAP "btnEstraiDati", x + MainGUI.MARGINS.x, y + h - MainGUI.MARGINS.y - MainGUI.BUTTON_H, MainGUI.BUTTON_W, MainGUI.BUTTON_H), "Estrai dati")            
            ; Gestore eventi per il pulsante Conferma
            btnEstraiDati.OnEvent("Click", this.EstraiDatiSAP.Bind(this))
            btnConfigImpianti := this.gui.Add("Button", Format("x{} y{} w{} h{} v" MainGUI.CTRL_PREFIX_SAP "btnConfigImpianti", x + w - MainGUI.BUTTON_H - MainGUI.MARGINS.x, y + h - MainGUI.MARGINS.y - MainGUI.BUTTON_H, MainGUI.BUTTON_H, MainGUI.BUTTON_H), "")
            ButtonIconManager.SetIcon(btnConfigImpianti, 'shell32.dll',315, 's' . 32)
            btnConfigImpianti.OnEvent("Click", this.ConfiguraImpianti.Bind(this))            
            
            ; Imposta i valori predefiniti (mese e anno correnti)
            ddlMese.Choose(Integer(FormatTime(A_Now, "M")))
            ddlAnno.Choose(2)  ; Seleziona il primo anno della lista (anno corrente)

            ; genero il map contenente i controlli e le loro posizioni
            ; Genera automaticamente la mappa dei controlli
            MainGUI.controlsMap_SAP := this.GeneratecontrolsMap(MainGUI.CTRL_PREFIX_SAP, x, y)
    }            

    ; crea controlli per il gruppo <Cambia date SAP>
    CreateControls_CambiaDateSAP(x, y, w, h) {    
        ; Calendario data inizio cardine
        centerX := x + (w - 140)/2
        ;txtDataInizioCardine := this.gui.Add("Text", Format("x{} y{} w120 h20 v" MainGUI.CTRL_PREFIX_DATE_SAP "txtDataInizioCardine", x + MainGUI.MARGINS.x, y + 2*MainGUI.MARGINS.y), "Date inizio cardine:")
        txtDataInizioCardine := this.gui.Add("Text", Format("x{} y{} w120 h20 v" MainGUI.CTRL_PREFIX_DATE_SAP "txtDataInizioCardine", centerX, y + 2*MainGUI.MARGINS.y), "Date inizio cardine:")
        txtDataInizioCardine.GetPos(&xp, &yp, &wp, &hp)
        ;dataInizioCardine := this.gui.Add("DateTime", Format("x{} y{} w140 v" MainGUI.CTRL_PREFIX_DATE_SAP "DataInizioCardine", x + MainGUI.MARGINS.x, yp + 2*MainGUI.PADDING), "dd.MMMM.yyyy")
        dataInizioCardine := this.gui.Add("DateTime", Format("x{} y{} w140 v" MainGUI.CTRL_PREFIX_DATE_SAP "DataInizioCardine", centerX, yp + 2*MainGUI.PADDING), "dd.MMMM.yyyy")

        dataInizioCardine.GetPos(&xp, &yp, &wp, &hp)          
        ; Calendario data fine cardine
        txtDataFineCardine := this.gui.Add("Text", Format("x{} y{} w120 h20 v" MainGUI.CTRL_PREFIX_DATE_SAP "txtDataFineCardine", xp, yp + 3*MainGUI.PADDING), "Date fine cardine:")
        txtDataFineCardine.GetPos(&xp, &yp, &wp, &hp)
        dataFineCardine := this.gui.Add("DateTime", Format("x{} y{} w140 v" MainGUI.CTRL_PREFIX_DATE_SAP "DataFineCardine", xp, yp + 2*MainGUI.PADDING), "dd.MMMM.yyyy")
    
        centerX := (w - MainGUI.BUTTON_W)/2
        ; Aggiunge un pulsante per confermare la selezione
        btnModificaData := this.gui.Add("Button", Format("x{} y{} w{} h{} v" MainGUI.CTRL_PREFIX_DATE_SAP "btnModificaData", x + centerX, y + h - MainGUI.MARGINS.y - MainGUI.BUTTON_H, MainGUI.BUTTON_W, MainGUI.BUTTON_H), "Modifica Data")            
        ; Gestore eventi per il pulsante Conferma
        btnModificaData.OnEvent("Click", this.ModificaDateCardineSAP.Bind(this))         
        
        dataFineCardine.GetPos(&xp, &yp, &wp, &hp)
        ; Creo una progress bar
        this.ProgressBar := this.gui.Add("Progress", Format("x{} y{} w{} h5 v" MainGUI.CTRL_PREFIX_DATE_SAP "MyProgressBar", x+MainGUI.MARGINS.x, yp+38, w-2*MainGUI.MARGINS.x))
        ; genero il map contenente i controlli e le loro posizioni
        ; Genera automaticamente la mappa dei controlli
        MainGUI.controlsMap_CambiaDateSAP := this.GeneratecontrolsMap(MainGUI.CTRL_PREFIX_DATE_SAP, x, y)
        this.SetControlsState(MainGUI.controlsMap_CambiaDateSAP, false)
}    
    
    UpdateControlsPosition(x, y, w, h, map) {
            ; Aggiorna la posizione di ogni controllo usando gli offset memorizzati
            for name, info in map {
                if (name = MainGUI.CTRL_PREFIX_LV "ListView") {
                    info.ctrl.Move(x + info.offsetX,  ; Nuova X = base X + offset
                        y + info.offsetY,     ; Nuova Y = base Y + offset
                        w - 2*MainGUI.MARGINS.x,               ; Larghezza originale
                        h - 80)               ; Altezza originale
                }
                else if (InStr(name, MainGUI.CTRL_PREFIX_LV . "btn")) {
                    info.ctrl.Move(x + info.offsetX,  ; Nuova X = base X + offset
                        y + h - MainGUI.MARGINS.y - MainGUI.BUTTON_H,     ; Nuova Y = base Y + offset
                        info.w,               ; Larghezza originale
                        info.h)               ; Altezza originale
                }
                else {
                    info.ctrl.Move(x + info.offsetX,  ; Nuova X = base X + offset
                                y + info.offsetY,     ; Nuova Y = base Y + offset
                                info.w,               ; Larghezza originale
                                info.h)               ; Altezza originale
                }
            }
    }
    
    SetControlsState(controlsMap, enable := true) {
        try {
            ; Imposta lo stato di tutti i controlli nella mappa
            for name, info in controlsMap {
                ; Verifica se è un controllo che può essere disabilitato
                if (info.ctrl.HasProp("Enabled")) {
                    ; Se enable è true, rimuove la proprietà Disabled, altrimenti la aggiunge
                    if enable
                        info.ctrl.Opt("-Disabled")
                    else
                        info.ctrl.Opt("+Disabled")
                }
            }
            return true
        }
        catch Error as err {
            MsgBox("Errore durante la modifica dello stato dei controlli: " err.Message, "Errore", 16)
            return false
        }
    }

    ; Definisco il menu contestuale da mostrare sulla LV
    ShowContextMenu(*) {
        if(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].GetCount() > 0) { ; se la LV contiene elementi
            contextMenu := Menu()
            contextMenu.Add("Seleziona tutto", (*) => this.SelezionaTutto())
            contextMenu.Add("Deseleziona tutto", (*) => this.DeSelezionaTutto())
            contextMenu.Add()   ; separatore            
            contextMenu.Add("Copia", (*) => this.CopySelectedText())
            if !this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].GetNext() ; se non ci sono righe selezionate disabilito il comando
                contextMenu.Disable("Copia")
            contextMenu.Add()   ; separatore
            contextMenu.Add("Esporta dati", (*) => this.ExportListViewToCSV(this.gui.LV))        
            if (!this.gui[MainGUI.CTRL_PREFIX_LV "btnSpostaOdM"].Enabled) { ; se questo tasto è disabilitato
                contextMenu.Add()   ; separatore
                contextMenu.Add("Check All ☒", (*) => this.CheckAll())
                contextMenu.Add("UnCheck All ☐", (*) => this.UnCheckAll())
                ; Verifica se c'è almeno un item selezionato in tutta la ListView
                if(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].GetNext(0, "Checked") != 0)
                    contextMenu.Enable("UnCheck All ☐")
                else
                    contextMenu.Disable("UnCheck All ☐")
            }
            contextMenu.Show()
        }
    }

    SelezionaTutto(*){
        this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].Modify(0, "Select")
        this.OnSelectionChange()
    }

    DeSelezionaTutto(*){
        this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].Modify(0, "-Select")
        this.OnSelectionChange()
    }    

    CheckAll(*) {
        this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].Modify(0, "Check")
        this.SetControlsState(MainGUI.controlsMap_CambiaDateSAP, true)  ; rendo attivi i comandi per la modifica della data cardine
        this.OnSelectionChange() ; richiamo la funzione per l'aggioranmento dei menu
    }

    UnCheckAll(*) {
        this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].Modify(0, "-Check")
        this.SetControlsState(MainGUI.controlsMap_CambiaDateSAP, false) ; redno inattivi i comandi per la modifica della data cardine
        this.OnSelectionChange() ; richiamo la funzione per l'aggioranmento dei menu
    }

    OnItemCheck(GuiCtrlObj, Item, RowNumber) {
        ; Verifica se c'è almeno un item checked usando direttamente GetNext
        isChecked := GuiCtrlObj.GetNext(0, "Checked") != 0
        
        ; Imposta lo stato dei controlli in base alla presenza di checkbox selezionati
        this.SetControlsState(MainGUI.controlsMap_CambiaDateSAP, isChecked)
        
        this.OnSelectionChange() ; richiamo la funzione per l'aggioranmento dei menu
    
    return isChecked        

/*         ; Verifica se c'è almeno un item selezionato in tutta la ListView
        isChecked := false
        row := 0
        while (row := GuiCtrlObj.GetNext(row, "Checked")) {
            isChecked := true
            break
        }
        
        if isChecked
            this.SetControlsState(MainGUI.controlsMap_CambiaDateSAP, true)
        else
            this.SetControlsState(MainGUI.controlsMap_CambiaDateSAP, false)
            
        ; Ottiene il testo della riga corrente
        itemText := GuiCtrlObj.GetText(RowNumber, 1)
        
        return isChecked */
    }       

    ; Funzione per gestire la selezione della cella
    OnItemFocus(LV, RowNumber) {
        try {
            this.Edit_DettagliOdM.SetText("") ; elimino i valori precedenti
            ; Trova l'indice della colonna "Ordini"
            colIndex := 0
            Loop LV.GetCount("Col") {
                if (LV.GetText(0, A_Index) = "Ordine") {
                    colIndex := A_Index
                    break
                }
            }
            
            if (colIndex = 0)
                return  ; Colonna non trovata
                
            ; Ottiene il numero dell'ordine dalla cella selezionata
            ordineSelezionato := LV.GetText(RowNumber, colIndex)
            
            ; Apre il database
            this.OpenDB()
            
            ; Query per ottenere le informazioni dell'ordine
            query := Format("
            (
                SELECT 
                    "Div.",
                    Ordine,
                    "Tp.",
                    "TAM",                    
                    "Tsto br.",
                    "CLavResp",
                    "Sede tecnica",                  
                    "Data acq.",
                    "In. card.",
                    "Fine card.",
                    "Stato sistema",
                    "St.utente"
                FROM {1}
                WHERE Ordine = '{2}'
            )", G_CONSTANTS.TABLE_NAME_ODM_LIST, ordineSelezionato)
            
            ; Esegue la query
            if !this.MyDB.db.GetTable(query, &result)
                throw Error("Errore durante la lettura dei dati: " . this.MyDB.db.ErrorMsg)
            
            if result.HasRows {
                row := Result.Rows[1] ; prende la prima riga della tabella risultante
                divisione := row[1]
                ordine := row[2]
                tipo := row[3]
                tam := row[4]
                testoBrv := row[5]
                clavResp := row[6]
                sedeTecnica := row[7]
                dataAcq := row[8]
                inCard := row[9]
                fineCard := row[10]           
                statoSistema := row[11]
                statoUtente := row[12]
                ; Formatta le informazioni ottenute
                ; Numero Ordine
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel("Ordine: ")
                ; Valore
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel(ordine . "`t")
                ; Tipo Ordine
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel("Tipo: ")
                ; Valore
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel(tipo . " ")
                ; Tipo attività
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel("Tipologia: ")
                ; Valore
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel(tam . "`n")
                ; Centro lavoro
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel("CdL: ")
                ; Valore
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel(clavResp . " ")
                ; Sede tecnica
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel("Sede Tecnica: ")
                ; Valore
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel(sedeTecnica . "`n")
                
                ; Testo Breve
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel("Testo: ")
                ; Valore
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel(testoBrv . "`n")

                ; Stato utente
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel("Stato utente: ")
                ; Valore
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel(statoUtente . "`n")
                ; Stato sistema
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel("Stato sistema: ")
                ; Valore
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel(SubStr(statoSistema, 1 , 27) . ((StrLen(statoSistema)>27) ? "...": "") . "`n")

                ; Data creazione
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel("Data creazione: ")
                ; Valore
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel(dataAcq . "`n")
                ; Inizio cardine
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel("Inizio c.: ")
                ; Valore
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel(inCard . " ")
                ; Fine cardine
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel("Fine c.: ")
                ; Valore
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel(fineCard . "`n") 
                ; Linea Orizontale
                this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                this.Edit_DettagliOdM.ReplaceSel("------------------------------------------------" . "`n")                                                                          

                ; Query per ottenere le informazioni sulle operazioni dell'ordine
                query := Format("
                (
                    SELECT 
                        "Ordine",
                        "Op. con PTW",
                        "Totale Op.",
                        "PTW POP"
                    FROM {1}
                    WHERE Ordine = '{2}'
                )", G_CONSTANTS.TABLE_NAME_PTW_PIVOT, ordineSelezionato)
                
                ; Esegue la query
                if !this.MyDB.db.GetTable(query, &result)
                    throw Error("Errore durante la lettura dei dati: " . this.MyDB.db.ErrorMsg)
                
                if result.HasRows {
                    row := Result.Rows[1] ; prende la prima riga della tabella risultante
                    totaleOperazioni  := row[3]
                    opConPTW := row[2]
                    opPOP := row[4]

                    ; Numero totale di operazioni
                    this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                    this.Edit_DettagliOdM.ReplaceSel("PTW ")

                    if (opConPTW > 0) {
                        this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 14, Color: 0x00FF00, Style: "B"})  
                        this.Edit_DettagliOdM.ReplaceSel("✔")                        
                    }
                    else {
                        this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 14, Color: 0xFF0000, Style: "B"})  
                        this.Edit_DettagliOdM.ReplaceSel("✘")  

                    }
                    ; Numero totale di operazioni
                    this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                    this.Edit_DettagliOdM.ReplaceSel("`tTot.op.: ")
                    ; Valore
                    this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                    this.Edit_DettagliOdM.ReplaceSel(totaleOperazioni . "`t") 
                    ; Numero operazioni con PTW
                    this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                    this.Edit_DettagliOdM.ReplaceSel("n° PTW: ")
                    ; Valore
                    this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                    this.Edit_DettagliOdM.ReplaceSel(opConPTW . "`t")                     
                    ; Numero operazioni con PTW
                    this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                    this.Edit_DettagliOdM.ReplaceSel("n° POP: ")
                    ; Valore
                    this.Edit_DettagliOdM.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                    this.Edit_DettagliOdM.ReplaceSel(opPOP)                     
                } 

/*                 ; Visualizza le informazioni (puoi modificare questa parte in base alle tue esigenze)
                this.Edit_DettagliOdM.SetText(infoText) */
            }
        }
        catch Error as err {
            MsgBox("Errore durante la lettura dei dati: " err.Message, "Errore", 16)
        }
        finally {
            this.CloseDB()
        }
    }

    CopySelectedText(*) {
        copiedText := ""
        rowNumber := 0

        ; Itera attraverso le righe selezionate
        while (rowNumber := this.gui.LV.GetNext(rowNumber)) {
            loop this.gui.LV.GetCount("Col") {
                cellText := this.gui.LV.GetText(rowNumber, A_Index)
                copiedText .= cellText . "`t"  ; Usa tab come separatore tra colonne
            }
            copiedText := RTrim(copiedText, "`t") . "`n"  ; Rimuovi l'ultimo tab e aggiungi un newline
        }

        if (copiedText != "") {
            A_Clipboard := RTrim(copiedText, "`n")  ; Rimuovi l'ultimo newline
            MsgBox("Testo copiato negli appunti!")
        }
    }

    UpdateImpianti(*) {
        tecnologiaCtrl := MainGUI.controlsMap_SAP[MainGUI.CTRL_PREFIX_SAP . "ddlTecnologia"].ctrl
        impiantoCtrl := MainGUI.controlsMap_SAP[MainGUI.CTRL_PREFIX_SAP . "ddlImpianto"].ctrl
        
        tecnologia := tecnologiaCtrl.Text
        impianti := ImpiantiManager.LeggiImpianti(tecnologia)
        impiantoCtrl.Delete()
        impiantoCtrl.Add(impianti)
        if (impianti.Length > 0)
            impiantoCtrl.Choose(1)
    }
    
    ConfiguraImpianti(*) {
        ; Disabilita la GUI principale mentre la GUI Impianti è aperta
        this.gui.Opt("+Disabled")
        ; Crea una nuova istanza di ImpiantiGUI passando il riferimento a this
        this.ImpiantiGui := ImpiantiGUI(this)
        this.gui.Opt("-Disabled")
    }

    ModificaDateCardineSAP(*) {
        ; creo una lista con le righe selezionate
        checkedItems := []
        row := 0
        
        loop {
            row := this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].GetNext(row, "Checked")
            if !row
                break
            checkedItems.Push(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].GetText(row, 1))
        }

        ; verifico che la lista prodotta contenga elementi
        if (checkedItems.Length = 0) {
            MsgBox("Nessun ordine selezionato", "Errore", 16)
            return
        }
        else {
            ; verifico che la data di inizio sia antecedente alla data di fine
            dataInizio := this.gui[MainGUI.CTRL_PREFIX_DATE_SAP "DataInizioCardine"].value
            dataFine := this.gui[MainGUI.CTRL_PREFIX_DATE_SAP "DataFineCardine"].value
            if (dataFine < dataInizio) {
                MsgBox("La data di fine deve essere successiva alla data di inizio", "Errore", 16)
                return
            }
            else {
                ; converto le date in modo che siano compatibili con il formato di SAP
                dataInizio_String := FormatTime(dataInizio, "dd.MM.yy")
                dataFine_String := FormatTime(dataFine, "dd.MM.yy")
                OutputDebug("Data Inizio: " . dataInizio_String . "`n")
                OutputDebug("Data Fine: " . dataFine_String . "`n")
                SAP_Transactions.IW32(checkedItems, dataInizio_String, dataFine_String, this.ProgressBar, this.SB)
            }
        }
        
        
    }

    EstraiDatiSAP(*) {
        try {
            ; elimino i valori precedenti nelle finestre dettagli OdM e KPI
            this.Edit_DettagliOdM.SetText("")
            this.Edit_DettagliKPI.SetText("")
            ; resetto lo stato della progress bar
            this.ProgressBar.Value := 0
            ; rendo inattivo il controllo per la modifica della data cardine
            this.SetControlsState(MainGUI.controlsMap_CambiaDateSAP, false)
            ; elimino i valori presenti nella LV
            this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].Delete()
            this.SetControlsState(MainGUI.controlsMap_LV, false)

            this.SB.SetText("Estraggo dati SAP")
            if (G_CONSTANTS.DEBUG_MODE) {
                ; In modalità debug, apri il DB esistente senza inizializzarlo
                OutputDebug("DEBUG MODE: Apertura DB esistente`n")
                this.MyDB := DBManager(G_CONSTANTS.DB_FILENAME, initialize := false)
                this.OnSelectionChange()    ; Modifico i menu visualizzati

/*                 ; Verifica che la tabella RAW_DATA esista
                if (!this.MyDB.TableExists(G_CONSTANTS.TABLE_NAME_RAW_DATA)) {
                    throw Error("Tabella RAW_DATA non trovata nel database.")
                } */
            }
            else {
                ; Creazione della data di inizio (primo giorno del mese)
                meseSelezionato := this.gui[MainGUI.CTRL_PREFIX_SAP . "ddlMese"].Text
                annoSelezionato := this.gui[MainGUI.CTRL_PREFIX_SAP . "ddlAnno"].Text
                ; Convertiamo le stringhe in numeri
                meseNum := ArrayTools.IndexOf(MainGUI.MESI, meseSelezionato, caseSensitive := true)
                annoNum := Integer(annoSelezionato)

                ; Creazione della data di inizio (primo giorno del mese)
                dataInizio := Format("01.{:02d}.{:02d}", meseNum, Mod(annoNum, 100))

                ; Determina l'ultimo giorno del mese
                giornoFinale := 31  ; Default per i mesi con 31 giorni
                if (meseNum = 4 || meseNum = 6 || meseNum = 9 || meseNum = 11)
                    giornoFinale := 30
                else if (meseNum = 2) {  ; Febbraio
                    if (Mod(annoNum, 4) = 0 && (Mod(annoNum, 100) != 0 || Mod(annoNum, 400) = 0))
                        giornoFinale := 29  ; Anno bisestile
                    else
                        giornoFinale := 28  ; Anno non bisestile
                }

                ; Creazione della data di fine
                dataFine := Format("{:02d}.{:02d}.{:02d}", giornoFinale, meseNum, Mod(annoNum, 100))
                OutputDebug("Data inizio: " . dataInizio . " - Data fine: " . dataFine . " - " . this.gui[MainGUI.CTRL_PREFIX_SAP . "ddlImpianto"].Text . "`n")
                
                ; estraggo i dati da SAP e creo un array
                this.SB.SetText("Eseguo transazione IW39")
                arrDati := SAP_Transactions.IW39(this.gui[MainGUI.CTRL_PREFIX_SAP . "ddlImpianto"].Text, dataInizio, dataFine)
                ; Inizializza il database (elimina quello esistente)
                this.MyDB := DBManager(G_CONSTANTS.DB_FILENAME, initialize := true)

                ; Parsa i dati normalizzando le intestazioni con i nomi canonici IW39
                data := DataParser.parseArray(arrDati, G_CONSTANTS.IW39_FIELD_MAP)
                ; Crea la tabella contenente la lista degli OdM estratta con la IW39
                this.MyDB.createTable(data, G_CONSTANTS.TABLE_NAME_ODM_LIST, ["Ordine"])
                ; Ricavo la lista degli OdM da utilizzare con la successiva estrazione IW49N
                listaOdM := this.MyDB.GetOrdersList()
                this.SB.SetText("Eseguo transazione IW49")
                arrDati := SAP_Transactions.IW49N(listaOdM)
                ; Parsa i dati
                data := DataParser.parseArray(arrDati)
                ; Crea la tabella principale
                this.MyDB.createTable(data, G_CONSTANTS.TABLE_NAME_RAW_DATA, ["Ordine", "Op."])
                ; --- Parte di visualizzazione dei dati indipendente dalla parte di recupero dei dati ---
                ; Crea le tabelle derivate e calcola le statistiche
                this.MyDB.createFilteredTable(G_CONSTANTS.TABLE_NAME_RAW_DATA, G_CONSTANTS.TABLE_NAME_CLEAN_DATA)
                ; creo una tabella per il conteggio dei PTW
                this.MyDB.CreateNewTableWithPTWColumn(G_CONSTANTS.TABLE_NAME_CLEAN_DATA, G_CONSTANTS.TABLE_NAME_ODM_PTW_DATA, G_CONSTANTS.STATI_PTW)
                ; creo una vista per visualizzare i dati nella LV
                this.MyDB.CreateViewWithPTWColumn(G_CONSTANTS.TABLE_NAME_CLEAN_DATA, G_CONSTANTS.VIEW_NAME_ODM_PTW_DATA, G_CONSTANTS.STATI_PTW)
                ; this.MyDB.addPTWColumn_old(G_CONSTANTS.STATI_PTW)
                this.MyDB.createPTWPivot(G_CONSTANTS.TABLE_NAME_ODM_PTW_DATA, G_CONSTANTS.TABLE_NAME_PTW_PIVOT)
                ; this.MyDB.addPTWColumn_old(G_CONSTANTS.STATI_PTW)
                this.MyDB.createPivotOdMsenzaPTW(G_CONSTANTS.TABLE_NAME_PTW_PIVOT, G_CONSTANTS.TABLE_NAME_ODM_SENZA_PTW)                
                
                ; Ottieni e mostra le statistiche
                stats := this.MyDB.getPTWStats(G_CONSTANTS.TABLE_NAME_PTW_PIVOT)
                if stats.HasRows {
                    row := stats.Rows[1]
                    ; Intestazone
                    this.Edit_DettagliKPI.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                    this.Edit_DettagliKPI.ReplaceSel("Analisi OdM con PTW: `n-------------------------------------------`n")
                    ; Totale OdM
                    this.Edit_DettagliKPI.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                    this.Edit_DettagliKPI.ReplaceSel("Totale OdM: ")
                    ; Valore
                    this.Edit_DettagliKPI.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                    this.Edit_DettagliKPI.ReplaceSel(row[2] . "`n") 
                    ; OdM con PTW
                    this.Edit_DettagliKPI.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                    this.Edit_DettagliKPI.ReplaceSel("OdM con PTW: ")
                    ; Valore
                    this.Edit_DettagliKPI.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                    this.Edit_DettagliKPI.ReplaceSel(row[1] . "`t")
                    ; PTW POP
                    this.Edit_DettagliKPI.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                    this.Edit_DettagliKPI.ReplaceSel(" -> PTW POP: ")
                    ; Valore
                    this.Edit_DettagliKPI.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                    this.Edit_DettagliKPI.ReplaceSel(row[4] . "`n")


                    ; Senza Ptw
                    this.Edit_DettagliKPI.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                    this.Edit_DettagliKPI.ReplaceSel("OdM senza PTW: ")
                    ; Valore
                    this.Edit_DettagliKPI.SetFont({Name: "Consolas", Size: 10, Color: 0x000000, Style: "N"})  
                    this.Edit_DettagliKPI.ReplaceSel(row[2] - row[1] . "`n")                                
                    ; Percentuale
                    this.Edit_DettagliKPI.SetFont({Name: "Consolas", Size: 10, Color: 0x0000FF, Style: "N"})  
                    this.Edit_DettagliKPI.ReplaceSel("Valore KPI: ")
                    ; Valore
                    if(Integer(row[3]) >= G_CONSTANTS.TARGET_KPI) {
                        this.Edit_DettagliKPI.SetFont({Name: "Consolas", Size: 10, Color: 0x00FF00, Style: "N"})  
                        this.Edit_DettagliKPI.ReplaceSel(row[3] . "% ")                        
                        this.Edit_DettagliKPI.SetFont({Name: "Consolas", Size: 14, Color: 0x00FF00, Style: "B"})  
                        this.Edit_DettagliKPI.ReplaceSel("✔")                    
                    }
                    else {
                        this.Edit_DettagliKPI.SetFont({Name: "Consolas", Size: 10, Color: 0xFF0000, Style: "N"})  
                        this.Edit_DettagliKPI.ReplaceSel(row[3] . "% ")                             
                        this.Edit_DettagliKPI.SetFont({Name: "Consolas", Size: 14, Color: 0xFF0000, Style: "B"})  
                        this.Edit_DettagliKPI.ReplaceSel("✘")                          
                    }
                }                  
            }

            try {
                OutputDebug("Aggiorno la LV con i dati della tabella RAW`n")
                ; DataView.PopulateListView(this.CLV, G_CONSTANTS.TABLE_NAME_RAW_DATA, this.MyDB)
                nRighe := DataView.PopulateListView(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"], G_CONSTANTS.TABLE_NAME_RAW_DATA, this.MyDB)
                this.SB.SetText("Totale righe: " . nRighe)
                this.color_LV(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"])
                this.SetControlsState(MainGUI.controlsMap_LV, true)
                this.gui[MainGUI.CTRL_PREFIX_LV "btnRawData"].Opt("+Disabled")
                this.OnSelectionChange()    ; Modifico i menu visualizzati
            } catch Error as err {        
                MsgBox("Errore: " . err.Message, "Errore", 16)
            }                    
        } catch Error as e {
            MsgBox("Error: " . e.Message, "Error", 16)
        } finally {
            this.CloseDB()
        }
    }

    set_LV_Pivot(ListView){
        ListView.Opt("-Redraw")
        try {
            If IsObject(this.CLV) {
                this.CLV.ShowColors(false)
                this.CLV.Clear(1, 1)  
            }
        }
        ListView.Opt("+Checked")
        Loop ListView.GetCount("Col")
            ListView.ModifyCol(A_Index, "AutoHdr")        
        
        ListView.Opt("+Redraw")    
    }


    color_LV_Pivot(ListView){
        ListView.Opt("-Redraw")
        try {
            If IsObject(this.CLV) {
                this.CLV.ShowColors(false)
                this.CLV.Clear(1, 1)  
            }
        }
        catch {
            this.CLV := LV_Colors(ListView, true, false, false)
            If !IsObject(this.CLV) {
                MsgBox("Couldn't create a new LV_Colors object!", "ERROR", 16)
                ExitApp
            }
        }
        ; ricavo l'indice della colonna dato il nome
        columnCount := ListView.GetCount("Column")
        Loop columnCount {
            if (ListView.GetText(0, A_Index) = "Ordine") {
                columnIndex_Ordine := A_Index
            }
            else if (ListView.GetText(0, A_Index) = "Op. con PTW") {
                columnIndex_OpPTW := A_Index
            }
            else if (ListView.GetText(0, A_Index) = "PTW POP") {
                columnIndex_OpPOP := A_Index
            }                       
        }
        
        ; verifico se l'operazione è fra quelle indicate come di sicurezza
        ; memorizzo il relativo OdM in un array
        arr_OdM := []
        Loop ListView.GetCount() { ; scorre tutte le righe della LV
            cellText := ListView.GetText(A_Index, columnIndex_OpPTW)
            if (Integer(cellText) > 0) {
                OdM := ListView.GetText(A_Index, columnIndex_Ordine)
                ListView.Modify(A_Index, "Icon1") ; icons := [295, 236, 132, 4] ; [OK, Allert, NOK, File]
                if !(ArrayTools.HasElement(arr_OdM, OdM))
                    arr_OdM.Push(OdM)
                this.CLV.cell(A_Index, columnIndex_OpPTW, 0xB2D8A7, 0x000080)
                ; verifico se ha POP
                cellText := ListView.GetText(A_Index, columnIndex_OpPOP)
                if (Integer(cellText) > 0) {
                    this.CLV.cell(A_Index, columnIndex_OpPOP, 0xFFF0B5, 0x000080)
                }                             
            } else {
                ListView.Modify(A_Index, "Icon2") ; icons := [295, 236, 132, 4] ; [OK, Allert, NOK, File]
            }
        }           
        
        ; genero una lista di colori da utilizzare con gli OdM
        map_colori := this.GeneraMapColori(arr_OdM)
        ; Colora le celle della ListView
        Loop ListView.GetCount() {
            cellText := ListView.GetText(A_Index, columnIndex_Ordine)
            if (ArrayTools.HasElement(arr_OdM, cellText)) {
                ; Usa il colore precedentemente assegnato all'OdM
                color := map_colori[cellText]
                this.CLV.cell(A_Index, columnIndex_Ordine, color, 0x000000)
            }
        }        


        this.CLV.ShowColors(true)
        ListView.Opt("+Redraw")
    }        

    color_LV(ListView) {
        
        ListView.Opt("-Redraw")
        try {
            If IsObject(this.CLV) {
                this.CLV.ShowColors(false)
                this.CLV.Clear(1, 1)  
            }
        }
        catch {
            this.CLV := LV_Colors(ListView, true, false, false)
            If !IsObject(this.CLV) {
                MsgBox("Couldn't create a new LV_Colors object!", "ERROR", 16)
                ExitApp
            }
        }
        
        columnCount := ListView.GetCount("Column")
        Loop columnCount {
            if (ListView.GetText(0, A_Index) = "ChTstStd") {
                columnIndex_ChTstStd := A_Index
            }
            else if (ListView.GetText(0, A_Index) = "Ordine") {
                columnIndex_Ordine := A_Index
            }            
        }
        
        ; verifico se l'operazione è fra quelle indicate come di sicurezza
        ; memorizzo il relativo OdM in un array
        arr_OdM := []
        Loop ListView.GetCount() {
            cellText := ListView.GetText(A_Index, columnIndex_ChTstStd)
            if (ArrayTools.HasElement(G_CONSTANTS.STATI_PTW, SubStr(cellText, 4), caseSensitive := true)) {
                OdM := ListView.GetText(A_Index, columnIndex_Ordine)
                if !(ArrayTools.HasElement(arr_OdM, OdM))
                    arr_OdM.Push(OdM)
                this.CLV.cell(A_Index, columnIndex_ChTstStd, 0xB2D8A7, 0x000080)                
            }
        }           
        
        ; genero una lista di colori da utilizzare con gli OdM
        map_colori := this.GeneraMapColori(arr_OdM)
        ; Colora le celle della ListView
        Loop ListView.GetCount() {
            cellText := ListView.GetText(A_Index, columnIndex_Ordine)
            if (ArrayTools.HasElement(arr_OdM, cellText)) {
                ; Usa il colore precedentemente assegnato all'OdM
                color := map_colori[cellText]
                this.CLV.cell(A_Index, columnIndex_Ordine, color, 0x000000)
            }
        }        


        this.CLV.ShowColors(true)
        ListView.Opt("+Redraw")
    }

    GeneraMapColori(arr_OdM) {

        ; Crea un dizionario per memorizzare i colori assegnati a ciascun OdM
        odm_colors := Map()
        
        ; Crea array dei colori disponibili
        colorValues := []
        for key, value in G_CONSTANTS.COLOR {
            colorValues.Push(value)
        }
        
        ; Salva una copia dell'array originale dei colori
        originalColors := []
        for color in colorValues {
            originalColors.Push(color)
        }
        
        ;Assegna colori unici a ciascun OdM
        for odm in arr_OdM {
            if (!odm_colors.Has(odm)) {
                ; Se non ci sono più colori disponibili, ricaricare l'array dei colori
                if (colorValues.Length = 0) {
                    for color in originalColors {
                        colorValues.Push(color)
                    }
                }
                
                ; Scegli un colore casuale dall'array dei colori disponibili
                randomIndex := Random(1, colorValues.Length)
                odm_colors[odm] := colorValues[randomIndex]
                
                ; Rimuovi il colore usato dall'array dei colori disponibili
                colorValues.RemoveAt(randomIndex)
            }
        }

        return odm_colors
    }


    ; Metodo per riaprire il DB
    OpenDB() {
        try {
            if !IsObject(this.MyDB) {
                this.MyDB := DBManager(G_CONSTANTS.DB_FILENAME, initialize := false)
            } else if !this.MyDB.db.HasKey("_handle") {  ; Controlla se il DB è chiuso
                this.MyDB := DBManager(G_CONSTANTS.DB_FILENAME, initialize := false)
            }
            OutputDebug("DB aperto`n") 
        } catch Error as e {
            MsgBox("Errore durante l'apertura del DB: " . e.Message, "Error", 16)
        }
    }
    
    ; Metodo per chiudere il DB quando necessario
    CloseDB() {
        try {        
            if IsObject(this.MyDB) {
                this.MyDB.close()
                this.MyDB := ""
                OutputDebug("DB chiuso`n")
            }
        } catch Error as e {
            MsgBox("Errore durante le chiusura del DB: " . e.Message, "Error", 16)
        }            
    }    

    ; *** funzioni per controlli tecnologia
    OnTecnologiaChange(*) {
        ; Ottieni la tecnologia selezionata
        tecnologia := this.gui [MainGUI.CTRL_PREFIX_SAP . "ddlTecnologia"].Text
        
        ; Ottieni gli impianti per questa tecnologia
        impianti := ImpiantiManager.LeggiImpianti(tecnologia)
        
        ; Aggiorna la DDL degli impianti
        this.gui [MainGUI.CTRL_PREFIX_SAP . "ddlImpianto"].Delete()
        this.gui [MainGUI.CTRL_PREFIX_SAP . "ddlImpianto"].Add(impianti)
        
        ; Seleziona il primo impianto se disponibile
        if (impianti.Length > 0)
            this.gui [MainGUI.CTRL_PREFIX_SAP . "ddlImpianto"].Choose(1)
    }
        
    OnLeggiClick(*) {
        tecnologia := this.gui [MainGUI.CTRL_PREFIX_SAP . "ddlTecnologia"].Text
        impianto := this.gui [MainGUI.CTRL_PREFIX_SAP . "ddlImpianto"].Text
        
        if (impianto = "") {
            MsgBox("Nessun impianto selezionato per la tecnologia " tecnologia)
            return
        }
        
        MsgBox("Selezione attuale:`nTecnologia: " tecnologia "`nImpianto: " impianto)
    }

    GetSelectedValues() {
        return {
            tecnologia: this.gui [MainGUI.CTRL_PREFIX_SAP . "ddlTecnologia"].Text,
            impianto: this.gui [MainGUI.CTRL_PREFIX_SAP . "ddlImpianto"].Text
        }
    }        

    ; Metodo per generare automaticamente la mappa dei controlli
    GeneratecontrolsMap(prefix, baseX, baseY) {
        newMap := Map()
        
        ; Itera attraverso tutti i controlli della GUI
        for ctrl in this.gui {
            ; Ottieni il nome della variabile del controllo
            try {
                varName := ctrl.Name  ; Nome variabile del controllo
                
                ; Se il controllo ha il prefisso specificato
                if (InStr(varName, prefix) = 1) {
                    ; Ottieni la posizione corrente del controllo
                    ctrl.GetPos(&ctrlX, &ctrlY, &ctrlW, &ctrlH)
                    
                    ; Calcola gli offset relativi
                    offsetX := ctrlX - baseX
                    offsetY := ctrlY - baseY
                    
                    ; Aggiungi alla mappa
                    newMap[varName] := {
                        ctrl: ctrl,
                        offsetX: offsetX,
                        offsetY: offsetY,
                        w: ctrlW,
                        h: ctrlH
                    }
                }
            }
        }
        return newMap
    }

    ;  mostra nella LV i dati letti dalla tabella del DB rawdata
    ShowRawData(*) {
        try {
            ; elimino i dati presenti nella scheda dettagli OdM
            this.Edit_DettagliOdM.SetText("")
            this.OpenDB()
            OutputDebug("Aggiorno la LV con i dati della tabella RAW`n")
            this.SB.SetText("Aggiorno la lista con i dati della tabella RAW", 1,)
            DataView.PopulateListView(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"], G_CONSTANTS.TABLE_NAME_RAW_DATA, this.MyDB)
            this.color_LV(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"])
            this.SB.SetText("Numero righe: " . this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].GetCount(), 1,)
            this.gui[MainGUI.CTRL_PREFIX_LV "btnRawData"].Opt("+Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnCleanedData"].Opt("-Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnPivot"].Opt("-Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnSpostaOdM"].Opt("-Disabled")
            this.SetControlsState(MainGUI.controlsMap_CambiaDateSAP, false) ; rendo inattivo il controllo per la modifica della data cardine           
            this.OnSelectionChange()    ; Modifico i menu visualizzati            
        } catch Error as err {        
            MsgBox("Errore: " . err.Message, "Errore", 16)
        } finally {
            this.CloseDB()
        }
    }

    ShowCleanedData(*) {
        try {
            ; elimino i dati presenti nella scheda dettagli OdM
            this.Edit_DettagliOdM.SetText("")            
            this.OpenDB()            
            OutputDebug("Aggiorno la LV con i dati della tabella CleanData`n")
            this.SB.SetText("Aggiorno la lista con i dati della tabella CleanData", 1,)
            DataView.PopulateListView(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"], G_CONSTANTS.TABLE_NAME_CLEAN_DATA, this.MyDB)
            this.SB.SetText("Numero righe: " . this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].GetCount(), 1,)
            this.color_LV(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"])
            this.gui[MainGUI.CTRL_PREFIX_LV "btnRawData"].Opt("-Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnCleanedData"].Opt("+Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnPivot"].Opt("-Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnSpostaOdM"].Opt("-Disabled")
            this.SetControlsState(MainGUI.controlsMap_CambiaDateSAP, false) ; rendo inattivo il controllo per la modifica della data cardine                       
            this.OnSelectionChange()    ; Modifico i menu visualizzati            
        } catch Error as err {        
            MsgBox("Errore: " . err.Message, "Errore", 16)
        } finally {
            this.CloseDB()
        }      
    }

    ShowSpostaOdM(*) {
        try {
            ; elimino i dati presenti nella scheda dettagli OdM
            this.Edit_DettagliOdM.SetText("")            
            this.OpenDB()           
            OutputDebug("Aggiorno la LV con i dati della tabella Odm senza PtW`n")
            this.SB.SetText("Aggiorno la lista con i dati della tabella sposta OdM", 1,)
            DataView.PopulateListView(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"], G_CONSTANTS.TABLE_NAME_ODM_SENZA_PTW, this.MyDB)
            this.set_LV_Pivot(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"])
            this.SB.SetText("Numero righe: " . this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].GetCount(), 1,)
            this.gui[MainGUI.CTRL_PREFIX_LV "btnRawData"].Opt("-Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnCleanedData"].Opt("-Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnPivot"].Opt("-Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnSpostaOdM"].Opt("+Disabled")
            this.SetControlsState(MainGUI.controlsMap_CambiaDateSAP, false) ; rendo inattivo il controllo per la modifica della data cardine                       
            this.OnSelectionChange()    ; Modifico i menu visualizzati            
        } catch Error as err {        
            MsgBox("Errore: " . err.Message, "Errore", 16)
        } finally {
            this.CloseDB()
        } 

    }

    ShowOdM_Ptw_Data(*){
        try {
            ; elimino i dati presenti nella scheda dettagli OdM
            this.Edit_DettagliOdM.SetText("")            
            this.OpenDB()           
            OutputDebug("Aggiorno la LV con i dati della tabella Odm con PtW`n")
            this.SB.SetText("Aggiorno la lista con i dati della tabella Pivot", 1,)
            DataView.PopulateListView(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"], G_CONSTANTS.VIEW_NAME_ODM_PTW_DATA, this.MyDB)
            this.color_LV(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"])
            this.SB.SetText("Numero righe: " . this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].GetCount(), 1,)
            this.gui[MainGUI.CTRL_PREFIX_LV "btnRawData"].Opt("-Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnCleanedData"].Opt("-Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnPivot"].Opt("+Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnSpostaOdM"].Opt("-Disabled")
            this.SetControlsState(MainGUI.controlsMap_CambiaDateSAP, false) ; rendo inattivo il controllo per la modifica della data cardine                       
            this.OnSelectionChange()    ; Modifico i menu visualizzati            
        } catch Error as err {        
            MsgBox("Errore: " . err.Message, "Errore", 16)
        } finally {
            this.CloseDB()
        }       
    }

    ShowPivot(*){
        try {
            ; elimino i dati presenti nella scheda dettagli OdM
            this.Edit_DettagliOdM.SetText("")            
            this.OpenDB()           
            OutputDebug("Aggiorno la LV con i dati della tabella Pivot`n")
            DataView.PopulateListView(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"], G_CONSTANTS.TABLE_NAME_PTW_PIVOT, this.MyDB)
            this.color_LV_Pivot(this.gui[MainGUI.CTRL_PREFIX_LV "ListView"])
            this.SB.SetText("Numero righe: " . this.gui[MainGUI.CTRL_PREFIX_LV "ListView"].GetCount(), 1,)
            this.gui[MainGUI.CTRL_PREFIX_LV "btnRawData"].Opt("-Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnCleanedData"].Opt("-Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnPivot"].Opt("+Disabled")
            this.gui[MainGUI.CTRL_PREFIX_LV "btnSpostaOdM"].Opt("-Disabled")
            this.SetControlsState(MainGUI.controlsMap_CambiaDateSAP, false) ; rendo inattivo il controllo per la modifica della data cardine                       
            this.OnSelectionChange()    ; Modifico i menu visualizzati            
        } catch Error as err {        
            MsgBox("Errore: " . err.Message, "Errore", 16)
        } finally {
            this.CloseDB()
        } 
    }      

    GuiShow() {
        this.gui.Show()
        this.gui.GetClientPos(&X, &Y, &Width, &Height)
        this.gui.Opt("+MinSize" . Width . "x" . Height)
    }

    ExportListViewToCSV(ListView) {
        try {
            ; Mostra la finestra di dialogo per salvare il file
            selectedFile := FileSelect("S16", , "Esporta tabella", "CSV Files (*.csv)")
            if (selectedFile = "")
                return  ; L'utente ha annullato
    
            ; Aggiunge l'estensione .csv se non presente
            if (!InStr(selectedFile, ".csv"))
                selectedFile .= ".csv"
    
            ; Verifica se il file esiste
            if FileExist(selectedFile) {
/*                 result := MsgBox("Il file esiste già. Vuoi sovrascriverlo?", "Conferma sovrascrittura", 4 + 48)  ; 4 = Yes/No, 48 = Icon Warning
                if (result = "No")
                    return false
                else */
                    FileDelete(selectedFile)  ; Cancella il file se esiste
            }
    
            ; Crea il contenuto CSV
            csvContent := ""
    
            ; Aggiunge l'header (nomi delle colonne)
            headerRow := ""
            Loop ListView.GetCount("Col") {
                headerRow .= (A_Index > 1 ? "," : "") . "`"" . ListView.GetText(0, A_Index) . "`""
            }
            csvContent := headerRow . "`n"
    
            ; Aggiunge le righe di dati
            Loop ListView.GetCount() {
                row_index := A_Index
                row := ""
                Loop ListView.GetCount("Col") {
                    row .= (A_Index > 1 ? "," : "") . "`"" . ListView.GetText(row_index, A_Index) . "`""
                }
                csvContent .= row . "`n"
            }
    
            ; Scrive il file
            FileAppend(csvContent, selectedFile, "UTF-8")
    
            MsgBox("File esportato con successo!", "Completato", 64)  ; 64 = Icon Info
            return true
        }
        catch Error as err {
            MsgBox("Errore durante l'esportazione: " err.Message, "Errore", 16)  ; 16 = Icon Error
            return false
        }
    }

    ShowInfo(*) {

    }

    ShowAbout(*) {

    }

    CloseApp(*){
        ; chiudo il DB
        this.CloseDB()
        ExitApp()        
    }

}

