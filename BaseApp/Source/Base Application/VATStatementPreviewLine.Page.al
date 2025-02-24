page 475 "VAT Statement Preview Line"
{
    Caption = 'Lines';
    Editable = false;
    LinksAllowed = false;
    PageType = ListPart;
    SourceTable = "VAT Statement Line";

    layout
    {
        area(content)
        {
            repeater(Control1)
            {
                ShowCaption = false;
                field("Row No."; Rec."Row No.")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies a number that identifies the line.';
                }
                field(Description; Description)
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies a description of the VAT statement line.';
                }
                field(Type; Type)
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies what the VAT statement line will include.';
                }
                field("Amount Type"; Rec."Amount Type")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies if the VAT statement line shows the VAT amounts, or the base amounts on which the VAT is calculated.';
                }
                field("VAT Bus. Posting Group"; Rec."VAT Bus. Posting Group")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the VAT specification of the involved customer or vendor to link transactions made for this record with the appropriate general ledger account according to the VAT posting setup.';
                }
                field("VAT Prod. Posting Group"; Rec."VAT Prod. Posting Group")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the VAT specification of the involved item or resource to link transactions made for this record with the appropriate general ledger account according to the VAT posting setup.';
                }
                field("Tax Jurisdiction Code"; Rec."Tax Jurisdiction Code")
                {
                    ApplicationArea = SalesTax;
                    ToolTip = 'Specifies a tax jurisdiction code for the statement.';
                    Visible = false;
                }
                field("Use Tax"; Rec."Use Tax")
                {
                    ApplicationArea = SalesTax;
                    ToolTip = 'Specifies whether to use only entries from the VAT Entry table that are marked as Use Tax to be totaled on this line.';
                    Visible = false;
                }
                field(ColumnValue; ColumnValue)
                {
                    ApplicationArea = Basic, Suite;
                    AutoFormatType = 1;
                    BlankZero = true;
                    Caption = 'Column Amount';
                    DrillDown = true;
                    ToolTip = 'Specifies the type of entries that will be included in the amounts in columns.';

                    trigger OnDrillDown()
                    begin
                        case Type of
                            Type::"Account Totaling":
                                begin
                                    GLEntry.SetFilter("G/L Account No.", "Account Totaling");
                                    SetDateFilterForGLEntry(GLEntry);
                                    OnColumnValueDrillDownOnBeforeRunGeneralLedgerEntries(VATEntry, GLEntry, Rec);
                                    PAGE.Run(PAGE::"General Ledger Entries", GLEntry);
                                end;
                            Type::"VAT Entry Totaling":
                                begin
                                    VATEntry.Reset();
                                    SetKeyForVATEntry(VATEntry);
                                    VATEntry.SetRange(Type, "Gen. Posting Type");
                                    VATEntry.SetRange("VAT Bus. Posting Group", "VAT Bus. Posting Group");
                                    VATEntry.SetRange("VAT Prod. Posting Group", "VAT Prod. Posting Group");
                                    VATEntry.SetRange("Tax Jurisdiction Code", "Tax Jurisdiction Code");
                                    VATEntry.SetRange("Use Tax", "Use Tax");
                                    if GetFilter("Date Filter") <> '' then
                                        SetDateFilterForVATEntry(VATEntry);
                                        
                                    case Selection of
                                        Selection::Open:
                                            VATEntry.SetRange(Closed, false);
                                        Selection::Closed:
                                            VATEntry.SetRange(Closed, true);
                                        Selection::"Open and Closed":
                                            VATEntry.SetRange(Closed);
                                    end;
                                    OnBeforeOpenPageVATEntryTotaling(VATEntry, Rec, GLEntry);
                                    PAGE.Run(PAGE::"VAT Entries", VATEntry);
                                end;
                            Type::"Row Totaling",
                            Type::Description:
                                Error(Text000, FieldCaption(Type), Type);
                        end;
                    end;
                }
            }
        }
    }

    actions
    {
    }

    trigger OnAfterGetRecord()
    begin
        CalcColumnValue(Rec, ColumnValue, 0);
        if "Print with" = "Print with"::"Opposite Sign" then
            ColumnValue := -ColumnValue;
    end;

    var
        Text000: Label 'Drilldown is not possible when %1 is %2.';

    protected var
        GLEntry: Record "G/L Entry";
        VATEntry: Record "VAT Entry";
        VATStatement: Report "VAT Statement";
        ColumnValue: Decimal;
        Selection: Enum "VAT Statement Report Selection";
        PeriodSelection: Enum "VAT Statement Report Period Selection";
        UseAmtsInAddCurr: Boolean;
        VATDateType: Enum "VAT Date Type";

    local procedure SetKeyForVATEntry(var VATEntryLocal: Record "VAT Entry")
    begin
        case VATDateType of
            VATDateType::"Document Date": 
                if not VATEntryLocal.SetCurrentKey(Type, Closed, "VAT Bus. Posting Group", "VAT Prod. Posting Group", "Document Date") then
                    VATEntryLocal.SetCurrentKey(Type, Closed, "Tax Jurisdiction Code", "Use Tax", "Document Date");
            VATDateType::"Posting Date": 
                if not VATEntryLocal.SetCurrentKey(Type, Closed, "VAT Bus. Posting Group", "VAT Prod. Posting Group", "Posting Date") then
                    VATEntryLocal.SetCurrentKey(Type, Closed, "Tax Jurisdiction Code", "Use Tax", "Posting Date");
            VATDateType::"VAT Reporting Date":
                if not VATEntryLocal.SetCurrentKey(Type, Closed, "VAT Bus. Posting Group", "VAT Prod. Posting Group", "VAT Reporting Date") then
                    VATEntryLocal.SetCurrentKey(Type, Closed, "Tax Jurisdiction Code", "Use Tax", "VAT Reporting Date");
        end
    end;

    local procedure SetDateFilterForGLEntry(var GLEntryLocal: Record "G/L Entry")
    begin
        case VATDateType of
            VATDateType::"Document Date": Rec.CopyFilter("Date Filter", GLEntryLocal."Document Date");
            VATDateType::"Posting Date": Rec.CopyFilter("Date Filter", GLEntryLocal."Posting Date");
            VATDateType::"VAT Reporting Date": Rec.CopyFilter("Date Filter", GLEntryLocal."VAT Reporting Date");
        end
    end;

    local procedure SetDateFilterForVATEntry(var VATEntryLocal: Record "VAT Entry")
    begin
        if PeriodSelection = PeriodSelection::"Before and Within Period" then
            case VATDateType of
                VATDateType::"Document Date": VATEntryLocal.SetRange("Document Date", 0D, Rec.GetRangeMax("Date Filter"));
                VATDateType::"Posting Date": VATEntryLocal.SetRange("Posting Date", 0D, Rec.GetRangeMax("Date Filter"));
                VATDateType::"VAT Reporting Date": VATEntryLocal.SetRange("VAT Reporting Date", 0D, Rec.GetRangeMax("Date Filter"));
            end
        else
            case VATDateType of
                VATDateType::"Document Date": Rec.CopyFilter("Date Filter", VATEntryLocal."Document Date");
                VATDateType::"Posting Date": Rec.CopyFilter("Date Filter", VATEntryLocal."Posting Date");
                VATDateType::"VAT Reporting Date": Rec.CopyFilter("Date Filter", VATEntryLocal."VAT Reporting Date");
            end
    end;

    local procedure CalcColumnValue(VATStatementLine: Record "VAT Statement Line"; var ColumnValue: Decimal; Level: Integer)
    var
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforeCalcColumnValue(VATStatementLine, ColumnValue, Level, IsHandled, Selection, PeriodSelection, false, UseAmtsInAddCurr);
        if IsHandled then
            exit;

        VATStatement.CalcLineTotal(VATStatementLine, ColumnValue, Level);
    end;

    procedure UpdateForm(var VATStmtName: Record "VAT Statement Name"; NewSelection: Enum "VAT Statement Report Selection"; NewPeriodSelection: Enum "VAT Statement Report Period Selection"; NewUseAmtsInAddCurr: Boolean; NewVATDateType: Enum "VAT Date Type")
    begin
        SetRange("Statement Template Name", VATStmtName."Statement Template Name");
        SetRange("Statement Name", VATStmtName.Name);
        VATStmtName.CopyFilter("Date Filter", "Date Filter");
        Selection := NewSelection;
        PeriodSelection := NewPeriodSelection;
        UseAmtsInAddCurr := NewUseAmtsInAddCurr;
        VATDateType := NewVATDateType;
        VATStatement.InitializeRequest(VATStmtName, Rec, Selection, PeriodSelection, false, UseAmtsInAddCurr, NewVATDateType);
        OnUpdateFormOnBeforePageUpdate2(VATStmtName, Rec, Selection, PeriodSelection, false, UseAmtsInAddCurr, NewVATDateType);
        CurrPage.Update();

        OnAfterUpdateForm();
    end;

