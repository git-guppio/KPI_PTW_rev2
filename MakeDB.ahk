#Requires AutoHotkey v2.0
#Include Class_SQLiteDB.ahk

class DBManager {
    
    /**
     * @param dbPath Percorso del file database
     * @param initialize Se true, elimina il DB esistente e ne crea uno nuovo
     */
    __New(dbPath, initialize := false) {
        this.dbPath := dbPath
        this.db := SQLiteDB()
        
        if (initialize) {
            this.createNewDB()
        } else {
            this.openExistingDB()
        }
    }

    TableExists(tableName) {
        try {
            ; Prova a fare una query sulla tabella
            sql := "SELECT COUNT(*) FROM " . G_CONSTANTS.TABLE_NAME_RAW_DATA
            Result := ""
            if !this.db.GetTable(sql, &Result)
                throw Error("Error getting PTW stats: " . this.db.ErrorMsg)            
        } catch Error {
            return false
        }
    }
    
    createNewDB() {
        if FileExist(this.dbPath)
            Try FileDelete(this.dbPath)
            
        if !this.db.OpenDB(this.dbPath) {
            throw Error("Error opening database: " . this.db.ErrorMsg)
        }
    }
    
    openExistingDB() {
        if !FileExist(this.dbPath)
            throw Error("Database file does not exist: " . this.dbPath)
            
        if !this.db.OpenDB(this.dbPath) {
            throw Error("Error opening database: " . this.db.ErrorMsg)
        }
    }
    
    createTable(data, tableName := G_CONSTANTS.TABLE_NAME_RAW_DATA, primaryKeys := []) {
        ; Costruisci la stringa SQL per creare la tabella
        sql := "CREATE TABLE IF NOT EXISTS " . tableName . " ("
        
        ; Aggiungi ID autoincrement solo se non sono specificate chiavi primarie
        if (primaryKeys.Length = 0) {
            sql .= "ID INTEGER PRIMARY KEY AUTOINCREMENT, "
        }

        ; Aggiungi le colonne
        for header in data.intestazione {
            sql .= "`"" . header . "`" TEXT, "
        }
        
        ; Gestione chiave primaria
        if (primaryKeys.Length > 0) {
            sql .= "PRIMARY KEY ("
            for index, key in primaryKeys {
                sql .= "`"" . key . "`""
                if (index < primaryKeys.Length)
                    sql .= ", "
            }
            sql .= ")"
        } else {
            sql := RTrim(sql, ", ")
        }
        
        sql .= ");"

        if !this.db.Exec(sql)
            throw Error("Error creating table: " . this.db.ErrorMsg)
            
