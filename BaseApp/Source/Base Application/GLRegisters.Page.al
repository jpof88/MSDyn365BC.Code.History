page 116 "G/L Registers"
{
    AdditionalSearchTerms = 'general ledger registers';
    ApplicationArea = Basic, Suite;
    Caption = 'G/L Registers';
    Editable = false;
    PageType = List;
    SourceTable = "G/L Register";
    SourceTableView = SORTING("No.")
                      ORDER(Descending);
    UsageCategory = History;

    layout
    {
        area(content)
        {
            repeater(Control1)
            {
                ShowCaption = false;
                field("No."; Rec."No.")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the number of the general ledger register.';
                }
                field("Creation Date"; Rec."Creation Date")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the date when the entries in the register were posted.';
                }
                field("Creation Time"; Rec."Creation Time")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the time when the entries in the register were posted.';
                }
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the ID of the user who posted the entry, to be used, for example, in the change log.';

                    trigger OnDrillDown()
                    var
                        UserMgt: Codeunit "User Management";
                    begin
                        UserMgt.DisplayUserInformation("User ID");
                    end;
                }
                field("Source Code"; Rec."Source Code")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the source code for the entries in the register.';
                }
                field("Journal Batch Name"; Rec."Journal Batch Name")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the batch name of the general journal that the entries were posted from.';
                }
                field(Reversed; Reversed)
                {
                    ApplicationArea = Suite;
                    ToolTip = 'Specifies if the register has been reversed (undone) from the Reverse Entries window.';
                    Visible = false;
                }
                field("From Entry No."; Rec."From Entry No.")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the first general ledger entry number in the register.';
                }
                field("To Entry No."; Rec."To Entry No.")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the last general ledger entry number in the register.';
                }
                field("From VAT Entry No."; Rec."From VAT Entry No.")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the first VAT entry number in the register.';
                }
                field("To VAT Entry No."; Rec."To VAT Entry No.")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the last entry number in the register.';
                }
            }
        }
        area(factboxes)
        {
            systempart(Control1900383207; Links)
            {
                ApplicationArea = RecordLinks;
                Visible = false;
            }
            systempart(Control1905767507; Notes)
            {
                ApplicationArea = Notes;
                Visible = false;
            }
        }
    }

    actions
    {
        area(navigation)
        {
            group("&Register")
            {
                Caption = '&Register';
                Image = Register;
                action("General Ledger")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'General Ledger';
                    Image = GLRegisters;
                    RunObject = Codeunit "G/L Reg.-Gen. Ledger";
                    ToolTip = 'View the general ledger entries that resulted in the current register entry.';
                }
                action("Customer &Ledger")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Customer &Ledger';
                    Image = CustomerLedger;
                    RunObject = Codeunit "G/L Reg.-Cust.Ledger";
                    ToolTip = 'View the customer ledger entries that resulted in the current register entry.';
                }
                action("Ven&dor Ledger")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Ven&dor Ledger';
                    Image = VendorLedger;
                    RunObject = Codeunit "G/L Reg.-Vend.Ledger";
                    ToolTip = 'View the vendor ledger entries that resulted in the current register entry.';
                }
                action("Bank Account Ledger")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Bank Account Ledger';
                    Image = BankAccountLedger;
                    RunObject = Codeunit "G/L Reg.-Bank Account Ledger";
                    ToolTip = 'View the bank account ledger entries that resulted in the current register entry.';
                }
                action("Fixed &Asset Ledger")
                {
                    ApplicationArea = FixedAssets;
                    Caption = 'Fixed &Asset Ledger';
                    Image = FixedAssetLedger;
                    RunObject = Codeunit "G/L Reg.-FALedger";
                    ToolTip = 'View registers that involve fixed assets.';
                }
                action("Maintenance Ledger")
                {
                    ApplicationArea = FixedAssets;
                    Caption = 'Maintenance Ledger';
                    Image = MaintenanceLedgerEntries;
                    RunObject = Codeunit "G/L Reg.-Maint.Ledger";
                    ToolTip = 'View the maintenance ledger entries for the selected fixed asset.';
                }
                action("VAT Entries")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'VAT Entries';
                    Image = VATLedger;
                    RunObject = Codeunit "G/L Reg.-VAT Entries";
                    ToolTip = 'View the VAT entries that are associated with the current register entry.';
                }
                action("Employee Ledger")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Employee Ledger';
                    Image = EmployeeAgreement;
                    ToolTip = 'View the employee ledger entries that resulted in the register entry.';

                    trigger OnAction()
                    var
                        EmployeeLedgerEntry: Record "Employee Ledger Entry";
                    begin
                        EmployeeLedgerEntry.SetRange("Entry No.", "From Entry No.", "To Entry No.");
                        PAGE.Run(PAGE::"Employee Ledger Entries", EmployeeLedgerEntry);
                    end;
                }
                action("Item Ledger Relation")
                {
                    ApplicationArea = Suite;
                    Caption = 'Item Ledger Relation';
                    Image = ItemLedger;
                    RunObject = Page "G/L - Item Ledger Relation";
                    RunPageLink = "G/L Register No." = FIELD("No.");
                    RunPageView = SORTING("G/L Register No.");
                    ToolTip = 'View the link between the general ledger entries and the value entries.';
                }

                action(ChangeDimensions)
                {
                    ApplicationArea = All;
                    Image = ChangeDimensions;
                    Caption = 'Correct Dimensions';
                    ToolTip = 'Correct dimensions for the related general ledger entries.';

                    trigger OnAction()
                    var
                        GLRegsiter: Record "G/L Register";
                        DimensionCorrection: Record "Dimension Correction";
                        DimensionCorrectionMgt: Codeunit "Dimension Correction Mgt";
                    begin
                        CurrPage.SetSelectionFilter(GLRegsiter);
                        DimensionCorrectionMgt.CreateCorrectionFromGLRegister(GLRegsiter, DimensionCorrection);
                        Page.Run(PAGE::"Dimension Correction Draft", DimensionCorrection);
                    end;
                }
            }
        }
        area(processing)
        {
            group(Reverse)
            {
                Caption = 'Reverse';
                Image = "ReverseRegister";
                action(ReverseRegister)
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Reverse Register';
                    Ellipsis = true;
                    Image = ReverseRegister;
                    ToolTip = 'Undo entries that were incorrectly posted. You can only reverse entries that were posted from a journal and have not already been involved in a reversal.';
                    Enabled = ReverseRegisterEnabled;

                    trigger OnAction()
                    var
                        ReversalEntry: Record "Reversal Entry";
                    begin
                        TestField("No.");
                        ReversalEntry.ReverseRegister("No.");
                    end;
                }
            }
            group("F&unctions")
            {
                Caption = 'F&unctions';
                Image = "Action";
                action("Delete Empty Registers")
                {
                    ApplicationArea = All;
                    Caption = 'Delete Empty Registers';
                    Image = Delete;
                    RunObject = Report "Delete Empty G/L Registers";
                    ToolTip = 'Find and delete empty G/L registers.';
                }
            }
        }
        area(reporting)
        {
            action("Detail Trial Balance")
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Detail Trial Balance';
                Image = "Report";
                RunObject = Report "Detail Trial Balance";
                ToolTip = 'Print or save a detail trial balance for the general ledger accounts that you specify.';
            }
            action("Trial Balance")
            {
                ApplicationArea = Suite;
                Caption = 'Trial Balance';
                Image = "Report";
                //The property 'PromotedCategory' can only be set if the property 'Promoted' is set to 'true'
                //PromotedCategory = "Report";
                RunObject = Report Budget;
                ToolTip = 'Print or save the chart of accounts that have balances and net changes.';
            }
            action("Trial Balance by Period")
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Trial Balance by Period';
                Image = "Report";
                RunObject = Report "Trial Balance by Period";
                ToolTip = 'Print or save the opening balance by general ledger account, the movements in the selected period of month, quarter, or year, and the resulting closing balance.';
            }
            action("G/L Register")
            {
                ApplicationArea = Suite;
                Caption = 'G/L Register';
                Image = "Report";
                RunObject = Report "G/L Register";
                ToolTip = 'View posted G/L entries.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process', Comment = 'Generated from the PromotedActionCategories property index 1.';

                actionref("General Ledger_Promoted"; "General Ledger")
                {
                }
                actionref("Customer &Ledger_Promoted"; "Customer &Ledger")
                {
                }
                actionref("Ven&dor Ledger_Promoted"; "Ven&dor Ledger")
                {
                }
                actionref("Employee Ledger_Promoted"; "Employee Ledger")
                {
                }
                actionref("Bank Account Ledger_Promoted"; "Bank Account Ledger")
                {
                }
                actionref("Fixed &Asset Ledger_Promoted"; "Fixed &Asset Ledger")
                {
                }
                actionref("Maintenance Ledger_Promoted"; "Maintenance Ledger")
                {
                }
                actionref("VAT Entries_Promoted"; "VAT Entries")
                {
                }
            }
            group(Category_Report)
            {
                Caption = 'Report', Comment = 'Generated from the PromotedActionCategories property index 2.';

                actionref("Detail Trial Balance_Promoted"; "Detail Trial Balance")
                {
                }
                actionref("Trial Balance by Period_Promoted"; "Trial Balance by Period")
                {
                }
                actionref("G/L Register_Promoted"; "G/L Register")
                {
                }
            }
            group(Category_Category4)
            {
                Caption = 'Reverse', Comment = 'Generated from the PromotedActionCategories property index 3.';

                actionref(ReverseRegister_Promoted; ReverseRegister)
                {
                }
                actionref(ChangeDimensions_Promoted; ChangeDimensions)
                {
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if FindSet() then;
    end;

    trigger OnAfterGetRecord()
    begin
        ReverseRegisterEnabled := GetReverseRegisterEnabled();
    end;

    local procedure GetReverseRegisterEnabled(): Boolean
    var
        IsHandled: Boolean;
        ReverseEnabled: Boolean;
    begin
        IsHandled := false;
        OnBeforeGetReverseRegisterEnabled("No.", ReverseEnabled, IsHandled);
        if IsHandled then
            exit(ReverseEnabled);

        if Reversed then
            exit(false);

        if "Journal Batch Name" = '' then
            exit(false);

        exit(true);
    end;

    var
        ReverseRegisterEnabled: Boolean;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeGetReverseRegisterEnabled(RegisterNo: Integer; var ReverseEnabled: Boolean; var IsHandled: Boolean)
    begin
    end;
}

