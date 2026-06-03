#Requires AutoHotkey v2.0

class ArrayTools {
    /*
     * Verifica se un elemento esiste in un array
     * @param array Array in cui cercare
     * @param element Elemento da cercare
     * @param caseSensitive (opzionale) Se true, la ricerca è case-sensitive. Default: true
     * @returns {Boolean} True se l'elemento è presente, False altrimenti
     */
    static HasElement(array, element, caseSensitive := true) {
        if !IsObject(array)
            return false
            
        if caseSensitive {
            for item in array {
                if (item = element)
                    return true
            }
        } else {
            for item in array {
                if (StrLower(item) = StrLower(element))
                    return true
            }
        }
        return false
    }
    
    /*
     * Restituisce l'indice di un elemento nell'array
     * @param array Array in cui cercare
     * @param element Elemento da cercare
     * @param caseSensitive (opzionale) Se true, la ricerca è case-sensitive. Default: true
     * @returns {Integer} Indice dell'elemento se trovato, 0 se non trovato
     */
    static IndexOf(array, element, caseSensitive := true) {
        if !IsObject(array)
            return 0
            
        if caseSensitive {
            for index, item in array {
                if (item = element)
                    return index
            }
        } else {
            for index, item in array {
                if (StrLower(item) = StrLower(element))
                    return index
            }
        }
        return 0
    }
    
    /*
     * Conta quante volte un elemento appare nell'array
     * @param array Array in cui cercare
     * @param element Elemento da contare
     * @param caseSensitive (opzionale) Se true, la ricerca è case-sensitive. Default: true
     * @returns {Integer} Numero di occorrenze dell'elemento
     */
    static Count(array, element, caseSensitive := true) {
        if !IsObject(array)
            return 0
            
        count := 0
        if caseSensitive {
            for item in array {
                if (item = element)
                    count++
            }
        } else {
            for item in array {
                if (StrLower(item) = StrLower(element))
                    count++
            }
        }
        return count
    }
    
    /*
     * Converte un array in una stringa con elementi separati da punto e virgola
     * @param array Array da convertire in stringa
     * @param delimiter (opzionale) Separatore da usare. Default: ";"
     * @returns {String} Stringa con elementi separati dal delimiter
     */    

    static Join(array, delimiter := ";", trimElement := true) {
        if !IsObject(array)
            return ""
            
        result := ""
        for index, element in array {
            if (index > 1)
                result .= delimiter
            if ((trimElement = true) and (StrLen(element))) {
                result .= trim(element)
            }
            else {
                result .= element
            }
        }
        return result
    }

    ; Metodo: ArrayDifference
    ; Descrizione: Effettua la differenza tra il contenuto di due array
    ; Parametri:
    ;   - param1: array contenente un insieme di elementi
    ;   - param2: array contenente un insieme di elementi (presumibilmente sottoinsieme del primo)
    ; Restituisce:
    ; - un array contenente i valori presenti nel primo array meno gli elementi presenti nel secondo (che è un sottoinsieme del primo)
    ; - un array privo di elementi
    ; Esempio: ArrayDifference(fl_array, array)

    Static ArrayDifference(array1, array2) {
        result := []
        for _, item in array1 {
            if !ArrayTools.HasElement(array2, item) {
                result.Push(item)
            }
        }
        return result
    } 
        
