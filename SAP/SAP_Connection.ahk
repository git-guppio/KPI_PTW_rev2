#Requires AutoHotkey v2.0
; Libreria: SAP_Connection
; Descrizione: Libreria contenente metodi per gestire una connessione SAP
; Esempio: session := SAPConnection.GetSession()

class SAPConnection {
    static _oSAP := ""
    static connection := ""
    static application := ""
    static session := ""

    static Connect() {
        if (!this.IsConnected()) {
            try {
				if WinExist("ahk_class SAP_FRONTEND_SESSION")
				{
					try
					{
						WinActivate ; Use the window found by WinExist.
						;; Stabilisco una connessione con SAP
						;>>>>>>>>>>>>>>>>>>>>>>>>>>
						this.application := ComObjGet("SAPGUI").GetScriptingEngine  ; Get the Already Running Instance
						this.session := this.application.Activesession
					}
					catch
					{
						;~ SB.SetText("Errore connessione SAP")
						MsgBox("Errore connessione SAP", "Errore", 262144)
						return false
					}
				}
				else
				{
                    try
                        this._oSAP := ComObjGet("SAPGUI")
                    catch
                        {
                            MsgBox("Connessione SAP non attiva", "Errore", 262144)
                            Run '"C:\Program Files (x86)\SAP\FrontEnd\SAPgui\saplogon.exe"'
                            if (WinWaitActive("SAP Logon", , 30)) { ; attendo per 30 secondi
                                this._oSAP := ComObjGet("SAPGUI")
                            }
                            else {
                                MsgBox("Time out SAP Logon", "Time out Error")
                                return false
                            }
                        }
                        this.application := ComObjGet("SAPGUI").GetScriptingEngine  ; Get the Already Running Instance
                        this.connection := this.application.OpenConnection("0116 E4E - R4P - Power Generation", true)
                        if (WinWaitActive("SAP Easy Access", , 30)) { ; attendo per 30 secondi
                            this.session := this.application.Activesession
                            return true
                        }
                        else {
                            MsgBox("Time out SAP Easy Access", "Time out Error")
                            return false
                        }


                        ;~ } else {
                            ;~ ; Altrimenti, usiamo la prima connessione disponibile
                            ;~ this.connection := this.application.Children(0)
                        ;~ }
                        ;~ if (this.connection.Children.Count > 0) {
                            ;~ this.session := this.connection.Children(0)
                            ;~ return true
                        ;~ }
                }
            } catch as err {
                MsgBox("Errore nella connessione a SAP: " err.Message)
                return false
            }
        }
        return true
    }

    static IsConnected() {
        return (this.session != "")
    }

    static Disconnect() {
        this._oSAP := ""
        this.connection := ""
        this.application := ""
        this.session := ""
    }

    static GetSession() {
        if (this.Connect()) {
            return this.session
        }
        return ""
    }
}