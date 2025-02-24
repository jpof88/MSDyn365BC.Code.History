report 1496 "Suggest Bank Acc. Recon. Lines"
{
    Caption = 'Suggest Bank Acc. Recon. Lines';
    ProcessingOnly = true;

    dataset
    {
        dataitem("Bank Account"; "Bank Account")
        {
            DataItemTableView = SORTING("No.");

            trigger OnAfterGetRecord()
            var
                LocalCheckLedgerEntry: Record "Check Ledger Entry";
            begin
                BankAccLedgEntry.Reset();
                BankAccLedgEntry.SetCurrentKey("Bank Account No.", "Posting Date");
                BankAccLedgEntry.SetRange("Bank Account No.", "No.");
                BankAccLedgEntry.SetRange("Posting Date", StartDate, EndDate);
                BankAccLedgEntry.SetRange(Open, true);
                BankAccLedgEntry.SetRange("Statement Status", BankAccLedgEntry."Statement Status"::Open);
                if ExcludeReversedEntries then
                    BankAccLedgEntry.SetRange(Reversed, false);
                EOFBankAccLedgEntries := not BankAccLedgEntry.Find('-');

                while not EOFBankAccLedgEntries do begin
                    InsertBankAccReconciliationLine(BankAccLedgEntry);
                    LocalCheckLedgerEntry.SetRange("Bank Account Ledger Entry No.", BankAccLedgEntry."Entry No.");
                    if LocalCheckLedgerEntry.FindFirst() then
                        MatchCLEToBankAccReconciliationLine(BankAccReconLine, LocalCheckLedgerEntry)
                    else
                        MatchBLEToBankAccReconciliationLine(BankAccReconLine, BankAccLedgEntry);
                    EOFBankAccLedgEntries := BankAccLedgEntry.Next() = 0;
                end;
            end;

            trigger OnPreDataItem()
            begin
                OnPreDataItemBankAccount(ExcludeReversedEntries);

                if EndDate = 0D then
                    Error(Text000);

                if BankAccRecon."Statement Date" <> 0D then
                    if BankAccRecon."Statement Date" < EndDate then
                        EndDate := BankAccRecon."Statement Date";

                BankAccReconLine.FilterBankRecLines(BankAccRecon);
                if not BankAccReconLine.FindLast() then begin
                    BankAccReconLine."Statement Type" := BankAccRecon."Statement Type";
                    BankAccReconLine."Bank Account No." := BankAccRecon."Bank Account No.";
                    BankAccReconLine."Statement No." := BankAccRecon."Statement No.";
                    BankAccReconLine."Statement Line No." := 0;
                end;

                SetRange("No.", BankAccRecon."Bank Account No.");
            end;
        }
    }

    requestpage
    {
        SaveValues = true;

        layout
        {
            area(content)
            {
                group(Options)
                {
                    Caption = 'Options';
                    group("Statement Period")
                    {
                        Caption = 'Statement Period';
                        field(StartingDate; StartDate)
                        {
                            ApplicationArea = Basic, Suite;
                            Caption = 'Starting Date';
                            ToolTip = 'Specifies the date from which the report or batch job processes information.';
                        }
                        field(EndingDate; EndDate)
                        {
                            ApplicationArea = Basic, Suite;
                            Caption = 'Ending Date';
                            ToolTip = 'Specifies the date to which the report or batch job processes information.';
                        }
                    }
                    field(IncludeChecks; IncludeChecks)
                    {
                        ApplicationArea = Basic, Suite;
                        Visible = False;
                        Caption = 'Include Checks';
                        ToolTip = 'Specifies if you want the report to include check ledger entries. If you choose this option, check ledger entries are suggested instead of the corresponding bank account ledger entries.';
                    }
                    field(ExcludeReversedEntries; ExcludeReversedEntries)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Exclude Reversed Entries';
                        ToolTip = 'Specifies if you want to exclude reversed entries from the report.';
                    }
                }
            }
        }

        actions
        {
        }
    }

    labels
    {
    }

    var
        BankAccLedgEntry: Record "Bank Account Ledger Entry";
        BankAccRecon: Record "Bank Acc. Reconciliation";
        BankAccReconLine: Record "Bank Acc. Reconciliation Line";
        BankAccSetStmtNo: Codeunit "Bank Acc. Entry Set Recon.-No.";
        CheckEntrySetReconNo: Codeunit "Check Entry set Recon.-No.";
        StartDate: Date;
        EndDate: Date;
        IncludeChecks: Boolean;
        EOFBankAccLedgEntries: Boolean;
        ExcludeReversedEntries: Boolean;

        Text000: Label 'Enter the Ending Date.';

    procedure SetStmt(var BankAccRecon2: Record "Bank Acc. Reconciliation")
    begin
        BankAccRecon := BankAccRecon2;
        EndDate := BankAccRecon."Statement Date";
    end;

    local procedure InsertBankAccReconciliationLine(var BankAccountLedgerEntry: Record "Bank Account Ledger Entry")
    begin
        BankAccReconLine.Init();
        BankAccReconLine."Statement Line No." := BankAccReconLine."Statement Line No." + 10000;
        BankAccReconLine."Transaction Date" := BankAccountLedgerEntry."Posting Date";
        BankAccReconLine.Description := BankAccountLedgerEntry.Description;
        BankAccReconLine."Document No." := BankAccountLedgerEntry."Document No.";
        BankAccReconLine."Statement Amount" := BankAccountLedgerEntry."Remaining Amount";

        OnBeforeInsertBankAccReconLine(BankAccReconLine, BankAccountLedgerEntry);
        BankAccReconLine.Insert();
    end;

    local procedure MatchCLEToBankAccReconciliationLine(var BankAccReconciliationLine: Record "Bank Acc. Reconciliation Line"; var CheckLedgerEntry: Record "Check Ledger Entry")
    var
        BankAccount: Record "Bank Account";
    begin
        if BankAccount.Get(CheckLedgerEntry."Bank Account No.") then
            if not BankAccount."Disable Automatic Pmt Matching" then begin
                BankAccReconciliationLine."Applied Amount" := BankAccReconciliationLine."Statement Amount";
                BankAccReconciliationLine."Check No." := CheckLedgerEntry."Check No.";
                BankAccReconciliationLine."Applied Entries" := 1;
                CheckEntrySetReconNo.SetReconNo(CheckLedgerEntry, BankAccReconciliationLine);
            end;
        OnInsertCheckLineOnBeforeBankAccReconLineInsert(BankAccReconciliationLine, CheckLedgerEntry);
        BankAccReconciliationLine.Modify();
    end;

    local procedure MatchBLEToBankAccReconciliationLine(var BankAccReconciliationLine: Record "Bank Acc. Reconciliation Line"; var BankAccountLedgerEntry: Record "Bank Account Ledger Entry")
    var
        BankAccount: Record "Bank Account";
    begin
        if BankAccount.Get(BankAccountLedgerEntry."Bank Account No.") then
            if not BankAccount."Disable Automatic Pmt Matching" then begin
                BankAccReconciliationLine."Applied Amount" := BankAccReconciliationLine."Statement Amount";
                BankAccReconciliationLine."Applied Entries" := 1;
                BankAccSetStmtNo.SetReconNo(BankAccountLedgerEntry, BankAccReconciliationLine);
            end;
        BankAccReconciliationLine.Modify();
    end;

    procedure InitializeRequest(NewStartDate: Date; NewEndDate: Date; NewIncludeChecks: Boolean)
    begin
        StartDate := NewStartDate;
        if (BankAccRecon."Statement Date" = 0D) or (NewEndDate < BankAccRecon."Statement Date") then
            EndDate := NewEndDate
        else
            EndDate := BankAccRecon."Statement Date";
        NewIncludeChecks := false;
        IncludeChecks := NewIncludeChecks;
        ExcludeReversedEntries := false;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeInsertBankAccReconLine(var BankAccReconLine: Record "Bank Acc. Reconciliation Line"; var BankAccLedgEntry: Record "Bank Account Ledger Entry")
    begin
    end;

    [IntegrationEvent(false, false)]
    [Scope('OnPrem')]
    procedure OnPreDataItemBankAccount(var ExcludeReversedEntries: Boolean)
    begin
        // ExcludeReversedEntries = FALSE by default
    end;

    [IntegrationEvent(false, false)]
    local procedure OnInsertCheckLineOnBeforeBankAccReconLineInsert(var BankAccReconLine: Record "Bank Acc. Reconciliation Line"; CheckLedgEntry: Record "Check Ledger Entry")
    begin
    end;
}

