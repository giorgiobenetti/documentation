' ============================================================
' MODULO: FP_Import_Tool
' ============================================================
Option Explicit

#If VBA7 Then
Private Declare PtrSafe Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)
#Else
Private Declare Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)
#End If

' Put your FirstPromoter API key between the quotes before running SendToFirstPromoter.
Private Const FP_API_KEY As String = ""
Private Const FP_TRACK_URL As String = "https://firstpromoter.com/api/v1/track/sale"
Private Const ECB_URL As String = "https://data-api.ecb.europa.eu/service/data/EXR/D.USD.EUR.SP00.A?format=csvdata&startPeriod=2023-05-01"

Private Const SHEET_EXCHANGE_RATES As String = "Exchange_Rates"
Private Const SHEET_COUPON_MAP As String = "Coupon_Map"
Private Const SHEET_PAYMENTS As String = "Payments"
Private Const SHEET_FILTER_OUTPUT As String = "Filter_Output"
Private Const SHEET_FP_IMPORT_LOG As String = "FP_Import_Log"

Private Const OUTPUT_FIRST_ROW As Long = 11
Private Const MAP_FIRST_ROW As Long = 4
Private Const RATES_FIRST_ROW As Long = 4

' ---------------------------------------------
' BOTTONE 1: Aggiorna tassi ECB
' ---------------------------------------------
Public Sub UpdateECBRates()
    On Error GoTo CleanFail

    Dim ws As Worksheet
    Set ws = GetToolWorksheet(SHEET_EXCHANGE_RATES)

    Dim http As Object
    Set http = CreateObject("MSXML2.XMLHTTP")

    Application.StatusBar = "Fetching ECB rates..."

    http.Open "GET", ECB_URL, False
    http.Send

    If http.Status <> 200 Then
        Err.Raise vbObjectError + 1001, "UpdateECBRates", "ECB API error: HTTP " & http.Status & " - " & Left$(http.responseText, 200)
    End If

    Dim lines() As String
    lines = Split(NormalizeLineEndings(http.responseText), vbLf)

    Dim timePeriodCol As Long
    Dim obsValueCol As Long
    timePeriodCol = -1
    obsValueCol = -1

    Dim i As Long
    Dim r As Long
    r = RATES_FIRST_ROW

    ws.Range("A3:C3").Value = Array("Date", "EUR/USD rate", "Source")

    Dim lastRateClearRow As Long
    lastRateClearRow = Application.Max(RATES_FIRST_ROW, ws.Cells(ws.Rows.Count, 1).End(xlUp).Row)
    ClearRangeContentsAndFill ws.Range("A" & RATES_FIRST_ROW & ":C" & lastRateClearRow)

    For i = LBound(lines) To UBound(lines)
        Dim line As String
        line = Trim$(Replace$(lines(i), vbCr, vbNullString))
        If Len(line) = 0 Then GoTo NextRateLine

        Dim fields() As String
        fields = ParseCsvLine(line)

        If timePeriodCol < 0 Or obsValueCol < 0 Then
            timePeriodCol = FindCsvColumn(fields, "TIME_PERIOD")
            obsValueCol = FindCsvColumn(fields, "OBS_VALUE")
            GoTo NextRateLine
        End If

        If UBound(fields) < timePeriodCol Or UBound(fields) < obsValueCol Then GoTo NextRateLine

        Dim rateDate As Date
        Dim rateValue As Double
        If Not TryParseDate(fields(timePeriodCol), rateDate) Then GoTo NextRateLine
        If Not TryParseNumber(fields(obsValueCol), rateValue) Then GoTo NextRateLine
        If rateValue <= 0 Then GoTo NextRateLine

        ws.Cells(r, 1).Value = DateValue(rateDate)
        SetNumberFormatSafe ws.Cells(r, 1), "dd/mm/yyyy"
        ' ECB series D.USD.EUR.SP00.A is USD per 1 EUR.
        ws.Cells(r, 2).Value = rateValue
        SetNumberFormatSafe ws.Cells(r, 2), "0.0000"
        ws.Cells(r, 3).Value = "ECB"
        r = r + 1

NextRateLine:
    Next i

    If r = RATES_FIRST_ROW Then
        Err.Raise vbObjectError + 1002, "UpdateECBRates", "No ECB rates were imported. The CSV did not contain TIME_PERIOD and OBS_VALUE rows."
    End If

    SortRatesByDate ws, r - 1
    ws.Cells(2, 1).Value = "Source: European Central Bank - Last updated: " & Format$(Now, "dd/mm/yyyy hh:nn")

    Application.StatusBar = False
    MsgBox "ECB rates updated. " & (r - RATES_FIRST_ROW) & " records imported.", vbInformation
    Exit Sub

CleanFail:
    Application.StatusBar = False
    MsgBox "UpdateECBRates failed:" & vbCrLf & Err.Description, vbCritical
End Sub