#if not CLEAN21
    [Obsolete('Replaced by UpdateForm(var VATStmtName: Record "VAT Statement Name"; NewSelection: Enum "VAT Statement Report Selection"; NewPeriodSelection: Enum "VAT Statement Report Period Selection"; NewUseAmtsInAddCurr: Boolean; NewVATDateType: Enum "VAT Date Type")', '21.0')]
    procedure UpdateForm(var VATStmtName: Record "VAT Statement Name"; NewSelection: Enum "VAT Statement Report Selection"; NewPeriodSelection: Enum "VAT Statement Report Period Selection"; NewUseAmtsInAddCurr: Boolean)
    begin
        SetRange("Statement Template Name", VATStmtName."Statement Template Name");
        SetRange("Statement Name", VATStmtName.Name);
        VATStmtName.CopyFilter("Date Filter", "Date Filter");
        Selection := NewSelection;
        PeriodSelection := NewPeriodSelection;
        UseAmtsInAddCurr := NewUseAmtsInAddCurr;
        VATStatement.InitializeRequest(VATStmtName, Rec, Selection, PeriodSelection, false, UseAmtsInAddCurr);
        OnUpdateFormOnBeforePageUpdate(VATStmtName, Rec, Selection, PeriodSelection, false, UseAmtsInAddCurr);
        CurrPage.Update();

        OnAfterUpdateForm();
    end;