        this.insertData(data, tableName)
    }
    
    insertData(data, tableName) {
        if !this.db.Exec("BEGIN TRANSACTION;")
            throw Error("Error starting transaction: " . this.db.ErrorMsg)
            
        try {
            SQL_intestazione := "INSERT INTO " . tableName . " ("
            for element in data.intestazione {
                SQL_intestazione .= "`"" . element . "`", " 
            }
            SQL_intestazione := RTrim(SQL_intestazione, ", ") . ")"
            
            for key, value in data.record {
                SQL_value := " VALUES ("
                for element in value {
                    SQL_value .= "`"" . this.sanitizeSQLText(element) . "`", "
                }
                SQL_value := RTrim(SQL_value, ", ") . ");"
                SQL := SQL_intestazione . SQL_value
                
                if !this.db.Exec(SQL)
                    throw Error("Error inserting data: " . this.db.ErrorMsg)
            }
            
            if !this.db.Exec("COMMIT;")
                throw Error("Error committing transaction: " . this.db.ErrorMsg)
                
        } catch Error as err {
            this.db.Exec("ROLLBACK;")
            throw err
        }
    }
    
    createFilteredTable(sourceTableName, newTableName) {
        SQL_Table_OdM_filtrati := "
        (
            CREATE TABLE XXnewTableNameXX AS 
            SELECT 
                Ordine,
                "Op.",
                "Operazione testo breve",
                "In. card.",
                "Fine card.",
                "CLavResp",
                "ChTstStd",
                "Stato sistema",
                COALESCE("St.utente", "Stato utente") as "St.utente"
            FROM XXsourceTableNameXX 
            WHERE NOT (("Stato sistema" LIKE '%APER%')
               OR ("Stato sistema" LIKE '%FCAN%')
               OR ("Stato sistema" LIKE '%BLOC%'));
        )"

        SQL_Table_OdM_filtrati := StrReplace(SQL_Table_OdM_filtrati, "XXsourceTableNameXX", sourceTableName)
        SQL_Table_OdM_filtrati := StrReplace(SQL_Table_OdM_filtrati, "XXnewTableNameXX", newTableName)

        if !this.db.Exec(SQL_Table_OdM_filtrati)
            throw Error("Error creating filtered table: " . this.db.ErrorMsg)
    }
    
    addPTWColumn(tableName, stati_PTW) {
        ; Aggiungi colonna PTW
        SQL := "ALTER TABLE XXtableNameXX ADD COLUMN PTW INT;"
        SQL := StrReplace(SQL, "XXTableNameXX", tableName)
        if !this.db.Exec(SQL)
            throw Error("Error adding PTW column: " . this.db.ErrorMsg)
            
        ; Costruisci condizione per PTW
        criteriPtw := ""
        for element in stati_PTW {
            criteriPtw .= "`"ChTstStd`" LIKE '%" . element . "%' OR"
        }
        criteriPtw := RTrim(criteriPtw, " OR")
        
        ; Aggiorna valori PTW
        SQL_Update_PTW := "UPDATE Table_OdM_filtrati SET PTW = CASE WHEN " . criteriPtw . " THEN 1 ELSE 0 END;"
        if !this.db.Exec(SQL_Update_PTW)
            throw Error("Error updating PTW values: " . this.db.ErrorMsg)
    }
    
    CreateNewTableWithPTWColumn(sourceTableName, newTableName, stati_PTW) {
        
        ; Crea la nuova tabella con tutte le colonne della tabella originale più la colonna PTW e POP
        SQL_Create := "
        (
            CREATE TABLE XXnewTableNameXX AS 
            SELECT *,
                CASE 
                    WHEN #condizione# THEN 1 
                    ELSE 0 
                END as PTW,
                CASE 
                    WHEN "ChTstStd" LIKE '%SF_POP%' THEN 1 
                    ELSE 0 
                END as POP
            FROM XXsourceTableNameXX;
        )"
        SQL_Create := StrReplace(SQL_Create, "XXsourceTableNameXX", sourceTableName)
        SQL_Create := StrReplace(SQL_Create, "XXnewTableNameXX", newTableName)

        ; Costruisci condizione per PTW
        criteriPtw := ""
        for element in stati_PTW {
            criteriPtw .= "`"ChTstStd`" LIKE '%" . element . "%' OR "
        }
        criteriPtw := RTrim(criteriPtw, " OR")
        
        ; Sostituisci la condizione nella query
        SQL_Create := StrReplace(SQL_Create, "#condizione#", criteriPtw)
        OutputDebug(SQL_Create . "`n")
        ; Esegui la query per creare la nuova tabella
        if !this.db.Exec(SQL_Create)
            throw Error("Error creating new table with PTW: " . this.db.ErrorMsg)
            
        return newTableName
    }

    CreateViewWithPTWColumn(sourceTableName, newViewName, stati_PTW) {
        SQL_View := "
        (
            CREATE VIEW XXnewViewNameXX AS 
            SELECT *,
                CASE 
                    WHEN #condizione# THEN 'PTW'
                    ELSE ''
                END as PTW
            FROM XXsourceTableNameXX;
        )"
        SQL_View := StrReplace(SQL_View, "XXsourceTableNameXX", sourceTableName)
        SQL_View := StrReplace(SQL_View, "XXnewViewNameXX", newViewName)

        ; Costruisci condizione per PTW
        criteriPtw := ""
        for element in stati_PTW {
            criteriPtw .= "`"ChTstStd`" LIKE '%" . element . "%' OR "
        }
        criteriPtw := RTrim(criteriPtw, " OR")
        
        ; Sostituisci la condizione nella query
        SQL_View := StrReplace(SQL_View, "#condizione#", criteriPtw)        
        OutputDebug(SQL_View . "`n")
        ; Esegui la query per creare la nuova tabella
        if !this.db.Exec(SQL_View)
            throw Error("Error creating new view with PTW: " . this.db.ErrorMsg)
            
        return newViewName        
    }

    createPTWPivot(sourceTableName, newTableName) {
/*         SQL_Create_Pivot := "
        (
            CREATE TABLE XXnewTableNameXX AS
            SELECT 
                Ordine,
                COUNT("Op.") as "Totale Op.", 
                SUM(PTW) as "Op. con PTW",
                SUM(POP) as "PTW POP",
                "Stato sistema",
                "St.utente"            
            FROM XXsourceTableNameXX
            GROUP BY Ordine
            ORDER BY Ordine;
        )" */

        SQL_Create_Pivot := "
        (
            CREATE TABLE XXnewTableNameXX AS
            SELECT 
                s.Ordine,
                iw39."Tsto br." as "Testo breve",
                COUNT(s."Op.") as "Totale Op.", 
                SUM(s.PTW) as "Op. con PTW",
                SUM(s.POP) as "PTW POP",
                s."Stato sistema",
                s."St.utente"            
            FROM XXsourceTableNameXX s
            LEFT JOIN IW39 iw39 ON s.Ordine = iw39.Ordine
            GROUP BY s.Ordine
            ORDER BY s.Ordine;
        )"        

        SQL_Create_Pivot := StrReplace(SQL_Create_Pivot, "XXsourceTableNameXX", sourceTableName)
        SQL_Create_Pivot := StrReplace(SQL_Create_Pivot, "XXnewTableNameXX", newTableName)

        if !this.db.Exec(SQL_Create_Pivot)
            throw Error("Error creating PTW pivot: " . this.db.ErrorMsg)
    }

    createPivotOdMsenzaPTW(sourceTableName, newTableName) {
        SQL_Create_Pivot := "
        (
            CREATE TABLE XXnewTableNameXX AS
            SELECT 
                Ordine,
                "Testo breve"
                "Totale Op.",
                "Op. con PTW",
                "Stato sistema",
                "St.utente"
            FROM XXsourceTableNameXX
            WHERE (("Op. con PTW" = 0)
                AND ("Stato sistema" LIKE '%RIL%'))
            ORDER BY Ordine;
        )"

        SQL_Create_Pivot := StrReplace(SQL_Create_Pivot, "XXsourceTableNameXX", sourceTableName)
        SQL_Create_Pivot := StrReplace(SQL_Create_Pivot, "XXnewTableNameXX", newTableName)

        if !this.db.Exec(SQL_Create_Pivot)
            throw Error("Error creating PTW pivot: " . this.db.ErrorMsg)
    }    
    
    getPTWStats(pivotTable) {
        SQL_Stats := "
        (
            SELECT 
                COUNT(Ordine) as OdM_Con_PTW,
                (SELECT COUNT(Ordine) FROM XXpivotTableXX) as Totale_OdM,
                ROUND(CAST(COUNT(Ordine) AS FLOAT) / (SELECT COUNT(Ordine) FROM XXpivotTableXX) * 100, 2) as Percentuale,
                (SELECT COUNT(Ordine) FROM XXpivotTableXX WHERE "PTW POP" > 0) as OdM_Con_PTW_POP
            FROM XXpivotTableXX 
            WHERE "Op. con PTW" > 0;
        )"        

        SQL_Stats := StrReplace(SQL_Stats, "XXpivotTableXX", pivotTable)        
        OutputDebug(SQL_Stats . "`n")
        Result := ""
        if !this.db.GetTable(SQL_Stats, &Result)
            throw Error("Error getting PTW stats: " . this.db.ErrorMsg)
            
        return Result
    }
    
    sanitizeSQLText(text) {
        text := StrReplace(text, '"', "'")
        text := StrReplace(text, "'", "''")
        text := RegExReplace(text, "[;\\]", "")
        text := RegExReplace(text, "[\x00-\x1F\x7F]", "")
        text := RegExReplace(text, "[--/*]", "_")
        return text
    }
    
    close() {
        if !this.db.CloseDB() {
            OutputDebug("Errore nella chiusura del Db")
            throw Error("Error closing database: " . this.db.ErrorMsg)
        }
        else {
            OutputDebug("Db chiuso regolarmente")
        }
    }

    GetOrdersList() {
        ; Prepara la query
        query := "SELECT Ordine FROM XXsourceTableNameXX ORDER BY Ordine"
        query := StrReplace(query, "XXsourceTableNameXX", G_CONSTANTS.TABLE_NAME_ODM_LIST)

        ; Ottieni i dati
        if !this.db.GetTable(query, &data) {
            MsgBox("Errore nel recupero dei dati: " . this.db.ErrorMsg)
            return ""
        }

        ; Costruisci la stringa con gli ordini
        ordersList := ""
        for row in data.Rows {
            ordersList .= row[1] . "`r`n"
        }
        
        ; Rimuove l'ultimo a capo se la stringa non è vuota
        if (ordersList != "")
            ordersList := RTrim(ordersList, "`r`n")
            
        return ordersList
    }

}

