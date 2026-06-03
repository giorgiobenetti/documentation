' ============================================================
' MODULO: FP_Import_Tool
' ============================================================
Option Explicit

#If VBA7 Then
Private Declare PtrSafe Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)
#Else
Private Declare Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)
#End If

' API key selection:
' Put credentials here to bypass Named Range ambiguity. Constants win over Named Ranges when non-empty.
Private Const FP_API_KEY_HARDCODED As String = ""
Private Const FP_LEGACY_API_KEY_HARDCODED As String = ""
Private Const FP_ACCOUNT_ID_HARDCODED As String = ""
' Already Paid rows are imported, then immediately marked paid. If mark-paid fails, import stops.
Private Const FP_IMPORT_ALREADY_PAID As Boolean = True
Private Const FP_TRACK_URL_V1 As String = "https://firstpromoter.com/api/v1/track/sale"
Private Const FP_TRACK_URL_V2 As String = "https://api.firstpromoter.com/api/v2/track/sale"
Private Const FP_SIGNUP_URL_V2 As String = "https://api.firstpromoter.com/api/v2/track/signup"
Private Const FP_SIGNUP_DELAY_MS As Long = 2500
Private Const FP_RATE_LIMIT_MAX_RETRIES As Long = 5
Private Const FP_RATE_LIMIT_BASE_WAIT_MS As Long = 15000
Private Const FP_LEAD_UPDATE_URL_V1 As String = "https://firstpromoter.com/api/v1/leads/update"
Private Const FP_COMMISSIONS_URL_V2 As String = "https://api.firstpromoter.com/api/v2/company/commissions"
Private Const ECB_URL As String = "https://data-api.ecb.europa.eu/service/data/EXR/D.USD.EUR.SP00.A?format=csvdata&startPeriod=2023-05-01"

Private Const SHEET_EXCHANGE_RATES As String = "Exchange_Rates"
Private Const SHEET_COUPON_MAP As String = "Coupon_Map"
Private Const SHEET_PAYMENTS As String = "Payments"
Private Const SHEET_FILTER_OUTPUT As String = "Filter_Output"
Private Const SHEET_FP_IMPORT_LOG As String = "FP_Import_Log"
Private Const SHEET_FP_DEBUG_LOG As String = "FP_Debug_Log"
Private Const SHEET_INFLUENCER_REPORT As String = "Influencer_Report"

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

    If hasPaidFilter And hasTobePaidFilter Then
        If DateRangesOverlap(paidFrom, paidTo, tobePaidFrom, tobePaidTo) Then
            Err.Raise vbObjectError + 1303, "GenerateOutput", _
                "Paid and To Be Paid date ranges overlap. Fix Filter_Output B5:D5 and B6:D6 before generating output."
        End If
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
    Dim colCustomerID As Long
    Dim colDisputeDate As Long
    ResolvePaymentsLayout wsP, dataStartRow, colID, colCreated, colAmount, colRefundedAmount, colCurrency, colRefundedDate, colEmail, colCustomerID, colDisputeDate

    Dim lastOutputRow As Long
    lastOutputRow = Application.Max(OUTPUT_FIRST_ROW, wsO.Cells(wsO.Rows.Count, 1).End(xlUp).Row)
    ClearRangeContentsAndFill wsO.Range("A" & OUTPUT_FIRST_ROW & ":L" & lastOutputRow)

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
        Dim stripeCustomerID As String
        stripeCustomerID = vbNullString
        If colCustomerID > 0 Then stripeCustomerID = Trim$(CStr(wsP.Cells(i, colCustomerID).Value))
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
        wsO.Cells(outRow, 12).Value = stripeCustomerID

        ApplyStatusFill wsO.Range(wsO.Cells(outRow, 1), wsO.Cells(outRow, 12)), statusText

        outRow = outRow + 1

NextPaymentRow:
    Next i

    MsgBox (outRow - OUTPUT_FIRST_ROW) & " transactions found and written to output.", vbInformation
    Exit Sub

CleanFail:
    MsgBox "GenerateOutput failed:" & vbCrLf & Err.Description, vbCritical
End Sub


' ---------------------------------------------
' REPORT: fatturato e commissioni influencer
' ---------------------------------------------
Public Sub GenerateInfluencerReport()
    On Error GoTo CleanFail

    Dim wsP As Worksheet
    Dim wsM As Worksheet
    Dim wsR As Worksheet

    Set wsP = GetToolWorksheet(SHEET_PAYMENTS)
    Set wsM = GetToolWorksheet(SHEET_COUPON_MAP)
    Set wsR = GetOrCreateWorksheet(SHEET_INFLUENCER_REPORT)

    SetupInfluencerReportSheet wsR

    Dim reportFrom As Date
    Dim reportTo As Date
    If Not TryParseDate(wsR.Range("B2").Value, reportFrom) Then
        Err.Raise vbObjectError + 1901, "GenerateInfluencerReport", "Enter report start date in Influencer_Report!B2."
    End If
    reportFrom = DateValue(reportFrom)
    If TryParseDate(wsR.Range("D2").Value, reportTo) Then
        reportTo = DateValue(reportTo)
    Else
        reportTo = Date
    End If
    If reportFrom > reportTo Then Err.Raise vbObjectError + 1902, "GenerateInfluencerReport", "Report start date is after end date."

    Dim commissionRate As Double
    commissionRate = GetCommissionRate(wsR.Range("B4").Value)

    Dim couponFilters As Object
    Set couponFilters = BuildCouponFilter(Trim$(CStr(wsR.Range("B3").Value)))

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
    Dim colCustomerID As Long
    Dim colDisputeDate As Long
    ResolvePaymentsLayout wsP, dataStartRow, colID, colCreated, colAmount, colRefundedAmount, colCurrency, colRefundedDate, colEmail, colCustomerID, colDisputeDate

    Dim lastClearRow As Long
    lastClearRow = Application.Max(8, wsR.Cells(wsR.Rows.Count, 1).End(xlUp).Row, wsR.Cells(wsR.Rows.Count, 12).End(xlUp).Row)
    ClearRangeContentsAndFill wsR.Range("A7:Q" & lastClearRow)
    WriteInfluencerReportHeaders wsR

    Dim summary As Object
    Dim uniqueCustomers As Object
    Set summary = CreateObject("Scripting.Dictionary")
    Set uniqueCustomers = CreateObject("Scripting.Dictionary")

    Dim lastRow As Long
    lastRow = wsP.Cells(wsP.Rows.Count, colID).End(xlUp).Row

    Dim outRow As Long
    outRow = 8

    Dim i As Long
    For i = dataStartRow To lastRow
        Dim payID As String
        Dim payDate As Date
        Dim payDateOnly As Date
        Dim amount As Double
        Dim amountRefunded As Double
        Dim paymentCurrency As String
        Dim refundDate As String
        Dim disputeDate As String
        Dim custEmail As String
        Dim customerUID As String

        payID = Trim$(CStr(wsP.Cells(i, colID).Value))
        If payID = vbNullString Then GoTo NextPayment
        If Not TryParseDate(wsP.Cells(i, colCreated).Value, payDate) Then GoTo NextPayment
        payDateOnly = DateValue(payDate)
        If payDateOnly < reportFrom Or payDateOnly > reportTo Then GoTo NextPayment
        If Not TryParseNumber(wsP.Cells(i, colAmount).Value, amount) Then GoTo NextPayment
        If Not TryParseNumber(wsP.Cells(i, colRefundedAmount).Value, amountRefunded) Then amountRefunded = 0

        paymentCurrency = UCase$(Trim$(CStr(wsP.Cells(i, colCurrency).Value)))
        refundDate = Trim$(CStr(wsP.Cells(i, colRefundedDate).Value))
        disputeDate = Trim$(CStr(wsP.Cells(i, colDisputeDate).Value))
        custEmail = NormalizeEmail(wsP.Cells(i, colEmail).Value)
        customerUID = vbNullString
        If colCustomerID > 0 Then customerUID = Trim$(CStr(wsP.Cells(i, colCustomerID).Value))

        If amount <= 0 Then GoTo NextPayment
        If amountRefunded > 0 Then GoTo NextPayment
        If refundDate <> vbNullString Then GoTo NextPayment
        If disputeDate <> vbNullString Then GoTo NextPayment
        If custEmail = vbNullString Then GoTo NextPayment

        Dim coupon As String
        Dim affiliateName As String
        coupon = vbNullString
        affiliateName = vbNullString
        If couponByEmail.Exists(custEmail) Then coupon = Trim$(CStr(couponByEmail(custEmail)))
        If affiliateByEmail.Exists(custEmail) Then affiliateName = Trim$(CStr(affiliateByEmail(custEmail)))
        If Not CouponIsAllowed(coupon, couponFilters) Then GoTo NextPayment

        Dim rate As Double
        Dim amountEUR As Double
        Select Case paymentCurrency
            Case "EUR"
                rate = 1
                amountEUR = amount
            Case "USD"
                rate = GetRate(payDateOnly)
                amountEUR = amount / rate
            Case Else
                GoTo NextPayment
        End Select

        Dim commissionEUR As Double
        commissionEUR = Round(amountEUR * commissionRate, 2)

        wsR.Cells(outRow, 1).Value = payDateOnly
        SetNumberFormatSafe wsR.Cells(outRow, 1), "dd/mm/yyyy"
        wsR.Cells(outRow, 2).Value = MaskCustomer(customerUID, custEmail)
        wsR.Cells(outRow, 3).Value = coupon
        wsR.Cells(outRow, 4).Value = affiliateName
        wsR.Cells(outRow, 5).Value = Round(amountEUR, 2)
        SetNumberFormatSafe wsR.Cells(outRow, 5), "#,##0.00"
        wsR.Cells(outRow, 6).Value = commissionEUR
        SetNumberFormatSafe wsR.Cells(outRow, 6), "#,##0.00"
        wsR.Cells(outRow, 7).Value = payID
        wsR.Cells(outRow, 8).Value = amount
        SetNumberFormatSafe wsR.Cells(outRow, 8), "#,##0.00"
        wsR.Cells(outRow, 9).Value = paymentCurrency
        wsR.Cells(outRow, 10).Value = Round(rate, 4)
        SetNumberFormatSafe wsR.Cells(outRow, 10), "0.0000"

        UpdateInfluencerSummary summary, uniqueCustomers, coupon, affiliateName, customerUID, custEmail, amountEUR, commissionEUR
        outRow = outRow + 1

