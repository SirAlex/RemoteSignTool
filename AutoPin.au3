$Caption = "Token Logon"

While 1
    Local $hWnd = WinWait($Caption)
    WinActivate($hWnd)
    ControlSetText($hWnd, "", "Edit2", $CmdLine[1])
    Sleep(500)
    ControlClick($hWnd, "", "Button1")
    WinWaitClose($Caption)
Wend