class DataParser {
    static parseFile(filePath) {
        try {
            fileContent := FileRead(filePath)
            return DataParser.parseContent(StrSplit(fileContent, "`n", "`r"))
        } catch Error as err {
            throw Error("Error reading file: " . err.Message)
        }
    }
    
    static parseArray(inputArray) {
        return DataParser.parseContent(inputArray)
    }
    
    static parseContent(lines) {
        result := {intestazione: [], record: {}}
        
        ; Filtra le righe valide
        validLines := []
        for line in lines {
            if (line != "" && !RegExMatch(line, "^-+$"))
                validLines.Push(line)
        }
        
        if (validLines.Length < 2)
            throw Error("Malformed data: insufficient valid lines")
            
        ; Processa intestazioni
        headerLine := validLines[1]
        if (!RegExMatch(headerLine, "^\|.*\|$"))
            throw Error("Header format error: missing | delimiters")
            
        headerParts := StrSplit(Trim(headerLine, "|"), "|")
        for part in headerParts
            result.intestazione.Push(Trim(part))
            
        ; Processa record
        mapRecord := Map()
        for i, line in validLines {
            if (i = 1) ; salta la riga di intestazione
                continue
                
            if (!RegExMatch(line, "^\|.*\|$"))
                continue
                
            fields := StrSplit(Trim(line, "|"), "|")
            if (fields.Length != result.intestazione.Length)
                continue
                
            arr := []
            for field in fields
                arr.Push(Trim(field))
                
            mapRecord[i-1] := arr
        }
        
        result.record := mapRecord
        return result
    }