' ---------------------------------------------
' Helper: Get EUR/USD rate for a date
' ---------------------------------------------
Public Function GetRate(ByVal targetDate As Date) As Double
    Dim ws As Worksheet
    Set ws = GetToolWorksheet(SHEET_EXCHANGE_RATES)

    Dim lastRow As Long
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row

    Dim i As Long
    Dim bestDate As Date
    Dim bestRate As Double
    bestRate = 0
    bestDate = DateSerial(1900, 1, 1)

    For i = RATES_FIRST_ROW To lastRow
        If IsDate(ws.Cells(i, 1).Value) And IsNumeric(ws.Cells(i, 2).Value) Then
            Dim rateDate As Date
            rateDate = DateValue(CDate(ws.Cells(i, 1).Value))

            If rateDate <= DateValue(targetDate) And rateDate >= bestDate Then
                bestDate = rateDate
                bestRate = CDbl(ws.Cells(i, 2).Value)
            End If
        End If
    Next i

    If bestRate <= 0 Then
        Err.Raise vbObjectError + 1101, "GetRate", "No EUR/USD rate found on or before " & Format$(targetDate, "yyyy-mm-dd") & ". Run UpdateECBRates first."
    End If

    GetRate = bestRate
End Function

' ---------------------------------------------
' Helper: Get coupon from email via Coupon_Map
' ---------------------------------------------
Public Function GetCouponFromEmail(ByVal email As String) As String
    Dim ws As Worksheet
    Set ws = GetToolWorksheet(SHEET_COUPON_MAP)

    Dim lastRow As Long
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row

    Dim i As Long
    For i = MAP_FIRST_ROW To lastRow
        If NormalizeEmail(ws.Cells(i, 1).Value) = NormalizeEmail(email) Then
            GetCouponFromEmail = Trim$(CStr(ws.Cells(i, 2).Value))
            Exit Function
        End If
    Next i

    GetCouponFromEmail = vbNullString
End Function

' ---------------------------------------------
' BOTTONE 2: Genera Output
' ---------------------------------------------
Public Sub GenerateOutput()
    On Error GoTo CleanFail

    Dim wsP As Worksheet
    Dim wsO As Worksheet
    Dim wsM As Worksheet

    Set wsP = GetToolWorksheet(SHEET_PAYMENTS)
    Set wsO = GetToolWorksheet(SHEET_FILTER_OUTPUT)
    Set wsM = GetToolWorksheet(SHEET_COUPON_MAP)

    Dim couponFilter As String
    couponFilter = Trim$(CStr(wsO.Range("B4").Value))

    Dim paidFrom As Date
    Dim paidTo As Date
    Dim tobePaidFrom As Date
    Dim tobePaidTo As Date
    Dim hasPaidFilter As Boolean
    Dim hasTobePaidFilter As Boolean

    hasPaidFilter = HasDateRange(wsO.Range("B5").Value, wsO.Range("D5").Value, paidFrom, paidTo)
    hasTobePaidFilter = HasDateRange(wsO.Range("B6").Value, wsO.Range("D6").Value, tobePaidFrom, tobePaidTo)

    If couponFilter = vbNullString And Not hasPaidFilter And Not hasTobePaidFilter Then
        MsgBox "Please enter at least one filter (coupon or date range).", vbExclamation
        Exit Sub
    End If

    Dim couponFilters As Object
    Set couponFilters = BuildCouponFilter(couponFilter)

    Dim couponByEmail As Object
    Dim affiliateByEmail As Object
    Set couponByEmail = CreateObject("Scripting.Dictionary")
    Set affiliateByEmail = CreateObject("Scripting.Dictionary")
    LoadCouponMap wsM, couponByEmail, affiliateByEmail

    Dim dataStartRow As Long
    Dim colID As Long
    Dim colCreated As Long
    Dim colAmount As Long
    Dim colRefundedAmount As Long
    Dim colCurrency As Long
    Dim colRefundedDate As Long
    Dim colEmail As Long
    Dim colDisputeDate As Long
    ResolvePaymentsLayout wsP, dataStartRow, colID, colCreated, colAmount, colRefundedAmount, colCurrency, colRefundedDate, colEmail, colDisputeDate

    Dim lastOutputRow As Long
    lastOutputRow = Application.Max(OUTPUT_FIRST_ROW, wsO.Cells(wsO.Rows.Count, 1).End(xlUp).Row)
    ClearRangeContentsAndFill wsO.Range("A" & OUTPUT_FIRST_ROW & ":K" & lastOutputRow)

    Dim lastRow As Long
    lastRow = wsP.Cells(wsP.Rows.Count, colID).End(xlUp).Row

    Dim outRow As Long
    outRow = OUTPUT_FIRST_ROW

    Dim i As Long
    For i = dataStartRow To lastRow
        Dim payID As String
        payID = Trim$(CStr(wsP.Cells(i, colID).Value))
        If payID = vbNullString Then GoTo NextPaymentRow

        Dim payDate As Date
        If Not TryParseDate(wsP.Cells(i, colCreated).Value, payDate) Then GoTo NextPaymentRow
        Dim payDateOnly As Date
        payDateOnly = DateValue(payDate)

        Dim amount As Double
        Dim amountRefunded As Double
        If Not TryParseNumber(wsP.Cells(i, colAmount).Value, amount) Then GoTo NextPaymentRow
        If Not TryParseNumber(wsP.Cells(i, colRefundedAmount).Value, amountRefunded) Then amountRefunded = 0

        Dim paymentCurrency As String
        Dim refundDate As String
        Dim custEmail As String
        Dim disputeDate As String

        paymentCurrency = UCase$(Trim$(CStr(wsP.Cells(i, colCurrency).Value)))
        refundDate = Trim$(CStr(wsP.Cells(i, colRefundedDate).Value))
        custEmail = NormalizeEmail(wsP.Cells(i, colEmail).Value)
        disputeDate = Trim$(CStr(wsP.Cells(i, colDisputeDate).Value))

        If amount <= 0 Then GoTo NextPaymentRow
        If amountRefunded > 0 Then GoTo NextPaymentRow
        If refundDate <> vbNullString Then GoTo NextPaymentRow
        If disputeDate <> vbNullString Then GoTo NextPaymentRow

        Dim coupon As String
        Dim affiliateName As String
        coupon = vbNullString
        affiliateName = vbNullString

        If couponByEmail.Exists(custEmail) Then coupon = CStr(couponByEmail(custEmail))
        If affiliateByEmail.Exists(custEmail) Then affiliateName = CStr(affiliateByEmail(custEmail))

        If Not CouponIsAllowed(coupon, couponFilters) Then GoTo NextPaymentRow

        Dim inPaid As Boolean
        Dim inTobePaid As Boolean
        inPaid = hasPaidFilter And (payDateOnly >= paidFrom And payDateOnly <= paidTo)
        inTobePaid = hasTobePaidFilter And (payDateOnly >= tobePaidFrom And payDateOnly <= tobePaidTo)

        If hasPaidFilter Or hasTobePaidFilter Then
            If Not inPaid And Not inTobePaid Then GoTo NextPaymentRow
        End If

        Dim amountEUR As Double
        Dim rate As Double

        Select Case paymentCurrency
            Case "EUR"
                amountEUR = amount
                rate = 1
            Case "USD"
                rate = GetRate(payDateOnly)
                amountEUR = amount / rate
            Case Else
                GoTo NextPaymentRow
        End Select

        Dim statusText As String
        If inPaid Then
            statusText = "Already Paid"
        ElseIf inTobePaid Then
            statusText = "To Be Paid"
        Else
            statusText = "In Range"
        End If

        wsO.Cells(outRow, 1).Value = payID
        wsO.Cells(outRow, 2).Value = payDateOnly
        SetNumberFormatSafe wsO.Cells(outRow, 2), "dd/mm/yyyy"
        wsO.Cells(outRow, 3).Value = custEmail
        wsO.Cells(outRow, 4).Value = coupon
        wsO.Cells(outRow, 5).Value = affiliateName
        wsO.Cells(outRow, 6).Value = amount
        SetNumberFormatSafe wsO.Cells(outRow, 6), "#,##0.00"
        wsO.Cells(outRow, 7).Value = paymentCurrency
        wsO.Cells(outRow, 8).Value = Round(amountEUR, 2)
        SetNumberFormatSafe wsO.Cells(outRow, 8), "#,##0.00"
        wsO.Cells(outRow, 9).Value = Round(rate, 4)
        SetNumberFormatSafe wsO.Cells(outRow, 9), "0.0000"
        wsO.Cells(outRow, 10).Value = statusText
        wsO.Cells(outRow, 11).Value = "No"

        ApplyStatusFill wsO.Range(wsO.Cells(outRow, 1), wsO.Cells(outRow, 11)), statusText

        outRow = outRow + 1