NextPayment:
    Next i

    WriteInfluencerSummary wsR, summary, uniqueCustomers
    wsR.Range("B4").Value = commissionRate
    SetNumberFormatSafe wsR.Range("B4"), "0.00%"
    wsR.Cells(5, 1).Value = "Last generated"
    wsR.Cells(5, 2).Value = Now
    SetNumberFormatSafe wsR.Cells(5, 2), "dd/mm/yyyy hh:mm:ss"

    MsgBox "Influencer report generated." & vbCrLf & _
           "Transactions: " & (outRow - 8) & vbCrLf & _
           "Commission rate: " & Format$(commissionRate, "0.00%"), vbInformation
    Exit Sub

CleanFail:
    MsgBox "GenerateInfluencerReport failed:" & vbCrLf & _
           "Error " & Err.Number & ": " & Err.Description, vbCritical
End Sub

' ---------------------------------------------
' BOTTONE 3: Invia a FirstPromoter
' ---------------------------------------------
Public Sub SendToFirstPromoter()
    On Error GoTo CleanFail

    Dim wsO As Worksheet
    Dim wsLog As Worksheet
    Set wsO = GetToolWorksheet(SHEET_FILTER_OUTPUT)
    Set wsLog = GetWritableFirstPromoterLogWorksheet(GetToolWorksheet(SHEET_FP_IMPORT_LOG))

    If Not IsFirstPromoterV2() Then
        MsgBox "Referral-only import requires FirstPromoter API v2." & vbCrLf & _
               "Create workbook named ranges FP_API_KEY and FP_ACCOUNT_ID first.", vbCritical
        Exit Sub
    End If

    Dim apiKey As String
    apiKey = GetFirstPromoterApiKey()

    Dim lastRow As Long
    lastRow = wsO.Cells(wsO.Rows.Count, 1).End(xlUp).Row

    If lastRow < OUTPUT_FIRST_ROW Then
        MsgBox "No data in output. Run Generate Output first.", vbExclamation
        Exit Sub
    End If

    Dim confirm As VbMsgBoxResult
    confirm = MsgBox("Import referrals only for " & (lastRow - OUTPUT_FIRST_ROW + 1) & " output rows?" & vbCrLf & vbCrLf & _
                     "No sales, commissions, or payouts will be created." & vbCrLf & _
                     "Every attempted row will be written to " & wsLog.Name & ".", vbYesNo + vbQuestion)
    If confirm = vbNo Then Exit Sub

    Dim logRow As Long
    logRow = NextFirstPromoterLogRow(wsLog)

    Dim i As Long
    Dim importedCount As Long
    Dim existingCount As Long
    Dim errorCount As Long
    Dim skippedCount As Long
    importedCount = 0
    existingCount = 0
    errorCount = 0
    skippedCount = 0

    For i = OUTPUT_FIRST_ROW To lastRow
        Dim stage As String
        Dim payID As String
        Dim payDate As Date
        Dim custEmail As String
        Dim coupon As String
        Dim customerUID As String
        Dim amountEUR As Double
        Dim requestPayload As String
        Dim fpStatus As Long
        Dim fpResponse As String
        Dim resultLabel As String

        stage = "Read row"
        payID = vbNullString
        custEmail = vbNullString
        coupon = vbNullString
        customerUID = vbNullString
        amountEUR = 0
        requestPayload = vbNullString
        fpStatus = 0
        fpResponse = vbNullString
        resultLabel = vbNullString

        On Error GoTo RowFailed

        payID = Trim$(CStr(wsO.Cells(i, 1).Value))
        If payID = vbNullString Then
            skippedCount = skippedCount + 1
            GoTo RowComplete
        End If

        Dim importState As String
        importState = UCase$(Trim$(CStr(wsO.Cells(i, 11).Value)))
        If importState = "REFERRAL IMPORTED" Or importState = "REFERRAL EXISTS" Then
            skippedCount = skippedCount + 1
            GoTo RowComplete
        End If

        stage = "Validate historical date"
        If Not TryParseDate(wsO.Cells(i, 2).Value, payDate) Then
            Err.Raise vbObjectError + 1701, "SendToFirstPromoter", "Invalid historical date in Filter_Output column B."
        End If

        stage = "Validate customer email"
        custEmail = NormalizeEmail(wsO.Cells(i, 3).Value)
        If custEmail = vbNullString Or InStr(1, custEmail, "@", vbTextCompare) = 0 Then
            Err.Raise vbObjectError + 1702, "SendToFirstPromoter", "Missing or invalid customer email in Filter_Output column C."
        End If

        stage = "Validate ref_id / coupon"
        coupon = Trim$(CStr(wsO.Cells(i, 4).Value))
        If coupon = vbNullString Then
            Err.Raise vbObjectError + 1703, "SendToFirstPromoter", "Missing ref_id / coupon in Filter_Output column D."
        End If

        stage = "Validate Stripe customer uid"
        customerUID = Trim$(CStr(wsO.Cells(i, 12).Value))
        If customerUID = vbNullString Then
            Err.Raise vbObjectError + 1706, "SendToFirstPromoter", "Missing Stripe Customer ID / uid in Filter_Output column L."
        End If

        Call TryParseNumber(wsO.Cells(i, 8).Value, amountEUR)

        stage = "Build FirstPromoter signup payload"
        requestPayload = BuildFirstPromoterSignupJson(payDate, custEmail, coupon, customerUID)

        stage = "HTTP signup request to FirstPromoter"
        Call PostFirstPromoterSignup(requestPayload, apiKey, fpStatus, fpResponse)
        resultLabel = FirstPromoterReferralResultLabel(fpStatus)

        stage = "Write FirstPromoter log"
        WriteFirstPromoterLog wsLog, logRow, i, stage, payID, coupon, amountEUR, fpStatus, resultLabel, fpResponse, requestPayload
        logRow = logRow + 1

        stage = "Update Filter_Output status"
        Select Case fpStatus
            Case 200
                SetImportStatusSafe wsO, i, "Referral Imported", RGB(212, 237, 218)
                importedCount = importedCount + 1
            Case 422
                SetImportStatusSafe wsO, i, "Referral Exists", RGB(255, 243, 205)
                existingCount = existingCount + 1
            Case Else
                SetImportStatusSafe wsO, i, "Referral Error", RGB(248, 215, 218)
                errorCount = errorCount + 1
        End Select

        SleepMs FP_SIGNUP_DELAY_MS
        GoTo RowComplete

