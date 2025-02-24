codeunit 136100 "Service Contract"
{
    Subtype = Test;
    TestPermissions = Disabled;

    trigger OnRun()
    begin
        // [FEATURE] [Service]
        isInitialized := false;
    end;

    var
        OneWeekTxt: Label '<1W>', Locked = true;
        LinesAreNotEqualErr: Label 'Lines are not equal: Act: %1, Exp %2.';
        NoOfServiceLinesNotSameErr: Label 'No of Service Lines is not the same after copy contract Act: %1 Exp: %2.';
        OnlyOneInvoiceExpectedErr: Label 'Only one invoice expected - Actual: %1.';
        InvoiceCreatedForUnbalancedErr: Label 'Invioce created for unbalanced Service Contract.';
        Assert: Codeunit Assert;
        LibraryERM: Codeunit "Library - ERM";
        LibraryRandom: Codeunit "Library - Random";
        LibraryService: Codeunit "Library - Service";
        LibrarySales: Codeunit "Library - Sales";
        LibraryDimension: Codeunit "Library - Dimension";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryUtility: Codeunit "Library - Utility";
        LibraryTestInitialize: Codeunit "Library - Test Initialize";
        DistributionType: Option Even,Profit,Line;
        isInitialized: Boolean;
        ConfirmType: Option Create,Sign,Invoice;

    [Test]
    [HandlerFunctions('ContractAmountDistribution,ConfirmDialog,SelectTemplate')]
    [Scope('OnPrem')]
    procedure ChangeAnnualAmountLineDistr()
    begin
        // Change Annual ammount with Random Value between 100 - 1000
        // Distribution based on line Amount
        TestChangeAnnualAmount(100 * LibraryRandom.RandInt(10), DistributionType::Line);
    end;

    [Test]
    [HandlerFunctions('ContractAmountDistribution,ConfirmDialog,SelectTemplate')]
    [Scope('OnPrem')]
    procedure ChangeAnnualAmountEvenDistr()
    begin
        // Change Annual ammount with Random Value between 100 - 1000
        // Distribution based on even distribution
        TestChangeAnnualAmount(100 * LibraryRandom.RandInt(10), DistributionType::Even);
    end;

    [Test]
    [HandlerFunctions('ContractAmountDistribution,ConfirmDialog,SelectTemplate')]
    [Scope('OnPrem')]
    procedure ChangeAnnualAmountProfitDistr()
    begin
        // Change Annual ammount with Random Value between 100 - 1000
        // Distribution based on Profit distribution
        TestChangeAnnualAmount(100 * LibraryRandom.RandInt(10), DistributionType::Profit);
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,SelectTemplate')]
    [Scope('OnPrem')]
    procedure SignUnbalancedAnnualAmount()
    var
        ServiceContractHeader: Record "Service Contract Header";
        ServiceHeader: Record "Service Header";
    begin
        // Refresh Shared Fixture
        Initialize();

        // Setup: Create Contract with allow unbalanced Annual Amount = True
        ConfirmType := ConfirmType::Create;
        CreateServiceContract(ServiceContractHeader, true);

        // Excercise: Sign Contract and expect error: Cannot sign unbalanced annual amount
        asserterror SignContract(ServiceContractHeader."Contact No.");

        // Validation: Language independant error validation is currently not possible.

        // Validate no Invoice is created for this contract.
        // Assume the Contract No. is unique for this test case.
        ServiceHeader.SetRange("Contract No.", ServiceContractHeader."Contract No.");
        ServiceHeader.SetRange("Document Type", ServiceHeader."Document Type"::Invoice);
        if ServiceHeader.FindFirst() then
            Error(InvoiceCreatedForUnbalancedErr);
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,SelectTemplate,MessageHandler')]
    [Scope('OnPrem')]
    procedure SignBalancedAnnualAmount()
    var
        ServiceContractHeader: Record "Service Contract Header";
    begin
        // Refresh Shared Fixture.
        Initialize();

        // Setup: Create Contract with allow unbalanced Annual Amount = True.
        ConfirmType := ConfirmType::Create;
        CreateServiceContractWithAnnualAmount(ServiceContractHeader);

        // Excercise: Sign Contract.
        SignContract(ServiceContractHeader."Contract No.");

        // Validate sum of all lines is equal total amount.
        ValidateServiceContractAmount(ServiceContractHeader);

        // Validate Invoice Created for the Contract.
        // Assume the Contract No. is unique for this test case.
        ValidateServiceInvoice(ServiceContractHeader);
    end;

    [HandlerFunctions('ContractAmountDistribution,SelectTemplate')]
    local procedure TestChangeAnnualAmount(AmountChange: Decimal; Distribution: Option)
    var
        ServiceContractHeader: Record "Service Contract Header";
        TempServiceContractLine: Record "Service Contract Line" temporary;
    begin
        // Refresh Shared Fixture
        Initialize();

        // Setup: Create Contract and save state for later validation
        SetupForContractValueCalculate;
        CreateServiceContract(ServiceContractHeader, false);
        SaveLineAmount(ServiceContractHeader, TempServiceContractLine);

        // Excercise: Change Annual Amount
        DistributionType := Distribution;
        Commit();  // Required because Modal Form will pop up when modified.
        ServiceContractHeader.Validate("Annual Amount", ServiceContractHeader."Annual Amount" + AmountChange);
        ServiceContractHeader.Modify(true);

        // Verify: Sum of all lines is equal total amount
        ValidateServiceContractAmount(ServiceContractHeader);

        // Verify: Distribution based on Even, Profit or Line distribution
        ValidateDistribution(TempServiceContractLine, AmountChange, Distribution);
    end;

    [Test]
    [HandlerFunctions('ConfirmDialogHandler,SelectTemplate')]
    [Scope('OnPrem')]
    procedure TwoContractsForOneServiceItem()
    var
        ServiceContractHeader: Record "Service Contract Header";
        Customer: Record Customer;
        ServiceItemNo: Code[20];
        ContractNo1: Code[20];
    begin
        // Refresh Shared Fixture
        Initialize();

        // Setup: Create Service Contract
        LibrarySales.CreateCustomer(Customer);
        ServiceItemNo := CreateServiceItem(Customer."No.");
        ContractNo1 := CreateServiceContractHeader(ServiceContractHeader, Customer."No.");
        CreateServiceContractLine(ServiceContractHeader, ServiceItemNo);

        // Excercise: Create contract with the same Service item
        CreateServiceContractHeader(ServiceContractHeader, Customer."No.");
        CreateServiceContractLine(ServiceContractHeader, ServiceItemNo);

        // Validate: Service Item should be the same on both Contracts
        // Second part of the validation is the handler that
        // should verify the confirm dialog - ConfirmDialog
        AssertEqualServiceItem(ContractNo1, ServiceContractHeader."Contract No.");
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,SelectTemplate')]
    [Scope('OnPrem')]
    procedure CopyServiceDocument()
    var
        ServiceContractHeaderFrom: Record "Service Contract Header";
        ServiceContractHeaderTo: Record "Service Contract Header";
        ServiceContractLineTo: Record "Service Contract Line";
        CopyDocMgt: Codeunit "Copy Document Mgt.";
    begin
        // Refresh Shared Fixture
        Initialize();

        // Setup: Create Service Contract
        CreateServiceContract(ServiceContractHeaderFrom, false);

        // Excercise: Copy Service Contract using Copy Service Document Report
        CreateServiceContractHeader(ServiceContractHeaderTo, ServiceContractHeaderFrom."Customer No.");
        CopyDocMgt.CopyServContractLines(ServiceContractHeaderTo,
          ServiceContractHeaderFrom."Contract Type".AsInteger(),
          ServiceContractHeaderFrom."Contract No.",
          ServiceContractLineTo);

        // Validate: All data should be the same except Contract No and Line No.
        AssertEqualContract(ServiceContractHeaderTo, ServiceContractHeaderFrom);
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,ContractTemplateHandler')]
    [Scope('OnPrem')]
    procedure ServiceContractNoSeries()
    var
        ServiceContractHeader: Record "Service Contract Header";
    begin
        // Test Service Contract No is incremented automatically.
        TestContractNo(ServiceContractHeader."Contract Type"::Contract);
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,ContractTemplateHandler')]
    [Scope('OnPrem')]
    procedure ServiceContractQuoteNoSeries()
    var
        ServiceContractHeader: Record "Service Contract Header";
    begin
        // Test Service Contract Quote No is incremented automatically.
        TestContractNo(ServiceContractHeader."Contract Type"::Quote);
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,SelectTemplate,MessageHandler')]
    [Scope('OnPrem')]
    procedure ChangeGlobalDimensionInLockedServiceContract()
    var
        ServiceContractHeader: Record "Service Contract Header";
        InitialDimensionCode: Code[20];
    begin
        // [FEATURE] [Dimension]
        // [SCENARIO 363042] Check that Global Dimension cannot be changed for Locked Service Contract

        Initialize();
        // [GIVEN] Signed & Locked Service Contract with Dimension Code = "X"
        ConfirmType := ConfirmType::Create;
        CreateServiceContractWithAnnualAmount(ServiceContractHeader);
        UpdateGlobalDimensionCodeInServiceContract(ServiceContractHeader);
        InitialDimensionCode := ServiceContractHeader."Shortcut Dimension 1 Code";
        SignContract(ServiceContractHeader."Contract No.");
        Commit();

        // [WHEN] Change Dimension Code from "X" to "Y"
        asserterror UpdateGlobalDimensionCodeInServiceContract(ServiceContractHeader);

        // [THEN] Dimension code remains "X"
        ServiceContractHeader.Find();
        Assert.AreEqual(
          InitialDimensionCode, ServiceContractHeader."Shortcut Dimension 1 Code",
          ServiceContractHeader.FieldCaption("Shortcut Dimension 1 Code"));
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,ContractTemplateHandler')]
    [Scope('OnPrem')]
    procedure UT_AmountPerPeriodUpdatedAfterAddingServContractLineWithExpDate()
    var
        Customer: Record Customer;
        ServContractHeader: Record "Service Contract Header";
        ServContractMgt: Codeunit ServContractManagement;
        LineAmount: Decimal;
    begin
        // [FEATURE] [UT]
        // [SCENARIO 375949] Amount Per Period should be updated after adding Service Contract Line with Expiration Date before the end of contract

        Initialize();
        // [GIVEN] Service Contract with "Invoice Period" = Year, "Next Invoice Date Date" = 01/02, "Expiration Date" = 30/11
        LibrarySales.CreateCustomer(Customer);
        LibraryService.CreateServiceContractHeader(
          ServContractHeader, ServContractHeader."Contract Type"::Contract, Customer."No.");
        ServContractHeader.Validate("Invoice Period", ServContractHeader."Invoice Period"::Year);
        ServContractHeader.Validate("Expiration Date", CalcDate('<CY-1M>', ServContractHeader."Next Invoice Date"));
        ServContractHeader.Modify(true);

        // [WHEN] Create Service Contract Line with "Line Amount" = 1200
        LineAmount := CreateServiceContractLine(ServContractHeader, CreateServiceItem(Customer."No."));

        // [THEN] "Amount Per Period" in Service Contract = 1000
        ServContractHeader.Find();
        ServContractHeader.TestField("Amount per Period",
          Round(LineAmount / 12 *
            ServContractMgt.NoOfMonthsAndMPartsInPeriod(ServContractHeader."Next Invoice Date", ServContractHeader."Expiration Date")));
    end;

    [Test]
    [HandlerFunctions('ConfirmDialogHandler,SelectTemplate')]
    [Scope('OnPrem')]
    procedure VerifyServContractAnnualAmountExpirationDateDecreaseIncrease()
    var
        ServiceContractHeader: Record "Service Contract Header";
    begin
        // [SCENARIO 376507] After changing Service Contract Expiration Date Back and the to future Date Annual Amount is updated
        Initialize();

        // [GIVEN] Service Contract with Starting Date = 26/01/2017, Expiration Date = 31/01/2018, Annual Amount = 1200.
        CreateServiceContractHeader(ServiceContractHeader, LibrarySales.CreateCustomerNo);
        ServiceContractHeader.Validate("Invoice Period", ServiceContractHeader."Invoice Period"::Year);
        ServiceContractHeader.Validate("Expiration Date", CalcDate('<CM+1Y>', ServiceContractHeader."Starting Date"));
        ServiceContractHeader.Modify(true);
        CreateServiceContractLine(
          ServiceContractHeader, CreateServiceItem(ServiceContractHeader."Customer No."));
        ServiceContractHeader.Find();

        // [GIVEN] Service Header Expiration Date is set to 28/02/17, Annual Amount = 100
        ModifyServContractExpirationDateVerifyAnnualAmount(
          ServiceContractHeader, CalcDate('<CM+1M>', ServiceContractHeader."Starting Date"));

        // [WHEN] Service Contract Expiration Date Changed to 31/03/17
        // [THEN] Annual Amount = 200
        ModifyServContractExpirationDateVerifyAnnualAmount(
          ServiceContractHeader, CalcDate('<CM+2M>', ServiceContractHeader."Starting Date"));
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,SelectTemplate,MessageHandler')]
    [Scope('OnPrem')]
    procedure InvoicePeriodNotShiftedWhenLockContractWithNewLine()
    var
        ContractNo: Code[20];
        MonthlyAmount: Decimal;
        SavedWorkDate: Date;
    begin
        // [SCENARIO 379298] Lock Service Contract when adding new line after Invoice + Credit Memo in case of Prepaid = FALSE, "Contract Lines On Invoice" = FALSE
        Initialize();
        SavedWorkDate := WorkDate();

        // [GIVEN] Signed Service Contract with line and "Starting Date" = 01-01-2016, "Invoice Period" = Quarter, Prepaid = FALSE, "Contract Lines On Invoice" = FALSE
        ContractNo := CreateSignServiceContractWithStartingDate(CalcDate('<-CY>', WorkDate()), false, true);
        // [GIVEN] Create, post service invoice on 01-04-2016
        CreatePostServiceContractInvoice(ContractNo, CalcDate('<-CY+3M>', WorkDate()));
        // [GIVEN] Create, post service invoice on 01-07-2016
        CreatePostServiceContractInvoice(ContractNo, CalcDate('<-CY+6M>', WorkDate()));
        // [GIVEN] Set WorkDate = 01-03-2016
        WorkDate := CalcDate('<-CY+2M>', WorkDate());
        // [GIVEN] Reopen the contract
        OpenServContract(ContractNo);
        // [GIVEN] Modify contract line "Contract Expiration Date" = 01-03-2016. Create, post Service Credit Memo.
        CreatePostServiceContractCreditMemo(ContractNo, CalcDate('<-CY+2M>', WorkDate()));
        // [GIVEN] Add a new service contract line with "Line Amount" = 1200
        MonthlyAmount := AddServiceContractLine(ContractNo);

        // [WHEN] Lock the contract
        LockServContract(ContractNo);

        // [THEN] Contract "Next Invoice Date" = 30-09-2016
        // [THEN] Contract "Next Invoice Period" = "01-07-16 to 30-09-16"
        // [THEN] Contract "Last Invoice Date" = 30-06-2016
        VerifyServiceContractDates(
          ContractNo, CalcDate('<-CY+9M-1D>', WorkDate()), CalcDate('<-CY+6M>', WorkDate()),
          CalcDate('<-CY+9M-1D>', WorkDate()), CalcDate('<-CY+6M-1D>', WorkDate()));
        // [THEN] Created invoice has 1 line with G/L Account "No." = "Non-Prepaid Contract Acc.", "Amount" = 400
        VerifyOpenServiceInvoiceDetails(ContractNo, 1, GetServiceContractAccountNo(ContractNo), MonthlyAmount / 3);

        // Tear Down
        WorkDate := SavedWorkDate;
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,SelectTemplate,MessageHandler')]
    [Scope('OnPrem')]
    procedure InvoicePeriodNotShiftedWhenLockContractWithNewLine_Prepaid()
    var
        ContractNo: Code[20];
        MonthlyAmount: Decimal;
        SavedWorkDate: Date;
    begin
        // [SCENARIO 379298] Lock Service Contract when adding new line after Invoice + Credit Memo in case of Prepaid = TRUE, "Contract Lines On Invoice" = FALSE
        Initialize();
        SavedWorkDate := WorkDate();

        // [GIVEN] Signed Service Contract with "Starting Date" = 01-01-2016, "Invoice Period" = Quarter,  Prepaid = TRUE, "Contract Lines On Invoice" = FALSE
        ContractNo := CreateSignServiceContractWithStartingDate(CalcDate('<-CY>', WorkDate()), true, false);
        // [GIVEN] Create, post service invoice on 01-03-2016
        CreatePostServiceContractInvoice(ContractNo, CalcDate('<-CY+2M>', WorkDate()));
        // [GIVEN] Create, post service invoice on 01-06-2016
        CreatePostServiceContractInvoice(ContractNo, CalcDate('<-CY+5M>', WorkDate()));
        // [GIVEN] Set WorkDate = 01-03-2016
        WorkDate := CalcDate('<-CY+2M>', WorkDate());
        // [GIVEN] Reopen the contract
        OpenServContract(ContractNo);
        // [GIVEN] Modify contract line "Contract Expiration Date" = 01-03-2016. Create, post Service Credit Memo.
        CreatePostServiceContractCreditMemo(ContractNo, CalcDate('<-CY+2M>', WorkDate()));
        // [GIVEN] Add a new service contract line with "Line Amount" = 1200
        MonthlyAmount := AddServiceContractLine(ContractNo);

        // [WHEN] Lock the contract
        LockServContract(ContractNo);

        // [THEN] Contract "Next Invoice Date" = 01-07-2016
        // [THEN] Contract "Next Invoice Period" = "01-07-16 to 30-09-16"
        // [THEN] Contract "Last Invoice Date" = 01-07-2016
        VerifyServiceContractDates(
          ContractNo, CalcDate('<-CY+6M>', WorkDate()), CalcDate('<-CY+6M>', WorkDate()),
          CalcDate('<-CY+9M-1D>', WorkDate()), CalcDate('<-CY+6M>', WorkDate()));
        // [THEN] Created invoice has 4 lines with G/L Account "No." = "Prepaid Contract Acc.", "Amount" = 100
        VerifyOpenServiceInvoiceDetails(ContractNo, 4, GetServiceContractAccountNo(ContractNo), MonthlyAmount / 12);

        // Tear Down
        WorkDate := SavedWorkDate;
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,SelectTemplate,MessageHandler')]
    [Scope('OnPrem')]
    procedure InvoicePeriodNotShiftedWhenLockContractWithNewLine_ContractLinesOnInvoice()
    var
        ContractNo: Code[20];
        MonthlyAmount: Decimal;
        SavedWorkDate: Date;
    begin
        // [SCENARIO 379298] Lock Service Contract when adding new line after Invoice + Credit Memo in case of Prepaid = FALSE, "Contract Lines On Invoice" = TRUE
        Initialize();
        SavedWorkDate := WorkDate();

        // [GIVEN] Signed Service Contract with line and "Starting Date" = 01-01-2016, "Invoice Period" = Quarter, Prepaid = FALSE, "Contract Lines On Invoice" = TRUE
        ContractNo := CreateSignServiceContractWithStartingDate(CalcDate('<-CY>', WorkDate()), false, true);
        // [GIVEN] Create, post service invoice on 01-04-2016
        CreatePostServiceContractInvoice(ContractNo, CalcDate('<-CY+3M>', WorkDate()));
        // [GIVEN] Create, post service invoice on 01-07-2016
        CreatePostServiceContractInvoice(ContractNo, CalcDate('<-CY+6M>', WorkDate()));
        // [GIVEN] Set WorkDate = 01-03-2016
        WorkDate := CalcDate('<-CY+2M>', WorkDate());
        // [GIVEN] Reopen the contract
        OpenServContract(ContractNo);
        // [GIVEN] Modify contract line "Contract Expiration Date" = 01-03-2016. Create, post Service Credit Memo.
        CreatePostServiceContractCreditMemo(ContractNo, CalcDate('<-CY+2M>', WorkDate()));
        // [GIVEN] Add a new service contract line with "Line Amount" = 1200
        MonthlyAmount := AddServiceContractLine(ContractNo);

        // [WHEN] Lock the contract
        LockServContract(ContractNo);

        // [THEN] Contract "Next Invoice Date" = 30-09-2016
        // [THEN] Contract "Next Invoice Period" = "01-07-16 to 30-09-16"
        // [THEN] Contract "Last Invoice Date" = 30-06-2016
        VerifyServiceContractDates(
          ContractNo, CalcDate('<-CY+9M-1D>', WorkDate()), CalcDate('<-CY+6M>', WorkDate()),
          CalcDate('<-CY+9M-1D>', WorkDate()), CalcDate('<-CY+6M-1D>', WorkDate()));
        // [THEN] Created invoice has 1 line with G/L Account "No." = "Non-Prepaid Contract Acc.", "Amount" = 400
        VerifyOpenServiceInvoiceDetails(ContractNo, 1, GetServiceContractAccountNo(ContractNo), MonthlyAmount / 3);

        // Tear Down
        WorkDate := SavedWorkDate;
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,SelectTemplate,MessageHandler')]
    [Scope('OnPrem')]
    procedure InvoicePeriodNotShiftedWhenLockContractWithNewLine_Prepaid_ContractLinesOnInvoice()
    var
        ContractNo: Code[20];
        MonthlyAmount: Decimal;
        SavedWorkDate: Date;
    begin
        // [SCENARIO 379298] Lock Service Contract when adding new line after Invoice + Credit Memo in case of Prepaid = TRUE, "Contract Lines On Invoice" = TRUE
        Initialize();
        SavedWorkDate := WorkDate();

        // [GIVEN] Signed Service Contract with "Starting Date" = 01-01-2016, "Invoice Period" = Quarter,  Prepaid = TRUE, "Contract Lines On Invoice" = TRUE
        ContractNo := CreateSignServiceContractWithStartingDate(CalcDate('<-CY>', WorkDate()), true, true);
        // [GIVEN] Create, post service invoice on 01-03-2016
        CreatePostServiceContractInvoice(ContractNo, CalcDate('<-CY+2M>', WorkDate()));
        // [GIVEN] Create, post service invoice on 01-06-2016
        CreatePostServiceContractInvoice(ContractNo, CalcDate('<-CY+5M>', WorkDate()));
        // [GIVEN] Set WorkDate = 01-03-2016
        WorkDate := CalcDate('<-CY+2M>', WorkDate());
        // [GIVEN] Reopen the contract
        OpenServContract(ContractNo);
        // [GIVEN] Modify contract line "Contract Expiration Date" = 01-03-2016. Create, post Service Credit Memo.
        CreatePostServiceContractCreditMemo(ContractNo, CalcDate('<-CY+2M>', WorkDate()));
        // [GIVEN] Add a new service contract line with "Line Amount" = 1200
        MonthlyAmount := AddServiceContractLine(ContractNo);

        // [WHEN] Lock the contract
        LockServContract(ContractNo);

        // [THEN] Contract "Next Invoice Date" = 01-07-2016
        // [THEN] Contract "Next Invoice Period" = "01-07-16 to 30-09-16"
        // [THEN] Contract "Last Invoice Date" = 01-07-2016
        VerifyServiceContractDates(
          ContractNo, CalcDate('<-CY+6M>', WorkDate()), CalcDate('<-CY+6M>', WorkDate()),
          CalcDate('<-CY+9M-1D>', WorkDate()), CalcDate('<-CY+6M>', WorkDate()));
        // [THEN] Created invoice has 4 lines with G/L Account "No." = "Prepaid Contract Acc.", "Amount" = 100
        VerifyOpenServiceInvoiceDetails(ContractNo, 4, GetServiceContractAccountNo(ContractNo), MonthlyAmount / 12);

        // Tear Down
        WorkDate := SavedWorkDate;
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,ContractTemplateHandler,MessageHandler')]
    [Scope('OnPrem')]
    procedure ServiceInvoiceWithUniformDistributionAmount()
    var
        ServiceContractHeader: Record "Service Contract Header";
        SavedWorkDate: Date;
        LineAmount: Decimal;
    begin
        // [SCENARIO 379677] Create Service Invoice for Service Contract with Starting Date = 11.06 and Invoice Period = Year and monthly uniform distribution of the total amount
        Initialize();
        SavedWorkDate := WorkDate();

        // [GIVEN] Signed and Locked Service Contract with "Starting Date" = 11.06.2016, "Invoice Period" = Year, "Service Period" = 1Y,
        // [GIVEN] Prepaid = TRUE, "Contract Lines On Invoice" = TRUE and "Line Amount" = 1200
        LineAmount := CreateSingAndLockServiceContract(ServiceContractHeader);
        // [GIVEN] Set WorkDate := 01.07.2016
        WorkDate := CalcDate('<CM+1D>', WorkDate());

        // [WHEN] Create Service Invoice for the period from 01.07.16 to 11.06.17
        CreateServiceInvoice(ServiceContractHeader."Contract No.");

        // [THEN] Created invoice has 12 line where Line 1..11 with "Line Amount Excl. VAT" = 100
        LineAmount := LineAmount / 12;
        VerifyServiceInvoiceLineAmount(ServiceContractHeader, LineAmount, 12);

        // Tear Down
        WorkDate := SavedWorkDate;
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,SelectTemplate')]
    [Scope('OnPrem')]
    procedure PaymentMethodFromBillToCustomer()
    var
        ServiceContractHeader: Record "Service Contract Header";
        Customer: Record Customer;
    begin
        // [FEATURE] [UT]
        // [SCENARIO 325156] Payment Method Code is copied from customer 
        Initialize();

        // [GIVEN] Create customer "CUST" with Payment Method Code "PM"
        LibrarySales.CreateCustomer(Customer);

        // [WHEN] Create Service Contract for customer "CUST"
        CreateServiceContractHeader(ServiceContractHeader, Customer."No.");

        // [THEN] Created Service Contract has Payment Method Code = "PM"
        ServiceContractHeader.TestField("Payment Method Code", Customer."Payment Method Code");
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,SelectTemplate')]
    [Scope('OnPrem')]
    procedure ServiceContractDirectDebitWhenValidatePaymentMethodCode()
    var
        ServiceContractHeader: Record "Service Contract Header";
        SEPADirectDebitMandate: Record "SEPA Direct Debit Mandate";
        Customer: Record Customer;
        PaymentMethod: Record "Payment Method";
    begin
        // [FEATURE] [UT]
        // [SCENARIO 325156] "Direct Debit Mandate ID" is filled in when Payment Method validated on Service Contract
        Initialize();

        // [GIVEN] Customer "CUST" with DD Mandate "DD"
        UpdateSalesSetupDirectDebitMandateNos();
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateCustomerMandate(SEPADirectDebitMandate, Customer."No.", '', 0D, 0D);

        // [WHEN] Create Service Contract for customer "CUST"
        CreateServiceContractHeader(ServiceContractHeader, Customer."No.");

        // [GIVEN] Payment method "PM" with "Direct Debit" = true
        CreateDirectDebitPaymentMethod(PaymentMethod);

        // [WHEN] Payment Method Code is being changed to "PM"
        ServiceContractHeader.Validate("Payment Method Code", PaymentMethod.Code);

        // [THEN] "Direct Debit Mandate ID" = "DD"
        ServiceContractHeader.TestField("Direct Debit Mandate ID", SEPADirectDebitMandate.ID);
    end;

    [Test]
    [HandlerFunctions('ConfirmDialogHandler,SelectTemplate,MessageHandler')]
    [Scope('OnPrem')]
    procedure ServiceDocDirectDebitWhenCreateFromContract()
    var
        ServiceContractHeader: Record "Service Contract Header";
        SEPADirectDebitMandate: Record "SEPA Direct Debit Mandate";
        SEPADirectDebitMandate2: Record "SEPA Direct Debit Mandate";
        Customer: Record Customer;
        PaymentMethod: Record "Payment Method";
        ServiceHeader: Record "Service Header";
        SignServContractDoc: Codeunit SignServContractDoc;
        CurrentWorkDate: date;
    begin
        // [FEATURE] [UT]
        // [SCENARIO 325156] "Direct Debit Mandate ID" is filled in when Service Invoice is being created from Service Contract
        Initialize();

        // [GIVEN] Customer "CUST" with DD Mandates "DD1" and "DD2"
        UpdateSalesSetupDirectDebitMandateNos();
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateCustomerMandate(SEPADirectDebitMandate, Customer."No.", '', 0D, 0D);
        LibrarySales.CreateCustomerMandate(SEPADirectDebitMandate2, Customer."No.", '', 0D, 0D);

        // [WHEN] Create Service Contract for customer "CUST" with "Direct Debit Mandate ID" = "DD2"
        CreateServiceContractHeader(ServiceContractHeader, Customer."No.");
        CreateDirectDebitPaymentMethod(PaymentMethod);
        ServiceContractHeader.Validate("Payment Method Code", PaymentMethod.Code);
        ServiceContractHeader.Validate("Direct Debit Mandate ID", SEPADirectDebitMandate2.ID);
        ServiceContractHeader.Modify();
        CreateServiceContractLine(
          ServiceContractHeader, CreateServiceItem(ServiceContractHeader."Customer No."));
        ServiceContractHeader.Find();

        SignServContractDoc.SignContract(ServiceContractHeader);
        ServiceContractHeader.Find();

        // [WHEN] Service invoice is being created from Service contract
        CurrentWorkDate := WorkDate();
        WorkDate := ServiceContractHeader."Next Invoice Date";
        RunCreateServiceInvoice(ServiceContractHeader."Contract No.");

        // [THEN] Created service invoice has "Direct Debit Mandate ID" = "DD2"
        FindServiceHeader(ServiceHeader, ServiceHeader."Document Type"::Invoice, ServiceContractHeader."Contract No.");
        ServiceHeader.TestField("Direct Debit Mandate ID", SEPADirectDebitMandate2.ID);

        // TearDown
        WorkDate := CurrentWorkDate;
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,SelectTemplate,MessageHandler')]
    [Scope('OnPrem')]
    procedure LockSignedContractWith100PctLineDisc()
    var
        ServiceContractHeader: Record "Service Contract Header";
        ServiceContractLine: Record "Service Contract Line";
        LockOpenServContract: Codeunit "Lock-OpenServContract";
    begin
        // [SCENARIO 394609] Unlock then lock signed contract with 100 % line discount
        Initialize();

        // [GIVEN] Unlocked signed service contract with several lines, last line has "Line Discount" = 100 %
        CreateServiceContract(ServiceContractHeader, false);
        ServiceContractLine.SetRange("Contract Type", ServiceContractHeader."Contract Type");
        ServiceContractLine.SetRange("Contract No.", ServiceContractHeader."Contract No.");
        ServiceContractLine.FindLast();
        ServiceContractLine.Validate("Line Discount %", 100);
        ServiceContractLine.Modify(true);

        ServiceContractHeader.Get(ServiceContractHeader."Contract Type", ServiceContractHeader."Contract No.");
        ServiceContractHeader.Validate("Annual Amount", CalcAnnualAmount(ServiceContractHeader));
        ServiceContractHeader.Modify(true);

        SignContract(ServiceContractHeader."Contract No.");

        ServiceContractHeader.Get(ServiceContractHeader."Contract Type", ServiceContractHeader."Contract No.");
        LockOpenServContract.OpenServContract(ServiceContractHeader);

        // [WHEN] Lock signed contract
        ServiceContractHeader.Get(ServiceContractHeader."Contract Type", ServiceContractHeader."Contract No.");
        LockOpenServContract.LockServContract(ServiceContractHeader);

        // [THEN] Contratc successfully locked
        ServiceContractHeader.Get(ServiceContractHeader."Contract Type", ServiceContractHeader."Contract No.");
        ServiceContractHeader.TestField("Change Status", ServiceContractHeader."Change Status"::Locked);
    end;

    [Test]
    [HandlerFunctions('ConfirmDialog,SelectTemplate,MessageHandler')]
    [Scope('OnPrem')]
    procedure DimensionTransferServiceContractToServiceInvoice()
    var
        ServiceContractHeader: Record "Service Contract Header";
        ServiceHeader: Record "Service Header";
        CreateContractInvoices: Report "Create Contract Invoices";
    begin
        // [FEATURE] [Dimension]
        // [SCENARIO 438613] Dimensions should be copied from Service Contract to Service Invoice
        Initialize();

        // [GIVEN] Service Contract with "Dimension Set ID" = 'X', "Shortcut Dimension 1/2 Code" = 'SH1C/SH2C'
        ConfirmType := ConfirmType::Create;
        CreateServiceContractWithAnnualAmount(ServiceContractHeader);
        UpdateGlobalDimensionCodesInServiceContract(ServiceContractHeader);

        // [WHEN] Service Contract signed and Service Invoice created
        SignContract(ServiceContractHeader."Contract No.");
        Commit();

        // [THEN] Service Invoice created with "Dimension Set ID" = 'X', "Shortcut Dimension 1/2 Code" = 'SH1C/SH2C'
        ServiceHeader.SetRange("Contract No.", ServiceContractHeader."Contract No.");
        ServiceHeader.SetRange("Document Type", ServiceHeader."Document Type"::Invoice);
        ServiceHeader.FindFirst();
        ServiceHeader.TestField("Shortcut Dimension 1 Code", ServiceContractHeader."Shortcut Dimension 1 Code");
        ServiceHeader.TestField("Shortcut Dimension 2 Code", ServiceContractHeader."Shortcut Dimension 2 Code");
        ServiceHeader.TestField("Dimension Set ID", ServiceContractHeader."Dimension Set ID");
    end;

    local procedure Initialize()
    var
        LibraryERMCountryData: Codeunit "Library - ERM Country Data";
    begin
        LibraryTestInitialize.OnTestInitialize(Codeunit::"Service Contract");

        if isInitialized then
            exit;

        LibraryTestInitialize.OnBeforeTestSuiteInitialize(Codeunit::"Service Contract");

        LibraryERMCountryData.CreateVATData();
        LibraryERMCountryData.UpdateAccountsInServiceContractAccountGroups();
        LibraryERMCountryData.CreateGeneralPostingSetupData();
        LibraryERMCountryData.UpdateGeneralPostingSetup();
        LibraryERMCountryData.UpdateSalesReceivablesSetup();
        isInitialized := true;

        LibraryTestInitialize.OnAfterTestSuiteInitialize(Codeunit::"Service Contract");
    end;

    local procedure RunCreateServiceInvoice(ContractNo: Code[20])
    var
        ServiceContract: TestPage "Service Contract";
    begin
        ServiceContract.OpenEdit;
        ServiceContract.FILTER.SetFilter("Contract No.", ContractNo);
        ServiceContract.CreateServiceInvoice.Invoke;
        ServiceContract.OK.Invoke;
    end;

    local procedure ValidateServiceContractAmount(ServiceContractHeader: Record "Service Contract Header")
    var
        ServiceContractLine: Record "Service Contract Line";
        TotalAmount: Decimal;
    begin
        ServiceContractLine.SetFilter("Contract No.", ServiceContractHeader."Contract No.");
        ServiceContractLine.FindSet();

        repeat
            TotalAmount += ServiceContractLine."Line Amount";
        until ServiceContractLine.Next() = 0;

        ServiceContractHeader.TestField("Annual Amount", TotalAmount);
    end;

    local procedure ValidateDistribution(var OldServiceContractLine: Record "Service Contract Line"; Change: Decimal; Distribution: Option)
    var
        ServiceContractLine: Record "Service Contract Line";
        ServiceContractHeader: Record "Service Contract Header";
    begin
        // Line  : Relative size of Line Amounts should be same before and after distribution.
        // Profit: Relative size of profit should be the same before and after distribution.
        // Even  : Diff bewteen Line Amounts before and after is equal for all lines.

        OldServiceContractLine.FindSet();
        ServiceContractLine.SetFilter("Contract No.", OldServiceContractLine."Contract No.");
        ServiceContractLine.FindSet();
        ServiceContractHeader.SetFilter("Contract No.", OldServiceContractLine."Contract No.");
        ServiceContractHeader.FindFirst();

        repeat
            case Distribution of
                DistributionType::Line:
                    ValidateLine(
                      ServiceContractLine."Line Amount",
                      OldServiceContractLine."Line Amount",
                      ServiceContractHeader."Annual Amount",
                      Change);
                DistributionType::Profit:
                    ValidateLine(
                      ServiceContractLine.Profit,
                      OldServiceContractLine.Profit,
                      ServiceContractHeader."Annual Amount",
                      Change);
                DistributionType::Even:
                    AssertEqual(
                      ServiceContractLine."Line Amount",
                      OldServiceContractLine."Line Amount" + Change / ServiceContractLine.Count,
                      'Even Distribution is incorrect');
            end;
            OldServiceContractLine.Next();
        until ServiceContractLine.Next() = 0;
    end;

    local procedure ValidateLine(New: Decimal; Old: Decimal; TotalAmount: Decimal; Change: Decimal)
    var
        Delta: Decimal;
    begin
        // Relative Size to Total Amount is Equal before and after.
        Delta := TotalAmount - Change;
        AssertEqual(
          Round(Old / Delta),
          Round(New / TotalAmount),
          'Line Amount distribution is not correct');
    end;

    local procedure ValidateServiceInvoice(ServiceContractHeader: Record "Service Contract Header")
    var
        ServiceHeader: Record "Service Header";
    begin
        // Verify that only one invoice is created.
        // Assume Contract No is unique for test case.
        ServiceHeader.SetRange("Contract No.", ServiceContractHeader."Contract No.");
        ServiceHeader.SetRange("Document Type", ServiceHeader."Document Type"::Invoice);

        if ServiceHeader.Count <> 1 then
            Error(OnlyOneInvoiceExpectedErr, ServiceHeader.Count);
    end;

    local procedure SaveLineAmount(ServiceContractHeader: Record "Service Contract Header"; var SaveServiceContractLine: Record "Service Contract Line")
    var
        ServiceContractLine: Record "Service Contract Line";
    begin
        // Save Line Amount value in temperary record
        ServiceContractLine.SetFilter("Contract No.", ServiceContractHeader."Contract No.");
        ServiceContractLine.FindSet();

        repeat
            SaveServiceContractLine := ServiceContractLine;
            SaveServiceContractLine.Insert();
        until ServiceContractLine.Next() = 0;
    end;

    local procedure AssertEqual(Actual: Decimal; Expected: Decimal; ErrorText: Text[250])
    begin
        Assert.AreNearlyEqual(Expected, Actual, LibraryERM.GetAmountRoundingPrecision * 10, ErrorText)
    end;

    local procedure AssertEqualServiceItem(ContractNo1: Code[20]; ContractNo2: Code[20])
    var
        ServiceContractLine: Record "Service Contract Line";
        ServiceItemNo: Code[20];
    begin
        ServiceContractLine.SetFilter("Contract No.", '%1|%2', ContractNo1, ContractNo2);
        ServiceContractLine.FindSet();

        repeat
            if ServiceItemNo = '' then
                ServiceItemNo := ServiceContractLine."Service Item No.";
            Assert.AreEqual(ServiceItemNo, ServiceContractLine."Service Item No.", 'Service Items are not the same');
        until ServiceContractLine.Next() = 0;
    end;

    local procedure AssertEqualContract(ServiceContractHeaderActual: Record "Service Contract Header"; ServiceContractHeaderExpected: Record "Service Contract Header")
    var
        ServiceContractLineActual: Record "Service Contract Line";
        ServiceContractLineExpected: Record "Service Contract Line";
        LineContentActual: Text[1024];
        LineContentExpected: Text[1024];
    begin
        // Compare all lines and validate they have identical values except from Contract No and Line No
        ServiceContractLineActual.SetRange("Contract Type", ServiceContractHeaderActual."Contract Type");
        ServiceContractLineActual.SetRange("Contract No.", ServiceContractHeaderActual."Contract No.");
        ServiceContractLineActual.FindSet();

        ServiceContractLineExpected.SetRange("Contract Type", ServiceContractHeaderExpected."Contract Type");
        ServiceContractLineExpected.SetRange("Contract No.", ServiceContractHeaderExpected."Contract No.");
        ServiceContractLineExpected.FindSet();

        if ServiceContractLineActual.Count <> ServiceContractLineActual.Count then
            Error(NoOfServiceLinesNotSameErr, ServiceContractLineActual.Count, ServiceContractLineActual.Count);

        repeat
            // Compare Lines except from Contract No and Line No
            LineContentActual := Remove(Format(ServiceContractLineActual), ServiceContractLineActual."Contract No.");
            LineContentActual := Remove(Format(LineContentActual), Format(ServiceContractLineActual."Line No."));
            LineContentExpected := Remove(Format(ServiceContractLineExpected), ServiceContractLineExpected."Contract No.");
            LineContentExpected := Remove(Format(LineContentExpected), Format(ServiceContractLineExpected."Line No."));

            if LineContentActual <> LineContentExpected then
                Error(LinesAreNotEqualErr, LineContentActual, LineContentExpected);

            ServiceContractLineExpected.Next();
        until ServiceContractLineActual.Next() = 0;
    end;

    local procedure CreateServiceContractWithAnnualAmount(var ServiceContractHeader: Record "Service Contract Header")
    begin
        CreateServiceContract(ServiceContractHeader, true);
        ServiceContractHeader.Validate(
          "Annual Amount", CalcAnnualAmount(ServiceContractHeader));
        ServiceContractHeader.Modify(true);
    end;

    local procedure CreateServiceContract(var ServiceContractHeader: Record "Service Contract Header"; AllowUnbalanced: Boolean)
    var
        Customer: Record Customer;
        LineCount: Integer;
    begin
        // CreateContractTemplate;
        LibrarySales.CreateCustomer(Customer);

        // Create 2 to 10 lines - Boundary 2 is important.
        // Only Equal numbers for rounding simplicity
        LineCount := 2 * LibraryRandom.RandInt(5);

        CreateServiceContractHeader(ServiceContractHeader, Customer."No.");
        ServiceContractHeader.Validate("Allow Unbalanced Amounts", AllowUnbalanced);
        ServiceContractHeader.Modify(true);

        while LineCount > 0 do begin
            CreateServiceContractLine(ServiceContractHeader, CreateServiceItem(Customer."No."));
            LineCount -= 1;
        end;

        ServiceContractHeader.Get(ServiceContractHeader."Contract Type", ServiceContractHeader."Contract No.");
    end;

    local procedure CreateServiceContractHeader(var ServiceContractHeader: Record "Service Contract Header"; CustomerNo: Code[20]): Code[20]
    var
        ServiceContractAccountGroup: Record "Service Contract Account Group";
        ServicePeriod: DateFormula;
    begin
        ConfirmType := ConfirmType::Create;
        Clear(ServiceContractHeader);
        ServiceContractHeader.Init();
        ServiceContractHeader.Validate("Contract Type", ServiceContractHeader."Contract Type"::Contract);
        ServiceContractHeader.Validate("Customer No.", CustomerNo);
        ServiceContractHeader.Insert(true);
        Evaluate(ServicePeriod, OneWeekTxt); // 1W is required field but not important for the test case
        ServiceContractHeader.Validate("Service Period", ServicePeriod);

        // Account Group Required field for Signed Contracts
        LibraryService.FindContractAccountGroup(ServiceContractAccountGroup);
        ServiceContractHeader.Validate("Serv. Contract Acc. Gr. Code", ServiceContractAccountGroup.Code);
        ServiceContractHeader.Modify(true);
        exit(ServiceContractHeader."Contract No.");
    end;

    local procedure CreateDirectDebitPaymentMethod(var PaymentMethod: Record "Payment Method")
    var
        PaymentTerms: Record "Payment Terms";
    begin
        LibraryERM.CreatePaymentTerms(PaymentTerms);
        LibraryERM.CreatePaymentMethod(PaymentMethod);
        PaymentMethod.Validate("Direct Debit", true);
        PaymentMethod.Validate("Direct Debit Pmt. Terms Code", PaymentTerms.Code);
        PaymentMethod.Modify();
    end;


    local procedure CreateServiceContractLine(ServiceContractHeader: Record "Service Contract Header"; ServiceItemNo: Code[20]): Decimal
    var
        ServiceContractLine: Record "Service Contract Line";
    begin
        ServiceContractLine.Init();
        ServiceContractLine.Validate("Contract Type", ServiceContractHeader."Contract Type");
        ServiceContractLine.Validate("Contract No.", ServiceContractHeader."Contract No.");
        ServiceContractLine.Validate("Line No.", GetLineNo(ServiceContractHeader));
        ServiceContractLine.Validate("Customer No.", ServiceContractHeader."Customer No.");
        ServiceContractLine.Validate("Service Item No.", ServiceItemNo);
        ServiceContractLine.Validate(Description, ServiceItemNo); // Required field - Not important for test
        ServiceContractLine.SetupNewLine();
        ServiceContractLine.Insert(true);
        exit(ServiceContractLine."Line Amount");
    end;

    local procedure CreateServiceItem(CustomerNo: Code[20]): Code[20]
    var
        ServiceItem: Record "Service Item";
    begin
        LibraryService.CreateServiceItem(ServiceItem, CustomerNo);
        ServiceItem.Validate("Item No.", CreateItem);
        ServiceItem.Validate("Sales Unit Price", ServiceItem."Sales Unit Price" * 12);
        ServiceItem.Modify(true);
        exit(ServiceItem."No.");
    end;

    local procedure CreateItem(): Code[20]
    var
        Item: Record Item;
    begin
        LibraryInventory.CreateItem(Item);
        with Item do begin
            Validate("Unit Cost", 10 * LibraryRandom.RandInt(100));
            Validate("Unit Price", "Unit Cost" + 10 * LibraryRandom.RandInt(100));
            Modify(true);
            exit("No.");
        end;
    end;

    local procedure CreateSignServiceContractWithStartingDate(StartingDate: Date; Prepaid: Boolean; ContractLinesOnInvoice: Boolean): Code[20]
    var
        ServiceContractHeader: Record "Service Contract Header";
    begin
        CreateServiceContractHeader(ServiceContractHeader, LibrarySales.CreateCustomerNo);
        UpdateServiceContractHeader(
          ServiceContractHeader, StartingDate, ServiceContractHeader."Invoice Period"::Quarter, Prepaid, ContractLinesOnInvoice);
        CreateServiceContractLine(
          ServiceContractHeader, CreateServiceItem(ServiceContractHeader."Customer No."));
        SignContract(ServiceContractHeader."Contract No.");
        exit(ServiceContractHeader."Contract No.");
    end;

    local procedure CreatePostServiceContractInvoice(ContractNo: Code[20]; PostingDate: Date)
    var
        ServiceContractHeader: Record "Service Contract Header";
        ServiceHeader: Record "Service Header";
        CreateContractInvoices: Report "Create Contract Invoices";
    begin
        Clear(CreateContractInvoices);
        ServiceContractHeader.SetRange("Contract No.", ContractNo);
        CreateContractInvoices.SetTableView(ServiceContractHeader);
        CreateContractInvoices.SetOptions(PostingDate, PostingDate, 0);
        CreateContractInvoices.UseRequestPage(false);
        CreateContractInvoices.Run();

        FindServiceHeader(ServiceHeader, ServiceHeader."Document Type"::Invoice, ContractNo);
        LibraryService.PostServiceOrder(ServiceHeader, true, false, true);
    end;

    local procedure CreatePostServiceContractCreditMemo(ContractNo: Code[20]; ExpirationDate: Date)
    var
        ServiceContractLine: Record "Service Contract Line";
        ServiceHeader: Record "Service Header";
        ServContractManagement: Codeunit ServContractManagement;
    begin
        FindServiceContractLine(ServiceContractLine, ContractNo);
        ServiceContractLine.Validate("Contract Expiration Date", ExpirationDate);
        ServiceContractLine.Modify(true);

        ServContractManagement.CreateContractLineCreditMemo(ServiceContractLine, false);
        FindServiceHeader(ServiceHeader, ServiceHeader."Document Type"::"Credit Memo", ServiceContractLine."Contract No.");
        LibraryService.PostServiceOrder(ServiceHeader, true, false, true);
    end;

    local procedure CreateSingAndLockServiceContract(var ServiceContractHeader: Record "Service Contract Header") LineAmount: Decimal
    begin
        CreateServiceContractHeader(ServiceContractHeader, LibrarySales.CreateCustomerNo);
        UpdateServiceContractHeader(
          ServiceContractHeader, WorkDate(), ServiceContractHeader."Invoice Period"::Year, true, true);
        Evaluate(ServiceContractHeader."Service Period", '<1Y>');
        ServiceContractHeader."Expiration Date" := CalcDate('<+1Y>', ServiceContractHeader."Starting Date");
        ServiceContractHeader.Modify();
        LineAmount := CreateServiceContractLine(
            ServiceContractHeader, CreateServiceItem(ServiceContractHeader."Customer No."));
        SignContract(ServiceContractHeader."Contract No.");
        LockServContract(ServiceContractHeader."Contract No.");
        exit(LineAmount);
    end;

    local procedure CreateServiceInvoice(ContractNo: Code[20])
    var
        ServiceContractHeader: Record "Service Contract Header";
        ServContractManagement: Codeunit ServContractManagement;
    begin
        Clear(ServContractManagement);
        ServiceContractHeader.Get(ServiceContractHeader."Contract Type"::Contract, ContractNo);
        ServContractManagement.InitCodeUnit();
        ServContractManagement.CreateInvoice(ServiceContractHeader);
        ServContractManagement.FinishCodeunit();
    end;

    local procedure AddServiceContractLine(ContractNo: Code[20]) MonthlyAmount: Decimal
    var
        ServiceContractHeader: Record "Service Contract Header";
    begin
        ServiceContractHeader.Get(ServiceContractHeader."Contract Type"::Contract, ContractNo);
        MonthlyAmount := CreateServiceContractLine(
            ServiceContractHeader, CreateServiceItem(ServiceContractHeader."Customer No."));
    end;

    local procedure FindServiceContractLine(var ServiceContractLine: Record "Service Contract Line"; ContractNo: Code[20])
    begin
        with ServiceContractLine do begin
            SetRange("Contract Type", "Contract Type"::Contract);
            SetRange("Contract No.", ContractNo);
            FindFirst();
        end;
    end;

    local procedure FindServiceHeader(var ServiceHeader: Record "Service Header"; DocumentType: Enum "Service Document Type"; ContractNo: Code[20])
    begin
        with ServiceHeader do begin
            SetRange("Document Type", DocumentType);
            SetRange("Contract No.", ContractNo);
            FindFirst();
        end;
    end;

    local procedure GetLineNo(ServiceContractHeader: Record "Service Contract Header"): Integer
    var
        ServiceContractLine: Record "Service Contract Line";
    begin
        ServiceContractLine.SetRange("Contract Type", ServiceContractHeader."Contract Type");
        ServiceContractLine.SetRange("Contract No.", ServiceContractHeader."Contract No.");
        if ServiceContractLine.FindLast() then
            exit(ServiceContractLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure GetServiceContractAccountNo(ContractNo: Code[20]): Code[20]
    var
        ServiceContractHeader: Record "Service Contract Header";
        ServiceContractAccountGroup: Record "Service Contract Account Group";
    begin
        ServiceContractHeader.Get(ServiceContractHeader."Contract Type"::Contract, ContractNo);
        ServiceContractAccountGroup.Get(ServiceContractHeader."Serv. Contract Acc. Gr. Code");
        if ServiceContractHeader.Prepaid then
            exit(ServiceContractAccountGroup."Prepaid Contract Acc.");
        exit(ServiceContractAccountGroup."Non-Prepaid Contract Acc.");
    end;

    local procedure CalcAnnualAmount(ServiceContractHeader: Record "Service Contract Header"): Decimal
    var
        ServiceContractLine: Record "Service Contract Line";
    begin
        ServiceContractLine.SetRange("Contract Type", ServiceContractHeader."Contract Type");
        ServiceContractLine.SetRange("Contract No.", ServiceContractHeader."Contract No.");
        ServiceContractLine.CalcSums("Line Amount");
        exit(ServiceContractLine."Line Amount");
    end;

    local procedure ModifyServContractExpirationDateVerifyAnnualAmount(var ServiceContractHeader: Record "Service Contract Header"; ExpirationDate: Date)
    var
        ServContractMgt: Codeunit ServContractManagement;
    begin
        ServiceContractHeader.Validate("Expiration Date", ExpirationDate);
        ServiceContractHeader.Modify(true);
        ServiceContractHeader.TestField("Amount per Period",
          Round(ServiceContractHeader."Annual Amount" / 12 *
            ServContractMgt.NoOfMonthsAndMPartsInPeriod(
              ServiceContractHeader."Next Invoice Period Start", ServiceContractHeader."Expiration Date")));
    end;

    local procedure UpdateNoSeriesAndGetLastNoUsed(): Code[20]
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        ServiceMgtSetup: Record "Service Mgt. Setup";
    begin
        ServiceMgtSetup.Get();
        NoSeries.SetRange(Code, ServiceMgtSetup."Service Contract Nos.");
        NoSeries.FindFirst();
        NoSeries.Validate("Manual Nos.", false);
        NoSeries.Modify(true);

        NoSeriesLine.SetRange("Series Code", ServiceMgtSetup."Service Contract Nos.");
        NoSeriesLine.FindFirst();
        exit(NoSeriesLine."Last No. Used");
    end;

    local procedure UpdateGlobalDimensionCodeInServiceContract(var ServiceContractHeader: Record "Service Contract Header")
    var
        DimensionValue: Record "Dimension Value";
    begin
        LibraryDimension.CreateDimensionValue(DimensionValue, LibraryERM.GetGlobalDimensionCode(1));
        ServiceContractHeader.Find();
        ServiceContractHeader.Validate("Shortcut Dimension 1 Code", DimensionValue.Code);
        ServiceContractHeader.Modify(true);
    end;

    local procedure UpdateGlobalDimensionCodesInServiceContract(var ServiceContractHeader: Record "Service Contract Header")
    var
        DimensionValue: Array[2] of Record "Dimension Value";
    begin
        LibraryDimension.CreateDimensionValue(DimensionValue[1], LibraryERM.GetGlobalDimensionCode(1));
        LibraryDimension.CreateDimensionValue(DimensionValue[2], LibraryERM.GetGlobalDimensionCode(2));
        ServiceContractHeader.Find();
        ServiceContractHeader.Validate("Shortcut Dimension 1 Code", DimensionValue[1].Code);
        ServiceContractHeader.Validate("Shortcut Dimension 2 Code", DimensionValue[2].Code);
        ServiceContractHeader.Modify(true);
    end;

    local procedure UpdateServiceContractHeader(var ServiceContractHeader: Record "Service Contract Header"; StartingDate: Date; InvoicePeriod: Enum "Service Contract Header Invoice Period"; NewPrepaid: Boolean; ContractLinesOnInvoice: Boolean)
    begin
        with ServiceContractHeader do begin
            Validate(Prepaid, NewPrepaid);
            Validate("Starting Date", StartingDate);
            Validate("Invoice Period", InvoicePeriod);
            Validate("Contract Lines on Invoice", ContractLinesOnInvoice);
            Modify(true);
        end;
    end;

    local procedure Remove(Value: Text[1024]; Trim: Text[1024]) Result: Text[1024]
    begin
        Result := Value;
        if not (StrPos(Value, Trim) < 0) then
            Result := DelStr(Value, StrPos(Value, Trim), StrLen(Trim));
    end;

    local procedure SetupForContractValueCalculate()
    var
        ServiceMgtSetup: Record "Service Mgt. Setup";
    begin
        // Setup the fields Contract Value Calc. Method and Contract Value % of the Service Management Setup.
        ServiceMgtSetup.Get();
        ServiceMgtSetup.Validate("Contract Value Calc. Method", ServiceMgtSetup."Contract Value Calc. Method"::"Based on Unit Price");
        ServiceMgtSetup.Validate("Contract Value %", 100);
        ServiceMgtSetup.Modify(true);
    end;

    local procedure SignContract(ContractNo: Code[20])
    var
        ServiceContractHeader: Record "Service Contract Header";
        SignServContractDoc: Codeunit SignServContractDoc;
    begin
        ServiceContractHeader.Get(ServiceContractHeader."Contract Type"::Contract, ContractNo);
        ConfirmType := ConfirmType::Sign;
        SignServContractDoc.SignContract(ServiceContractHeader);
    end;

    local procedure OpenServContract(ContractNo: Code[20])
    var
        ServiceContractHeader: Record "Service Contract Header";
        LockOpenServContract: Codeunit "Lock-OpenServContract";
    begin
        ServiceContractHeader.Get(ServiceContractHeader."Contract Type"::Contract, ContractNo);
        LockOpenServContract.OpenServContract(ServiceContractHeader);
    end;

    local procedure LockServContract(ContractNo: Code[20])
    var
        ServiceContractHeader: Record "Service Contract Header";
        LockOpenServContract: Codeunit "Lock-OpenServContract";
    begin
        ServiceContractHeader.Get(ServiceContractHeader."Contract Type"::Contract, ContractNo);
        LockOpenServContract.LockServContract(ServiceContractHeader);
    end;

    local procedure UpdateSalesSetupDirectDebitMandateNos()
    var
        SalesSetup: Record "Sales & Receivables Setup";
    begin
        SalesSetup.Get();
        if SalesSetup."Direct Debit Mandate Nos." = '' then begin
            SalesSetup."Direct Debit Mandate Nos." := LibraryUtility.GetGlobalNoSeriesCode;
            SalesSetup.Modify();
        end;
    end;

    local procedure TestContractNo(ContractType: Enum "Service Contract Type")
    var
        Customer: Record Customer;
        ServiceContractHeader: Record "Service Contract Header";
        LastNoUsed: Code[20];
    begin
        // 1. Setup: CreateCustomer and get next Service Contract No from No Series.
        Initialize();
        LibrarySales.CreateCustomer(Customer);
        LastNoUsed := UpdateNoSeriesAndGetLastNoUsed();

        // 2. Exercise: Find Customer and Create new Service Contract.
        LibraryService.CreateServiceContractHeader(ServiceContractHeader, ContractType, Customer."No.");

        // 3. Verify: Check that the Service Contract No is incremented automatically.
        ServiceContractHeader.TestField("Contract No.", IncStr(LastNoUsed));
    end;

    local procedure VerifyServiceContractDates(ContractNo: Code[20]; ExpectedNextInvoiceDate: Date; ExpectedNextInvPeriodStartDate: Date; ExpectedNextInvPeriodEndDate: Date; ExpectedLastInvoiceDate: Date)
    var
        ServiceContractHeader: Record "Service Contract Header";
    begin
        with ServiceContractHeader do begin
            Get("Contract Type"::Contract, ContractNo);
            Assert.AreEqual(ExpectedNextInvoiceDate, "Next Invoice Date", FieldCaption("Next Invoice Date"));
            Assert.AreEqual(ExpectedNextInvPeriodStartDate, "Next Invoice Period Start", FieldCaption("Next Invoice Period Start"));
            Assert.AreEqual(ExpectedNextInvPeriodEndDate, "Next Invoice Period End", FieldCaption("Next Invoice Period End"));
            Assert.AreEqual(ExpectedLastInvoiceDate, "Last Invoice Date", FieldCaption("Last Invoice Date"));
        end;
    end;

    local procedure VerifyOpenServiceInvoiceDetails(ContractNo: Code[20]; ExpectedCount: Integer; ExpectedAccountNo: Code[20]; ExpectedAmount: Decimal)
    var
        ServiceHeader: Record "Service Header";
        ServiceLine: Record "Service Line";
    begin
        FindServiceHeader(ServiceHeader, ServiceHeader."Document Type"::Invoice, ContractNo);
        with ServiceLine do begin
            SetRange("Document Type", "Document Type"::Invoice);
            SetRange("Document No.", ServiceHeader."No.");
            SetRange(Type, Type::"G/L Account");
            Assert.RecordCount(ServiceLine, ExpectedCount);
            FindSet();
            repeat
                Assert.AreEqual(ExpectedAccountNo, "No.", FieldCaption("No."));
                Assert.AreEqual(ExpectedAmount, Amount, FieldCaption(Amount));
            until Next = 0;
        end;
    end;

    local procedure VerifyServiceInvoiceLineAmount(ServiceContractHeader: Record "Service Contract Header"; ExpectedAmount: Decimal; ExpectedCount: Integer)
    var
        ServiceHeader: Record "Service Header";
        ServiceLine: Record "Service Line";
        I: Integer;
    begin
        ServiceHeader.SetRange("Posting Date", WorkDate());
        FindServiceHeader(ServiceHeader, ServiceHeader."Document Type"::Invoice, ServiceContractHeader."Contract No.");
        with ServiceLine do begin
            SetRange("Document Type", "Document Type"::Invoice);
            SetRange("Document No.", ServiceHeader."No.");
            SetRange(Type, Type::"G/L Account");
            Assert.AreEqual(ExpectedCount, Count, '');
            FindSet();
            for I := 1 to ExpectedCount - 1 do begin
                Assert.AreNearlyEqual(
                  ExpectedAmount, Amount,
                  LibraryERM.GetCurrencyAmountRoundingPrecision(ServiceHeader."Currency Code"),
                  FieldCaption(Amount));
                Next;
            end;
        end;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure ContractTemplateHandler(var ServiceContractTemplateList: Page "Service Contract Template List"; var Response: Action)
    begin
        Response := ACTION::LookupOK;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure ContractAmountDistribution(var ContractAmountDistribution: Page "Contract Amount Distribution"; var Response: Action)
    begin
        ContractAmountDistribution.SetResult(DistributionType);
        Response := ACTION::Yes;
    end;

    [ConfirmHandler]
    [Scope('OnPrem')]
    procedure ConfirmDialog(Question: Text[1024]; var Reply: Boolean)
    begin
        // Message verification can not be done language independant.
        // Verification should be done based on outcome of the action

        case ConfirmType of
            ConfirmType::Create:
                Assert.IsTrue(StrPos(Question, 'Do you want to create') > 0, 'Wrong confirm for create');
            ConfirmType::Sign:
                begin
                    ConfirmType := ConfirmType::Invoice;
                    Assert.IsTrue(StrPos(Question, 'Do you want to sign') > 0, 'Wrong confirm for sign');
                end;
        end;
        Reply := true;
    end;

    [ConfirmHandler]
    [Scope('OnPrem')]
    procedure ConfirmDialogHandler(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure SelectTemplate(var ServiceContractTemplateList: Page "Service Contract Template List"; var Response: Action)
    begin
        Response := ACTION::OK;
    end;

    [MessageHandler]
    [Scope('OnPrem')]
    procedure MessageHandler(Message: Text[1024])
    begin
        // Message verification can not be done language independant.
        // Verification should be done based on outcome of the action
    end;
}

