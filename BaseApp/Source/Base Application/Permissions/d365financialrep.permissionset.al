permissionset 7576 "D365 FINANCIAL REP."
{
    Assignable = true;

    Caption = 'Dynamics 365 Financial reports';
    Permissions = tabledata "Acc. Sched. KPI Web Srv. Line" = RIMD,
                  tabledata "Acc. Sched. KPI Web Srv. Setup" = RIMD,
                  tabledata "Acc. Schedule Line" = RIMD,
                  tabledata "Acc. Schedule Line Entity" = RIMD,
                  tabledata "Acc. Schedule Name" = RIMD,
                  tabledata "Financial Report" = RIMD,
                  tabledata "Financial Report User Filters" = RIMD,
                  tabledata "Accounting Period" = RIMD,
                  tabledata "Analysis Column" = RIMD,
                  tabledata "Analysis Column Template" = RIMD,
                  tabledata "Analysis Field Value" = Rimd,
                  tabledata "Analysis Line" = RIMD,
                  tabledata "Analysis Line Template" = RIMD,
                  tabledata "Analysis Report Name" = RIMD,
                  tabledata "Analysis Type" = RIMD,
                  tabledata "Analysis View" = RIMD,
                  tabledata "Analysis View Budget Entry" = RIMD,
                  tabledata "Analysis View Entry" = RIMD,
                  tabledata "Bank Acc. Reconciliation" = RIMD,
                  tabledata "Bank Acc. Reconciliation Line" = RIMD,
                  tabledata "Bank Acc. Rec. Match Buffer" = RIMD,
                  tabledata "Bank Account" = RM,
                  tabledata "Bank Account Ledger Entry" = Rimd,
                  tabledata "Bank Account Posting Group" = RIMD,
                  tabledata "Bank Account Statement" = RimD,
                  tabledata "Bank Account Statement Line" = Rimd,
                  tabledata "Batch Processing Parameter" = Rimd,
                  tabledata "Batch Processing Session Map" = Rimd,
                  tabledata "Check Ledger Entry" = Rimd,
                  tabledata "Company Information" = RM,
                  tabledata "Contact Business Relation" = R,
                  tabledata Currency = RIMD,
                  tabledata "Currency Exchange Rate" = RIMD,
                  tabledata "Cust. Ledger Entry" = Rimd,
                  tabledata Customer = Rimd,
                  tabledata "Date Compr. Register" = Rimd,
                  tabledata Dimension = RIMD,
                  tabledata "Employee Ledger Entry" = Rimd,
                  tabledata "Exch. Rate Adjmt. Reg." = Rimd,
                  tabledata "G/L Account (Analysis View)" = RIMD,
                  tabledata "G/L Account" = RIMD,
                  tabledata "G/L Account Category" = RIMD,
                  tabledata "G/L Budget Entry" = RIMD,
                  tabledata "G/L Budget Name" = RIMD,
                  tabledata "G/L Entry - VAT Entry Link" = R,
                  tabledata "G/L Entry" = Rimd,
                  tabledata "G/L Register" = Rimd,
                  tabledata "Gen. Journal Line" = RIMD,
                  tabledata "General Ledger Setup" = RM,
                  tabledata "Item Analysis View" = RIMD,
                  tabledata "Item Analysis View Budg. Entry" = Rimd,
                  tabledata "Item Analysis View Entry" = Rimd,
                  tabledata "Item Analysis View Filter" = RIMD,
                  tabledata "Item Budget Entry" = RIMD,
                  tabledata "Item Budget Name" = RIMD,
                  tabledata "Item Ledger Entry" = Rimd,
                  tabledata "Object Options" = RIMD,
                  tabledata "Purchase Header" = Rmd,
                  tabledata "Purchase Line" = Rmd,
                  tabledata "Sales Header" = Rmd,
                  tabledata "Sales Line" = Rmd,
                  tabledata "Tariff Number" = R,
                  tabledata "Tax Area" = RIMD,
                  tabledata "Tax Area Line" = RIMD,
                  tabledata "Tax Area Translation" = RIMD,
                  tabledata "Tax Detail" = RIMD,
                  tabledata "Tax Group" = RIMD,
                  tabledata "Tax Jurisdiction" = RIMD,
                  tabledata "Tax Jurisdiction Translation" = RIMD,
                  tabledata "Transaction Type" = R,
                  tabledata "Transport Method" = R,
                  tabledata "VAT Amount Line" = RIMD,
                  tabledata "VAT Entry" = Rimd,
                  tabledata "VAT Rate Change Log Entry" = Ri,
                  tabledata "VAT Rate Change Setup" = R,
                  tabledata "VAT Report Error Log" = RIMD,
                  tabledata "VAT Report Header" = RIMD,
                  tabledata "VAT Report Line" = RIMD,
                  tabledata "VAT Report Line Relation" = RIMD,
                  tabledata "VAT Report Setup" = RIMD,
                  tabledata "VAT Return Period" = RIMD,
                  tabledata "VAT Statement Line" = RIMD,
                  tabledata "VAT Statement Name" = RIMD,
                  tabledata "VAT Statement Template" = RIMD,
#if not CLEAN20
                  tabledata "XBRL Comment Line" = RIMD,
                  tabledata "XBRL G/L Map Line" = RIMD,
                  tabledata "XBRL Line Constant" = RIMD,
                  tabledata "XBRL Linkbase" = RIMD,
                  tabledata "XBRL Rollup Line" = RIMD,
                  tabledata "XBRL Schema" = RIMD,
                  tabledata "XBRL Taxonomy" = RIMD,
                  tabledata "XBRL Taxonomy Label" = RIMD,
                  tabledata "XBRL Taxonomy Line" = RIMD,
#endif
                  tabledata "Vendor Ledger Entry" = Rimd;
}