RowFailed:
        Dim rowErrNumber As Long
        Dim rowErrDescription As String
        rowErrNumber = Err.Number
        rowErrDescription = Err.Description
        Err.Clear

        fpStatus = 0
        resultLabel = "VBA error before/during referral import"
        fpResponse = "Stage: " & stage & " | Error " & rowErrNumber & ": " & rowErrDescription

        On Error GoTo RowLogFailed
        WriteFirstPromoterLog wsLog, logRow, i, stage, payID, coupon, amountEUR, fpStatus, resultLabel, fpResponse, requestPayload
        logRow = logRow + 1
        SetImportStatusSafe wsO, i, "Referral Error", RGB(248, 215, 218)
        errorCount = errorCount + 1
        On Error GoTo CleanFail
        GoTo RowComplete

RowLogFailed:
        MsgBox "Cannot write to log sheet." & vbCrLf & _
               "Output row: " & i & vbCrLf & _
               "Original stage: " & stage & vbCrLf & _
               "Original error: " & rowErrNumber & " - " & rowErrDescription & vbCrLf & _
               "Log error: " & Err.Number & " - " & Err.Description, vbCritical
        Exit Sub

RowComplete:
        On Error GoTo CleanFail
    Next i

    MsgBox "Referral import complete." & vbCrLf & _
           "Imported: " & importedCount & vbCrLf & _
           "Already existed: " & existingCount & vbCrLf & _
           "Errors: " & errorCount & vbCrLf & _
           "Skipped: " & skippedCount, vbInformation
    Exit Sub

CleanFail:
    MsgBox "SendToFirstPromoter failed before row processing/logging:" & vbCrLf & _
           "Error " & Err.Number & ": " & Err.Description, vbCritical
End Sub

Private Function GetWritableFirstPromoterLogWorksheet(ByVal preferredLog As Worksheet) As Worksheet
    On Error Resume Next
    Err.Clear
    EnsureFirstPromoterLogHeaders preferredLog
    If Err.Number = 0 Then
        Set GetWritableFirstPromoterLogWorksheet = preferredLog
        On Error GoTo 0
        Exit Function
    End If

    Dim preferredError As String
    preferredError = "FP_Import_Log not writable: " & Err.Number & " - " & Err.Description
    Err.Clear
    On Error GoTo 0

    Dim debugLog As Worksheet
    Set debugLog = GetOrCreateWorksheet(SHEET_FP_DEBUG_LOG)
    EnsureFirstPromoterLogHeaders debugLog

    Dim debugRow As Long
    debugRow = NextFirstPromoterLogRow(debugLog)
    debugLog.Cells(debugRow, 1).Value = Now
    debugLog.Cells(debugRow, 2).Value = 0
    debugLog.Cells(debugRow, 3).Value = "LOG_FALLBACK"
    debugLog.Cells(debugRow, 7).Value = "Using FP_Debug_Log"
    debugLog.Cells(debugRow, 8).Value = preferredError
    debugLog.Cells(debugRow, 10).Value = FirstPromoterApiMode()

    Set GetWritableFirstPromoterLogWorksheet = debugLog
End Function

Private Function GetOrCreateWorksheet(ByVal sheetName As String) As Worksheet
    Dim wb As Workbook
    Set wb = GetToolWorkbook()

    Dim ws As Worksheet
    For Each ws In wb.Worksheets
        If NormalizeSheetName(ws.Name) = NormalizeSheetName(sheetName) Then
            Set GetOrCreateWorksheet = ws
            Exit Function
        End If
    Next ws

    Set ws = wb.Worksheets.Add(After:=wb.Worksheets(wb.Worksheets.Count))
    ws.Name = sheetName
    Set GetOrCreateWorksheet = ws
End Function

Private Sub EnsureFirstPromoterLogHeaders(ByVal wsLog As Worksheet)
    On Error GoTo HeaderFailed

    wsLog.Cells(3, 1).Value = "Timestamp"
    wsLog.Cells(3, 2).Value = "Output Row"
    wsLog.Cells(3, 3).Value = "Payment ID"
    wsLog.Cells(3, 4).Value = "Coupon/Promo Code"
    wsLog.Cells(3, 5).Value = "Amount EUR"
    wsLog.Cells(3, 6).Value = "HTTP Status"
    wsLog.Cells(3, 7).Value = "Result"
    wsLog.Cells(3, 8).Value = "Response / VBA Error"
    wsLog.Cells(3, 9).Value = "Payload"
    wsLog.Cells(3, 10).Value = "API Mode"
    Exit Sub

HeaderFailed:
    Err.Raise vbObjectError + 1801, "EnsureFirstPromoterLogHeaders", _
        "Cannot write headers to FP_Import_Log. Is the sheet protected or locked? " & _
        "Excel error " & Err.Number & ": " & Err.Description
End Sub

Private Function NextFirstPromoterLogRow(ByVal wsLog As Worksheet) As Long
    Dim lastRow As Long
    lastRow = wsLog.Cells(wsLog.Rows.Count, 1).End(xlUp).Row
    If lastRow < MAP_FIRST_ROW Then
        NextFirstPromoterLogRow = MAP_FIRST_ROW
    Else
        NextFirstPromoterLogRow = lastRow + 1
    End If
End Function

