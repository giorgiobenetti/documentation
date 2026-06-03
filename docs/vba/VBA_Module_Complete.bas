Option Explicit

Private Const OH_TIME As Integer = 1
Private Const OH_ACCOUNT_ID As Integer = 2
Private Const OH_NAME As Integer = 3
Private Const OH_MARKET As Integer = 5
Private Const OH_CCY As Integer = 6
Private Const OH_PERIOD As Integer = 8
Private Const OH_DEAL_SIZE As Integer = 9
Private Const OH_DEAL_LEVEL As Integer = 10
Private Const OH_CHANNEL As Integer = 13
Private Const OH_DEAL_ID As Integer = 19

Private Const LH_TIME As Integer = 1
Private Const LH_ACCOUNT_ID As Integer = 2
Private Const LH_NAME As Integer = 3
Private Const LH_SUMMARY As Integer = 7
Private Const LH_CCY As Integer = 13
Private Const LH_PNL As Integer = 14
Private Const LH_TRANS_REF As Integer = 5
Private Const LH_DESCRIPTION As Integer = 8

Private Const CP_ACCOUNT_ID As Integer = 1
Private Const CP_NAME As Integer = 2
Private Const CP_MARKET As Integer = 3
Private Const CP_PNL As Integer = 17
Private Const CP_CCY As Integer = 18
Private Const CP_DEAL_ID As Integer = 8

Private Const CM_COLS As Integer = 9
Private Const CM_TIME As Integer = 1
Private Const CM_ACCOUNT As Integer = 2
Private Const CM_NAME As Integer = 3
Private Const CM_TYPE As Integer = 4
Private Const CM_SUMMARY As Integer = 5
Private Const CM_DESC As Integer = 6
Private Const CM_CCY As Integer = 7
Private Const CM_PNL As Integer = 8
Private Const CM_GSHEET As Integer = 9
Private Const CM_META_LABEL As Integer = 11
Private Const CM_META_VALUE As Integer = 12

Function IsCashMovement(summaryVal As String) As Boolean
    Dim s As String: s = LCase$(Trim$(summaryVal))
    IsCashMovement = (InStr(s, "cash") > 0 Or InStr(s, "internal") > 0 Or InStr(s, "inter account") > 0 Or InStr(s, "transfer") > 0)
End Function

Private Function RigaLedgerECash(summaryVal As String, txnType As String, descVal As String) As Boolean
    If IsCashMovement(summaryVal) Then
        RigaLedgerECash = True
        Exit Function
    End If
    Dim t As String: t = UCase$(Trim$(txnType))
    If t = "DEPO" Or t = "WITH" Then
        Dim s As String: s = LCase$(Trim$(summaryVal & " " & descVal))
        RigaLedgerECash = (InStr(s, "cash") > 0 Or InStr(s, "transfer") > 0 Or InStr(s, "internal") > 0 Or InStr(s, "inter account") > 0)
    End If
End Function

Function TipoCashMovement(summaryVal As String, importo As Double, Optional txnType As String = "") As String
    Dim s As String: s = LCase$(Trim$(summaryVal))
    Dim t As String: t = UCase$(Trim$(txnType))
    If InStr(s, "internal") > 0 Or InStr(s, "inter account") > 0 Then
        TipoCashMovement = "Inter Account Transfer"
    ElseIf t = "DEPO" Then
        TipoCashMovement = "Cash In"
    ElseIf t = "WITH" Then
        TipoCashMovement = "Cash Out"
    ElseIf importo >= 0 Then
        TipoCashMovement = "Cash In"
    Else
        TipoCashMovement = "Cash Out"
    End If
End Function

Function IsMT4(channelVal As String) As Boolean
    IsMT4 = (InStr(1, Trim$(channelVal), "MT4", vbTextCompare) > 0)
End Function

Private Function NormalizzaTimeCash(val As Variant) As String
    On Error Resume Next
    If IsEmpty(val) Then
        NormalizzaTimeCash = ""
    ElseIf IsDate(val) Then
        NormalizzaTimeCash = Format$(CDate(val), "yyyy-mm-dd hh:nn:ss")
    Else
        Dim s As String
        s = Trim$(CStr(val))
        If Len(s) > 0 And IsDate(s) Then
            NormalizzaTimeCash = Format$(CDate(s), "yyyy-mm-dd hh:nn:ss")
        Else
            NormalizzaTimeCash = s
        End If
    End If
    On Error GoTo 0
End Function

Private Type LedgerMap
    Time As Long
    AccountId As Long
    Name As Long
    TxnType As Long
    TransRef As Long
    Summary As Long
    Description As Long
    Ccy As Long
    Pnl As Long
    Valid As Boolean
End Type

Private Function IgLedgerMap() As LedgerMap
    Dim m As LedgerMap
    m.Time = LH_TIME
    m.AccountId = LH_ACCOUNT_ID
    m.Name = LH_NAME
    m.TxnType = 4
    m.TransRef = LH_TRANS_REF
    m.Summary = LH_SUMMARY
    m.Description = LH_DESCRIPTION
    m.Ccy = LH_CCY
    m.Pnl = LH_PNL
    m.Valid = True
    IgLedgerMap = m
End Function

Private Function LedgerCellText(ws As Worksheet, ByVal r As Long, ByVal c As Long) As String
    If c <= 0 Then
        LedgerCellText = ""
        Exit Function
    End If
    LedgerCellText = Trim$(CStr(ws.Cells(r, c).Value2))
    If LedgerCellText = "" Then LedgerCellText = Trim$(ws.Cells(r, c).Text)
    If Left$(LedgerCellText, 1) = "'" Then LedgerCellText = Mid$(LedgerCellText, 2)
End Function

Private Function ChiaveCashMovementRow(ByVal accountId As String, ByVal timeVal As Variant, ByVal importo As Double) As String
    ChiaveCashMovementRow = Trim$(accountId) & "|" & NormalizzaTimeCash(timeVal) & "|" & Format$(importo, "0.00########")
End Function

Private Sub FormattaTransRefLedgerText(ws As Worksheet)
    Dim lastR As Long
    lastR = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row
    If lastR >= 2 Then ws.Range(ws.Cells(2, LH_TRANS_REF), ws.Cells(lastR, LH_TRANS_REF)).NumberFormat = "@"
End Sub

Private Const CASH_SUMMARY_MARKER As String = "RIASSUNTO"

Private Sub ScriviRiassuntoColonneKL(ws As Worksheet, ByVal totVers As Double, ByVal totPrel As Double, ByVal nVers As Long, ByVal nPrel As Long, ByVal nTransfer As Long, ByVal saldo As Double)
    ws.Range(ws.Cells(1, CM_META_LABEL), ws.Cells(8, CM_META_VALUE)).ClearContents
    On Error Resume Next
    ws.Range(ws.Cells(1, CM_META_LABEL), ws.Cells(1, CM_META_VALUE)).UnMerge
    On Error GoTo 0
    ws.Range(ws.Cells(1, CM_META_LABEL), ws.Cells(1, CM_META_VALUE)).Merge
    ws.Cells(1, CM_META_LABEL).Value = CASH_SUMMARY_MARKER
    ws.Cells(1, CM_META_LABEL).Font.Bold = True
    ws.Cells(1, CM_META_LABEL).HorizontalAlignment = xlCenter
    ws.Cells(2, CM_META_LABEL).Value = "Totale versamenti"
    ws.Cells(2, CM_META_VALUE).Value = totVers
    ws.Cells(3, CM_META_LABEL).Value = "Totale prelievi"
    ws.Cells(3, CM_META_VALUE).Value = Abs(totPrel)
    ws.Cells(4, CM_META_LABEL).Value = "N° versamenti"
    ws.Cells(4, CM_META_VALUE).Value = nVers
    ws.Cells(5, CM_META_LABEL).Value = "N° prelievi"
    ws.Cells(5, CM_META_VALUE).Value = nPrel
    ws.Cells(6, CM_META_LABEL).Value = "N° transfer interni"
    ws.Cells(6, CM_META_VALUE).Value = nTransfer
    ws.Cells(7, CM_META_LABEL).Value = "Saldo (versamenti - prelievi)"
    ws.Cells(7, CM_META_VALUE).Value = saldo
    ws.Range(ws.Cells(2, CM_META_LABEL), ws.Cells(7, CM_META_LABEL)).Font.Bold = True
    ws.Range(ws.Cells(2, CM_META_VALUE), ws.Cells(3, CM_META_VALUE)).NumberFormat = "[$€-410]#,##0.00"
    ws.Range(ws.Cells(4, CM_META_VALUE), ws.Cells(6, CM_META_VALUE)).NumberFormat = "0"
    ws.Cells(7, CM_META_VALUE).NumberFormat = "[$€-410]#,##0.00"
