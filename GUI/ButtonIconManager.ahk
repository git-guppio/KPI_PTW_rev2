#Requires AutoHotkey v2.0

class ButtonIconManager {
    ; Costanti
    
    /*
     * Imposta un'icona su un pulsante
     * @param {Integer} Handle - Handle del pulsante
     * @param {String} File - Percorso del file contenente l'icona
     * @param {Integer} Index - Indice dell'icona nel file (default: 1)
     * @param {String} Options - Opzioni di formattazione
     *                w[n] - Larghezza
     *                h[n] - Altezza
     *                s[n] - Dimensione quadrata (imposta sia width che height)
     *                l[n] - Margine sinistro
     *                t[n] - Margine superiore
     *                r[n] - Margine destro
     *                b[n] - Margine inferiore
     *                a[n] - Allineamento (default: 4)
     * @returns {Integer} ID dell'immagine aggiunta
     */

    static SetIcon(Handle, File, Index := 1, Options := '') {
        RegExMatch(Options, 'i)w\K\d+', &W) ? W := W.0 : W := 16
        RegExMatch(Options, 'i)h\K\d+', &H) ? H := H.0 : H := 16
        RegExMatch(Options, 'i)s\K\d+', &S) ? W := H := S.0 : ''
        RegExMatch(Options, 'i)l\K\d+', &L) ? L := L.0 : L := 0
        RegExMatch(Options, 'i)t\K\d+', &T) ? T := T.0 : T := 0
        RegExMatch(Options, 'i)r\K\d+', &R) ? R := R.0 : R := 0
        RegExMatch(Options, 'i)b\K\d+', &B) ? B := B.0 : B := 0
        RegExMatch(Options, 'i)a\K\d+', &A) ? A := A.0 : A := 4
        W *= A_ScreenDPI / 96, H *= A_ScreenDPI / 96
        button_il := Buffer(20 + A_PtrSize)
        normal_il := DllCall('ImageList_Create', 'Int', W, 'Int', H, 'UInt', 0x21, 'Int', 1, 'Int', 1)
        NumPut('Ptr', normal_il, button_il, 0)			; Width & Height
        NumPut('UInt', L, button_il, 0 + A_PtrSize)		; Left Margin
        NumPut('UInt', T, button_il, 4 + A_PtrSize)		; Top Margin
        NumPut('UInt', R, button_il, 8 + A_PtrSize)		; Right Margin
        NumPut('UInt', B, button_il, 12 + A_PtrSize)	; Bottom Margin
        NumPut('UInt', A, button_il, 16 + A_PtrSize)	; Alignment
        SendMessage(BCM_SETIMAGELIST := 5634, 0, button_il, Handle)
            Return IL_Add(normal_il, File, Index)
    }
}

; Esempio di utilizzo:

/* 
; In una GUI:
MyGui := Gui()
iconSize := 24
ButtonSize := iconSize + 10
btn := MyGui.Add("Button", "w" . ButtonSize . " h" . ButtonSize)
btn2 := MyGui.Add("Button", "w" . ButtonSize . " h" . ButtonSize)
ButtonIconManager.SetIcon(btn, 'shell32.dll',315, 's' . iconSize)
ButtonIconManager.SetIcon(btn2, 'shell32.dll',294, 's' . iconSize)

MyGui.Show()
*/