Private Sub WriteFirstPromoterLog(ByVal wsLog As Worksheet, _
                                   ByVal logRow As Long, _
                                   ByVal outputRow As Long, _
                                   ByVal stage As String, _
                                   ByVal payID As String, _
                                   ByVal coupon As String, _
                                   ByVal amountEUR As Double, _
                                   ByVal fpStatus As Long, _
                                   ByVal resultLabel As String, _
                                   ByVal fpResponse As String, _
                                   ByVal requestPayload As String)
    On Error GoTo LogFailed

    wsLog.Cells(logRow, 1).Value = Now
    SetNumberFormatSafe wsLog.Cells(logRow, 1), "dd/mm/yyyy hh:mm:ss"
    wsLog.Cells(logRow, 2).Value = outputRow
    wsLog.Cells(logRow, 3).Value = payID
    wsLog.Cells(logRow, 4).Value = coupon
    wsLog.Cells(logRow, 5).Value = Round(amountEUR, 2)
    SetNumberFormatSafe wsLog.Cells(logRow, 5), "#,##0.00"
    wsLog.Cells(logRow, 6).Value = fpStatus
    wsLog.Cells(logRow, 7).Value = resultLabel
    wsLog.Cells(logRow, 8).Value = fpResponse
    wsLog.Cells(logRow, 9).Value = requestPayload
    wsLog.Cells(logRow, 10).Value = FirstPromoterApiMode()
    Exit Sub

LogFailed:
    Err.Raise vbObjectError + 1802, "WriteFirstPromoterLog", _
        "Cannot write diagnostic log row " & logRow & " to FP_Import_Log. Stage: " & stage & _
        ". Excel error " & Err.Number & ": " & Err.Description
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
' Test: invia solo la riga selezionata come referral/signup
' ---------------------------------------------
Public Sub TestFirstPromoterSignupSelectedRow()
    On Error GoTo CleanFail

    Dim wsO As Worksheet
    Set wsO = GetToolWorksheet(SHEET_FILTER_OUTPUT)

    If ActiveCell Is Nothing Or NormalizeSheetName(ActiveCell.Worksheet.Name) <> NormalizeSheetName(wsO.Name) Then
        MsgBox "Select one output row in Filter_Output first.", vbExclamation
        Exit Sub
    End If

    Dim rowNumber As Long
    rowNumber = ActiveCell.Row
    If rowNumber < OUTPUT_FIRST_ROW Then Err.Raise vbObjectError + 1650, "TestFirstPromoterSignupSelectedRow", "Select a transaction row from row " & OUTPUT_FIRST_ROW & " onward."

    Dim payDate As Date
    Dim custEmail As String
    Dim coupon As String
    Dim customerUID As String
    Dim payload As String
    Dim fpStatus As Long
    Dim fpResponse As String

    If Not TryParseDate(wsO.Cells(rowNumber, 2).Value, payDate) Then Err.Raise vbObjectError + 1651, "TestFirstPromoterSignupSelectedRow", "Invalid date in column B."
    custEmail = NormalizeEmail(wsO.Cells(rowNumber, 3).Value)
    coupon = Trim$(CStr(wsO.Cells(rowNumber, 4).Value))
    customerUID = Trim$(CStr(wsO.Cells(rowNumber, 12).Value))

    If custEmail = vbNullString Then Err.Raise vbObjectError + 1652, "TestFirstPromoterSignupSelectedRow", "Missing email in column C."
    If coupon = vbNullString Then Err.Raise vbObjectError + 1653, "TestFirstPromoterSignupSelectedRow", "Missing ref_id/coupon in column D."
    If customerUID = vbNullString Then Err.Raise vbObjectError + 1654, "TestFirstPromoterSignupSelectedRow", "Missing uid / Stripe Customer ID in column L."

    payload = BuildFirstPromoterSignupJson(payDate, custEmail, coupon, customerUID)
    Call PostFirstPromoterSignup(payload, GetFirstPromoterApiKey(), fpStatus, fpResponse)

    MsgBox "FirstPromoter signup test" & vbCrLf & _
           "HTTP status: " & fpStatus & vbCrLf & _
           "Response:" & vbCrLf & fpResponse & vbCrLf & vbCrLf & _
           "Payload:" & vbCrLf & payload, vbInformation
    Exit Sub

CleanFail:
    MsgBox "TestFirstPromoterSignupSelectedRow failed:" & vbCrLf & _
           "Error " & Err.Number & ": " & Err.Description, vbCritical
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
    Dim customerUID As String
    Dim amountEUR As Double

    payID = Trim$(CStr(wsO.Cells(rowNumber, 1).Value))
    If payID = vbNullString Then Err.Raise vbObjectError + 1601, "DiagnoseFirstPromoterSelectedRow", "Missing Stripe payment id in column A."
    If Not TryParseDate(wsO.Cells(rowNumber, 2).Value, payDate) Then Err.Raise vbObjectError + 1602, "DiagnoseFirstPromoterSelectedRow", "Invalid payment date in column B."

    custEmail = NormalizeEmail(wsO.Cells(rowNumber, 3).Value)
    If custEmail = vbNullString Or InStr(1, custEmail, "@", vbTextCompare) = 0 Then Err.Raise vbObjectError + 1603, "DiagnoseFirstPromoterSelectedRow", "Missing or invalid customer email in column C."

    coupon = Trim$(CStr(wsO.Cells(rowNumber, 4).Value))
    If coupon = vbNullString Then Err.Raise vbObjectError + 1604, "DiagnoseFirstPromoterSelectedRow", "Missing promo/tracking coupon in column D."
    customerUID = Trim$(CStr(wsO.Cells(rowNumber, 12).Value))

    Call TryParseNumber(wsO.Cells(rowNumber, 8).Value, amountEUR)
    If customerUID = vbNullString Then Err.Raise vbObjectError + 1605, "DiagnoseFirstPromoterSelectedRow", "Missing Stripe Customer ID / uid in column L."

    Call GetFirstPromoterApiKey
    If Not IsFirstPromoterV2() Then Err.Raise vbObjectError + 1606, "DiagnoseFirstPromoterSelectedRow", "Referral-only import requires FP_ACCOUNT_ID / API v2."

    Dim requestPayload As String
    requestPayload = BuildFirstPromoterSignupJson(payDate, custEmail, coupon, customerUID)

    MsgBox "Local validation OK. No request was sent." & vbCrLf & vbCrLf & _
           "Checks:" & vbCrLf & _
           "- column D is sent as ref_id." & vbCrLf & _
           "- email is the Stripe customer/lead email, not the promoter email." & vbCrLf & _
           "- column L is sent as uid (Stripe customer id)." & vbCrLf & _
           "- no sales, commissions, or payouts are created by referral-only import." & vbCrLf & _
           "- API mode: " & FirstPromoterApiMode() & vbCrLf & vbCrLf & _
           "Signup payload:" & vbCrLf & requestPayload, vbInformation
    Exit Sub

CleanFail:
    MsgBox "DiagnoseFirstPromoterSelectedRow failed:" & vbCrLf & _
           "Error " & Err.Number & ": " & Err.Description, vbCritical
End Sub

Private Function IsImportablePayoutStatus(ByVal payoutStatus As String) As Boolean
    Select Case UCase$(Trim$(payoutStatus))
        Case "TO BE PAID"
            IsImportablePayoutStatus = True
        Case "ALREADY PAID"
            IsImportablePayoutStatus = FP_IMPORT_ALREADY_PAID
        Case Else
            IsImportablePayoutStatus = False
    End Select
End Function

Private Function IsAlreadyPaidPayoutStatus(ByVal payoutStatus As String) As Boolean
    IsAlreadyPaidPayoutStatus = (UCase$(Trim$(payoutStatus)) = "ALREADY PAID")
End Function