NextPaymentRow:
    Next i

    MsgBox (outRow - OUTPUT_FIRST_ROW) & " transactions found and written to output.", vbInformation
    Exit Sub

CleanFail:
    MsgBox "GenerateOutput failed:" & vbCrLf & Err.Description, vbCritical
End Sub

' ---------------------------------------------
' BOTTONE 3: Invia a FirstPromoter
' ---------------------------------------------
Public Sub SendToFirstPromoter()
    On Error GoTo CleanFail

    Dim wsO As Worksheet
    Dim wsLog As Worksheet
    Set wsO = GetToolWorksheet(SHEET_FILTER_OUTPUT)
    Set wsLog = GetToolWorksheet(SHEET_FP_IMPORT_LOG)

    Dim apiKey As String
    apiKey = GetFirstPromoterApiKey()

    Dim lastRow As Long
    lastRow = wsO.Cells(wsO.Rows.Count, 1).End(xlUp).Row

    If lastRow < OUTPUT_FIRST_ROW Then
        MsgBox "No data in output. Run Generate Output first.", vbExclamation
        Exit Sub
    End If

    Dim confirm As VbMsgBoxResult
    confirm = MsgBox("Send " & (lastRow - OUTPUT_FIRST_ROW + 1) & " transactions to FirstPromoter?", vbYesNo + vbQuestion)
    If confirm = vbNo Then Exit Sub

    Dim logRow As Long
    logRow = wsLog.Cells(wsLog.Rows.Count, 1).End(xlUp).Row + 1
    If logRow < MAP_FIRST_ROW Then logRow = MAP_FIRST_ROW

    Dim i As Long
    Dim successCount As Long
    Dim noReferralCount As Long
    Dim duplicateCount As Long
    Dim errorCount As Long
    successCount = 0
    noReferralCount = 0
    duplicateCount = 0
    errorCount = 0

    For i = OUTPUT_FIRST_ROW To lastRow
        Dim payID As String
        payID = Trim$(CStr(wsO.Cells(i, 1).Value))
        If payID = vbNullString Then GoTo NextSend

        If UCase$(Trim$(CStr(wsO.Cells(i, 11).Value))) = "YES" Then GoTo NextSend

        Dim payDate As Date
        Dim custEmail As String
        Dim coupon As String
        Dim amountEUR As Double

        If Not TryParseDate(wsO.Cells(i, 2).Value, payDate) Then GoTo NextSend
        custEmail = NormalizeEmail(wsO.Cells(i, 3).Value)
        coupon = Trim$(CStr(wsO.Cells(i, 4).Value))
        If Not TryParseNumber(wsO.Cells(i, 8).Value, amountEUR) Then GoTo NextSend
        If amountEUR <= 0 Then GoTo NextSend

        Dim postBody As String
        postBody = BuildFirstPromoterSaleQuery(payID, payDate, custEmail, coupon, amountEUR)

        Dim fpStatus As Long
        Dim fpResponse As String
        Call PostFirstPromoterSale(postBody, apiKey, fpStatus, fpResponse)

        WriteFirstPromoterLog wsLog, logRow, payID, coupon, amountEUR, fpStatus, fpResponse, postBody

        Select Case fpStatus
            Case 200
                SetImportStatusSafe wsO, i, "Yes", RGB(212, 237, 218)
                successCount = successCount + 1
            Case 204
                SetImportStatusSafe wsO, i, "No Referral", RGB(255, 243, 205)
                noReferralCount = noReferralCount + 1
            Case 409
                SetImportStatusSafe wsO, i, "Duplicate", RGB(255, 243, 205)
                duplicateCount = duplicateCount + 1
            Case Else
                SetImportStatusSafe wsO, i, "Error", RGB(248, 215, 218)
                errorCount = errorCount + 1
        End Select

        logRow = logRow + 1
        SleepMs 300

