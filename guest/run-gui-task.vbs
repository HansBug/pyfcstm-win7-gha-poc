Option Explicit

Dim shell, command
If WScript.Arguments.Count <> 1 Then
    WScript.Quit 2
End If

Set shell = CreateObject("WScript.Shell")
command = "cmd.exe /c call """ & WScript.Arguments(0) & """"
shell.Run command, 0, True