Private Sub MarkHistoricalCommissionPaid(ByVal eventID As String, _
                                         ByVal apiKey As String, _
                                         ByRef fpStatus As Long, _
                                         ByRef fpResponse As String, _
                                         ByRef resultLabel As String)
    If Not IsFirstPromoterV2() Then
        fpStatus = 0
        resultLabel = "Already Paid requires v2 commission API"
        fpResponse = fpResponse & " | Cannot mark paid without FP_ACCOUNT_ID / v2 API."
        Exit Sub
    End If

    If fpStatus <> 200 And fpStatus <> 409 Then
        resultLabel = "Sale failed before mark-paid"
        Exit Sub
    End If

    Dim saleResponse As String
    saleResponse = fpResponse

    Dim findStatus As Long
    Dim findResponse As String
    Dim commissionID As String
    Call FindFirstPromoterCommissionID(eventID, apiKey, findStatus, findResponse, commissionID)

    If findStatus <> 200 Or commissionID = vbNullString Then
        fpStatus = 0
        resultLabel = "MARK PAID FAILED - commission not found"
        fpResponse = "Sale HTTP " & CStr(fpStatus) & ": " & Left$(saleResponse, 180) & _
            " | Find commission HTTP " & CStr(findStatus) & ": " & Left$(findResponse, 300)
        Exit Sub
    End If

    Dim markStatus As Long
    Dim markResponse As String
    Call MarkFirstPromoterCommissionPaid(commissionID, apiKey, markStatus, markResponse)

    If markStatus = 200 Then
        fpStatus = 200
        resultLabel = "Historical sale imported and marked paid"
        fpResponse = "Sale: " & Left$(saleResponse, 180) & _
            " | Commission ID " & commissionID & " marked paid: " & Left$(markResponse, 300)
    Else
        fpStatus = 0
        resultLabel = "MARK PAID FAILED - commission remains payable"
        fpResponse = "Sale: " & Left$(saleResponse, 160) & _
            " | Commission ID " & commissionID & " mark paid HTTP " & CStr(markStatus) & ": " & Left$(markResponse, 300)
    End If
End Sub

Private Sub FindFirstPromoterCommissionID(ByVal eventID As String, _
                                          ByVal apiKey As String, _
                                          ByRef fpStatus As Long, _
                                          ByRef fpResponse As String, _
                                          ByRef commissionID As String)
    Call FirstPromoterV2Request("GET", FP_COMMISSIONS_URL_V2 & "?q=" & UrlEncode(eventID), vbNullString, apiKey, fpStatus, fpResponse)
    If fpStatus = 200 Then commissionID = ExtractFirstJsonNumberByKey(fpResponse, "id")
End Sub

Private Sub MarkFirstPromoterCommissionPaid(ByVal commissionID As String, _
                                            ByVal apiKey As String, _
                                            ByRef fpStatus As Long, _
                                            ByRef fpResponse As String)
    Dim jsonPayload As String
    jsonPayload = "{" & JsonString("is_paid") & ":true," & _
        JsonString("internal_note") & ":" & JsonString("Historical import - already paid before FirstPromoter migration") & "}"

    Call FirstPromoterV2Request("PUT", FP_COMMISSIONS_URL_V2 & "/" & commissionID, jsonPayload, apiKey, fpStatus, fpResponse)
End Sub

Private Function ExtractFirstJsonNumberByKey(ByVal jsonText As String, ByVal keyName As String) As String
    Dim keyPattern As String
    keyPattern = Chr$(34) & keyName & Chr$(34) & ":"

    Dim pos As Long
    pos = InStr(1, jsonText, keyPattern, vbTextCompare)
    If pos = 0 Then Exit Function

    pos = pos + Len(keyPattern)
    Do While pos <= Len(jsonText) And Mid$(jsonText, pos, 1) = " "
        pos = pos + 1
    Loop

    Dim startPos As Long
    startPos = pos
    Do While pos <= Len(jsonText) And Mid$(jsonText, pos, 1) Like "[0-9]"
        pos = pos + 1
    Loop

    If pos > startPos Then ExtractFirstJsonNumberByKey = Mid$(jsonText, startPos, pos - startPos)
End Function

Private Function FirstPromoterReferralResultLabel(ByVal fpStatus As Long) As String
    Select Case fpStatus
        Case 200
            FirstPromoterReferralResultLabel = "Referral imported"
        Case 422
            FirstPromoterReferralResultLabel = "Referral already exists"
        Case 400
            FirstPromoterReferralResultLabel = "Bad request - check signup payload"
        Case 401, 403
            FirstPromoterReferralResultLabel = "Authentication/authorization error"
        Case 404
            FirstPromoterReferralResultLabel = "ref_id not found or invalid"
        Case 0
            FirstPromoterReferralResultLabel = "VBA/WinHTTP error"
        Case Else
            FirstPromoterReferralResultLabel = "HTTP " & CStr(fpStatus)
    End Select
End Function

Private Function FirstPromoterResultLabel(ByVal fpStatus As Long) As String
    Select Case fpStatus
        Case 200
            FirstPromoterResultLabel = "Tracked sale - commission generated"
        Case 204
            FirstPromoterResultLabel = "No referral sale - no commission generated (v1)"
        Case 404
            FirstPromoterResultLabel = "No referral found or promoter banned (v2)"
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

Private Sub PostFirstPromoterSale(ByVal requestPayload As String, _
                                  ByVal apiKey As String, _
                                  ByVal payDate As Date, _
                                  ByVal custEmail As String, _
                                  ByVal coupon As String, _
                                  ByVal customerUID As String, _
                                  ByRef fpStatus As Long, _
                                  ByRef fpResponse As String)
    If IsFirstPromoterV2() Then
        If GetConfigValue("FP_LEGACY_API_KEY", FP_LEGACY_API_KEY_HARDCODED) = vbNullString Then
            fpStatus = 0
            fpResponse = "Missing FP_LEGACY_API_KEY. No signup or sale was sent because customer_since cannot be backdated safely."
            Exit Sub
        End If

        Dim signupStatus As Long
        Dim signupResponse As String
        Dim signupPayload As String
        signupPayload = BuildFirstPromoterSignupJson(payDate, custEmail, coupon, customerUID)

        Call PostFirstPromoterSignup(signupPayload, apiKey, signupStatus, signupResponse)
        If signupStatus <> 200 And signupStatus <> 422 Then
            fpStatus = signupStatus
            fpResponse = "Signup failed; sale not sent: " & signupResponse & " | Signup payload: " & signupPayload
            Exit Sub
        End If

        Dim customerSinceStatus As Long
        Dim customerSinceResponse As String
        Call UpdateFirstPromoterCustomerSince(payDate, custEmail, coupon, customerUID, customerSinceStatus, customerSinceResponse)
        If customerSinceStatus <> 200 Then
            fpStatus = customerSinceStatus
            fpResponse = "customer_since backdate failed; sale not sent. Signup HTTP " & CStr(signupStatus) & _
                ": " & Left$(signupResponse, 160) & " | customer_since response: " & customerSinceResponse
            Exit Sub
        End If

        Call FirstPromoterV2Request("POST", FP_TRACK_URL_V2, requestPayload, apiKey, fpStatus, fpResponse)
        fpResponse = "Signup HTTP " & CStr(signupStatus) & ": " & Left$(signupResponse, 120) & _
            " | customer_since HTTP " & CStr(customerSinceStatus) & ": " & Left$(customerSinceResponse, 120) & _
            " | Sale: " & fpResponse
    Else
        Call FirstPromoterLegacyRequest("POST", FP_TRACK_URL_V1 & "?" & requestPayload, GetFirstPromoterApiKey(), fpStatus, fpResponse)
    End If