NextSend:
    Next i

    MsgBox "Import complete." & vbCrLf & _
           "Tracked sales: " & successCount & vbCrLf & _
           "No referral (204): " & noReferralCount & vbCrLf & _
           "Duplicates (409): " & duplicateCount & vbCrLf & _
           "Errors: " & errorCount, vbInformation
    Exit Sub

CleanFail:
    MsgBox "SendToFirstPromoter failed:" & vbCrLf & _
           "Error " & Err.Number & ": " & Err.Description, vbCritical
End Sub

Private Sub WriteFirstPromoterLog(ByVal wsLog As Worksheet, _
                                   ByVal logRow As Long, _
                                   ByVal payID As String, _
                                   ByVal coupon As String, _
                                   ByVal amountEUR As Double, _
                                   ByVal fpStatus As Long, _
                                   ByVal fpResponse As String, _
                                   ByVal postBody As String)
    On Error Resume Next

    wsLog.Cells(logRow, 1).Value = Now
    SetNumberFormatSafe wsLog.Cells(logRow, 1), "dd/mm/yyyy hh:mm:ss"
    wsLog.Cells(logRow, 2).Value = payID
    wsLog.Cells(logRow, 3).Value = coupon
    wsLog.Cells(logRow, 4).Value = Round(amountEUR, 2)
    SetNumberFormatSafe wsLog.Cells(logRow, 4), "#,##0.00"
    wsLog.Cells(logRow, 5).Value = fpStatus
    wsLog.Cells(logRow, 6).Value = fpResponse
    wsLog.Cells(logRow, 7).Value = FirstPromoterResultLabel(fpStatus)
    wsLog.Cells(logRow, 8).Value = postBody

    Err.Clear
    On Error GoTo 0
End Sub

Private Sub SetImportStatusSafe(ByVal ws As Worksheet, _
                                ByVal rowNumber As Long, _
                                ByVal statusText As String, _
                                ByVal fillColor As Long)
    On Error Resume Next

    ws.Cells(rowNumber, 11).Value = statusText
    ws.Cells(rowNumber, 11).Interior.Color = fillColor

    Err.Clear
    On Error GoTo 0
End Sub