End Sub

Private Function ColonnaExcelLetter(ws As Worksheet, ByVal colNum As Long) As String
    ColonnaExcelLetter = Split(ws.Cells(1, colNum).Address(True, False), "$")(0)
End Function

Private Sub ScriviInfoCashMovements(ws As Worksheet, wsLedger As Worksheet, ByVal cnt As Long, ByVal dupes As Long, ByVal skipped As Long, cols As LedgerMap)
    ws.Range(ws.Cells(9, CM_META_LABEL), ws.Cells(40, CM_META_VALUE + 2)).ClearContents
    Dim r As Long
    r = 9
    ws.Cells(r, CM_META_LABEL).Value = "Controllo import (ledger)"
    ws.Cells(r, CM_META_LABEL).Font.Bold = True
    r = r + 1
    ws.Cells(r, CM_META_LABEL).Value = "Righe cash"
    ws.Cells(r, CM_META_VALUE).Value = cnt
    r = r + 1
    ws.Cells(r, CM_META_LABEL).Value = "Col. Summary (ledger)"
    ws.Cells(r, CM_META_VALUE).Value = cols.Summary
    r = r + 1
    ws.Cells(r, CM_META_LABEL).Value = "Col. P/L (ledger)"
    ws.Cells(r, CM_META_VALUE).Value = cols.Pnl
    r = r + 1
    ws.Cells(r, CM_META_LABEL).Value = "Col. Trans Ref (ledger)"
    ws.Cells(r, CM_META_VALUE).Value = cols.TransRef
    r = r + 1
    ws.Cells(r, CM_META_LABEL).Value = "Duplicati ignorati"
    ws.Cells(r, CM_META_VALUE).Value = dupes
    r = r + 1
    ws.Cells(r, CM_META_LABEL).Value = "Righe escluse (non cash)"
    ws.Cells(r, CM_META_VALUE).Value = skipped
    r = r + 2
    ws.Cells(r, CM_META_LABEL).Value = "Intestazioni Ledger_History (riga 1)"
    ws.Cells(r, CM_META_LABEL).Font.Bold = True
    r = r + 1
    ws.Cells(r, CM_META_LABEL).Value = "Col"
    ws.Cells(r, CM_META_VALUE).Value = "Intestazione"
    ws.Cells(r, CM_META_LABEL).Font.Bold = True
    ws.Cells(r, CM_META_VALUE).Font.Bold = True
    Dim c As Long
    For c = 1 To 14
        r = r + 1
        ws.Cells(r, CM_META_LABEL).Value = ColonnaExcelLetter(wsLedger, c)
        ws.Cells(r, CM_META_VALUE).Value = LedgerCellText(wsLedger, 1, c)
    Next c
    ws.Columns(CM_META_LABEL).AutoFit
    ws.Columns(CM_META_VALUE).AutoFit
End Sub

Private Function GetRateCached(ByVal ccy As String, wsFX As Worksheet, ByVal tDate As Date, ByRef dct As Object) As Double
    Dim ky As String
    ky = UCase$(Trim$(ccy)) & "|" & Format$(tDate, "yyyymmdd")
    If dct.Exists(ky) Then
        GetRateCached = dct(ky)
    Else
        Dim v As Double
        v = GetSafeRate(Trim$(ccy), wsFX, tDate)
        dct.Add ky, v
        GetRateCached = v
    End If
End Function

Sub Reset_Dati_Direct()
    Dim risp As VbMsgBoxResult
    risp = MsgBox("Sei sicuro di voler cancellare i dati?", vbYesNo + vbCritical, "ATTENZIONE")
    If risp = vbYes Then
        ClearDataSheet "Order_History"
        ClearDataSheet "Ledger_History"
        ClearDataSheet "Client_Position_Summary"
        ClearDataSheet "Cash_Movements"
        GetOrCreateSheet("Report_Daily").UsedRange.Clear
        GetOrCreateSheet("Report_Client").UsedRange.Clear
        GetOrCreateSheet("Report_Today").UsedRange.Clear
        GetOrCreateSheet("Report_Yesterday").UsedRange.Clear
        GetOrCreateSheet("Report_PnL").UsedRange.Clear
        GetOrCreateSheet("Report_Inactive").UsedRange.Clear
        MsgBox "Dati azzerati.", vbInformation
    End If
End Sub

Sub ClearDataSheet(sheetName As String)
    If Not FoglioEsiste(sheetName) Then Exit Sub
    Dim ws As Worksheet: Set ws = ThisWorkbook.Sheets(sheetName)
    Dim lastR As Long: lastR = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row
    If lastR > 1 Then ws.Rows("2:" & lastR).ClearContents
End Sub

Sub AggiornaTassiBCE()
    Dim wsFX As Worksheet: Set wsFX = GetOrCreateSheet("FX_Rates")
    Application.StatusBar = "Download tassi BCE in corso..."
    Application.ScreenUpdating = False
    DownloadTassiPuriBCE wsFX
    Application.StatusBar = False
    Application.ScreenUpdating = True
    MsgBox "Tassi BCE aggiornati con successo!", vbInformation
End Sub

Sub AggiornaCashMovements()
    If Not FoglioEsiste("Ledger_History") Then
        MsgBox "Foglio Ledger_History non trovato.", vbCritical
        Exit Sub
    End If
    Dim wsLedger As Worksheet: Set wsLedger = ThisWorkbook.Sheets("Ledger_History")
    Dim wsCash As Worksheet: Set wsCash = GetOrCreateSheet("Cash_Movements")
    Dim cols As LedgerMap
    cols = IgLedgerMap()
    FormattaTransRefLedgerText wsLedger
    Application.ScreenUpdating = False
    wsCash.Cells.Clear
    wsCash.Cells(1, CM_TIME).Value = "Time"
    wsCash.Cells(1, CM_ACCOUNT).Value = "Account ID"
    wsCash.Cells(1, CM_NAME).Value = "Name"
    wsCash.Cells(1, CM_TYPE).Value = "Transaction Type"
    wsCash.Cells(1, CM_SUMMARY).Value = "Summary"
    wsCash.Cells(1, CM_DESC).Value = "Description"
    wsCash.Cells(1, CM_CCY).Value = "Ccy"
    wsCash.Cells(1, CM_PNL).Value = "Profit/Loss"
    wsCash.Cells(1, CM_GSHEET).Value = "GSheet"
    wsCash.Rows(1).Font.Bold = True
    Dim lastRowL As Long
    lastRowL = wsLedger.Cells(wsLedger.Rows.Count, cols.Time).End(xlUp).Row
    If lastRowL < 2 Then
        Application.ScreenUpdating = True
        MsgBox "Ledger vuoto.", vbExclamation
        Exit Sub
    End If
    Dim dictChiavi As Object: Set dictChiavi = CreateObject("Scripting.Dictionary")
    Dim cnt As Long: cnt = 0
    Dim dupes As Long: dupes = 0
    Dim skipped As Long: skipped = 0
    Dim totVers As Double, totPrel As Double
    Dim nVers As Long, nPrel As Long, nTransfer As Long
    Dim outRow As Long
    outRow = 2
    Dim r As Long
    For r = 2 To lastRowL
        Dim summaryVal As String
        summaryVal = LedgerCellText(wsLedger, r, cols.Summary)
        Dim descVal As String
        descVal = LedgerCellText(wsLedger, r, cols.Description)
        Dim txnType As String
        txnType = LedgerCellText(wsLedger, r, cols.TxnType)
        If Not RigaLedgerECash(summaryVal, txnType, descVal) Then
            skipped = skipped + 1
            GoTo NextL
        End If
        Dim accountId As String
        accountId = LedgerCellText(wsLedger, r, cols.AccountId)
        If accountId = "" Then GoTo NextL
        Dim importo As Double
        importo = CDbl(SafeVal(wsLedger.Cells(r, cols.Pnl).Value2))
        Dim chiave As String
        chiave = ChiaveCashMovementRow(accountId, wsLedger.Cells(r, cols.Time).Value2, importo)
        If dictChiavi.Exists(chiave) Then
            dupes = dupes + 1
            GoTo NextL
        End If
        Dim tipo As String
        tipo = TipoCashMovement(summaryVal, importo, txnType)
        Select Case tipo
            Case "Cash In"
                totVers = totVers + importo
                nVers = nVers + 1
            Case "Cash Out"
                totPrel = totPrel + importo
                nPrel = nPrel + 1
            Case "Inter Account Transfer"
                nTransfer = nTransfer + 1
        End Select
        wsCash.Cells(outRow, CM_TIME).Value = wsLedger.Cells(r, cols.Time).Value2
        wsCash.Cells(outRow, CM_ACCOUNT).Value = accountId
        wsCash.Cells(outRow, CM_NAME).Value = PulisciNomeCliente(LedgerCellText(wsLedger, r, cols.Name))
        wsCash.Cells(outRow, CM_TYPE).Value = tipo
        wsCash.Cells(outRow, CM_SUMMARY).Value = summaryVal
        wsCash.Cells(outRow, CM_DESC).Value = descVal
        wsCash.Cells(outRow, CM_CCY).Value = LedgerCellText(wsLedger, r, cols.Ccy)
        wsCash.Cells(outRow, CM_PNL).Value = importo
        wsCash.Cells(outRow, CM_GSHEET).Value = importo
        dictChiavi.Add chiave, 1
        cnt = cnt + 1
        outRow = outRow + 1
