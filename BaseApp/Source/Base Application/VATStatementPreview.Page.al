page 474 "VAT Statement Preview"
{
    Caption = 'VAT Statement Preview';
    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = ListPlus;
    SaveValues = true;
    SourceTable = "VAT Statement Name";

    layout
    {
        area(content)
        {
            group(General)
            {
                Caption = 'General';
                field(Selection; Selection)
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Include VAT entries';
                    ToolTip = 'Specifies that VAT entries are included in the VAT Statement Preview window. This only works for lines of type VAT Entry Totaling. It does not work for lines of type Account Totaling.';

                    trigger OnValidate()
                    begin
                        if Selection = Selection::"Open and Closed" then
                            OpenandClosedSelectionOnValida();
                        if Selection = Selection::Closed then
                            ClosedSelectionOnValidate();
                        if Selection = Selection::Open then
                            OpenSelectionOnValidate();
                    end;
                }
                field(PeriodSelection; PeriodSelection)
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Include VAT entries';
                    ToolTip = 'Specifies that VAT entries are included in the VAT Statement Preview window. This only works for lines of type VAT Entry Totaling. It does not work for lines of type Account Totaling.';

                    trigger OnValidate()
                    begin
                        if PeriodSelection = PeriodSelection::"Before and Within Period" then
                            BeforeandWithinPeriodSelection();
                        if PeriodSelection = PeriodSelection::"Within Period" then
                            WithinPeriodPeriodSelectionOnV();
                    end;
                }
                field(UseAmtsInAddCurr; UseAmtsInAddCurr)
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Show Amounts in Add. Reporting Currency';
                    MultiLine = true;
                    ToolTip = 'Specifies that the VAT Statement Preview window shows amounts in the additional reporting currency.';

                    trigger OnValidate()
                    begin
                        UseAmtsInAddCurrOnPush();
                    end;
                }
                field(VATDateType; VATDateType) 
                {
                    ApplicationArea = VAT;
                    Caption = 'VAT Date Type';
                    ToolTip = 'Specifies what date will be used to filter the amounts in the window.';

                    trigger OnValidate()
                    begin
                        UpdateSubForm();
                        CurrPage.Update();
                    end;

                }
                field(DateFilter; DateFilter)
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Date Filter';
                    ToolTip = 'Specifies the dates that will be used to filter the amounts in the window.';

                    trigger OnValidate()
                    var
                        FilterTokens: Codeunit "Filter Tokens";
                    begin
                        FilterTokens.MakeDateFilter(DateFilter);
                        Rec.SetFilter("Date Filter", DateFilter);
                        UpdateSubForm();
                        CurrPage.Update();
                    end;
                }
            }
            part(VATStatementLineSubForm; "VAT Statement Preview Line")
            {
                ApplicationArea = Basic, Suite;
                SubPageLink = "Statement Template Name" = FIELD("Statement Template Name"),
                              "Statement Name" = FIELD(Name);
                SubPageView = SORTING("Statement Template Name", "Statement Name", "Line No.");
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
    }

    trigger OnAfterGetCurrRecord()
    begin
        UpdateSubForm();
    end;

    trigger OnOpenPage()
    begin
        VATDateType := VATDateType::"Posting Date";
        if ValuesPassed then begin
            Selection := PassedSelection;
            PeriodSelection := PassedPeriodSelection;
            DateFilter := PassedDateFilter;
            Rec.SetFilter("Date Filter", PassedDateFilter);
        end else
            DateFilter := '';
        UpdateSubForm();
    end;

    var
        PassedSelection: Enum "VAT Statement Report Selection";
        PassedPeriodSelection: Enum "VAT Statement Report Period Selection";
        PassedDateFilter: Text[30];
        ValuesPassed: Boolean;

    protected var
        Selection: Enum "VAT Statement Report Selection";
        PeriodSelection: Enum "VAT Statement Report Period Selection";
        UseAmtsInAddCurr: Boolean;
        DateFilter: Text[30];
        VATDateType: Enum "VAT Date Type";

    procedure UpdateSubForm()
    begin
        CurrPage.VATStatementLineSubForm.PAGE.UpdateForm(Rec, Selection, PeriodSelection, UseAmtsInAddCurr, VATDateType);
    end;

    procedure GetParameters(var NewSelection: Enum "VAT Statement Report Selection"; var NewPeriodSelection: Enum "VAT Statement Report Period Selection"; var NewUseAmtsInAddCurr: Boolean)
    begin
        NewSelection := Selection;
        NewPeriodSelection := PeriodSelection;
        NewUseAmtsInAddCurr := UseAmtsInAddCurr;
    end;

    procedure SetParameters(NewSelection: Enum "VAT Statement Report Selection"; NewPeriodSelection: Enum "VAT Statement Report Period Selection"; NewDateFilter: Text[30])
    begin
        PassedSelection := NewSelection;
        PassedPeriodSelection := NewPeriodSelection;
        PassedDateFilter := NewDateFilter;
        Rec.SetFilter("Date Filter", PassedDateFilter);
        ValuesPassed := true;
    end;

    local procedure OpenandClosedSelectionOnPush()
    begin
        UpdateSubForm();
    end;

    local procedure ClosedSelectionOnPush()
    begin
        UpdateSubForm();
    end;

    local procedure OpenSelectionOnPush()
    begin
        UpdateSubForm();
    end;

    local procedure BeforeandWithinPeriodSelOnPush()
    begin
        UpdateSubForm();
    end;

    local procedure WithinPeriodPeriodSelectOnPush()
    begin
        UpdateSubForm();
    end;

    local procedure UseAmtsInAddCurrOnPush()
    begin
        UpdateSubForm();
    end;

    local procedure OpenSelectionOnValidate()
    begin
        OpenSelectionOnPush();
    end;

    local procedure ClosedSelectionOnValidate()
    begin
        ClosedSelectionOnPush();
    end;

    local procedure OpenandClosedSelectionOnValida()
    begin
        OpenandClosedSelectionOnPush();
    end;

    local procedure WithinPeriodPeriodSelectionOnV()
    begin
        WithinPeriodPeriodSelectOnPush();
    end;

    local procedure BeforeandWithinPeriodSelection()
    begin
        BeforeandWithinPeriodSelOnPush();
    end;
}