End Sub

Private Sub UpdateFirstPromoterCustomerSince(ByVal customerSinceDate As Date, _
                                             ByVal custEmail As String, _
                                             ByVal coupon As String, _
                                             ByVal customerUID As String, _
                                             ByRef fpStatus As Long, _
                                             ByRef fpResponse As String)
    Dim legacyApiKey As String
    legacyApiKey = GetFirstPromoterLegacyApiKey()

    Dim queryString As String
    If Trim$(customerUID) <> vbNullString Then
        queryString = "uid=" & UrlEncode(Trim$(customerUID))
    Else
        queryString = "email=" & UrlEncode(NormalizeEmail(custEmail))
    End If

    queryString = queryString & _
        "&state=active" & _
        "&customer_since=" & UrlEncode(Format$(customerSinceDate, "yyyy-mm-dd\Thh:nn:ss\Z"))

    Call FirstPromoterLegacyRequest("PUT", FP_LEAD_UPDATE_URL_V1 & "?" & queryString, legacyApiKey, fpStatus, fpResponse)
End Sub

Private Sub PostFirstPromoterJson(ByVal url As String, _
                                  ByVal jsonPayload As String, _
                                  ByVal apiKey As String, _
                                  ByRef fpStatus As Long, _
                                  ByRef fpResponse As String)
    Call FirstPromoterV2Request("POST", url, jsonPayload, apiKey, fpStatus, fpResponse)
End Sub

Private Sub PostFirstPromoterSignup(ByVal jsonPayload As String, _
                                      ByVal apiKey As String, _
                                      ByRef fpStatus As Long, _
                                      ByRef fpResponse As String)
    Dim attempt As Long
    Dim waitMs As Long

    For attempt = 0 To FP_RATE_LIMIT_MAX_RETRIES
        Call PostFirstPromoterSignupOnce(jsonPayload, apiKey, fpStatus, fpResponse)

        If fpStatus <> 429 Then
            Application.StatusBar = False
            Exit Sub
        End If

        If attempt < FP_RATE_LIMIT_MAX_RETRIES Then
            waitMs = FP_RATE_LIMIT_BASE_WAIT_MS * (attempt + 1)
            Application.StatusBar = "FirstPromoter rate limit (429). Waiting " & Format$(waitMs / 1000, "0") & " seconds before retry " & (attempt + 1) & "..."
            SleepMs waitMs
        End If
    Next attempt

    fpResponse = "Rate limit persisted after " & (FP_RATE_LIMIT_MAX_RETRIES + 1) & " attempts. Last response: " & fpResponse
    Application.StatusBar = False
End Sub

Private Sub PostFirstPromoterSignupOnce(ByVal jsonPayload As String, _
                                          ByVal apiKey As String, _
                                          ByRef fpStatus As Long, _
                                          ByRef fpResponse As String)
    On Error GoTo RequestFailed

    ' Dedicated, Postman-equivalent request for referral-only imports.
    ' Do not route this through generic helpers: this endpoint only needs JSON signup.
    Dim http As Object
    Set http = CreateObject("MSXML2.ServerXMLHTTP.6.0")

    http.setTimeouts 5000, 10000, 30000, 30000
    http.Open "POST", FP_SIGNUP_URL_V2, False
    http.setRequestHeader "Content-Type", "application/json"
    http.setRequestHeader "Accept", "application/json"
    http.setRequestHeader "Authorization", "Bearer " & NormalizeBearerToken(apiKey)
    http.setRequestHeader "Account-ID", NormalizeAccountID(GetFirstPromoterAccountID())
    http.Send CStr(jsonPayload)

    fpStatus = CLng(http.Status)
    fpResponse = Left$(CStr(http.responseText), 1000)
    Exit Sub

RequestFailed:
    fpStatus = 0
    fpResponse = "Signup HTTP error " & Err.Number & ": " & Err.Description
End Sub

Private Sub FirstPromoterV2Request(ByVal method As String, _
                                   ByVal url As String, _
                                   ByVal jsonPayload As String, _
                                   ByVal apiKey As String, _
                                   ByRef fpStatus As Long, _
                                   ByRef fpResponse As String)
    On Error GoTo RequestFailed

    Dim hasJsonBody As Boolean
    hasJsonBody = (Len(jsonPayload) > 0)

    Dim http As Object
    Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
    http.SetTimeouts 5000, 10000, 30000, 30000
    http.Open method, url, False
    http.SetRequestHeader "Accept", "application/json"
    If hasJsonBody Then http.SetRequestHeader "Content-Type", "application/json"
    http.SetRequestHeader "Authorization", "Bearer " & NormalizeBearerToken(apiKey)
    http.SetRequestHeader "Account-ID", NormalizeAccountID(GetFirstPromoterAccountID())
    http.SetRequestHeader "User-Agent", "Excel VBA FirstPromoter Import Tool"
    http.Send IIf(hasJsonBody, jsonPayload, vbNullString)

    fpStatus = CLng(http.Status)
    fpResponse = Left$(CStr(http.ResponseText), 1000)
    Exit Sub

RequestFailed:
    fpStatus = 0
    fpResponse = "WinHTTP " & method & " error " & Err.Number & ": " & Err.Description & " | URL: " & url
End Sub

Private Sub FirstPromoterLegacyRequest(ByVal method As String, _
                                       ByVal url As String, _
                                       ByVal legacyApiKey As String, _
                                       ByRef fpStatus As Long, _
                                       ByRef fpResponse As String)
    On Error GoTo RequestFailed

    Dim http As Object
    Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
    http.SetTimeouts 5000, 10000, 30000, 30000
    http.Open method, url, False
    http.SetRequestHeader "Accept", "application/json"
    http.SetRequestHeader "X-API-KEY", NormalizeBearerToken(legacyApiKey)
    http.SetRequestHeader "User-Agent", "Excel VBA FirstPromoter Import Tool"
    http.Send vbNullString

    fpStatus = CLng(http.Status)
    fpResponse = Left$(CStr(http.ResponseText), 1000)
    Exit Sub

RequestFailed:
    fpStatus = 0
    fpResponse = "WinHTTP legacy " & method & " error " & Err.Number & ": " & Err.Description & " | URL: " & url
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

Private Function DateRangesOverlap(ByVal firstFrom As Date, _
                                   ByVal firstTo As Date, _
                                   ByVal secondFrom As Date, _
                                   ByVal secondTo As Date) As Boolean
    DateRangesOverlap = (DateValue(firstFrom) <= DateValue(secondTo) And DateValue(secondFrom) <= DateValue(firstTo))
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
                                  ByRef colCustomerID As Long, _
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
        colCustomerID = FindFirstHeaderColumnInRow(ws, headerRow, Array("Customer ID", "Customer Id", "Customer", "Stripe Customer ID", "Stripe Customer Id"))
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
    colCustomerID = 9 ' Optional Stripe customer id in column I.
    colDisputeDate = 8
End Sub

Private Function FindFirstHeaderColumnInRow(ByVal ws As Worksheet, ByVal rowNumber As Long, ByVal headerNames As Variant) As Long
    Dim i As Long
    For i = LBound(headerNames) To UBound(headerNames)
        FindFirstHeaderColumnInRow = FindHeaderColumnInRow(ws, rowNumber, CStr(headerNames(i)))
        If FindFirstHeaderColumnInRow > 0 Then Exit Function
    Next i