NextL:
    Next r
    If cnt > 0 Then
        With wsCash.Range(wsCash.Cells(2, CM_TIME), wsCash.Cells(1 + cnt, CM_TIME))
            .NumberFormat = "dd/mm/yyyy hh:mm:ss"
        End With
        wsCash.Range(wsCash.Cells(2, CM_PNL), wsCash.Cells(1 + cnt, CM_PNL)).NumberFormat = "[$€-410]#,##0.00"
        wsCash.Range(wsCash.Cells(2, CM_GSHEET), wsCash.Cells(1 + cnt, CM_GSHEET)).NumberFormat = "[$-409]0.00"
        wsCash.Range("A2:I" & (1 + cnt)).Sort Key1:=wsCash.Range("A2"), Order1:=xlAscending, Header:=xlNo
    End If
    Dim saldo As Double
    saldo = totVers + totPrel
    ScriviRiassuntoColonneKL wsCash, totVers, totPrel, nVers, nPrel, nTransfer, saldo
    ScriviInfoCashMovements wsCash, wsLedger, cnt, dupes, skipped, cols
    wsCash.Columns("A:L").AutoFit
    wsCash.Activate
    wsCash.Cells(1, CM_META_LABEL).Select
    Application.ScreenUpdating = True
    MsgBox "Cash Movements aggiornato: " & cnt & " righe. Riassunto in K-L.", vbInformation
End Sub

Sub CalcolaVolumi_Direct_USD()
    Dim wsOrder As Worksheet, wsFX As Worksheet
    Dim wsDaily As Worksheet, wsClient As Worksheet
    Dim wsToday As Worksheet, wsYesterday As Worksheet
    Dim lastRow As Long, i As Long
    Dim dictDaily As Object, dictClient As Object
    Dim dictToday As Object, dictYesterday As Object
    Dim dictActiveAccounts As Object
    Dim rateCache As Object
    Dim mktName As String, baseCurr As String, opDate As Date
    Dim dSize As Double, pPrice As Double, fxRate As Double
    Dim rateBaseBCE As Double, rateUSDBCE As Double, volumeUSD As Double
    Dim accountID As String, clientName As String, periodVal As String
    Dim isBarrier As Boolean
    Dim todayDate As Date, yesterdayDate As Date
    Dim evOld As Boolean
    evOld = Application.EnableEvents
    Application.ScreenUpdating = False
    Application.EnableEvents = False
    Application.Calculation = xlCalculationManual
    Application.StatusBar = "Avvio calcolo..."
    On Error GoTo Cleanup
    If Not FoglioEsiste("Order_History") Then
        MsgBox "Foglio Order_History non trovato.", vbCritical
        GoTo Cleanup
    End If
    Set wsOrder = ThisWorkbook.Sheets("Order_History")
    Set wsFX = GetOrCreateSheet("FX_Rates")
    Set wsDaily = GetOrCreateSheet("Report_Daily")
    Set wsClient = GetOrCreateSheet("Report_Client")
    Set wsToday = GetOrCreateSheet("Report_Today")
    Set wsYesterday = GetOrCreateSheet("Report_Yesterday")
    Set rateCache = CreateObject("Scripting.Dictionary")
    If Not BCE_GiaAggiornato(wsFX) Then
        Application.StatusBar = "Download tassi BCE..."
        DownloadTassiPuriBCE wsFX
    End If
    wsDaily.UsedRange.Clear
    wsClient.UsedRange.Clear
    wsToday.UsedRange.Clear
    wsYesterday.UsedRange.Clear
    todayDate = Date
    yesterdayDate = Date - 1
    lastRow = wsOrder.Cells(wsOrder.Rows.Count, 1).End(xlUp).Row
    wsOrder.Cells(1, 22).Value = "Volume_USD"
    wsOrder.Cells(1, 23).Value = "Calc_DealSize"
    wsOrder.Cells(1, 24).Value = "Calc_DealLevel"
    wsOrder.Cells(1, 25).Value = "Calc_FX_Rate"
    wsOrder.Cells(1, 26).Value = "Calc_BaseCurr"
    wsOrder.Cells(1, 27).Value = "Calc_Note"
    Set dictDaily = CreateObject("Scripting.Dictionary")
    Set dictClient = CreateObject("Scripting.Dictionary")
    Set dictToday = CreateObject("Scripting.Dictionary")
    Set dictYesterday = CreateObject("Scripting.Dictionary")
    Set dictActiveAccounts = CreateObject("Scripting.Dictionary")
    If lastRow < 2 Then GoTo AfterOrderBlock
    Application.StatusBar = "Calcolo volumi - " & lastRow - 1 & " righe..."
    Dim inData As Variant, outData As Variant
    inData = wsOrder.Range(wsOrder.Cells(2, 1), wsOrder.Cells(lastRow, 13)).Value2
    outData = wsOrder.Range(wsOrder.Cells(2, 22), wsOrder.Cells(lastRow, 27)).Value2
    Dim nR As Long: nR = UBound(inData, 1)
    Dim idx As Long
    For idx = 1 To nR
        If idx Mod 1000 = 0 Then Application.StatusBar = "Order History: " & idx & " di " & nR & " righe..."
        i = idx + 1
        If IsEmpty(inData(idx, OH_TIME)) Then GoTo NextOrderIdx
        If Trim$(CStr(inData(idx, OH_TIME))) = "" Then GoTo NextOrderIdx
        mktName = Trim$(CStr(inData(idx, OH_MARKET)))
        periodVal = Trim$(CStr(inData(idx, OH_PERIOD)))
        isBarrier = (InStr(1, mktName, "Barrier", vbTextCompare) > 0)
        If periodVal = "-" Or (periodVal <> "-" And Not isBarrier) Then
            On Error Resume Next
            opDate = CDate(Int(CDbl(inData(idx, OH_TIME))))
            On Error GoTo 0
            accountID = Trim$(CStr(inData(idx, OH_ACCOUNT_ID)))
            clientName = PulisciNomeCliente(CStr(inData(idx, OH_NAME)))
            dSize = Abs(SafeVal(inData(idx, OH_DEAL_SIZE)))
            pPrice = SafeVal(inData(idx, OH_DEAL_LEVEL))
            If InStr(mktName, "/") > 0 Then
                baseCurr = Left$(mktName, 3)
            Else
                baseCurr = Trim$(CStr(inData(idx, OH_CCY)))
            End If
            rateBaseBCE = GetRateCached(baseCurr, wsFX, opDate, rateCache)
            rateUSDBCE = GetRateCached("USD", wsFX, opDate, rateCache)
            fxRate = rateUSDBCE / rateBaseBCE
            Dim nota As String
            Dim isMT4Chan As Boolean
            isMT4Chan = IsMT4(CStr(inData(idx, OH_CHANNEL)))
            If InStr(mktName, "/") > 0 Then
                If isMT4Chan Then
                    volumeUSD = dSize * 100000 * fxRate
                    nota = "FX MT4: DealSize x 100.000 x FXrate"
                Else
                    volumeUSD = dSize * fxRate
                    nota = "FX: DealSize x FXrate"
                End If
            Else
                volumeUSD = (dSize * pPrice) * fxRate
                nota = "Non-FX: DealSize x DealLevel x FXrate"
            End If
            outData(idx, 1) = volumeUSD
            outData(idx, 2) = dSize
            outData(idx, 3) = pPrice
            outData(idx, 4) = fxRate
            outData(idx, 5) = baseCurr
            outData(idx, 6) = nota
            Dim clientKey As String
            clientKey = accountID & "|" & clientName
            dictDaily(opDate) = dictDaily(opDate) + volumeUSD
            dictClient(clientKey) = dictClient(clientKey) + volumeUSD
            If Not dictActiveAccounts.Exists(accountID) Then dictActiveAccounts.Add accountID, clientName
            If opDate = todayDate Then dictToday(clientKey) = dictToday(clientKey) + volumeUSD
            If opDate = yesterdayDate Then dictYesterday(clientKey) = dictYesterday(clientKey) + volumeUSD
        Else
            outData(idx, 1) = 0
            outData(idx, 6) = "ESCLUSO - Barrier Period: " & periodVal
        End If