' ---------------------------------------------
' Diagnostica: verifica riga selezionata senza inviare a FirstPromoter
' ---------------------------------------------
Public Sub DiagnoseFirstPromoterSelectedRow()
    On Error GoTo CleanFail

    Dim wsO As Worksheet
    Set wsO = GetToolWorksheet(SHEET_FILTER_OUTPUT)

    If ActiveCell Is Nothing Then
        MsgBox "Select one output row in Filter_Output first.", vbExclamation
        Exit Sub
    End If

    If NormalizeSheetName(ActiveCell.Worksheet.Name) <> NormalizeSheetName(wsO.Name) Then
        MsgBox "Select one output row in the Filter_Output sheet first.", vbExclamation
        Exit Sub
    End If

    Dim rowNumber As Long
    rowNumber = ActiveCell.Row
    If rowNumber < OUTPUT_FIRST_ROW Then
        MsgBox "Select a transaction row from row " & OUTPUT_FIRST_ROW & " onward.", vbExclamation
        Exit Sub
    End If

    Dim payID As String
    Dim payDate As Date
    Dim custEmail As String
    Dim coupon As String
    Dim amountEUR As Double

    payID = Trim$(CStr(wsO.Cells(rowNumber, 1).Value))
    If payID = vbNullString Then Err.Raise vbObjectError + 1601, "DiagnoseFirstPromoterSelectedRow", "Missing Stripe payment id in column A."
    If Not TryParseDate(wsO.Cells(rowNumber, 2).Value, payDate) Then Err.Raise vbObjectError + 1602, "DiagnoseFirstPromoterSelectedRow", "Invalid payment date in column B."

    custEmail = NormalizeEmail(wsO.Cells(rowNumber, 3).Value)
    If custEmail = vbNullString Or InStr(1, custEmail, "@", vbTextCompare) = 0 Then Err.Raise vbObjectError + 1603, "DiagnoseFirstPromoterSelectedRow", "Missing or invalid customer email in column C."

    coupon = Trim$(CStr(wsO.Cells(rowNumber, 4).Value))
    If coupon = vbNullString Then Err.Raise vbObjectError + 1604, "DiagnoseFirstPromoterSelectedRow", "Missing promo/tracking coupon in column D."

    If Not TryParseNumber(wsO.Cells(rowNumber, 8).Value, amountEUR) Then Err.Raise vbObjectError + 1605, "DiagnoseFirstPromoterSelectedRow", "Invalid EUR amount in column H."
    If amountEUR <= 0 Then Err.Raise vbObjectError + 1606, "DiagnoseFirstPromoterSelectedRow", "EUR amount must be greater than zero."

    Call GetFirstPromoterApiKey

    Dim queryString As String
    queryString = BuildFirstPromoterSaleQuery(payID, payDate, custEmail, coupon, amountEUR)

    MsgBox "Local validation OK. No request was sent." & vbCrLf & vbCrLf & _
           "Checks:" & vbCrLf & _
           "- promo_code is column D and must be an active unique promoter-level Tracking Coupon in FirstPromoter." & vbCrLf & _
           "- email is the Stripe customer/lead email, not the promoter email." & vbCrLf & _
           "- event_id is the Stripe payment id and must be unique." & vbCrLf & vbCrLf & _
           "Query:" & vbCrLf & queryString, vbInformation
    Exit Sub

CleanFail:
    MsgBox "DiagnoseFirstPromoterSelectedRow failed:" & vbCrLf & _
           "Error " & Err.Number & ": " & Err.Description, vbCritical
End Sub

Private Function FirstPromoterResultLabel(ByVal fpStatus As Long) As String
    Select Case fpStatus
        Case 200
            FirstPromoterResultLabel = "Tracked sale - commission generated"
        Case 204
            FirstPromoterResultLabel = "No referral sale - no commission generated"
        Case 400
            FirstPromoterResultLabel = "Bad request - check response/body"
        Case 409
            FirstPromoterResultLabel = "Duplicate event_id"
        Case 0
            FirstPromoterResultLabel = "VBA/MSXML HTTP error"
        Case Else
            FirstPromoterResultLabel = "HTTP " & CStr(fpStatus)
    End Select
End Function

Private Sub PostFirstPromoterSale(ByVal queryString As String, _
                                  ByVal apiKey As String, _
                                  ByRef fpStatus As Long, _
                                  ByRef fpResponse As String)
    On Error GoTo RequestFailed

    Dim http As Object
    Set http = CreateObject("MSXML2.ServerXMLHTTP.6.0")

    ' Resolve/connect/send/receive timeouts in milliseconds.
    http.setTimeouts 5000, 10000, 30000, 30000
    http.Open "POST", FP_TRACK_URL & "?" & queryString, False
    http.setRequestHeader "Accept", "application/json"
    http.setRequestHeader "User-Agent", "Excel VBA FirstPromoter Import Tool"
    http.setRequestHeader "x-api-key", apiKey
    http.Send vbNullString

    fpStatus = CLng(http.Status)
    fpResponse = Left$(CStr(http.responseText), 500)
    Exit Sub

RequestFailed:
    fpStatus = 0
    fpResponse = "VBA HTTP error " & Err.Number & ": " & Err.Description
End Sub

Private Function GetToolWorkbook() As Workbook
    If WorkbookHasRequiredSheets(ThisWorkbook) Then
        Set GetToolWorkbook = ThisWorkbook
        Exit Function
    End If

    If Not ActiveWorkbook Is Nothing Then
        If WorkbookHasRequiredSheets(ActiveWorkbook) Then
            Set GetToolWorkbook = ActiveWorkbook
            Exit Function
        End If
    End If

    Err.Raise vbObjectError + 1201, "GetToolWorkbook", _
        "Cannot find the FirstPromoter workbook. Open the .xlsm file that contains sheets " & _
        SHEET_EXCHANGE_RATES & ", " & SHEET_COUPON_MAP & ", " & SHEET_PAYMENTS & ", " & _
        SHEET_FILTER_OUTPUT & " and " & SHEET_FP_IMPORT_LOG & "."