End Function

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

Private Sub SetupInfluencerReportSheet(ByVal ws As Worksheet)
    ws.Cells(1, 1).Value = "Influencer report"
    ws.Cells(2, 1).Value = "Date from"
    ws.Cells(2, 3).Value = "Date to"
    ws.Cells(3, 1).Value = "Coupons"
    ws.Cells(3, 3).Value = "Comma-separated coupon list in B3; leave B3 blank for all mapped coupons"
    ws.Cells(4, 1).Value = "Commission rate"
    If Trim$(CStr(ws.Range("B4").Value)) = vbNullString Then
        ws.Range("B4").Value = 0.095
        SetNumberFormatSafe ws.Range("B4"), "0.00%"
    End If
End Sub

Private Sub WriteInfluencerReportHeaders(ByVal ws As Worksheet)
    ws.Range("A6").Value = "Details"
    ws.Range("A7:J7").Value = Array("Date", "Customer", "Coupon", "Affiliate", "Revenue EUR", "Commission EUR", "Payment ID", "Amount orig", "Currency", "Rate EUR/USD")
    ws.Range("L6").Value = "Summary by coupon / affiliate"
    ws.Range("L7:Q7").Value = Array("Coupon", "Affiliate", "Sales", "Unique Customers", "Revenue EUR", "Commission EUR")
End Sub

Private Function GetCommissionRate(ByVal value As Variant) As Double
    Dim textValue As String
    textValue = Trim$(CStr(value))

    If textValue = vbNullString Then
        GetCommissionRate = 0.095
        Exit Function
    End If

    Dim hasPercent As Boolean
    hasPercent = (InStr(1, textValue, "%", vbTextCompare) > 0)
    textValue = Replace$(textValue, "%", vbNullString)

    Dim parsed As Double
    If Not TryParseNumber(textValue, parsed) Then
        Err.Raise vbObjectError + 1910, "GetCommissionRate", "Invalid commission rate. Use 9.5% or 0.095."
    End If

    If hasPercent Or parsed > 1 Then parsed = parsed / 100
    If parsed < 0 Then Err.Raise vbObjectError + 1911, "GetCommissionRate", "Commission rate cannot be negative."
    GetCommissionRate = parsed
End Function

Private Function MaskCustomer(ByVal customerUID As String, ByVal email As String) As String
    customerUID = Trim$(customerUID)
    email = NormalizeEmail(email)

    If customerUID <> vbNullString Then
        If Len(customerUID) <= 10 Then
            MaskCustomer = Left$(customerUID, 4) & "..."
        Else
            MaskCustomer = Left$(customerUID, 6) & "..." & Right$(customerUID, 4)
        End If
        Exit Function
    End If

    Dim atPos As Long
    atPos = InStr(1, email, "@", vbTextCompare)
    If atPos > 1 Then
        MaskCustomer = Left$(email, Application.Min(2, atPos - 1)) & "***" & Mid$(email, atPos)
    Else
        MaskCustomer = "anonymous"
    End If
End Function