NextOrderIdx:
    Next idx
    wsOrder.Range(wsOrder.Cells(2, 22), wsOrder.Cells(lastRow, 27)).Value2 = outData
    wsOrder.Range(wsOrder.Cells(2, 22), wsOrder.Cells(lastRow, 22)).NumberFormat = "[$$-409]#,##0.00"
AfterOrderBlock:
    Application.StatusBar = "Scrittura Report Daily..."
    wsDaily.Cells(1, 1).Value = "Data"
    wsDaily.Cells(1, 2).Value = "Volume USD"
    Dim k As Variant, rr As Long: rr = 2
    For Each k In dictDaily.Keys
        wsDaily.Cells(rr, 1).Value = k
        wsDaily.Cells(rr, 2).Value = dictDaily(k)
        wsDaily.Cells(rr, 2).NumberFormat = "[$$-409]#,##0.00"
        rr = rr + 1
    Next k
    If rr > 2 Then
        wsDaily.UsedRange.Sort Key1:=wsDaily.Range("A2"), Order1:=xlAscending, Header:=xlYes
        wsDaily.Range("G4").Value = "Totale Periodo": wsDaily.Range("G4").Font.Bold = True
        wsDaily.Range("H4").Formula = "=SUM(B2:B" & rr - 1 & ")"
        wsDaily.Range("H4").NumberFormat = "[$$-409]#,##0.00": wsDaily.Range("H4").Font.Bold = True
        wsDaily.Range("G5").Value = "Ultimo aggiornamento": wsDaily.Range("G5").Font.Bold = True
        wsDaily.Range("H5").Value = Now()
        wsDaily.Range("H5").NumberFormat = "dd/mm/yyyy hh:mm"
    End If
    Application.StatusBar = "Scrittura Report Client..."
    ScriviReportClienti wsClient, dictClient, "Numero Conto", "Nome Cliente", "Volume USD"
    If wsClient.Range("G4").Value <> "" Then
        wsClient.Range("G5").Value = "Ultimo aggiornamento": wsClient.Range("G5").Font.Bold = True
        wsClient.Range("H5").Value = Now()
        wsClient.Range("H5").NumberFormat = "dd/mm/yyyy hh:mm"
    End If
    Application.StatusBar = "Scrittura Report Today..."
    ScriviReportClienti wsToday, dictToday, "Numero Conto", "Nome Cliente", "Volume USD (Oggi)"
    If wsToday.Range("G4").Value <> "" Then
        wsToday.Range("G5").Value = "Ultimo aggiornamento": wsToday.Range("G5").Font.Bold = True
        wsToday.Range("H5").Value = Now()
        wsToday.Range("H5").NumberFormat = "dd/mm/yyyy hh:mm"
    End If
    Application.StatusBar = "Scrittura Report Yesterday..."
    ScriviReportClienti wsYesterday, dictYesterday, "Numero Conto", "Nome Cliente", "Volume USD (Ieri)"
    Application.StatusBar = "Calcolo P/L..."
    CalcolaReportPnL wsFX, dictClient, dictActiveAccounts
    If FoglioEsiste("Dashboard") Then
        ThisWorkbook.Sheets("Dashboard").Range("A1").Value = "Ultimo aggiornamento: " & Format$(Now(), "dd/mm/yyyy hh:mm")
        ThisWorkbook.Sheets("Dashboard").Range("A1").Font.Bold = True
    End If
    wsDaily.Columns.AutoFit
    wsClient.Columns.AutoFit
    wsToday.Columns.AutoFit
    wsYesterday.Columns.AutoFit
Cleanup:
    Application.StatusBar = False
    Application.Calculation = xlCalculationAutomatic
    Application.ScreenUpdating = True
    Application.EnableEvents = evOld
    MsgBox "Calcolo completato!", vbInformation
End Sub

Sub CalcolaReportPnL(wsFX As Worksheet, dictVolume As Object, dictActiveAccounts As Object)
    Dim wsLedger As Worksheet, wsPosition As Worksheet, wsPnL As Worksheet
    Dim wsInactive As Worksheet
    Dim dictRealised As Object, dictUnrealised As Object
    Dim dictAccNames As Object, dictVolAcc As Object
    Dim rateCache As Object
    Dim lastRow As Long, i As Long
    Dim accountID As String, clientName As String
    Dim pnlVal As Double, ccy As String, pnlEUR As Double
    Dim summaryVal As String
    Set wsLedger = ThisWorkbook.Sheets("Ledger_History")
    Set wsPosition = ThisWorkbook.Sheets("Client_Position_Summary")
    Set wsPnL = GetOrCreateSheet("Report_PnL")
    Set wsInactive = GetOrCreateSheet("Report_Inactive")
    wsPnL.UsedRange.Clear
    wsInactive.UsedRange.Clear
    Set dictRealised = CreateObject("Scripting.Dictionary")
    Set dictUnrealised = CreateObject("Scripting.Dictionary")
    Set dictAccNames = CreateObject("Scripting.Dictionary")
    Set dictVolAcc = CreateObject("Scripting.Dictionary")
    Set rateCache = CreateObject("Scripting.Dictionary")
    Dim ky As Variant, parti() As String
    For Each ky In dictVolume.Keys
        parti = Split(CStr(ky), "|")
        Dim accID As String: accID = parti(0)
        Dim accName As String: accName = parti(1)
        dictVolAcc(accID) = dictVolAcc(accID) + dictVolume(ky)
        If Not dictAccNames.Exists(accID) Then dictAccNames.Add accID, accName
    Next ky
    lastRow = wsLedger.Cells(wsLedger.Rows.Count, 2).End(xlUp).Row
    Application.StatusBar = "P/L: ciclo Ledger - " & lastRow - 1 & " righe..."
    If lastRow >= 2 Then
        Dim ledPnL As Variant
        ledPnL = wsLedger.Range(wsLedger.Cells(2, 1), wsLedger.Cells(lastRow, 14)).Value2
        For i = 1 To UBound(ledPnL, 1)
            accountID = Trim$(CStr(ledPnL(i, LH_ACCOUNT_ID)))
            If accountID = "" Then GoTo NextLedger
            summaryVal = Trim$(CStr(ledPnL(i, LH_SUMMARY)))
            If IsCashMovement(summaryVal) Then GoTo NextLedger
            clientName = PulisciNomeCliente(CStr(ledPnL(i, LH_NAME)))
            pnlVal = SafeVal(ledPnL(i, LH_PNL))
            dictRealised(accountID) = dictRealised(accountID) + pnlVal
            If Not dictAccNames.Exists(accountID) Then dictAccNames.Add accountID, clientName
NextLedger:
        Next i
    End If
    lastRow = wsPosition.Cells(wsPosition.Rows.Count, 1).End(xlUp).Row
    Application.StatusBar = "P/L: ciclo Posizioni - " & lastRow - 1 & " righe..."
    If lastRow >= 2 Then
        Dim posPnL As Variant
        posPnL = wsPosition.Range(wsPosition.Cells(2, 1), wsPosition.Cells(lastRow, 18)).Value2
        For i = 1 To UBound(posPnL, 1)
            accountID = Trim$(CStr(posPnL(i, CP_ACCOUNT_ID)))
            If accountID = "" Then GoTo NextPosition
            clientName = PulisciNomeCliente(CStr(posPnL(i, CP_NAME)))
            pnlVal = SafeVal(posPnL(i, CP_PNL))
            ccy = Trim$(CStr(posPnL(i, CP_CCY)))
            If ccy = "EUR" Or ccy = "" Then
                pnlEUR = pnlVal
            Else
                Dim rateCcy As Double
                rateCcy = GetRateCached(ccy, wsFX, Date, rateCache)
                pnlEUR = pnlVal / rateCcy
            End If
            dictUnrealised(accountID) = dictUnrealised(accountID) + pnlEUR
            If Not dictAccNames.Exists(accountID) Then dictAccNames.Add accountID, clientName