End Function

Private Function GetToolWorksheet(ByVal sheetName As String) As Worksheet
    Dim wb As Workbook
    Set wb = GetToolWorkbook()

    Dim ws As Worksheet
    For Each ws In wb.Worksheets
        If NormalizeSheetName(ws.Name) = NormalizeSheetName(sheetName) Then
            Set GetToolWorksheet = ws
            Exit Function
        End If
    Next ws

    Err.Raise vbObjectError + 1202, "GetToolWorksheet", _
        "Worksheet '" & sheetName & "' was not found in workbook '" & wb.Name & "'."
End Function

Private Function WorkbookHasRequiredSheets(ByVal wb As Workbook) As Boolean
    If wb Is Nothing Then Exit Function

    WorkbookHasRequiredSheets = _
        WorkbookHasSheet(wb, SHEET_EXCHANGE_RATES) And _
        WorkbookHasSheet(wb, SHEET_COUPON_MAP) And _
        WorkbookHasSheet(wb, SHEET_PAYMENTS) And _
        WorkbookHasSheet(wb, SHEET_FILTER_OUTPUT) And _
        WorkbookHasSheet(wb, SHEET_FP_IMPORT_LOG)
End Function

Private Function WorkbookHasSheet(ByVal wb As Workbook, ByVal sheetName As String) As Boolean
    Dim ws As Worksheet
    For Each ws In wb.Worksheets
        If NormalizeSheetName(ws.Name) = NormalizeSheetName(sheetName) Then
            WorkbookHasSheet = True
            Exit Function
        End If
    Next ws
End Function

Private Function NormalizeSheetName(ByVal value As String) As String
    NormalizeSheetName = UCase$(Trim$(Replace$(value, ChrW$(160), " ")))
End Function

Private Function NormalizeHeader(ByVal value As String) As String
    Dim normalized As String
    normalized = UCase$(Trim$(Replace$(Replace$(value, vbCr, " "), vbLf, " ")))
    Do While InStr(normalized, "  ") > 0
        normalized = Replace$(normalized, "  ", " ")
    Loop
    NormalizeHeader = normalized
End Function

Private Function NormalizeEmail(ByVal value As Variant) As String
    NormalizeEmail = LCase$(Trim$(CStr(value)))
End Function

Private Function NormalizeLineEndings(ByVal value As String) As String
    value = Replace$(value, vbCrLf, vbLf)
    value = Replace$(value, vbCr, vbLf)
    NormalizeLineEndings = value
End Function

Private Sub ClearRangeContentsAndFill(ByVal targetRange As Range)
    targetRange.ClearContents
    targetRange.Interior.Pattern = xlNone
End Sub

Private Sub SortRatesByDate(ByVal ws As Worksheet, ByVal lastRateRow As Long)
    If lastRateRow <= RATES_FIRST_ROW Then Exit Sub

    With ws.Sort
        .SortFields.Clear
        .SortFields.Add Key:=ws.Range("A" & RATES_FIRST_ROW & ":A" & lastRateRow), _
                        SortOn:=xlSortOnValues, Order:=xlAscending, DataOption:=xlSortNormal
        .SetRange ws.Range("A" & RATES_FIRST_ROW & ":C" & lastRateRow)
        .Header = xlNo
        .Apply
    End With
End Sub