    /**
     * Gestisce la creazione del DB, utilizzando i metodi precedentemente definiti, leggendo i dati da un file
     * @param dB_Path Il percorso del file da utilizzare per creare il DB
     * @param exportFileName Il percorso completo del file da leggere
     * @param stati_PTW gli stati che determinano se un OdM ha un ptw associato 
     * @throws Error Se ci sono problemi nelle operazioni nel DB
     */
    ManageDB_File(dB_Path, exportFileName, stati_PTW) {
       
        try {
            ; Inizializza il database
            dbManager := DBManager(dB_Path)
            
            ; Parsa i dati
            data := DataParser.parseFile(exportFileName)
            
            ; Crea la tabella principale
            dbManager.createTable(data, "IW49", ["Ordine", "Op."])
            
            ; Crea le tabelle derivate e calcola le statistiche
            dbManager.createFilteredTable()
            dbManager.addPTWColumn(stati_PTW)
            dbManager.createPTWPivot()
            
            ; Ottieni e mostra le statistiche
            stats := dbManager.getPTWStats()
            if stats.HasRows {
                row := stats.Rows[1]
                OutputDebug(
                    "Analisi OdM con PTW:`n" .
                    "------------------------`n" .
                    "OdM con PTW: " . row[1] . "`n" .
                    "OdM senza PTW: " . row[2] - row[1] . "`n" . 
                    "Totale OdM: " . row[2] . "`n" .
                    "Percentuale: " . row[3] . "%"
                )
            }
            
        } catch Error as err {
                throw Error("Errore nella scrittura del file: " . err.Message)
        } finally {
            dbManager.close()
        }
    }
}

class DataView {
    /**
     * Popola una ListView esistente con i dati di una tabella
     * @param listView Il controllo ListView da popolare
     * @param tableName Nome della tabella da cui prelevare i dati
     * @param dbManager Istanza del DBManager
     * @throws Error Se ci sono problemi nella query o nell'aggiornamento della ListView
     */
    static PopulateListView(ListView, tableName, dbManager) {
        try {
            ListView.Opt("-Redraw")
            ListView.Opt("-Checked")
            ; Ottieni struttura della tabella
            SQL_columns := "PRAGMA table_info(" . tableName . ");"
            if !dbManager.db.GetTable(SQL_columns, &columns) {
                throw Error("Errore nel recupero della struttura della tabella: " . dbManager.db.ErrorMsg)
            }
            
            ; Cancella il contenuto attuale della C_listView.LV
            ListView.Delete()
            
            ; Cancella e ricrea le colonne
            Loop ListView.GetCount("Column")
                ListView.DeleteCol(1)
                
            ; Aggiungi le colonne
            for row in columns.Rows {
                ListView.InsertCol(A_Index, , row[2])  ; row[2] è il nome della colonna
/*                 ; recupero l'indice della colonna "ChTstStd"
                if (row[2] = "ChTstStd") {
                    index_ChTstStd := A_Index
                } */
            }
            
            ; Ottieni i dati
            SQL_data := "SELECT * FROM " . tableName . ";"
            if !dbManager.db.GetTable(SQL_data, &data) {
                throw Error("Errore nel recupero dei dati: " . dbManager.db.ErrorMsg)
            }
            
            ; Popola la C_listView.LV
            for row in data.Rows {
                rowData := []
                for value in row {
                    rowData.Push(value)
                }
                ListView.Add("Icon-1", rowData*)
            }
            
            ; Adatta la larghezza delle colonne
            loop columns.Rows.Length {
                ListView.ModifyCol(A_Index, "AutoHdr")
            }


            ListView.Opt("+Redraw")

            return data.Rows.Length

        } catch Error as err {
            throw Error("Errore nell'aggiornamento della listView.LV: " . err.Message)
        }
    }

    /* ; Esempio di utilizzo:
    try {
        PopulateListView(this.gui[MainGUI.CTRL_PREFIX . "lvwTable"], "NomeTabella", dbManager)
    } catch Error as err {
        MsgBox("Errore: " . err.Message)
    } */
}