Private Sub UpdateInfluencerSummary(ByVal summary As Object, _
                                    ByVal uniqueCustomers As Object, _
                                    ByVal coupon As String, _
                                    ByVal affiliateName As String, _
                                    ByVal customerUID As String, _
                                    ByVal email As String, _
                                    ByVal amountEUR As Double, _
                                    ByVal commissionEUR As Double)
    Dim summaryKey As String
    summaryKey = UCase$(Trim$(coupon)) & vbTab & Trim$(affiliateName)

    Dim metrics As Variant
    If summary.Exists(summaryKey) Then
        metrics = summary(summaryKey)
    Else
        metrics = Array(0&, 0#, 0#)
    End If

    metrics(0) = CLng(metrics(0)) + 1
    metrics(1) = CDbl(metrics(1)) + amountEUR
    metrics(2) = CDbl(metrics(2)) + commissionEUR
    summary(summaryKey) = metrics

    Dim customerKey As String
    customerKey = Trim$(customerUID)
    If customerKey = vbNullString Then customerKey = NormalizeEmail(email)
    If customerKey <> vbNullString Then uniqueCustomers(summaryKey & vbTab & customerKey) = True
End Sub

Private Sub WriteInfluencerSummary(ByVal ws As Worksheet, ByVal summary As Object, ByVal uniqueCustomers As Object)
    Dim rowNumber As Long
    rowNumber = 8

    Dim key As Variant
    For Each key In summary.Keys
        Dim parts() As String
        parts = Split(CStr(key), vbTab)

        Dim metrics As Variant
        metrics = summary(key)

        ws.Cells(rowNumber, 12).Value = parts(0)
        If UBound(parts) >= 1 Then ws.Cells(rowNumber, 13).Value = parts(1)
        ws.Cells(rowNumber, 14).Value = CLng(metrics(0))
        ws.Cells(rowNumber, 15).Value = CountUniqueForSummary(uniqueCustomers, CStr(key))
        ws.Cells(rowNumber, 16).Value = Round(CDbl(metrics(1)), 2)
        SetNumberFormatSafe ws.Cells(rowNumber, 16), "#,##0.00"
        ws.Cells(rowNumber, 17).Value = Round(CDbl(metrics(2)), 2)
        SetNumberFormatSafe ws.Cells(rowNumber, 17), "#,##0.00"
        rowNumber = rowNumber + 1
    Next key
End Sub

Private Function CountUniqueForSummary(ByVal uniqueCustomers As Object, ByVal summaryKey As String) As Long
    Dim key As Variant
    Dim prefix As String
    prefix = summaryKey & vbTab

    For Each key In uniqueCustomers.Keys
        If Left$(CStr(key), Len(prefix)) = prefix Then CountUniqueForSummary = CountUniqueForSummary + 1
    Next key
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

Private Function BuildFirstPromoterSalePayload(ByVal payID As String, _
                                             ByVal payDate As Date, _
                                             ByVal custEmail As String, _
                                             ByVal coupon As String, _
                                             ByVal amountEUR As Double, _
                                             ByVal customerUID As String) As String
    If IsFirstPromoterV2() Then
        BuildFirstPromoterSalePayload = BuildFirstPromoterSaleJson(payID, custEmail, coupon, amountEUR, customerUID)
    Else
        BuildFirstPromoterSalePayload = BuildFirstPromoterSaleQuery(payID, payDate, custEmail, coupon, amountEUR, customerUID)
    End If
End Function

Private Function BuildFirstPromoterSaleQuery(ByVal payID As String, _
                                             ByVal payDate As Date, _
                                             ByVal custEmail As String, _
                                             ByVal coupon As String, _
                                             ByVal amountEUR As Double, _
                                             ByVal customerUID As String) As String
    BuildFirstPromoterSaleQuery = "promo_code=" & UrlEncode(Trim$(coupon)) & _
        "&ref_id=" & UrlEncode(Trim$(coupon)) & _
        "&email=" & UrlEncode(NormalizeEmail(custEmail)) & _
        OptionalQueryParam("uid", customerUID) & _
        "&amount=" & CStr(AmountToCents(amountEUR)) & _
        "&currency=eur" & _
        "&event_id=" & UrlEncode(Trim$(payID)) & _
        "&created_at=" & UrlEncode(Format$(payDate, "yyyy-mm-dd\Thh:nn:ss\Z")) & _
        "&skip_email_notification=true"
End Function

Private Function BuildFirstPromoterSaleJson(ByVal payID As String, _
                                            ByVal custEmail As String, _
                                            ByVal coupon As String, _
                                            ByVal amountEUR As Double, _
                                            ByVal customerUID As String) As String
    BuildFirstPromoterSaleJson = "{" & _
        JsonString("promo_code") & ":" & JsonString(Trim$(coupon)) & "," & _
        JsonString("ref_id") & ":" & JsonString(Trim$(coupon)) & "," & _
        JsonString("email") & ":" & JsonString(NormalizeEmail(custEmail)) & "," & _
        OptionalJsonStringProperty("uid", customerUID) & _
        JsonString("amount") & ":" & CStr(AmountToCents(amountEUR)) & "," & _
        JsonString("currency") & ":" & JsonString("eur") & "," & _
        JsonString("event_id") & ":" & JsonString(Trim$(payID)) & "," & _
        JsonString("skip_email_notification") & ":true" & _
        "}"
End Function

Private Function BuildFirstPromoterSignupJson(ByVal signupDate As Date, _
                                              ByVal custEmail As String, _
                                              ByVal coupon As String, _
                                              ByVal customerUID As String) As String
    BuildFirstPromoterSignupJson = "{" & _
        JsonString("ref_id") & ":" & JsonString(Trim$(coupon)) & "," & _
        JsonString("email") & ":" & JsonString(NormalizeEmail(custEmail)) & "," & _
        OptionalJsonStringProperty("uid", customerUID) & _
        JsonString("created_at") & ":" & JsonString(Format$(signupDate, "yyyy-mm-dd\Thh:nn:ss\Z")) & "," & _
        JsonString("skip_email_notification") & ":true" & _
        "}"
End Function

Private Function OptionalQueryParam(ByVal paramName As String, ByVal paramValue As String) As String
    paramValue = Trim$(paramValue)
    If paramValue <> vbNullString Then
        OptionalQueryParam = "&" & paramName & "=" & UrlEncode(paramValue)
    End If
End Function

Private Function OptionalJsonStringProperty(ByVal propertyName As String, ByVal propertyValue As String) As String
    propertyValue = Trim$(propertyValue)
    If propertyValue <> vbNullString Then
        OptionalJsonStringProperty = JsonString(propertyName) & ":" & JsonString(propertyValue) & ","
    End If
End Function

Private Function IsFirstPromoterV2() As Boolean
    IsFirstPromoterV2 = (GetFirstPromoterAccountID() <> vbNullString)
End Function

Private Function FirstPromoterApiMode() As String
    If IsFirstPromoterV2() Then
        FirstPromoterApiMode = "v2 JSON (api.firstpromoter.com, Bearer token, Account-ID)"
    Else
        FirstPromoterApiMode = "v1 query string (firstpromoter.com, X-API-KEY)"
    End If
End Function

Private Function JsonString(ByVal value As String) As String
    JsonString = Chr$(34) & JsonEscape(value) & Chr$(34)
End Function

Private Function JsonEscape(ByVal value As String) As String
    Dim i As Long
    Dim ch As String
    Dim code As Long
    Dim escaped As String

    For i = 1 To Len(value)
        ch = Mid$(value, i, 1)
        code = AscW(ch)
        Select Case ch
            Case Chr$(34)
                escaped = escaped & Chr$(92) & Chr$(34)
            Case Chr$(92)
                escaped = escaped & Chr$(92) & Chr$(92)
            Case vbCr
                escaped = escaped & Chr$(92) & "r"
            Case vbLf
                escaped = escaped & Chr$(92) & "n"
            Case vbTab
                escaped = escaped & Chr$(92) & "t"
            Case Else
                If code < 32 Then
                    escaped = escaped & Chr$(92) & "u" & Right$("0000" & Hex$(code), 4)
                Else
                    escaped = escaped & ch
                End If
        End Select
    Next i

    JsonEscape = escaped
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
    Dim apiKey As String
    apiKey = GetConfigValue("FP_API_KEY", FP_API_KEY_HARDCODED)

    If apiKey = vbNullString Then
        Err.Raise vbObjectError + 1501, "GetFirstPromoterApiKey", _
            "FirstPromoter API key is missing. Create workbook named range FP_API_KEY or set FP_API_KEY_HARDCODED in this module."
    End If

    GetFirstPromoterApiKey = apiKey
End Function

Private Function GetFirstPromoterLegacyApiKey() As String
    Dim legacyApiKey As String
    legacyApiKey = GetConfigValue("FP_LEGACY_API_KEY", FP_LEGACY_API_KEY_HARDCODED)

    If legacyApiKey = vbNullString Then
        Err.Raise vbObjectError + 1502, "GetFirstPromoterLegacyApiKey", _
            "FirstPromoter Legacy API key is missing. Create workbook named range FP_LEGACY_API_KEY before using API v2 imports, so customer_since can be backdated before any sale is sent."
    End If

    GetFirstPromoterLegacyApiKey = legacyApiKey
End Function

Private Function GetFirstPromoterAccountID() As String
    GetFirstPromoterAccountID = GetConfigValue("FP_ACCOUNT_ID", FP_ACCOUNT_ID_HARDCODED)
End Function

Private Function GetConfigValue(ByVal configName As String, ByVal hardcodedValue As String) As String
    hardcodedValue = CleanConfigValue(hardcodedValue)
    If hardcodedValue <> vbNullString Then
        GetConfigValue = hardcodedValue
        Exit Function
    End If

    On Error GoTo MissingName

    Dim wb As Workbook
    Set wb = GetToolWorkbook()

    GetConfigValue = CleanConfigValue(CStr(wb.Names(configName).RefersToRange.Value))
    Exit Function

MissingName:
    GetConfigValue = vbNullString
End Function

Private Function CleanConfigValue(ByVal value As String) As String
    value = Replace$(value, vbCr, vbNullString)
    value = Replace$(value, vbLf, vbNullString)
    value = Replace$(value, vbTab, vbNullString)
    value = Replace$(value, ChrW$(160), vbNullString)
    value = Trim$(value)
    If Len(value) >= 2 Then
        If (Left$(value, 1) = Chr$(34) And Right$(value, 1) = Chr$(34)) Or _
           (Left$(value, 1) = "'" And Right$(value, 1) = "'") Then
            value = Mid$(value, 2, Len(value) - 2)
        End If
    End If
    CleanConfigValue = Trim$(value)
End Function

Private Function NormalizeBearerToken(ByVal value As String) As String
    value = CleanConfigValue(value)
    If InStr(1, value, ":", vbTextCompare) > 0 Then
        If LCase$(Left$(value, InStr(1, value, ":", vbTextCompare) - 1)) = "authorization" Then
            value = Mid$(value, InStr(1, value, ":", vbTextCompare) + 1)
        End If
    End If
    value = Trim$(value)
    If LCase$(Left$(value, 7)) = "bearer " Then value = Mid$(value, 8)
    NormalizeBearerToken = Trim$(value)
End Function

Private Function NormalizeAccountID(ByVal value As String) As String
    value = CleanConfigValue(value)
    If InStr(1, value, ":", vbTextCompare) > 0 Then
        If LCase$(Left$(value, InStr(1, value, ":", vbTextCompare) - 1)) = "account-id" Then
            value = Mid$(value, InStr(1, value, ":", vbTextCompare) + 1)
        End If
    End If
    NormalizeAccountID = Trim$(value)
End Function

Private Sub SleepMs(ByVal milliseconds As Long)
    DoEvents
    Sleep milliseconds
    DoEvents
End Sub
