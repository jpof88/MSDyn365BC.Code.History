report 88 "VAT- VIES Declaration Disk"
{
    Caption = 'VAT- VIES Declaration Disk';
    Permissions = TableData "VAT Entry" = imd;
    ProcessingOnly = true;
    UsageCategory = ReportsAndAnalysis;

    dataset
    {
        dataitem("VAT Entry"; "VAT Entry")
        {
            DataItemTableView = SORTING(Type, "Country/Region Code", "VAT Registration No.", "VAT Bus. Posting Group", "VAT Prod. Posting Group", "VAT Reporting Date") WHERE(Type = CONST(Sale));
            RequestFilterFields = "VAT Bus. Posting Group", "VAT Prod. Posting Group", "VAT Reporting Date";

            trigger OnAfterGetRecord()
            var
                VATEntry: Record "VAT Entry";
                TotalValueOfItemSupplies: Decimal;
                TotalValueOfServiceSupplies: Decimal;
                GroupTotal: Boolean;
            begin
                if "EU Service" then begin
                    if UseAmtsInAddCurr then
                        TotalValueOfServiceSupplies := "Additional-Currency Base"
                    else
                        TotalValueOfServiceSupplies := Base
                end else
                    if UseAmtsInAddCurr then
                        TotalValueOfItemSupplies := "Additional-Currency Base"
                    else
                        TotalValueOfItemSupplies := Base;

                if "EU 3-Party Trade" then begin
                    EU3PartyItemTradeAmt := EU3PartyItemTradeAmt + TotalValueOfItemSupplies;
                    EU3PartyServiceTradeAmt := EU3PartyServiceTradeAmt + TotalValueOfServiceSupplies;
                end;
                TotalValueofItemSuppliesTotal += TotalValueOfItemSupplies;
                TotalValueofServiceSuppliesTot += TotalValueOfServiceSupplies;

                VATEntry.Copy("VAT Entry");
                if VATEntry.Next() = 1 then begin
                    if (VATEntry."Country/Region Code" <> "Country/Region Code") or
                       (VATEntry."VAT Registration No." <> "VAT Registration No.")
                    then
                        GroupTotal := true;
                end else
                    GroupTotal := true;

                if GroupTotal then begin
                    case VATDateType of 
                        VATDateType::"VAT Reporting Date": WriteGrTotalsToFile(TotalValueofServiceSuppliesTot, TotalValueofItemSuppliesTotal, EU3PartyServiceTradeAmt, EU3PartyItemTradeAmt, "VAT Reporting Date");
                        VATDateType::"Posting Date": WriteGrTotalsToFile(TotalValueofServiceSuppliesTot, TotalValueofItemSuppliesTotal, EU3PartyServiceTradeAmt, EU3PartyItemTradeAmt, "Posting Date");
                        VATDateType::"Document Date": WriteGrTotalsToFile(TotalValueofServiceSuppliesTot, TotalValueofItemSuppliesTotal, EU3PartyServiceTradeAmt, EU3PartyItemTradeAmt, "Document Date");
                    end;
                    EU3PartyItemTradeTotalAmt += EU3PartyItemTradeAmt;
                    EU3PartyServiceTradeTotalAmt += EU3PartyServiceTradeAmt;

                    TotalValueofItemSuppliesTotal := 0;
                    TotalValueofServiceSuppliesTot := 0;

                    EU3PartyItemTradeAmt := 0;
                    EU3PartyServiceTradeAmt := 0;
                end;
            end;

            trigger OnPostDataItem()
            begin
                VATFile.Write(
                  Format(
                    '10' + DecimalNumeralZeroFormat(NoOfGrTotal, 9) +
                    DecimalNumeralZeroFormat(EU3PartyItemTradeTotalAmt, 15) +
                    DecimalNumeralSign(-EU3PartyItemTradeTotalAmt) +
                    DecimalNumeralZeroFormat(EU3PartyServiceTradeTotalAmt, 15) +
                    DecimalNumeralSign(-EU3PartyServiceTradeTotalAmt),
                    80));
                VATFile.Close();
            end;

            trigger OnPreDataItem()
            begin
                Clear(VATFile);
                VATFile.TextMode := true;
                VATFile.WriteMode := true;
                VATFile.Create(FileName);

                CompanyInfo.Get();
                GeneralLedgerSetup.Get();
                VATRegNo := ConvertStr(CompanyInfo."VAT Registration No.", Text001, '    ');
                VATFile.Write(Format('00' + Format(VATRegNo, 8) + Text002, 80));
                VATFile.Write(Format('0100001', 80));

                NoOfGrTotal := 0;
                case VATDateType of 
                    VATDateType::"VAT Reporting Date": Period := GetRangeMax("VAT Reporting Date");
                    VATDateType::"Posting Date": Period := GetRangeMax("Posting Date");
                    VATDateType::"Document Date": Period := GetRangeMax("Document Date");
                end;
                InternalReferenceNo := Format(Period, 4, 2) + '000000';
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
                    field(UseAmtsInAddCurr; UseAmtsInAddCurr)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Show Amounts in Add. Reporting Currency';
                        MultiLine = true;
                        ToolTip = 'Specifies if the reported amounts are shown in the additional reporting currency.';
                    }
                    field(VATDateTypeField; VATDateType)
                    {
                        ApplicationArea = VAT;
                        Caption = 'Period Date Type';
                        ToolTip = 'Specifies the type of date used for the report period.';
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

    trigger OnPostReport()
    var
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforeOnPostReport(FileName, ToFileNameTxt, HideFileDialog, IsHandled);
        if IsHandled then
            exit;

        if not HideFileDialog then begin
            FileManagement.DownloadHandler(FileName, '', '', FileManagement.GetToFilterText('', FileName), ToFileNameTxt);
            FileManagement.DeleteServerFile(FileName);
        end
    end;

    trigger OnPreReport()
    begin
        FileName := FileManagement.ServerTempFileName('txt');
    end;

    var
        CompanyInfo: Record "Company Information";
        Country: Record "Country/Region";
        Cust: Record Customer;
        GeneralLedgerSetup: Record "General Ledger Setup";
        FileManagement: Codeunit "File Management";
        VATFile: File;
        TotalValueofServiceSuppliesTot: Decimal;
        TotalValueofItemSuppliesTotal: Decimal;
        EU3PartyServiceTradeAmt: Decimal;
        EU3PartyItemTradeAmt: Decimal;
        EU3PartyItemTradeTotalAmt: Decimal;
        EU3PartyServiceTradeTotalAmt: Decimal;
        NoOfGrTotal: Integer;
        FileName: Text;
        VATRegNo: Code[20];
        InternalReferenceNo: Text[10];
        Period: Date;
        UseAmtsInAddCurr: Boolean;
        ToFileNameTxt: Label 'Default.txt';
        HideFileDialog: Boolean;
        VATDateType: Enum "VAT Date Type";

        Text001: Label 'WwWw';
        Text002: Label 'LIST';
        Text003: Label '%1 was not filled in for all VAT entries in which %2 = %3.';
        Text004: Label 'It is not possible to display %1 in a field with a length of %2.';

    local procedure DecimalNumeralSign(DecimalNumeral: Decimal): Text[1]
    begin
        if DecimalNumeral >= 0 then
            exit('+');
        exit('-');
    end;

    local procedure DecimalNumeralZeroFormat(DecimalNumeral: Decimal; Length: Integer): Text[250]
    begin
        exit(TextZeroFormat(DelChr(Format(Round(Abs(DecimalNumeral), 1, '<'), 0, 1)), Length));
    end;

    local procedure TextZeroFormat(Text: Text[250]; Length: Integer): Text[250]
    begin
        if StrLen(Text) > Length then
            Error(
              Text004,
              Text, Length);
        exit(PadStr('', Length - StrLen(Text), '0') + Text);
    end;

    local procedure WriteGrTotalsToFile(TotalValueofServiceSupplies: Decimal; TotalValueofItemSupplies: Decimal; EU3PartyServiceTradeAmt: Decimal; EU3PartyItemTradeAmt: Decimal; VATDate: Date)
    begin
        if (Round(Abs(TotalValueofItemSupplies), 1, '<') <> 0) or (Round(Abs(TotalValueofServiceSupplies), 1, '<') <> 0) or
           (Round(Abs(EU3PartyItemTradeAmt), 1, '<') <> 0) or (Round(Abs(EU3PartyServiceTradeAmt), 1, '<') <> 0)
        then
            with "VAT Entry" do begin
                if "VAT Registration No." = '' then begin
                    Type := Type::Sale;
                    Error(
                      Text003,
                      FieldCaption("VAT Registration No."), FieldCaption(Type), Type);
                end;

                Cust.Get(GetCustomerNoToCheck("VAT Entry"));
                Cust.TestField("Country/Region Code");
                Country.Get(Cust."Country/Region Code");
                Cust.TestField("VAT Registration No.");
                Country.Get("Country/Region Code");
                Country.TestField("EU Country/Region Code");
                NoOfGrTotal := NoOfGrTotal + 1;

                InternalReferenceNo := IncStr(InternalReferenceNo);
                ModifyVATEntryInternalRefNo("Country/Region Code", "Bill-to/Pay-to No.", InternalReferenceNo, VATDate);

                VATFile.Write(
                  Format(
                    '02' + Format(InternalReferenceNo, 10) +
                    DecimalNumeralZeroFormat(Date2DMY(Period, 3) mod 100, 2) +
                    DecimalNumeralZeroFormat(Date2DMY(Period, 2), 2) +
                    DecimalNumeralZeroFormat(Date2DMY(Period, 1), 2) +
                    Format(VATRegNo, 8) + Format(Country."EU Country/Region Code", 2) + Format("VAT Registration No.", 12) +
                    DecimalNumeralZeroFormat(TotalValueofItemSupplies, 15) + DecimalNumeralSign(-TotalValueofItemSupplies) + '0' +
                    DecimalNumeralZeroFormat(TotalValueofServiceSupplies, 15) + DecimalNumeralSign(-TotalValueofServiceSupplies) + '0' +
                    DecimalNumeralZeroFormat(EU3PartyItemTradeAmt, 15) + DecimalNumeralSign(-EU3PartyItemTradeAmt) + '0' +
                    DecimalNumeralZeroFormat(EU3PartyServiceTradeAmt, 15) + DecimalNumeralSign(-EU3PartyServiceTradeAmt),
                    120));
            end;
    end;

    local procedure GetCustomerNoToCheck(VATEntry: Record "VAT Entry"): Code[20]
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
        DetailedCustLedgEntry: Record "Detailed Cust. Ledg. Entry";
    begin
        if GeneralLedgerSetup."Bill-to/Sell-to VAT Calc." = GeneralLedgerSetup."Bill-to/Sell-to VAT Calc."::"Bill-to/Pay-to No." then
            exit(VATEntry."Bill-to/Pay-to No.");

        DetailedCustLedgEntry.SetRange("Customer No.", VATEntry."Bill-to/Pay-to No.");
        DetailedCustLedgEntry.SetRange("Document Type", VATEntry."Document Type");
        DetailedCustLedgEntry.SetRange("Document No.", VATEntry."Document No.");
        DetailedCustLedgEntry.SetRange("Posting Date", VATEntry."Posting Date");
        DetailedCustLedgEntry.FindFirst(); 
        CustLedgerEntry.Get(DetailedCustLedgEntry."Cust. Ledger Entry No.");
        exit(CustLedgerEntry."Sell-to Customer No.");
    end;

    procedure GetFileName(): Text[1024]
    begin
        exit(FileName);
    end;

    procedure InitializeRequest(NewHideFileDialog: Boolean)
    begin
        HideFileDialog := NewHideFileDialog;
        VATDateType := VATDateType::"Posting Date";
    end;

    local procedure ModifyVATEntryInternalRefNo(CountryRegionCode: Code[10]; BillToPayToNo: Code[20]; InternalRefNo: Text[30]; VATDate: Date)
    var
        VATEntry: Record "VAT Entry";
    begin
        VATEntry.SetRange("Country/Region Code", CountryRegionCode);
        VATEntry.SetRange("Bill-to/Pay-to No.", BillToPayToNo);
        case VATDateType of 
            VATDateType::"VAT Reporting Date": VATEntry.SetRange("VAT Reporting Date", VATDate);
            VATDateType::"Posting Date": VATEntry.SetRange("Posting Date", VATDate);
            VATDateType::"Document Date": VATEntry.SetRange("Document Date", VATDate);
        end;
        VATEntry.ModifyAll("Internal Ref. No.", InternalRefNo);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeOnPostReport(var FileName: Text; ToFileNameTxt: Text; HideFileDialog: Boolean; var IsHandled: Boolean)
    begin
    end;
}