NextPosition:
        Next i
    End If
    Dim dictAll As Object
    Set dictAll = CreateObject("Scripting.Dictionary")
    For Each ky In dictVolAcc.Keys
        If Not dictAll.Exists(ky) Then dictAll.Add ky, 1
    Next ky
    For Each ky In dictRealised.Keys
        If Not dictAll.Exists(ky) Then dictAll.Add ky, 1
    Next ky
    For Each ky In dictUnrealised.Keys
        If Not dictAll.Exists(ky) Then dictAll.Add ky, 1
    Next ky
    With wsPnL
        .Cells(1, 1).Value = "Numero Conto"
        .Cells(1, 2).Value = "Nome Cliente"
        .Cells(1, 3).Value = "Volume USD"
        .Cells(1, 4).Value = "P/L Realizzato (EUR)"
        .Cells(1, 5).Value = "P/L Non Realizzato (EUR)"
        .Cells(1, 6).Value = "P/L Totale (EUR)"
        Dim col As Integer
        For col = 1 To 6
            .Cells(1, col).Font.Bold = True
        Next col
    End With
    Dim r As Long: r = 2
    Dim volUSD As Double, realPnL As Double, unrealPnL As Double, totalPnL As Double
    For Each ky In dictAll.Keys
        volUSD = 0: realPnL = 0: unrealPnL = 0
        If dictVolAcc.Exists(ky) Then volUSD = dictVolAcc(ky)
        If dictRealised.Exists(ky) Then realPnL = dictRealised(ky)
        If dictUnrealised.Exists(ky) Then unrealPnL = dictUnrealised(ky)
        totalPnL = realPnL + unrealPnL
        wsPnL.Cells(r, 1).Value = ky
        wsPnL.Cells(r, 2).Value = dictAccNames(ky)
        wsPnL.Cells(r, 3).Value = volUSD
        wsPnL.Cells(r, 3).NumberFormat = "[$$-409]#,##0.00"
        wsPnL.Cells(r, 4).Value = realPnL
        wsPnL.Cells(r, 4).NumberFormat = "[$€-410]#,##0.00"
        wsPnL.Cells(r, 5).Value = unrealPnL
        wsPnL.Cells(r, 5).NumberFormat = "[$€-410]#,##0.00"
        wsPnL.Cells(r, 6).Value = totalPnL
        wsPnL.Cells(r, 6).NumberFormat = "[$€-410]#,##0.00"
        If totalPnL > 0 Then
            wsPnL.Cells(r, 6).Font.Color = RGB(0, 150, 0)
        ElseIf totalPnL < 0 Then
            wsPnL.Cells(r, 6).Font.Color = RGB(200, 0, 0)
        End If
        r = r + 1
    Next ky
    If r > 2 Then
        wsPnL.UsedRange.Sort Key1:=wsPnL.Range("C2"), Order1:=xlDescending, Header:=xlYes
        wsPnL.Cells(r, 2).Value = "TOTALE": wsPnL.Cells(r, 2).Font.Bold = True
        wsPnL.Cells(r, 3).Formula = "=SUM(C2:C" & r - 1 & ")"
        wsPnL.Cells(r, 3).NumberFormat = "[$$-409]#,##0.00": wsPnL.Cells(r, 3).Font.Bold = True
        wsPnL.Cells(r, 4).Formula = "=SUM(D2:D" & r - 1 & ")"
        wsPnL.Cells(r, 4).NumberFormat = "[$€-410]#,##0.00": wsPnL.Cells(r, 4).Font.Bold = True
        wsPnL.Cells(r, 5).Formula = "=SUM(E2:E" & r - 1 & ")"
        wsPnL.Cells(r, 5).NumberFormat = "[$€-410]#,##0.00": wsPnL.Cells(r, 5).Font.Bold = True
        wsPnL.Cells(r, 6).Formula = "=SUM(F2:F" & r - 1 & ")"
        wsPnL.Cells(r, 6).NumberFormat = "[$€-410]#,##0.00": wsPnL.Cells(r, 6).Font.Bold = True
        wsPnL.Range("H4").Value = "Totale Volume": wsPnL.Range("H4").Font.Bold = True
        wsPnL.Range("I4").Formula = "=SUM(C2:C" & r - 1 & ")"
        wsPnL.Range("I4").NumberFormat = "[$$-409]#,##0.00": wsPnL.Range("I4").Font.Bold = True
        wsPnL.Range("H5").Value = "Totale P/L Realizzato": wsPnL.Range("H5").Font.Bold = True
        wsPnL.Range("I5").Formula = "=SUM(D2:D" & r - 1 & ")"
        wsPnL.Range("I5").NumberFormat = "[$€-410]#,##0.00": wsPnL.Range("I5").Font.Bold = True
        wsPnL.Range("H6").Value = "Totale P/L Non Realizzato": wsPnL.Range("H6").Font.Bold = True
        wsPnL.Range("I6").Formula = "=SUM(E2:E" & r - 1 & ")"
        wsPnL.Range("I6").NumberFormat = "[$€-410]#,##0.00": wsPnL.Range("I6").Font.Bold = True
        wsPnL.Range("H7").Value = "Totale P/L Complessivo": wsPnL.Range("H7").Font.Bold = True
        wsPnL.Range("I7").Formula = "=SUM(F2:F" & r - 1 & ")"
        wsPnL.Range("I7").NumberFormat = "[$€-410]#,##0.00": wsPnL.Range("I7").Font.Bold = True
        wsPnL.Range("H8").Value = "Ultimo aggiornamento": wsPnL.Range("H8").Font.Bold = True
        wsPnL.Range("I8").Value = Now()
        wsPnL.Range("I8").NumberFormat = "dd/mm/yyyy hh:mm"
    End If
    wsPnL.Columns.AutoFit
    With wsInactive
        .Cells(1, 1).Value = "Numero Conto": .Cells(1, 1).Font.Bold = True
        .Cells(1, 2).Value = "Nome Cliente": .Cells(1, 2).Font.Bold = True
        .Cells(1, 3).Value = "P/L Non Realizzato (EUR)": .Cells(1, 3).Font.Bold = True
    End With
    Dim rI As Long: rI = 2
    For Each ky In dictUnrealised.Keys
        If Not dictActiveAccounts.Exists(ky) Then
            wsInactive.Cells(rI, 1).Value = ky
            wsInactive.Cells(rI, 2).Value = dictAccNames(ky)
            wsInactive.Cells(rI, 3).Value = dictUnrealised(ky)
            wsInactive.Cells(rI, 3).NumberFormat = "[$€-410]#,##0.00"
            If dictUnrealised(ky) > 0 Then
                wsInactive.Cells(rI, 3).Font.Color = RGB(0, 150, 0)
            ElseIf dictUnrealised(ky) < 0 Then
                wsInactive.Cells(rI, 3).Font.Color = RGB(200, 0, 0)
            End If
            rI = rI + 1
        End If
    Next ky
    If rI > 2 Then
        wsInactive.UsedRange.Sort Key1:=wsInactive.Range("C2"), Order1:=xlDescending, Header:=xlYes
        wsInactive.Cells(rI, 2).Value = "TOTALE": wsInactive.Cells(rI, 2).Font.Bold = True
        wsInactive.Cells(rI, 3).Formula = "=SUM(C2:C" & rI - 1 & ")"
        wsInactive.Cells(rI, 3).NumberFormat = "[$€-410]#,##0.00": wsInactive.Cells(rI, 3).Font.Bold = True
        wsInactive.Range("E4").Value = "Totale P/L Non Realizzato": wsInactive.Range("E4").Font.Bold = True
        wsInactive.Range("F4").Formula = "=SUM(C2:C" & rI - 1 & ")"
        wsInactive.Range("F4").NumberFormat = "[$€-410]#,##0.00": wsInactive.Range("F4").Font.Bold = True
        wsInactive.Range("E5").Value = "Numero Clienti Inattivi": wsInactive.Range("E5").Font.Bold = True
        wsInactive.Range("F5").Value = rI - 2: wsInactive.Range("F5").Font.Bold = True
        wsInactive.Range("E6").Value = "Ultimo aggiornamento": wsInactive.Range("E6").Font.Bold = True
        wsInactive.Range("F6").Value = Now()
        wsInactive.Range("F6").NumberFormat = "dd/mm/yyyy hh:mm"
    End If
    wsInactive.Columns.AutoFit
End Sub

Sub ScriviReportClienti(ws As Worksheet, dict As Object, col1 As String, col2 As String, col3 As String)
    ws.Cells(1, 1).Value = col1
    ws.Cells(1, 2).Value = col2
    ws.Cells(1, 3).Value = col3
    Dim r As Long: r = 2
    Dim k As Variant, parti() As String
    For Each k In dict.Keys
        parti = Split(CStr(k), "|")
        ws.Cells(r, 1).Value = parti(0)
        ws.Cells(r, 2).Value = parti(1)
        ws.Cells(r, 3).Value = dict(k)
        ws.Cells(r, 3).NumberFormat = "[$$-409]#,##0.00"
        r = r + 1
    Next k
    If r > 2 Then
        ws.UsedRange.Sort Key1:=ws.Range("C2"), Order1:=xlDescending, Header:=xlYes
        ws.Cells(r, 2).Value = "TOTALE": ws.Cells(r, 2).Font.Bold = True
        ws.Cells(r, 3).Formula = "=SUM(C2:C" & r - 1 & ")"
        ws.Cells(r, 3).NumberFormat = "[$$-409]#,##0.00": ws.Cells(r, 3).Font.Bold = True
        ws.Range("G4").Value = "Totale Periodo": ws.Range("G4").Font.Bold = True
        ws.Range("H4").Formula = "=SUM(C2:C" & r - 1 & ")"
        ws.Range("H4").NumberFormat = "[$$-409]#,##0.00": ws.Range("H4").Font.Bold = True
    End If