#endif

    [IntegrationEvent(true, false)]
    local procedure OnBeforeCalcColumnValue(VATStatementLine: Record "VAT Statement Line"; var TotalAmount: Decimal; Level: Integer; var IsHandled: Boolean; Selection: Enum "VAT Statement Report Selection"; PeriodSelection: Enum "VAT Statement Report Period Selection"; PrintInIntegers: Boolean; UseAmtsInAddCurr: Boolean)
    begin
    end;

    [IntegrationEvent(true, false)]
    local procedure OnBeforeOpenPageVATEntryTotaling(var VATEntry: Record "VAT Entry"; var VATStatementLine: Record "VAT Statement Line"; var GLEntry: Record "G/L Entry")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnColumnValueDrillDownOnBeforeRunGeneralLedgerEntries(var VATEntry: Record "VAT Entry"; var GLEntry: Record "G/L Entry"; var VATStatementLine: Record "VAT Statement Line")
    begin
    end;

#if not CLEAN21
    [IntegrationEvent(false, false)]
    [Obsolete('Replaced by OnUpdateFormOnBeforePageUpdate2(var NewVATStmtName: Record "VAT Statement Name"; var NewVATStatementLine: Record "VAT Statement Line"; NewSelection: Enum "VAT Statement Report Selection"; NewPeriodSelection: Enum "VAT Statement Report Period Selection"; NewPrintInIntegers: Boolean; NewUseAmtsInAddCurr: Boolean; VATDateType: Enum "VAT Date Type")', '21.0')]
    local procedure OnUpdateFormOnBeforePageUpdate(var NewVATStmtName: Record "VAT Statement Name"; var NewVATStatementLine: Record "VAT Statement Line"; NewSelection: Enum "VAT Statement Report Selection"; NewPeriodSelection: Enum "VAT Statement Report Period Selection"; NewPrintInIntegers: Boolean; NewUseAmtsInAddCurr: Boolean)
    begin
    end;
#endif

    [IntegrationEvent(false, false)]
    local procedure OnUpdateFormOnBeforePageUpdate2(var NewVATStmtName: Record "VAT Statement Name"; var NewVATStatementLine: Record "VAT Statement Line"; NewSelection: Enum "VAT Statement Report Selection"; NewPeriodSelection: Enum "VAT Statement Report Period Selection"; NewPrintInIntegers: Boolean; NewUseAmtsInAddCurr: Boolean; NewVATDateType: Enum "VAT Date Type")
    begin
    end;

    [IntegrationEvent(true, false)]
    local procedure OnAfterUpdateForm()
    begin
    end;
}

