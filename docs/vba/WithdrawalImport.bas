Attribute VB_Name = "WithdrawalImport"
Option Explicit

Private Const OUT_SHEET As String = "Withdrawal_Output"
Private Const PICK_SHEET As String = "_MonthPick"

Private Type WdrColumns
    Login As Long
    Name As Long
    Amount As Long
    PaymentDate As Long
    TotalBalance As Long
    HeaderRow As Long
    Valid As Boolean
End Type

Private Function IsMonthSheetName(ByVal s As String) As Boolean
    Dim months As Variant
    Dim i As Long
    Dim t As String
    t = LCase$(Trim$(s))
    months = Array("january", "february", "march", "april", "may", "june", _
                   "july", "august", "september", "october", "november", "december")
    For i = LBound(months) To UBound(months)
        If InStr(1, t, CStr(months(i)), vbTextCompare) > 0 Then
            If InStr(t, "20") > 0 Then
                IsMonthSheetName = True
                Exit Function
            End If
        End If
    Next i
End Function

Private Function NormalizeHeader(ByVal s As String) As String
    NormalizeHeader = LCase$(Trim$(Replace$(Replace$(s, Chr$(160), " "), "  ", " ")))
End Function

Private Function FindWithdrawalColumns(ws As Worksheet) As WdrColumns
    Dim r As Long, c As Long, lastCol As Long
    Dim h As String
    Dim m As WdrColumns
    For r = 1 To 25
        lastCol = ws.Cells(r, ws.Columns.Count).End(xlToLeft).Column
        If lastCol < 5 Then GoTo NextR
        m.Login = 0: m.Name = 0: m.Amount = 0: m.PaymentDate = 0: m.TotalBalance = 0
        For c = 1 To lastCol
            h = NormalizeHeader(CStr(ws.Cells(r, c).Value))
            Select Case h
                Case "login": m.Login = c
                Case "name": m.Name = c
                Case "amount": m.Amount = c
                Case "payment date", "paymentdate": m.PaymentDate = c
                Case "total balance", "totalbalance": m.TotalBalance = c
            End Select
        Next c
        If m.Login > 0 And m.Name > 0 And m.Amount > 0 Then
            m.HeaderRow = r
            m.Valid = True
            FindWithdrawalColumns = m
            Exit Function
        End If
NextR:
    Next r
    m.Valid = False
    FindWithdrawalColumns = m
End Function

Private Function IsRowHighlighted(ws As Worksheet, ByVal rowNum As Long, ByVal firstCol As Long, ByVal lastCol As Long) As Boolean
    Dim c As Long
    Dim col As Long
    For c = firstCol To lastCol
        col = ws.Cells(rowNum, c).Interior.ColorIndex
        If col <> xlColorIndexNone And col <> 2 Then
            IsRowHighlighted = True
            Exit Function
        End If
        If ws.Cells(rowNum, c).Interior.Color <> 16777215 And ws.Cells(rowNum, c).Interior.Pattern <> xlNone Then
            If ws.Cells(rowNum, c).Interior.ColorIndex = xlColorIndexNone Then
                ' no fill
            ElseIf ws.Cells(rowNum, c).Interior.Color <> 16777215 Then
                IsRowHighlighted = True
                Exit Function
            End If
        End If
    Next c
End Function

Private Function SafeNum(v As Variant) As Double
    On Error Resume Next
    If IsEmpty(v) Or IsNull(v) Then
        SafeNum = 0
    ElseIf IsNumeric(v) Then
        SafeNum = CDbl(v)
    Else
        Dim s As String
        s = Trim$(CStr(v))
        s = Replace$(s, ".", Application.International(xlDecimalSeparator))
        s = Replace$(s, ",", Application.International(xlDecimalSeparator))
        If IsNumeric(s) Then SafeNum = CDbl(s) Else SafeNum = 0
    End If
    On Error GoTo 0
End Function

Private Function SafeDate(v As Variant) As Variant
    On Error Resume Next
    If IsEmpty(v) Or IsNull(v) Then
        SafeDate = Empty
    ElseIf IsDate(v) Then
        SafeDate = CDate(v)
    Else
        Dim s As String
        s = Trim$(CStr(v))
        If Len(s) > 0 And IsDate(s) Then SafeDate = CDate(s) Else SafeDate = Empty
    End If
    On Error GoTo 0
End Function

Private Function CellText(v As Variant) As String
    If IsEmpty(v) Or IsNull(v) Then
        CellText = ""
    Else
        CellText = Trim$(CStr(v))
    End If
End Function

