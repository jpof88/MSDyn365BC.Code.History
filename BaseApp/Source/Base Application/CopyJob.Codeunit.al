codeunit 1006 "Copy Job"
{

    trigger OnRun()
    begin
    end;

    var
        CopyPrices: Boolean;
        CopyQuantity: Boolean;
        CopyDimensions: Boolean;
        JobPlanningLineSource: Option "Job Planning Lines","Job Ledger Entries";
        JobPlanningLineType: Option " ",Budget,Billable;
        JobLedgerEntryType: Option " ",Usage,Sale;
        JobTaskRangeFrom: Code[20];
        JobTaskRangeTo: Code[20];
        JobTaskDateRangeFrom: Date;
        JobTaskDateRangeTo: Date;

#if not CLEAN20
    [Obsolete('Pending removal, use CopyJob with TargetJobSellToCustomer as a argument instead.', '20.0')]
    procedure CopyJob(SourceJob: Record Job; TargetJobNo: Code[20]; TargetJobDescription: Text[100]; TargetJobBillToCustomer: Code[20])
    begin
        CopyJob(SourceJob, TargetJobNo, TargetJobDescription, '', TargetJobBillToCustomer);
    end;
#endif

    procedure CopyJob(
        SourceJob: Record Job;
        TargetJobNo: Code[20];
        TargetJobDescription: Text[100];
        TargetJobSellToCustomer: Code[20];
        TargetJobBillToCustomer: Code[20]
    )
    var
        TargetJob: Record Job;
    begin
        TargetJob.SetHideValidationDialog(true);
        TargetJob."No." := TargetJobNo;
        TargetJob.TransferFields(SourceJob, false);
        TargetJob.Insert(true);
        if TargetJobDescription <> '' then
            TargetJob.Validate(Description, TargetJobDescription);
        if TargetJobSellToCustomer <> '' then
            TargetJob.Validate("Sell-to Customer No.", TargetJobSellToCustomer);
        if TargetJobBillToCustomer <> '' then
            TargetJob.Validate("Bill-to Customer No.", TargetJobBillToCustomer);
        TargetJob.Validate(Status, TargetJob.Status::Planning);
        if CopyDimensions then
            CopyJobDimensions(SourceJob, TargetJob);
        CopyJobTasks(SourceJob, TargetJob);

        if CopyPrices then
            OnBeforeCopyJobPrices(SourceJob, TargetJob);

        OnAfterCopyJob(TargetJob, SourceJob);
        TargetJob.Modify();
    end;

    procedure CopyJobTasks(SourceJob: Record Job; TargetJob: Record Job)
    var
        SourceJobTask: Record "Job Task";
        TargetJobTask: Record "Job Task";
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforeCopyJobTasks(SourceJob, TargetJob, IsHandled);
        if IsHandled then
            exit;

        SourceJobTask.SetRange("Job No.", SourceJob."No.");
        case true of
            (JobTaskRangeFrom <> '') and (JobTaskRangeTo <> ''):
                SourceJobTask.SetRange("Job Task No.", JobTaskRangeFrom, JobTaskRangeTo);
            (JobTaskRangeFrom <> '') and (JobTaskRangeTo = ''):
                SourceJobTask.SetFilter("Job Task No.", '%1..', JobTaskRangeFrom);
            (JobTaskRangeFrom = '') and (JobTaskRangeTo <> ''):
                SourceJobTask.SetFilter("Job Task No.", '..%1', JobTaskRangeTo);
        end;
        OnCopyJobTasksOnAfterSourceJobTaskSetFilters(SourceJobTask, SourceJob);

        if SourceJobTask.FindSet() then
            repeat
                TargetJobTask.Init();
                TargetJobTask.Validate("Job No.", TargetJob."No.");
                TargetJobTask.Validate("Job Task No.", SourceJobTask."Job Task No.");
                TargetJobTask.TransferFields(SourceJobTask, false);
                if TargetJobTask."WIP Method" <> '' then begin
                    TargetJobTask.Validate("WIP-Total", TargetJobTask."WIP-Total"::Total);
                    TargetJobTask.Validate("WIP Method", TargetJob."WIP Method");
                end;
                TargetJobTask.Validate("Recognized Sales Amount", 0);
                TargetJobTask.Validate("Recognized Costs Amount", 0);
                TargetJobTask.Validate("Recognized Sales G/L Amount", 0);
                TargetJobTask.Validate("Recognized Costs G/L Amount", 0);
                TargetJobTask.Insert(true);
                case true of
                    JobPlanningLineSource = JobPlanningLineSource::"Job Planning Lines":
                        CopyJobPlanningLines(SourceJobTask, TargetJobTask);
                    JobPlanningLineSource = JobPlanningLineSource::"Job Ledger Entries":
                        CopyJLEsToJobPlanningLines(SourceJobTask, TargetJobTask);
                end;
                if CopyDimensions then
                    CopyJobTaskDimensions(SourceJobTask, TargetJobTask);
                OnAfterCopyJobTask(TargetJobTask, SourceJobTask, CopyPrices, CopyQuantity);
            until SourceJobTask.Next() = 0;
    end;

    procedure CopyJobPlanningLines(SourceJobTask: Record "Job Task"; TargetJobTask: Record "Job Task")
    var
        SourceJobPlanningLine: Record "Job Planning Line";
        TargetJobPlanningLine: Record "Job Planning Line";
        SourceJob: Record Job;
        NextPlanningLineNo: Integer;
    begin
        SourceJob.Get(SourceJobTask."Job No.");

        case true of
            (JobTaskDateRangeFrom <> 0D) and (JobTaskDateRangeTo <> 0D):
                SourceJobTask.SetRange("Planning Date Filter", JobTaskDateRangeFrom, JobTaskDateRangeTo);
            (JobTaskDateRangeFrom <> 0D) and (JobTaskDateRangeTo = 0D):
                SourceJobTask.SetFilter("Planning Date Filter", '%1..', JobTaskDateRangeFrom);
            (JobTaskDateRangeFrom = 0D) and (JobTaskDateRangeTo <> 0D):
                SourceJobTask.SetFilter("Planning Date Filter", '..%1', JobTaskDateRangeTo);
        end;

        SourceJobPlanningLine.SetRange("Job No.", SourceJobTask."Job No.");
        SourceJobPlanningLine.SetRange("Job Task No.", SourceJobTask."Job Task No.");
        case JobPlanningLineType of
            JobPlanningLineType::Budget:
                SourceJobPlanningLine.SetRange("Line Type", SourceJobPlanningLine."Line Type"::Budget);
            JobPlanningLineType::Billable:
                SourceJobPlanningLine.SetRange("Line Type", SourceJobPlanningLine."Line Type"::Billable);
        end;
        SourceJobPlanningLine.SetFilter("Planning Date", SourceJobTask.GetFilter("Planning Date Filter"));
        if not SourceJobPlanningLine.FindLast() then
            exit;
        NextPlanningLineNo := 0;
        SourceJobPlanningLine.SetRange("Line No.", 0, SourceJobPlanningLine."Line No.");
        OnCopyJobPlanningLinesOnAfterSourceJobPlanningLineSetFilters(SourceJobPlanningLine);
        if SourceJobPlanningLine.FindSet() then
            repeat
                with TargetJobPlanningLine do begin
                    Init();
                    Validate("Job No.", TargetJobTask."Job No.");
                    Validate("Job Task No.", TargetJobTask."Job Task No.");
                    if NextPlanningLineNo = 0 then
                        NextPlanningLineNo := FindLastJobPlanningLine(TargetJobPlanningLine);
                    NextPlanningLineNo += 10000;
                    Validate("Line No.", NextPlanningLineNo);
                    TransferFields(SourceJobPlanningLine, false);
                    "Remaining Qty." := 0;
                    "Remaining Qty. (Base)" := 0;
                    "Remaining Total Cost" := 0;
                    "Remaining Total Cost (LCY)" := 0;
                    "Remaining Line Amount" := 0;
                    "Remaining Line Amount (LCY)" := 0;
                    "Qty. Posted" := 0;
                    "Qty. to Transfer to Journal" := 0;
                    "Posted Total Cost" := 0;
                    "Posted Total Cost (LCY)" := 0;
                    "Posted Line Amount" := 0;
                    "Posted Line Amount (LCY)" := 0;
                    "Qty. to Transfer to Invoice" := 0;
                    "Qty. to Invoice" := 0;
                    "Ledger Entry No." := 0;
                    "Ledger Entry Type" := "Ledger Entry Type"::" ";
                    Insert(true);
                    if Type <> Type::Text then begin
                        ExchangeJobPlanningLineAmounts(TargetJobPlanningLine, SourceJob."Currency Code");
                        if not CopyQuantity then
                            Validate(Quantity, 0)
                        else
                            Validate(Quantity);
                        OnCopyJobPlanningLinesOnBeforeModifyTargetJobPlanningLine(TargetJobPlanningLine);
                        Modify();
                    end;
                end;
                OnCopyJobPlanningLinesOnAfterCopyTargetJobPlanningLine(TargetJobPlanningLine, SourceJobPlanningLine);
            until SourceJobPlanningLine.Next() = 0;
    end;

    local procedure CopyJLEsToJobPlanningLines(SourceJobTask: Record "Job Task"; TargetJobTask: Record "Job Task")
    var
        TargetJobPlanningLine: Record "Job Planning Line";
        JobLedgEntry: Record "Job Ledger Entry";
        SourceJob: Record Job;
        JobTransferLine: Codeunit "Job Transfer Line";
        NextPlanningLineNo: Integer;
    begin
        SourceJob.Get(SourceJobTask."Job No.");
        TargetJobPlanningLine.SetRange("Job No.", TargetJobTask."Job No.");
        TargetJobPlanningLine.SetRange("Job Task No.", TargetJobTask."Job Task No.");
        if TargetJobPlanningLine.FindLast() then
            NextPlanningLineNo := TargetJobPlanningLine."Line No." + 10000
        else
            NextPlanningLineNo := 10000;

        JobLedgEntry.SetRange("Job No.", SourceJobTask."Job No.");
        JobLedgEntry.SetRange("Job Task No.", SourceJobTask."Job Task No.");
        case true of
            JobLedgerEntryType = JobLedgerEntryType::Usage:
                JobLedgEntry.SetRange("Entry Type", JobLedgEntry."Entry Type"::Usage);
            JobLedgerEntryType = JobLedgerEntryType::Sale:
                JobLedgEntry.SetRange("Entry Type", JobLedgEntry."Entry Type"::Sale);
        end;
        JobLedgEntry.SetFilter("Posting Date", SourceJobTask.GetFilter("Planning Date Filter"));
        if JobLedgEntry.FindSet() then
            repeat
                TargetJobPlanningLine.Init();
                JobTransferLine.FromJobLedgEntryToPlanningLine(JobLedgEntry, TargetJobPlanningLine);
                TargetJobPlanningLine."Job No." := TargetJobTask."Job No.";
                TargetJobPlanningLine.Validate("Line No.", NextPlanningLineNo);
                TargetJobPlanningLine.Insert(true);
                if JobLedgEntry."Entry Type" = JobLedgEntry."Entry Type"::Usage then
                    TargetJobPlanningLine.Validate("Line Type", TargetJobPlanningLine."Line Type"::Budget)
                else begin
                    TargetJobPlanningLine.Validate("Line Type", TargetJobPlanningLine."Line Type"::Billable);
                    TargetJobPlanningLine.Validate(Quantity, -JobLedgEntry.Quantity);
                    TargetJobPlanningLine.Validate("Unit Cost (LCY)", JobLedgEntry."Unit Cost (LCY)");
                    TargetJobPlanningLine.Validate("Unit Price (LCY)", JobLedgEntry."Unit Price (LCY)");
                    TargetJobPlanningLine.Validate("Line Discount %", JobLedgEntry."Line Discount %");
                end;
                ExchangeJobPlanningLineAmounts(TargetJobPlanningLine, SourceJob."Currency Code");
                if not CopyQuantity then
                    TargetJobPlanningLine.Validate(Quantity, 0);
                NextPlanningLineNo += 10000;
                TargetJobPlanningLine.Modify();
            until JobLedgEntry.Next() = 0;
    end;

    local procedure CopyJobDimensions(SourceJob: Record Job; var TargetJob: Record Job)
    var
        DefaultDimension: Record "Default Dimension";
        NewDefaultDimension: Record "Default Dimension";
        DimMgt: Codeunit DimensionManagement;
    begin
        DefaultDimension.SetRange("Table ID", DATABASE::Job);
        DefaultDimension.SetRange("No.", TargetJob."No.");
        if DefaultDimension.FindSet() then
            repeat
                DimMgt.DefaultDimOnDelete(DefaultDimension);
                DefaultDimension.Delete();
            until DefaultDimension.Next() = 0;

        DefaultDimension.SetRange("No.", SourceJob."No.");
        if DefaultDimension.FindSet() then
            repeat
                with NewDefaultDimension do begin
                    Init();
                    "Table ID" := DATABASE::Job;
                    "No." := TargetJob."No.";
                    "Dimension Code" := DefaultDimension."Dimension Code";
                    TransferFields(DefaultDimension, false);
                    Insert();
                    DimMgt.DefaultDimOnInsert(DefaultDimension);
                end;
            until DefaultDimension.Next() = 0;

        DimMgt.UpdateDefaultDim(
          DATABASE::Job, TargetJob."No.", TargetJob."Global Dimension 1 Code", TargetJob."Global Dimension 2 Code");

        OnAfterCopyJobDimensions(SourceJob, TargetJob);
    end;

    local procedure CopyJobTaskDimensions(SourceJobTask: Record "Job Task"; TargetJobTask: Record "Job Task")
    var
        DimensionManagement: Codeunit DimensionManagement;
    begin
        DimensionManagement.CopyJobTaskDimToJobTaskDim(SourceJobTask."Job No.",
          SourceJobTask."Job Task No.",
          TargetJobTask."Job No.",
          TargetJobTask."Job Task No.");

        OnAfterCopyJobTaskDimensions(SourceJobTask, TargetJobTask);
    end;

    local procedure ExchangeJobPlanningLineAmounts(var JobPlanningLine: Record "Job Planning Line"; CurrencyCode: Code[10])
    var
        Job: Record Job;
        CurrExchRate: Record "Currency Exchange Rate";
        Currency: Record Currency;
    begin
        Job.Get(JobPlanningLine."Job No.");
        if CurrencyCode <> Job."Currency Code" then
            if (CurrencyCode = '') and (Job."Currency Code" <> '') then begin
                JobPlanningLine."Currency Code" := Job."Currency Code";
                JobPlanningLine.UpdateCurrencyFactor();
                Currency.Get(JobPlanningLine."Currency Code");
                Currency.TestField("Unit-Amount Rounding Precision");
                JobPlanningLine."Unit Cost" := Round(
                    CurrExchRate.ExchangeAmtLCYToFCY(
                      JobPlanningLine."Currency Date", JobPlanningLine."Currency Code",
                      JobPlanningLine."Unit Cost (LCY)", JobPlanningLine."Currency Factor"),
                    Currency."Unit-Amount Rounding Precision");
                JobPlanningLine."Unit Price" := Round(
                    CurrExchRate.ExchangeAmtLCYToFCY(
                      JobPlanningLine."Currency Date", JobPlanningLine."Currency Code",
                      JobPlanningLine."Unit Price (LCY)", JobPlanningLine."Currency Factor"),
                    Currency."Unit-Amount Rounding Precision");
                JobPlanningLine.Validate("Currency Date");
            end else
                if (CurrencyCode <> '') and (Job."Currency Code" = '') then begin
                    JobPlanningLine."Currency Code" := '';
                    JobPlanningLine."Currency Date" := 0D;
                    JobPlanningLine.UpdateCurrencyFactor();
                    JobPlanningLine."Unit Cost" := JobPlanningLine."Unit Cost (LCY)";
                    JobPlanningLine."Unit Price" := JobPlanningLine."Unit Price (LCY)";
                    JobPlanningLine.Validate("Currency Date");
                end else
                    if (CurrencyCode <> '') and (Job."Currency Code" <> '') then begin
                        JobPlanningLine."Currency Code" := Job."Currency Code";
                        JobPlanningLine.UpdateCurrencyFactor();
                        Currency.Get(JobPlanningLine."Currency Code");
                        Currency.TestField("Unit-Amount Rounding Precision");
                        JobPlanningLine."Unit Cost" := Round(
                            CurrExchRate.ExchangeAmtFCYToFCY(
                              JobPlanningLine."Currency Date", CurrencyCode,
                              JobPlanningLine."Currency Code", JobPlanningLine."Unit Cost"),
                            Currency."Unit-Amount Rounding Precision");
                        JobPlanningLine."Unit Price" := Round(
                            CurrExchRate.ExchangeAmtFCYToFCY(
                              JobPlanningLine."Currency Date", CurrencyCode,
                              JobPlanningLine."Currency Code", JobPlanningLine."Unit Price"),
                            Currency."Unit-Amount Rounding Precision");
                        JobPlanningLine.Validate("Currency Date");
                    end;
    end;

    procedure SetCopyQuantity(CopyQuantity2: Boolean)
    begin
        CopyQuantity := CopyQuantity2;
    end;

    procedure SetCopyJobPlanningLineType(JobPlanningLineType2: Option " ",Budget,Billable)
    begin
        JobPlanningLineType := JobPlanningLineType2;
    end;

    procedure SetCopyOptions(CopyPrices2: Boolean; CopyQuantity2: Boolean; CopyDimensions2: Boolean; JobPlanningLineSource2: Option "Job Planning Lines","Job Ledger Entries"; JobPlanningLineType2: Option " ",Budget,Billable; JobLedgerEntryType2: Option " ",Usage,Sale)
    begin
        CopyPrices := CopyPrices2;
        CopyQuantity := CopyQuantity2;
        CopyDimensions := CopyDimensions2;
        JobPlanningLineSource := JobPlanningLineSource2;
        JobPlanningLineType := JobPlanningLineType2;
        JobLedgerEntryType := JobLedgerEntryType2;
    end;

    procedure SetJobTaskRange(JobTaskRangeFrom2: Code[20]; JobTaskRangeTo2: Code[20])
    begin
        JobTaskRangeFrom := JobTaskRangeFrom2;
        JobTaskRangeTo := JobTaskRangeTo2;
    end;

    procedure SetJobTaskDateRange(JobTaskDateRangeFrom2: Date; JobTaskDateRangeTo2: Date)
    begin
        JobTaskDateRangeFrom := JobTaskDateRangeFrom2;
        JobTaskDateRangeTo := JobTaskDateRangeTo2;
    end;

    local procedure FindLastJobPlanningLine(JobPlanningLine: Record "Job Planning Line"): Integer
    begin
        JobPlanningLine.SetRange("Job No.", JobPlanningLine."Job No.");
        JobPlanningLine.SetRange("Job Task No.", JobPlanningLine."Job Task No.");
        if JobPlanningLine.FindLast() then
            exit(JobPlanningLine."Line No.");
        exit(0);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCopyJob(var TargetJob: Record Job; SourceJob: Record Job)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCopyJobTask(var TargetJobTask: Record "Job Task"; SourceJobTask: Record "Job Task"; CopyPrices: Boolean; CopyQuantity: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCopyJobDimensions(SourceJob: Record Job; var TargetJob: Record Job)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCopyJobTaskDimensions(SourceJobTask: Record "Job Task"; TargetJobTask: Record "Job Task")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCopyJobPrices(var SourceJob: Record Job; var TargetJob: Record Job)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCopyJobTasks(var SourceJob: Record Job; var TargetJob: Record Job; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnCopyJobPlanningLinesOnBeforeModifyTargetJobPlanningLine(var TargetJobPlanningLine: Record "Job Planning Line")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnCopyJobPlanningLinesOnAfterCopyTargetJobPlanningLine(var TargetJobPlanningLine: Record "Job Planning Line"; SourceJobPlanningLine: Record "Job Planning Line")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnCopyJobPlanningLinesOnAfterSourceJobPlanningLineSetFilters(var SourceJobPlanningLine: Record "Job Planning Line")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnCopyJobTasksOnAfterSourceJobTaskSetFilters(var SourceJobTask: Record "Job Task"; SourceJob: Record Job)
    begin
    end;
}