End Sub

Sub ImportaCSV()
    Dim risp As VbMsgBoxResult
    risp = MsgBox("ATTENZIONE: questa funzione SOSTITUISCE i dati esistenti." & vbCrLf & _
                  "Per AGGIUNGERE file usa i pulsanti 'Aggiungi'." & vbCrLf & vbCrLf & _
                  "Verranno richiesti 3 file in sequenza:" & vbCrLf & _
                  "1. Order History (reportshistory...csv)" & vbCrLf & _
                  "2. Ledger (ledgerreport...csv)" & vbCrLf & _
                  "3. Posizioni Aperte (openpositions...csv)" & vbCrLf & vbCrLf & _
                  "Continuare?", vbYesNo + vbInformation, "Importazione CSV")
    If risp = vbNo Then Exit Sub
    Dim successCount As Integer: successCount = 0
    If ImportaSingoloCSV("Order_History", "Seleziona Order History", "reportshistory") Then successCount = successCount + 1
    If ImportaSingoloCSV("Ledger_History", "Seleziona Ledger", "ledgerreport") Then successCount = successCount + 1
    If ImportaSingoloCSV("Client_Position_Summary", "Seleziona Posizioni Aperte", "openpositions") Then successCount = successCount + 1
    Select Case successCount
        Case 3: MsgBox "Tutti e 3 i file importati con successo.", vbInformation
        Case 0: MsgBox "Nessun file importato.", vbExclamation
        Case Else: MsgBox successCount & " file su 3 importati.", vbExclamation
    End Select
End Sub

Sub AggiungiOrderHistory()
    AggiungiFileMultipli "Order_History", "reportshistory", "Seleziona file Order History da aggiungere", OH_DEAL_ID, OH_TIME, True
End Sub

Sub AggiungiLedger()
    AggiungiFileMultipli "Ledger_History", "ledgerreport", "Seleziona file Ledger da aggiungere", LH_TRANS_REF, LH_TIME, True
End Sub

Sub AggiungiPosizioni()
    Dim risp As VbMsgBoxResult
    risp = MsgBox("Le posizioni aperte sono uno snapshot." & vbCrLf & _
                  "Il file selezionato SOSTITUIRA' i dati esistenti." & vbCrLf & vbCrLf & _
                  "Continuare?", vbYesNo + vbInformation, "Importa Posizioni")
    If risp = vbNo Then Exit Sub
    ImportaSingoloCSV "Client_Position_Summary", "Seleziona file Posizioni Aperte", "openpositions"
End Sub

Sub AggiungiFileMultipli(nomeSheet As String, filtroNome As String, titolo As String, colChiave As Integer, colData As Integer, riordina As Boolean)
    Dim filePaths As Variant
    filePaths = Application.GetOpenFilename(FileFilter:="CSV Files (*.csv),*.csv", Title:=titolo, MultiSelect:=True)
    If Not IsArray(filePaths) Then
        MsgBox "Nessun file selezionato.", vbExclamation
        Exit Sub
    End If
    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual
    Application.StatusBar = "Aggiunta file in corso..."
    Dim wsTarget As Worksheet: Set wsTarget = GetOrCreateSheet(nomeSheet)
    Dim lastRowExist As Long
    lastRowExist = wsTarget.Cells(wsTarget.Rows.Count, 1).End(xlUp).Row
    Dim dictChiavi As Object: Set dictChiavi = CreateObject("Scripting.Dictionary")
    If lastRowExist > 1 Then
        Dim dataExist As Variant
        dataExist = wsTarget.Range(wsTarget.Cells(2, 1), wsTarget.Cells(lastRowExist, 21)).Value2
        Dim ex As Long
        For ex = 1 To UBound(dataExist, 1)
            Dim chiaveEx As String
            chiaveEx = Trim$(CStr(dataExist(ex, colChiave))) & "|" & Trim$(CStr(dataExist(ex, colData)))
            If chiaveEx <> "|" Then dictChiavi(chiaveEx) = 1
        Next ex
    End If
    Dim f As Integer
    Dim totalAdded As Long: totalAdded = 0
    Dim totalDupes As Long: totalDupes = 0
    For f = 1 To UBound(filePaths)
        Dim filePathStr As String: filePathStr = CStr(filePaths(f))
        Application.StatusBar = "Elaborazione file " & f & " di " & UBound(filePaths) & "..."
        Dim wsTemp As Worksheet: Set wsTemp = GetOrCreateSheet("_TempImport_")
        wsTemp.UsedRange.Clear
        Dim qt As QueryTable
        For Each qt In wsTemp.QueryTables
            qt.Delete
        Next qt
        Dim qtNew As QueryTable
        Set qtNew = wsTemp.QueryTables.Add(Connection:="TEXT;" & filePathStr, Destination:=wsTemp.Range("A1"))
        With qtNew
            .TextFileParseType = xlDelimited
            .TextFileCommaDelimiter = True
            .TextFileSemicolonDelimiter = False
            .TextFileTabDelimiter = False
            .TextFileSpaceDelimiter = False
            .TextFileConsecutiveDelimiter = False
            .TextFileTextQualifier = xlTextQualifierDoubleQuote
            .TextFileStartRow = 1
            .TextFileColumnDataTypes = Array(1)
            .AdjustColumnWidth = False
            .RefreshStyle = xlOverwriteCells
            .SaveData = True
            .Refresh BackgroundQuery:=False
        End With
        qtNew.Delete
        PulisciNumericiCSV wsTemp, filePathStr
        Dim lastRowTemp As Long
        lastRowTemp = wsTemp.Cells(wsTemp.Rows.Count, 1).End(xlUp).Row
        If lastRowTemp < 2 Then GoTo NextFile
        Dim dataTemp As Variant
        dataTemp = wsTemp.Range(wsTemp.Cells(2, 1), wsTemp.Cells(lastRowTemp, 21)).Value2
        If lastRowExist < 2 Then
            wsTarget.Rows(1).Value = wsTemp.Rows(1).Value
            lastRowExist = 1
        End If
        Dim newRows() As Variant
        ReDim newRows(1 To UBound(dataTemp, 1), 1 To UBound(dataTemp, 2))
        Dim newCount As Long: newCount = 0
        Dim t As Long
        For t = 1 To UBound(dataTemp, 1)
            Dim chiaveNew As String
            chiaveNew = Trim$(CStr(dataTemp(t, colChiave))) & "|" & Trim$(CStr(dataTemp(t, colData)))
            If chiaveNew = "|" Then GoTo NextTempRow
            If Not dictChiavi.Exists(chiaveNew) Then
                newCount = newCount + 1
                Dim col As Integer
                For col = 1 To UBound(dataTemp, 2)
                    newRows(newCount, col) = dataTemp(t, col)
                Next col
                dictChiavi(chiaveNew) = 1
                totalAdded = totalAdded + 1
            Else
                totalDupes = totalDupes + 1
            End If
NextTempRow:
        Next t
        If newCount > 0 Then
            Dim startRow As Long: startRow = lastRowExist + 1
            Dim sliceOut() As Variant
            ReDim sliceOut(1 To newCount, 1 To UBound(dataTemp, 2))
            Dim uu As Long, c2 As Integer
            For uu = 1 To newCount
                For c2 = 1 To UBound(dataTemp, 2)
                    sliceOut(uu, c2) = newRows(uu, c2)
                Next c2
            Next uu
            wsTarget.Range(wsTarget.Cells(startRow, 1), wsTarget.Cells(startRow + newCount - 1, UBound(dataTemp, 2))).Value2 = sliceOut
            lastRowExist = lastRowExist + newCount
        End If
NextFile:
    Next f
    Application.DisplayAlerts = False
    If FoglioEsiste("_TempImport_") Then ThisWorkbook.Sheets("_TempImport_").Delete
    Application.DisplayAlerts = True
    If riordina And lastRowExist > 2 Then
        wsTarget.Range(wsTarget.Cells(1, 1), wsTarget.Cells(lastRowExist, 21)).Sort Key1:=wsTarget.Cells(2, colData), Order1:=xlAscending, Header:=xlYes
    End If
    If nomeSheet = "Ledger_History" Then FormattaTransRefLedgerText wsTarget
    wsTarget.Columns.AutoFit
    Application.StatusBar = False
    Application.Calculation = xlCalculationAutomatic
    Application.ScreenUpdating = True
    If FoglioEsiste("Dashboard") Then ThisWorkbook.Sheets("Dashboard").Activate
    MsgBox "Operazione completata!" & vbCrLf & vbCrLf & "Righe aggiunte: " & totalAdded & vbCrLf & "Duplicati ignorati: " & totalDupes, vbInformation