Private Sub CleanupPickSheet()
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Sheets(PICK_SHEET)
    If Not ws Is Nothing Then
        Application.DisplayAlerts = False
        ws.Delete
        Application.DisplayAlerts = True
    End If
    On Error GoTo 0
End Sub

Private Function PickMonthSheets(wbSrc As Workbook) As Collection
    Dim ws As Worksheet
    Dim names As New Collection
    Dim labels As String
    Dim i As Long
    labels = ""
    i = 0
    For Each ws In wbSrc.Sheets
        If IsMonthSheetName(ws.Name) Then
            i = i + 1
            names.Add ws.Name
            labels = labels & i & ") " & ws.Name & vbCrLf
        End If
    Next ws
    If names.Count = 0 Then
        MsgBox "Nessun foglio mese trovato (es. January 2026).", vbExclamation
        Set PickMonthSheets = Nothing
        Exit Function
    End If
    Dim pick As String
    pick = InputBox( _
        "Fogli disponibili:" & vbCrLf & vbCrLf & labels & vbCrLf & _
        "Inserisci i numeri da importare separati da virgola" & vbCrLf & _
        "(es. 1,2,3 oppure 1-3). Lascia vuoto = tutti.", _
        "Seleziona mesi", "1-" & names.Count)
    If pick = "" Then pick = "1-" & names.Count
    If StrComp(pick, "False", vbTextCompare) = 0 Then
        Set PickMonthSheets = Nothing
        Exit Function
    End If
    Dim result As New Collection
    Dim parts() As String
    Dim p As Variant
    Dim idx As Long
    parts = Split(Replace$(pick, " ", ""), ",")
    For Each p In parts
        If InStr(CStr(p), "-") > 0 Then
            Dim a As Long, b As Long
            a = CLng(Split(CStr(p), "-")(0))
            b = CLng(Split(CStr(p), "-")(1))
            For idx = a To b
                If idx >= 1 And idx <= names.Count Then result.Add names(idx)
            Next idx
        Else
            idx = CLng(p)
            If idx >= 1 And idx <= names.Count Then result.Add names(idx)
        End If
    Next p
    If result.Count = 0 Then
        MsgBox "Nessun mese selezionato.", vbExclamation
        Set PickMonthSheets = Nothing
        Exit Function
    End If
    Set PickMonthSheets = result
End Function

Private Sub WriteOutputSheet(dict As Object)
    Dim wsOut As Worksheet
    On Error Resume Next
    Set wsOut = ThisWorkbook.Sheets(OUT_SHEET)
    On Error GoTo 0
    If wsOut Is Nothing Then
        Set wsOut = ThisWorkbook.Worksheets.Add(After:=ThisWorkbook.Sheets(ThisWorkbook.Sheets.Count))
        wsOut.Name = OUT_SHEET
    End If
    wsOut.Cells.Clear
    wsOut.Cells(1, 1).Value = "LOGIN"
    wsOut.Cells(1, 2).Value = "NAME"
    wsOut.Cells(1, 3).Value = "AMOUNT"
    wsOut.Cells(1, 4).Value = "PAYMENT DATE"
    wsOut.Cells(1, 5).Value = "TOTAL BALANCE"
    wsOut.Rows(1).Font.Bold = True
    Dim keys As Variant
    Dim i As Long, outR As Long
    keys = dict.Keys
    outR = 2
    For i = LBound(keys) To UBound(keys)
        wsOut.Cells(outR, 1).Value = dict(keys(i))("Login")
        wsOut.Cells(outR, 2).Value = keys(i)
        wsOut.Cells(outR, 3).Value = dict(keys(i))("Amount")
        If Not IsEmpty(dict(keys(i))("PayDate")) Then wsOut.Cells(outR, 4).Value = dict(keys(i))("PayDate")
        wsOut.Cells(outR, 5).Value = dict(keys(i))("TotalBal")
        outR = outR + 1
    Next i
    If outR > 2 Then
        wsOut.Range("A2:A" & outR - 1).NumberFormat = "@"
        wsOut.Range("C2:C" & outR - 1).NumberFormat = "#,##0.00"
        wsOut.Range("D2:D" & outR - 1).NumberFormat = "dd/mm/yyyy"
        wsOut.Range("E2:E" & outR - 1).NumberFormat = "#,##0.00"
        wsOut.Range("A1:E" & outR - 1).Sort Key1:=wsOut.Range("B2"), Order1:=xlAscending, Header:=xlYes
    End If
    wsOut.Columns("A:E").AutoFit
    wsOut.Activate
    wsOut.Cells(1, 1).Select
End Sub