Private Function ParseCsvLine(ByVal line As String) As String()
    Dim fields() As String
    ReDim fields(0 To 0)

    Dim currentField As String
    Dim inQuotes As Boolean
    Dim i As Long

    For i = 1 To Len(line)
        Dim ch As String
        ch = Mid$(line, i, 1)

        If ch = """" Then
            If inQuotes And i < Len(line) And Mid$(line, i + 1, 1) = """" Then
                currentField = currentField & """"
                i = i + 1
            Else
                inQuotes = Not inQuotes
            End If
        ElseIf ch = "," And Not inQuotes Then
            fields(UBound(fields)) = currentField
            ReDim Preserve fields(0 To UBound(fields) + 1)
            currentField = vbNullString
        Else
            currentField = currentField & ch
        End If
    Next i

    fields(UBound(fields)) = currentField
    ParseCsvLine = fields
End Function

Private Function FindCsvColumn(ByRef fields() As String, ByVal columnName As String) As Long
    Dim i As Long
    For i = LBound(fields) To UBound(fields)
        If NormalizeHeader(fields(i)) = NormalizeHeader(columnName) Then
            FindCsvColumn = i
            Exit Function
        End If
    Next i

    FindCsvColumn = -1
End Function

Private Function TryParseDate(ByVal value As Variant, ByRef parsedDate As Date) As Boolean
    On Error GoTo ParseFail

    If IsDate(value) Then
        parsedDate = CDate(value)
        TryParseDate = True
        Exit Function
    End If

    Dim textValue As String
    textValue = Trim$(CStr(value))
    If Len(textValue) = 0 Then Exit Function

    If Len(textValue) >= 10 And Mid$(textValue, 5, 1) = "-" And Mid$(textValue, 8, 1) = "-" Then
        parsedDate = DateSerial(CInt(Left$(textValue, 4)), CInt(Mid$(textValue, 6, 2)), CInt(Mid$(textValue, 9, 2)))

        If Len(textValue) >= 19 Then
            parsedDate = parsedDate + TimeSerial(CInt(Mid$(textValue, 12, 2)), CInt(Mid$(textValue, 15, 2)), CInt(Mid$(textValue, 18, 2)))
        End If

        TryParseDate = True
        Exit Function
    End If

ParseFail:
End Function

Private Function TryParseNumber(ByVal value As Variant, ByRef parsedNumber As Double) As Boolean
    On Error GoTo ParseFail

    If IsError(value) Then Exit Function

    Select Case VarType(value)
        Case vbByte, vbInteger, vbLong, vbSingle, vbDouble, vbCurrency, vbDecimal
            parsedNumber = CDbl(value)
            TryParseNumber = True
            Exit Function
    End Select

    Dim textValue As String
    textValue = Trim$(CStr(value))
    If Len(textValue) = 0 Then Exit Function

    textValue = Replace$(textValue, ChrW$(160), vbNullString)
    textValue = Replace$(textValue, " ", vbNullString)

    Dim decimalSeparator As String
    decimalSeparator = Application.International(xlDecimalSeparator)

    Dim dotPos As Long
    Dim commaPos As Long
    dotPos = InStrRev(textValue, ".")
    commaPos = InStrRev(textValue, ",")

    If dotPos > 0 And commaPos > 0 Then
        If dotPos > commaPos Then
            textValue = Replace$(textValue, ",", vbNullString)
            textValue = Replace$(textValue, ".", decimalSeparator)
        Else
            textValue = Replace$(textValue, ".", vbNullString)
            textValue = Replace$(textValue, ",", decimalSeparator)
        End If
    ElseIf dotPos > 0 Then
        textValue = Replace$(textValue, ".", decimalSeparator)
    ElseIf commaPos > 0 Then
        textValue = Replace$(textValue, ",", decimalSeparator)
    End If

    If IsNumeric(textValue) Then
        parsedNumber = CDbl(textValue)
        TryParseNumber = True
    End If

    Exit Function

ParseFail:
End Function

Private Function HasDateRange(ByVal fromValue As Variant, ByVal toValue As Variant, ByRef fromDate As Date, ByRef toDate As Date) As Boolean
    If Trim$(CStr(fromValue)) = vbNullString And Trim$(CStr(toValue)) = vbNullString Then Exit Function

    If Not TryParseDate(fromValue, fromDate) Or Not TryParseDate(toValue, toDate) Then
        Err.Raise vbObjectError + 1301, "HasDateRange", "Invalid date range. Enter both start and end dates."
    End If

    fromDate = DateValue(fromDate)
    toDate = DateValue(toDate)

    If fromDate > toDate Then
        Err.Raise vbObjectError + 1302, "HasDateRange", "Invalid date range: start date is after end date."
    End If

    HasDateRange = True
End Function

Private Function BuildCouponFilter(ByVal filterText As String) As Object
    If Trim$(filterText) = vbNullString Then Exit Function

    Dim dict As Object
    Set dict = CreateObject("Scripting.Dictionary")

    filterText = Replace$(filterText, ";", ",")
    filterText = Replace$(filterText, vbCr, ",")
    filterText = Replace$(filterText, vbLf, ",")

    Dim parts() As String
    parts = Split(filterText, ",")

    Dim i As Long
    For i = LBound(parts) To UBound(parts)
        Dim coupon As String
        coupon = UCase$(Trim$(parts(i)))
        If coupon <> vbNullString Then dict(coupon) = True
    Next i

    If dict.Count > 0 Then Set BuildCouponFilter = dict
End Function

Private Function CouponIsAllowed(ByVal coupon As String, ByVal couponFilters As Object) As Boolean
    If couponFilters Is Nothing Then
        CouponIsAllowed = True
    Else
        CouponIsAllowed = couponFilters.Exists(UCase$(Trim$(coupon)))
    End If
End Function

Private Sub LoadCouponMap(ByVal ws As Worksheet, ByVal couponByEmail As Object, ByVal affiliateByEmail As Object)
    Dim lastRow As Long
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row

    Dim i As Long
    For i = MAP_FIRST_ROW To lastRow
        Dim email As String
        email = NormalizeEmail(ws.Cells(i, 1).Value)
        If email <> vbNullString Then
            couponByEmail(email) = Trim$(CStr(ws.Cells(i, 2).Value))
            affiliateByEmail(email) = Trim$(CStr(ws.Cells(i, 3).Value))
        End If
    Next i
End Sub

Private Sub ResolvePaymentsLayout(ByVal ws As Worksheet, _
                                  ByRef dataStartRow As Long, _
                                  ByRef colID As Long, _
                                  ByRef colCreated As Long, _
                                  ByRef colAmount As Long, _
                                  ByRef colRefundedAmount As Long, _
                                  ByRef colCurrency As Long, _
                                  ByRef colRefundedDate As Long, _
                                  ByRef colEmail As Long, _
                                  ByRef colDisputeDate As Long)
    Dim headerRow As Long
    For headerRow = 1 To 10
        colID = FindHeaderColumnInRow(ws, headerRow, "id")
        colCreated = FindHeaderColumnInRow(ws, headerRow, "Created date UTC")
        colAmount = FindHeaderColumnInRow(ws, headerRow, "Converted Amount")
        colRefundedAmount = FindHeaderColumnInRow(ws, headerRow, "Converted Amount Refunded")
        colCurrency = FindHeaderColumnInRow(ws, headerRow, "Converted Currency")
        colRefundedDate = FindHeaderColumnInRow(ws, headerRow, "Refunded date UTC")
        colEmail = FindHeaderColumnInRow(ws, headerRow, "Customer Email")
        colDisputeDate = FindHeaderColumnInRow(ws, headerRow, "Dispute Date UTC")

        If colID > 0 And colCreated > 0 And colAmount > 0 And colRefundedAmount > 0 And _
           colCurrency > 0 And colRefundedDate > 0 And colEmail > 0 And colDisputeDate > 0 Then
            dataStartRow = headerRow + 1
            Exit Sub
        End If
    Next headerRow

    ' Fallback for the original workbook layout: headers in row 3, data from row 4.
    dataStartRow = 4
    colID = 1
    colCreated = 2
    colAmount = 3
    colRefundedAmount = 4
    colCurrency = 5
    colRefundedDate = 6
    colEmail = 7
    colDisputeDate = 8
End Sub

Private Function FindHeaderColumnInRow(ByVal ws As Worksheet, ByVal rowNumber As Long, ByVal headerText As String) As Long
    Dim lastCol As Long
    lastCol = ws.Cells(rowNumber, ws.Columns.Count).End(xlToLeft).Column

    Dim col As Long
    For col = 1 To lastCol
        If NormalizeHeader(CStr(ws.Cells(rowNumber, col).Value)) = NormalizeHeader(headerText) Then
            FindHeaderColumnInRow = col
            Exit Function
        End If
    Next col
End Function

Private Sub SetNumberFormatSafe(ByVal targetRange As Range, ByVal formatCode As String)
    On Error Resume Next
    targetRange.NumberFormat = formatCode
    If Err.Number <> 0 Then
        Err.Clear
        targetRange.NumberFormatLocal = formatCode
    End If
    Err.Clear
    On Error GoTo 0
End Sub

Private Sub ApplyStatusFill(ByVal targetRange As Range, ByVal statusText As String)
    On Error Resume Next

    Select Case statusText
        Case "Already Paid"
            targetRange.Interior.Color = RGB(212, 237, 218)
        Case "To Be Paid"
            targetRange.Interior.Color = RGB(255, 243, 205)
        Case Else
            targetRange.Interior.Pattern = xlNone
    End Select

    Err.Clear
    On Error GoTo 0
End Sub

Private Function BuildFirstPromoterSaleQuery(ByVal payID As String, _
                                             ByVal payDate As Date, _
                                             ByVal custEmail As String, _
                                             ByVal coupon As String, _
                                             ByVal amountEUR As Double) As String
    BuildFirstPromoterSaleQuery = "promo_code=" & UrlEncode(Trim$(coupon)) & _
        "&email=" & UrlEncode(NormalizeEmail(custEmail)) & _
        "&amount=" & CStr(AmountToCents(amountEUR)) & _
        "&currency=eur" & _
        "&event_id=" & UrlEncode(Trim$(payID)) & _
        "&created_at=" & UrlEncode(Format$(payDate, "yyyy-mm-dd\Thh:nn:ss\Z")) & _
        "&skip_email_notification=true"
End Function

Private Function AmountToCents(ByVal amountEUR As Double) As Long
    AmountToCents = CLng(Fix((amountEUR * 100) + 0.5))
End Function

Private Function UrlEncode(ByVal value As String) As String
    Dim i As Long
    Dim ch As String
    Dim code As Long
    Dim encoded As String

    For i = 1 To Len(value)
        ch = Mid$(value, i, 1)
        code = AscW(ch)

        Select Case code
            Case 48 To 57, 65 To 90, 97 To 122
                encoded = encoded & ch
            Case 45, 46, 95, 126
                encoded = encoded & ch
            Case 32
                encoded = encoded & "+"
            Case Else
                If code < 0 Then code = code + 65536
                If code <= 255 Then
                    encoded = encoded & "%" & Right$("0" & Hex$(code), 2)
                Else
                    Err.Raise vbObjectError + 1401, "UrlEncode", "Only ASCII characters are supported in API fields: " & value
                End If
        End Select
    Next i

    UrlEncode = encoded
End Function

Private Function GetFirstPromoterApiKey() As String
    If Trim$(FP_API_KEY) = vbNullString Then
        Err.Raise vbObjectError + 1501, "GetFirstPromoterApiKey", _
            "FirstPromoter API key is missing. Set the FP_API_KEY constant in this module."
    End If

    GetFirstPromoterApiKey = Trim$(FP_API_KEY)
End Function

Private Sub SleepMs(ByVal milliseconds As Long)
    DoEvents
    Sleep milliseconds
    DoEvents
End Sub