    /**
     * Crea un array a partire dai dati contenuti nella clipboard
     * @param raw 
     *              true --> restituisce un array contenente per ogni elemento una riga del contenuto della clipboard
     *              false --> pulisce il contenuto della clipboard e restituisce per ogni riga un elemento dell'array contenente un array costituito dagli elementi della riga
     */    
    static CreaArrayDaClipboard(raw := true) {
        try {
            ; Legge il contenuto del file
            clipboardContent := A_Clipboard
            ; Divide il contenuto in linee
            lines := StrSplit(clipboardContent, "`n", "`r")
            ; Rileva dinamicamente la riga di intestazione: prima riga con delimitatori |
            ; Compatibile con vecchio formato SAP (intestazione a riga 2)
            ; e nuovo formato SAP (riga titolo + doppio separatore prima dell'intestazione)
            expectedFields := 0
            for line in lines {
                if RegExMatch(line, "^\|.*\|$") {
                    expectedFields := StrSplit(line, "|").Length
                    break
                }
            }
            if (expectedFields = 0) {
                MsgBox("Intestazione non trovata nella clipboard.", "Errore", 4112)
                return false
            }
            ; Inizializza un array per i codici FL
            Arr := [] ; ogni elemento dell'array è un array contenente gli elementi della riga
            ; Estrae i codici paese
            for line in lines {
                if (raw = false) {
                    ; Processa solo righe pipe-delimited (intestazione e dati); ignora separatori, titolo e righe vuote
                    if RegExMatch(line, "^\|.*\|$") {
                        parts := StrSplit(line, "|")
                        if (parts.Length = expectedFields) { ; verifico che tutte le righe siano costituite dallo stesso numero di campi dell'intestazione
                            Arr.Push(parts)
                        }
                        else {
                            MsgBox("Errore nel contenuto della clipBoard.", "Errore", 4112)
                            return false
                        }
                    }
                }
                else {
                    Arr.Push(line)
                }

            }
            return Arr
        } catch Error as err {
            MsgBox("Errore nel contenuto della clipBoard. - " . err.Message, "Errore", 4112)
            return false
        }
    }

    /**
     * Scrive il contenuto di un array in un file
     * @param array L'array da scrivere nel file. Ogni elemento dell'array è costituito da un array contenente gli elementi della riga
     * @param filePath Il percorso completo del file da creare/sovrascrivere
     * @param overwrite (opzionale) Se true sovrascrive il file se esiste, se false genera errore
     * @param raw (opzionale)   true --> considera il contenuto della clipboard come un elemento per ogni riga della clipboard
     *                          false --> considera il contenuto della clipboard come un array di array 
     * @throws Error Se ci sono problemi nella scrittura o validazione
     */
    static WriteArrayToFile(array, filePath, overwrite := true, raw := true) {
        ; Validazione parametri
        if !IsObject(array)
            throw Error("Il primo parametro deve essere un array")
            
        if !array.Length
            throw Error("L'array è vuoto")
            
        if !IsSet(filePath) || filePath = ""
            throw Error("Il percorso del file non può essere vuoto")
            
        ; Controlla se il file esiste e gestisce overwrite
        if FileExist(filePath) {
            if !overwrite
                throw Error("Il file esiste già e overwrite non è permesso")
                
            try {
                FileDelete(filePath)
            } catch Error as err {
                throw Error("Impossibile eliminare il file esistente: " . err.Message)
            }
        }
        
        ; Controlla se la directory esiste
        SplitPath(filePath,, &dir)
        if !DirExist(dir)
            throw Error("La directory di destinazione non esiste: " . dir)
            
        ; Prepara il contenuto
        content := ""
        try {
            for index, line in array {
                if (raw = false) {
                    ; Verifica che l'elemento sia convertibile in stringa
                    if (line.Length) {
                        content .= ArrayTools.Join(line) . "`n"
                    } else {
                        throw Error("Elemento non valido nell'array alla posizione " . index)
                    }
                }
                else {
                    content .= line . "`n"
                }
            }
        } catch Error as err {
            throw Error("Errore nella preparazione del contenuto: " . err.Message)
        }
        
        ; Scrive il file
        try {
            FileAppend(content, filePath, "UTF-8")
        } catch Error as err {
            throw Error("Errore nella scrittura del file: " . err.Message)
        }
        
        return true
        
/*      ; esempio di uso 
        try {
            FileWriter.WriteArrayToFile(myArray, "C:\output.txt", false)  ; non sovrascrive
        } catch Error as err {        
            MsgBox("Errore: " . err.Message, "Errore", 16)
        } */

    }


}