Public Sub ImportWithdrawalRequests()
    Dim srcPath As String
    srcPath = Application.GetOpenFilename( _
        FileFilter:="Excel (*.xlsx;*.xlsm;*.xls),*.xlsx;*.xlsm;*.xls", _
        Title:="Seleziona file Withdrawal Request")
    If srcPath = "False" Or srcPath = "" Then Exit Sub
    Dim wbSrc As Workbook
    Application.ScreenUpdating = False
    Application.EnableEvents = False
    On Error GoTo ErrHandler
    Set wbSrc = Workbooks.Open(srcPath, ReadOnly:=True, UpdateLinks:=False)
    Dim picked As Collection
    Set picked = PickMonthSheets(wbSrc)
    If picked Is Nothing Then GoTo CleanExit
    Dim dict As Object
    Set dict = CreateObject("Scripting.Dictionary")
    dict.CompareMode = 1
    Dim sheetName As Variant
    Dim ws As Worksheet
    Dim cols As WdrColumns
    Dim lastRow As Long, r As Long
    Dim firstCol As Long, lastCol As Long
    Dim nameKey As String
    Dim loginVal As String
    Dim amt As Double, bal As Double
    Dim payD As Variant
    Dim rowsUsed As Long, rowsSkipHi As Long, rowsSkipEmpty As Long
    rowsUsed = 0: rowsSkipHi = 0: rowsSkipEmpty = 0
    For Each sheetName In picked
        Set ws = wbSrc.Sheets(CStr(sheetName))
        cols = FindWithdrawalColumns(ws)
        If Not cols.Valid Then
            MsgBox "Intestazioni non trovate nel foglio '" & sheetName & "'.", vbExclamation
            GoTo CleanExit
        End If
        firstCol = Application.WorksheetFunction.Min(cols.Login, cols.Name, cols.Amount)
        lastCol = cols.TotalBalance
        If lastCol = 0 Then lastCol = cols.PaymentDate
        If lastCol = 0 Then lastCol = cols.Amount
        lastRow = ws.Cells(ws.Rows.Count, cols.Name).End(xlUp).Row
        For r = cols.HeaderRow + 1 To lastRow
            nameKey = CellText(ws.Cells(r, cols.Name).Value)
            If nameKey = "" Then
                rowsSkipEmpty = rowsSkipEmpty + 1
                GoTo NextRow
            End If
            If IsRowHighlighted(ws, r, firstCol, lastCol) Then
                rowsSkipHi = rowsSkipHi + 1
                GoTo NextRow
            End If
            loginVal = CellText(ws.Cells(r, cols.Login).Value)
            amt = SafeNum(ws.Cells(r, cols.Amount).Value)
            bal = 0
            If cols.TotalBalance > 0 Then bal = SafeNum(ws.Cells(r, cols.TotalBalance).Value)
            payD = Empty
            If cols.PaymentDate > 0 Then payD = SafeDate(ws.Cells(r, cols.PaymentDate).Value)
            If Not dict.Exists(nameKey) Then
                dict.Add nameKey, CreateObject("Scripting.Dictionary")
                dict(nameKey).Add "Login", loginVal
                dict(nameKey).Add "Amount", amt
                dict(nameKey).Add "TotalBal", bal
                dict(nameKey).Add "PayDate", payD
            Else
                If dict(nameKey)("Login") = "" And loginVal <> "" Then dict(nameKey)("Login") = loginVal
                dict(nameKey)("Amount") = dict(nameKey)("Amount") + amt
                dict(nameKey)("TotalBal") = dict(nameKey)("TotalBal") + bal
                If Not IsEmpty(payD) Then
                    If IsEmpty(dict(nameKey)("PayDate")) Then
                        dict(nameKey)("PayDate") = payD
                    ElseIf CDate(payD) > CDate(dict(nameKey)("PayDate")) Then
                        dict(nameKey)("PayDate") = payD
                    End If
                End If
            End If
            rowsUsed = rowsUsed + 1
NextRow:
        Next r
    Next sheetName
    WriteOutputSheet dict
    MsgBox "Import completato." & vbCrLf & _
           "Nomi in output: " & dict.Count & vbCrLf & _
           "Righe lette (non evidenziate): " & rowsUsed & vbCrLf & _
           "Righe saltate (evidenziate): " & rowsSkipHi & vbCrLf & _
           "Righe saltate (nome vuoto): " & rowsSkipEmpty, vbInformation
CleanExit:
    On Error Resume Next
    If Not wbSrc Is Nothing Then wbSrc.Close SaveChanges:=False
    Application.ScreenUpdating = True
    Application.EnableEvents = True
    Exit Sub
ErrHandler:
    MsgBox "Errore: " & Err.Description, vbCritical
    Resume CleanExit
End Sub