End Sub

Function ImportaSingoloCSV(nomeSheet As String, titolo As String, filtroNome As String) As Boolean
    ImportaSingoloCSV = False
    Dim filePath As String
    filePath = Application.GetOpenFilename(FileFilter:="CSV Files (*.csv),*.csv", Title:=titolo, MultiSelect:=False)
    If filePath = "False" Or filePath = "" Then
        MsgBox "Importazione di '" & nomeSheet & "' annullata.", vbExclamation
        Exit Function
    End If
    Dim nomeFile As String
    nomeFile = LCase$(Mid$(filePath, InStrRev(filePath, "\") + 1))
    If InStr(1, nomeFile, LCase$(filtroNome), vbTextCompare) = 0 Then
        Dim risp As VbMsgBoxResult
        risp = MsgBox("Il file non sembra essere un '" & filtroNome & "'." & vbCrLf & "Vuoi importarlo comunque?", vbYesNo + vbExclamation)
        If risp = vbNo Then Exit Function
    End If
    Dim wsTarget As Worksheet: Set wsTarget = GetOrCreateSheet(nomeSheet)
    wsTarget.UsedRange.Clear
    Dim qt As QueryTable
    For Each qt In wsTarget.QueryTables: qt.Delete: Next qt
    Dim qtNew As QueryTable
    Set qtNew = wsTarget.QueryTables.Add(Connection:="TEXT;" & filePath, Destination:=wsTarget.Range("A1"))
    With qtNew
        .TextFileParseType = xlDelimited
        .TextFileCommaDelimiter = True
        .TextFileSemicolonDelimiter = False
        .TextFileTabDelimiter = False
        .TextFileSpaceDelimiter = False
        .TextFileConsecutiveDelimiter = False
        .TextFileTextQualifier = xlTextQualifierDoubleQuote
        .TextFileStartRow = 1
        .TextFileColumnDataTypes = Array(1)
        .AdjustColumnWidth = True
        .RefreshStyle = xlOverwriteCells
        .SaveData = True
        .Refresh BackgroundQuery:=False
    End With
    qtNew.Delete
    PulisciNumericiCSV wsTarget, filePath
    If nomeSheet = "Ledger_History" Then FormattaTransRefLedgerText wsTarget
    wsTarget.Columns.AutoFit
    If FoglioEsiste("Dashboard") Then ThisWorkbook.Sheets("Dashboard").Activate
    ImportaSingoloCSV = True
End Function

Sub PulisciNumericiCSV(wsTarget As Worksheet, ByVal filePath As String)
    Application.StatusBar = "Pulizia valori numerici..."
    Dim fileNum As Integer: fileNum = FreeFile
    Open filePath For Input As #fileNum
    Dim headerLine As String
    Line Input #fileNum, headerLine
    Dim rr As Long: rr = 2
    Dim dataLine As String
    Do While Not EOF(fileNum)
        Line Input #fileNum, dataLine
        If Trim$(dataLine) = "" Then GoTo NextLine
        Dim fields() As String
        fields = SplitCSVLine(dataLine)
        Dim c As Integer
        For c = 0 To UBound(fields)
            If wsTarget.Name = "Ledger_History" And c + 1 = LH_TRANS_REF Then GoTo NextCol
            Dim cellVal As String: cellVal = Trim$(fields(c))
            If cellVal <> "" And cellVal <> "-" Then
                Dim converted As String
                converted = Replace$(cellVal, ".", ",")
                If IsNumeric(converted) Then
                    Dim numVal As Double: numVal = CDbl(converted)
                    If wsTarget.Cells(rr, c + 1).Value2 <> numVal Then wsTarget.Cells(rr, c + 1).Value2 = numVal
                End If
            End If
NextCol:
        Next c
        rr = rr + 1
        If rr Mod 1000 = 0 Then Application.StatusBar = "Pulizia numerici: riga " & rr & "..."
NextLine:
    Loop
    Close #fileNum
End Sub

Function SplitCSVLine(ByVal line As String) As String()
    Dim fields() As String
    Dim fieldCount As Integer: fieldCount = 0
    Dim inQuotes As Boolean: inQuotes = False
    Dim currentField As String: currentField = ""
    Dim ii As Integer
    ReDim fields(0)
    For ii = 1 To Len(line)
        Dim ch As String: ch = Mid$(line, ii, 1)
        If ch = """" Then
            inQuotes = Not inQuotes
        ElseIf ch = "," And Not inQuotes Then
            ReDim Preserve fields(fieldCount)
            fields(fieldCount) = currentField
            fieldCount = fieldCount + 1
            currentField = ""
        Else
            currentField = currentField & ch
        End If
    Next ii
    ReDim Preserve fields(fieldCount)
    fields(fieldCount) = currentField
    SplitCSVLine = fields
End Function

Function BCE_GiaAggiornato(wsFX As Worksheet) As Boolean
    BCE_GiaAggiornato = False
    If wsFX.Cells(2, 1).Value2 = "" Then Exit Function
    On Error Resume Next
    Dim dataFX As Date: dataFX = CDate(wsFX.Cells(2, 1).Value2)
    On Error GoTo 0
    BCE_GiaAggiornato = (dataFX = Date Or dataFX = Date - 1)
End Function

Sub DebugVolumeCliente()
    Dim accountTarget As String
    accountTarget = InputBox("Inserisci il numero di conto da analizzare:", "Debug Volume Cliente")
    If accountTarget = "" Then Exit Sub
    Dim wsOrder As Worksheet: Set wsOrder = ThisWorkbook.Sheets("Order_History")
    Dim wsFX As Worksheet: Set wsFX = ThisWorkbook.Sheets("FX_Rates")
    Dim wsDebug As Worksheet: Set wsDebug = GetOrCreateSheet("Debug_Cliente")
    wsDebug.UsedRange.Clear
    wsDebug.Cells(1, 1).Value = "Riga"
    wsDebug.Cells(1, 2).Value = "Data"
    wsDebug.Cells(1, 3).Value = "Market Name"
    wsDebug.Cells(1, 4).Value = "Currency"
    wsDebug.Cells(1, 5).Value = "Period"
    wsDebug.Cells(1, 6).Value = "Deal Size"
    wsDebug.Cells(1, 7).Value = "Deal Level"
    wsDebug.Cells(1, 8).Value = "Base Curr"
    wsDebug.Cells(1, 9).Value = "Rate Base"
    wsDebug.Cells(1, 10).Value = "Rate USD"
    wsDebug.Cells(1, 11).Value = "FX Rate"
    wsDebug.Cells(1, 12).Value = "Volume USD"
    wsDebug.Cells(1, 13).Value = "Note"
    wsDebug.Rows(1).Font.Bold = True
    Dim lastRow As Long: lastRow = wsOrder.Cells(wsOrder.Rows.Count, 1).End(xlUp).Row
    Dim ii As Long, r As Long: r = 2
    Dim totaleVolume As Double: totaleVolume = 0
    Dim todayDate As Date: todayDate = Date
    Dim contatoreOggi As Long: contatoreOggi = 0
    Dim rateCache As Object: Set rateCache = CreateObject("Scripting.Dictionary")
    For ii = 2 To lastRow
        If Trim$(CStr(wsOrder.Cells(ii, OH_ACCOUNT_ID).Value2)) <> accountTarget Then GoTo NextDebugRow
        If wsOrder.Cells(ii, OH_TIME).Value2 = "" Then GoTo NextDebugRow
        Dim opDate As Date: opDate = CDate(Int(CDbl(wsOrder.Cells(ii, OH_TIME).Value2)))
        Dim mktO As String: mktO = Trim$(CStr(wsOrder.Cells(ii, OH_MARKET).Value2))
        Dim periodO As String: periodO = Trim$(CStr(wsOrder.Cells(ii, OH_PERIOD).Value2))
        Dim dSize As Double: dSize = Abs(SafeVal(wsOrder.Cells(ii, OH_DEAL_SIZE).Value2))
        Dim pPrice As Double: pPrice = SafeVal(wsOrder.Cells(ii, OH_DEAL_LEVEL).Value2)
        Dim currO As String: currO = Trim$(CStr(wsOrder.Cells(ii, OH_CCY).Value2))
        Dim isBarrier As Boolean: isBarrier = (InStr(1, mktO, "Barrier", vbTextCompare) > 0)
        Dim isMT4Debug As Boolean: isMT4Debug = IsMT4(CStr(wsOrder.Cells(ii, OH_CHANNEL).Value2))
        Dim nota As String: nota = ""
        Dim volUSD As Double: volUSD = 0
        Dim baseCurr As String: baseCurr = ""
        Dim rateBase As Double: rateBase = 0
        Dim rateUSD As Double: rateUSD = 0
        Dim fxRate As Double: fxRate = 0
        If periodO = "-" Or (periodO <> "-" And Not isBarrier) Then
            If InStr(mktO, "/") > 0 Then
                baseCurr = Left$(mktO, 3)
            Else
                baseCurr = currO
            End If
            rateBase = GetRateCached(baseCurr, wsFX, opDate, rateCache)
            rateUSD = GetRateCached("USD", wsFX, opDate, rateCache)
            fxRate = rateUSD / rateBase
            If InStr(mktO, "/") > 0 Then
                If isMT4Debug Then
                    volUSD = dSize * 100000 * fxRate
                    nota = "FX MT4: DealSize x 100.000 x FXrate"
                Else
                    volUSD = dSize * fxRate
                    nota = "FX: DealSize x FXrate"
                End If
            Else
                volUSD = (dSize * pPrice) * fxRate
                nota = "Non-FX: DealSize x DealLevel x FXrate"
            End If
            totaleVolume = totaleVolume + volUSD
            If opDate = todayDate Then contatoreOggi = contatoreOggi + 1
        Else
            nota = "ESCLUSO - Barrier Period: " & periodO
        End If
        wsDebug.Cells(r, 1).Value2 = ii
        wsDebug.Cells(r, 2).Value2 = opDate
        wsDebug.Cells(r, 2).NumberFormat = "dd/mm/yyyy"
        wsDebug.Cells(r, 3).Value2 = mktO
        wsDebug.Cells(r, 4).Value2 = currO
        wsDebug.Cells(r, 5).Value2 = periodO
        wsDebug.Cells(r, 6).Value2 = dSize
        wsDebug.Cells(r, 7).Value2 = pPrice
        wsDebug.Cells(r, 8).Value2 = baseCurr
        wsDebug.Cells(r, 9).Value2 = rateBase
        wsDebug.Cells(r, 10).Value2 = rateUSD
        wsDebug.Cells(r, 11).Value2 = fxRate
        wsDebug.Cells(r, 12).Value2 = volUSD
        wsDebug.Cells(r, 12).NumberFormat = "[$$-409]#,##0.00"
        wsDebug.Cells(r, 13).Value2 = nota
        If volUSD > 1000000 Then
            wsDebug.Rows(r).Interior.Color = RGB(255, 200, 200)
        ElseIf opDate = todayDate Then
            wsDebug.Rows(r).Interior.Color = RGB(200, 230, 255)
        End If
        r = r + 1
NextDebugRow:
    Next ii
    If r > 2 Then
        wsDebug.Cells(r, 11).Value = "TOTALE": wsDebug.Cells(r, 11).Font.Bold = True
        wsDebug.Cells(r, 12).Formula = "=SUM(L2:L" & r - 1 & ")"
        wsDebug.Cells(r, 12).NumberFormat = "[$$-409]#,##0.00": wsDebug.Cells(r, 12).Font.Bold = True
        wsDebug.Range("P2").Value = "Account": wsDebug.Range("Q2").Value = accountTarget
        wsDebug.Range("P3").Value = "Totale operazioni": wsDebug.Range("Q3").Value = r - 2
        wsDebug.Range("P4").Value = "Operazioni oggi": wsDebug.Range("Q4").Value = contatoreOggi
        wsDebug.Range("P5").Value = "Volume totale USD"
        wsDebug.Range("Q5").Value = totaleVolume
        wsDebug.Range("Q5").NumberFormat = "[$$-409]#,##0.00": wsDebug.Range("Q5").Font.Bold = True
        wsDebug.Range("P6").Value = "Righe > $1M"
        wsDebug.Range("Q6").Formula = "=COUNTIF(L2:L" & r - 1 & ","">1000000"")"
        wsDebug.Range("Q6").Font.Color = RGB(200, 0, 0)
    End If
    wsDebug.Columns.AutoFit
    wsDebug.Activate
    MsgBox "Debug completato per account: " & accountTarget & vbCrLf & "Trovate " & r - 2 & " operazioni.", vbInformation
End Sub

Function FoglioEsiste(nome As String) As Boolean
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Sheets(nome)
    On Error GoTo 0
    FoglioEsiste = Not ws Is Nothing
End Function

Function GetOrCreateSheet(sheetName As String) As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Sheets(sheetName)
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Sheets.Add(After:=ThisWorkbook.Sheets(ThisWorkbook.Sheets.Count))
        ws.Name = sheetName
    End If
    Set GetOrCreateSheet = ws
End Function

Function PulisciNomeCliente(ByVal nome As String) As String
    Dim titoli As Variant, t As Variant
    titoli = Array("Sign.ra", "Sign.r", "Sig.ra", "Sig.r", "Sig.na", "Sig.", _
                   "Mr.", "Mr", "Mrs.", "Mrs", "Ms.", "Ms", "Miss", _
                   "Herr", "Frau", "Dr.", "Dr", "Prof.", "Prof", _
                   "Dott.", "Dott", "Dott.ssa", "Ing.", "Ing", _
                   "Avv.", "Avv", "Rag.", "Rag")
    nome = Trim$(nome)
    For Each t In titoli
        If Left$(nome, Len(t)) = t Then
            nome = Trim$(Mid$(nome, Len(t) + 1))
            Exit For
        End If
    Next t
    PulisciNomeCliente = nome
End Function

Function SafeVal(ByVal v As Variant) As Double
    Dim s As String: s = Trim$(CStr(v))
    If s = "" Then SafeVal = 0: Exit Function
    Dim decimalSep As String: decimalSep = Mid$(Format$(0, "0.0"), 2, 1)
    If decimalSep = "," Then s = Replace$(s, ".", ",") Else s = Replace$(s, ",", ".")
    Dim i As Integer, cleanStr As String
    For i = 1 To Len(s)
        If IsNumeric(Mid$(s, i, 1)) Or Mid$(s, i, 1) = decimalSep Or Mid$(s, i, 1) = "-" Then
            cleanStr = cleanStr & Mid$(s, i, 1)
        End If
    Next i
    If IsNumeric(cleanStr) Then SafeVal = CDbl(cleanStr) Else SafeVal = 0
End Function

Sub DownloadTassiPuriBCE(ws As Worksheet)
    Dim xmlDoc As Object, xmlNode As Object, xmlChild As Object
    Dim r As Long, c As Variant
    Set xmlDoc = CreateObject("MSXML2.DOMDocument.6.0")
    xmlDoc.Async = False
    xmlDoc.SetProperty "ServerHTTPRequest", True
    If Not xmlDoc.Load("https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist-90d.xml") Then
        MsgBox "Impossibile scaricare i tassi BCE. Controlla la connessione.", vbExclamation
        Exit Sub
    End If
    ws.Cells.Clear: ws.Range("A1").Value = "Date": r = 2
    For Each xmlNode In xmlDoc.SelectNodes("//*[@time]")
        ws.Cells(r, 1).Value = CDate(xmlNode.Attributes.getNamedItem("time").Text)
        For Each xmlChild In xmlNode.ChildNodes
            c = Application.Match(xmlChild.Attributes.getNamedItem("currency").Text, ws.Rows(1), 0)
            If IsError(c) Then
                c = ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column + 1
                ws.Cells(1, c).Value = xmlChild.Attributes.getNamedItem("currency").Text
            End If
            ws.Cells(r, c).Value = SafeVal(xmlChild.Attributes.getNamedItem("rate").Text)
        Next xmlChild
        r = r + 1
    Next xmlNode
End Sub

Function GetSafeRate(ccy As String, wsFX As Worksheet, tDate As Date) As Double
    If ccy = "EUR" Or ccy = "" Then GetSafeRate = 1: Exit Function
    Dim colIdx As Variant, rowIdx As Variant, d As Date, j As Integer
    colIdx = Application.Match(ccy, wsFX.Rows(1), 0)
    If IsError(colIdx) Then GetSafeRate = 1: Exit Function
    d = tDate
    For j = 0 To 10
        rowIdx = Application.Match(CLng(d), wsFX.Columns(1), 0)
        If Not IsError(rowIdx) Then
            GetSafeRate = wsFX.Cells(rowIdx, colIdx).Value2
            If GetSafeRate > 0 Then Exit Function
        End If
        d = d - 1
    Next j
    GetSafeRate = 1
End Function
