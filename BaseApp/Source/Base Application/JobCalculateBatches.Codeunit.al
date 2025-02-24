codeunit 1005 "Job Calculate Batches"
{

    trigger OnRun()
    begin
    end;

    var
        JobDiffBuffer: array[2] of Record "Job Difference Buffer" temporary;
        PeriodLength2: DateFormula;

        Text000: Label '%1 lines were successfully transferred to the journal.';
        Text001: Label 'There is no remaining usage on the job(s).';
        Text002: Label 'The lines were successfully changed.';
        Text003: Label 'The From Date is later than the To Date.';
        Text004: Label 'You must specify %1.';
        Text005: Label 'There is nothing to invoice.';
        Text006: Label '1 invoice is created.';
        Text007: Label '%1 invoices are created.';
        Text008: Label 'The selected entries were successfully transferred to planning lines.';
        Text009: Label 'Total Cost,Total Price,Line Discount Amount,Line Amount';

    procedure SplitLines(var JT2: Record "Job Task"): Integer
    var
        JT: Record "Job Task";
        JobPlanningLine: Record "Job Planning Line";
        NoOfLinesSplitted: Integer;
    begin
        JobPlanningLine.LockTable();
        JT.LockTable();
        JT := JT2;
        JT.Find();
        JobPlanningLine.SetRange("Job No.", JT."Job No.");
        JobPlanningLine.SetRange("Job Task No.", JT."Job Task No.");
        JobPlanningLine.SetFilter("Planning Date", JT2.GetFilter("Planning Date Filter"));
        if JobPlanningLine.Find('-') then
            repeat
                if JobPlanningLine."Line Type" = JobPlanningLine."Line Type"::"Both Budget and Billable" then
                    if SplitOneLine(JobPlanningLine) then
                        NoOfLinesSplitted += 1;
            until JobPlanningLine.Next() = 0;
        exit(NoOfLinesSplitted);
    end;

    local procedure SplitOneLine(JobPlanningLine: Record "Job Planning Line"): Boolean
    var
        JobPlanningLine2: Record "Job Planning Line";
        NextLineNo: Integer;
    begin
        JobPlanningLine.TestField("Job No.");
        JobPlanningLine.TestField("Job Task No.");
        JobPlanningLine2 := JobPlanningLine;
        JobPlanningLine2.SetRange("Job No.", JobPlanningLine2."Job No.");
        JobPlanningLine2.SetRange("Job Task No.", JobPlanningLine2."Job Task No.");
        NextLineNo := JobPlanningLine."Line No." + 10000;
        if JobPlanningLine2.Next() <> 0 then
            NextLineNo := (JobPlanningLine."Line No." + JobPlanningLine2."Line No.") div 2;
        JobPlanningLine.Validate("Line Type", JobPlanningLine."Line Type"::Billable);
        JobPlanningLine.Modify();
        JobPlanningLine.Validate("Line Type", JobPlanningLine."Line Type"::Budget);
        JobPlanningLine.ClearTracking();
        JobPlanningLine."Line No." := NextLineNo;
        JobPlanningLine.InitJobPlanningLine();
        OnBeforeJobPlanningLineInsert(JobPlanningLine);
        JobPlanningLine.Insert(true);
        exit(true);
    end;

    procedure TransferToPlanningLine(var JobLedgEntry: Record "Job Ledger Entry"; LineType: Integer)
    var
        JobPostLine: Codeunit "Job Post-Line";
    begin
        JobLedgEntry.LockTable();
        if JobLedgEntry.Find('-') then
            repeat
                OnBeforeTransferToPlanningLine(JobLedgEntry);
                JobLedgEntry.TestField("Job No.");
                JobLedgEntry.TestField("Job Task No.");
                JobLedgEntry.TestField("Entry Type", JobLedgEntry."Entry Type"::Usage);
                JobLedgEntry."Line Type" := "Job Line Type".FromInteger(LineType);
                Clear(JobPostLine);
                JobPostLine.InsertPlLineFromLedgEntry(JobLedgEntry);
            until JobLedgEntry.Next() = 0;
        Commit();
        Message(Text008);
    end;

    procedure ChangePlanningDates(JT: Record "Job Task"; ScheduleLine: Boolean; ContractLine: Boolean; PeriodLength: DateFormula; FixedDate: Date; StartingDate: Date; EndingDate: Date)
    var
        Job: Record Job;
        JobPlanningLine: Record "Job Planning Line";
    begin
        JobPlanningLine.LockTable();
        JT.LockTable();

        if EndingDate = 0D then
            EndingDate := DMY2Date(31, 12, 9999);
        if EndingDate < StartingDate then
            Error(Text003);
        JT.TestField("Job No.");
        JT.TestField("Job Task No.");
        Job.Get(JT."Job No.");
        if Job.Blocked = Job.Blocked::All then
            Job.TestBlocked();
        JT.Find();
        JobPlanningLine.SetCurrentKey("Job No.", "Job Task No.");
        JobPlanningLine.SetRange("Job No.", Job."No.");
        JobPlanningLine.SetRange("Job Task No.", JT."Job Task No.");

        if ScheduleLine and not ContractLine then
            JobPlanningLine.SetRange("Schedule Line", true);
        if not ScheduleLine and ContractLine then
            JobPlanningLine.SetRange("Contract Line", true);
        JobPlanningLine.SetRange("Planning Date", StartingDate, EndingDate);
        if JobPlanningLine.Find('-') then
            repeat
                JobPlanningLine.CalcFields("Qty. Transferred to Invoice");
                if JobPlanningLine."Qty. Transferred to Invoice" = 0 then begin
                    JobPlanningLine.TestField("Planning Date");
                    if FixedDate > 0D then
                        JobPlanningLine."Planning Date" := FixedDate
                    else
                        if PeriodLength <> PeriodLength2 then
                            JobPlanningLine."Planning Date" :=
                              CalcDate(PeriodLength, JobPlanningLine."Planning Date");
                    JobPlanningLine."Last Date Modified" := Today;
                    JobPlanningLine."User ID" := UserId;
                    JobPlanningLine.Modify();
                end;
            until JobPlanningLine.Next() = 0;
    end;

    procedure ChangeCurrencyDates(JT: Record "Job Task"; scheduleLine: Boolean; ContractLine: Boolean; PeriodLength: DateFormula; FixedDate: Date; StartingDate: Date; EndingDate: Date)
    var
        Job: Record Job;
        JobPlanningLine: Record "Job Planning Line";
    begin
        if EndingDate = 0D then
            EndingDate := DMY2Date(31, 12, 9999);
        if EndingDate < StartingDate then
            Error(Text003);
        JT.TestField("Job No.");
        JT.TestField("Job Task No.");
        Job.Get(JT."Job No.");
        if Job.Blocked = Job.Blocked::All then
            Job.TestBlocked();
        JT.Find();
        JobPlanningLine.SetCurrentKey("Job No.", "Job Task No.");
        JobPlanningLine.SetRange("Job No.", Job."No.");
        JobPlanningLine.SetRange("Job Task No.", JT."Job Task No.");

        if scheduleLine and not ContractLine then
            JobPlanningLine.SetRange("Schedule Line", true);
        if not scheduleLine and ContractLine then
            JobPlanningLine.SetRange("Contract Line", true);
        JobPlanningLine.SetRange("Currency Date", StartingDate, EndingDate);
        if JobPlanningLine.Find('-') then
            repeat
                JobPlanningLine.CalcFields("Qty. Transferred to Invoice");
                if JobPlanningLine."Qty. Transferred to Invoice" = 0 then begin
                    JobPlanningLine.TestField("Planning Date");
                    JobPlanningLine.TestField("Currency Date");
                    if FixedDate > 0D then begin
                        JobPlanningLine."Currency Date" := FixedDate;
                        JobPlanningLine."Document Date" := FixedDate;
                    end else
                        if PeriodLength <> PeriodLength2 then begin
                            JobPlanningLine."Currency Date" :=
                              CalcDate(PeriodLength, JobPlanningLine."Currency Date");
                            JobPlanningLine."Document Date" :=
                              CalcDate(PeriodLength, JobPlanningLine."Document Date");
                        end;
                    JobPlanningLine.Validate("Currency Date");
                    JobPlanningLine."Last Date Modified" := Today;
                    JobPlanningLine."User ID" := UserId;
                    JobPlanningLine.Modify(true);
                end;
            until JobPlanningLine.Next() = 0;
    end;

    procedure ChangeDatesEnd()
    begin
        Commit();
        Message(Text002);
    end;

    procedure CreateJT(JobPlanningLine: Record "Job Planning Line")
    var
        Job: Record Job;
        JT: Record "Job Task";
    begin
        with JobPlanningLine do begin
            if Type = Type::Text then
                exit;
            if not "Schedule Line" then
                exit;
            Job.Get("Job No.");
            JT.Get("Job No.", "Job Task No.");
            JobDiffBuffer[1]."Job No." := "Job No.";
            JobDiffBuffer[1]."Job Task No." := "Job Task No.";
            JobDiffBuffer[1].Type := Type;
            JobDiffBuffer[1]."No." := "No.";
            JobDiffBuffer[1]."Location Code" := "Location Code";
            JobDiffBuffer[1]."Variant Code" := "Variant Code";
            JobDiffBuffer[1]."Unit of Measure code" := "Unit of Measure Code";
            JobDiffBuffer[1]."Work Type Code" := "Work Type Code";
            JobDiffBuffer[1].Quantity := Quantity;
            JobDiffBuffer[1]."Line Amount" := "Line Amount";
            OnCreateJTOnBeforeAssigneJobDiffBuffer2(JobDiffBuffer, JobPlanningLine);
            JobDiffBuffer[2] := JobDiffBuffer[1];
            if JobDiffBuffer[2].Find() then begin
                JobDiffBuffer[2].Quantity := JobDiffBuffer[2].Quantity + JobDiffBuffer[1].Quantity;
                JobDiffBuffer[2].Modify();
            end else
                JobDiffBuffer[1].Insert();
        end;
    end;

    procedure InitDiffBuffer()
    begin
        Clear(JobDiffBuffer);
        JobDiffBuffer[1].DeleteAll();
    end;

    procedure PostDiffBuffer(DocNo: Code[20]; PostingDate: Date; TemplateName: Code[10]; BatchName: Code[10])
    var
        JobLedgEntry: Record "Job Ledger Entry";
        JobJnlLine: Record "Job Journal Line";
        JobJnlTemplate: Record "Job Journal Template";
        JobJnlBatch: Record "Job Journal Batch";
        NextLineNo: Integer;
        LineNo: Integer;
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforePostDiffBuffer(JobDiffBuffer, IsHandled);
        if IsHandled then
            exit;

        if JobDiffBuffer[1].Find('-') then
            repeat
                JobLedgEntry.SetCurrentKey("Job No.", "Job Task No.");
                JobLedgEntry.SetRange("Job No.", JobDiffBuffer[1]."Job No.");
                JobLedgEntry.SetRange("Job Task No.", JobDiffBuffer[1]."Job Task No.");
                JobLedgEntry.SetRange("Entry Type", JobLedgEntry."Entry Type"::Usage);
                JobLedgEntry.SetRange(Type, JobDiffBuffer[1].Type);
                JobLedgEntry.SetRange("No.", JobDiffBuffer[1]."No.");
                JobLedgEntry.SetRange("Location Code", JobDiffBuffer[1]."Location Code");
                JobLedgEntry.SetRange("Variant Code", JobDiffBuffer[1]."Variant Code");
                JobLedgEntry.SetRange("Unit of Measure Code", JobDiffBuffer[1]."Unit of Measure code");
                JobLedgEntry.SetRange("Work Type Code", JobDiffBuffer[1]."Work Type Code");
                if JobLedgEntry.Find('-') then
                    repeat
                        JobDiffBuffer[1].Quantity := JobDiffBuffer[1].Quantity - JobLedgEntry.Quantity;
                    until JobLedgEntry.Next() = 0;
                OnPostDiffBufferOnBeforeModify(JobLedgEntry, JobDiffBuffer[1]);
                JobDiffBuffer[1].Modify();
            until JobDiffBuffer[1].Next() = 0;
        JobJnlLine.LockTable();
        JobJnlLine.Validate("Journal Template Name", TemplateName);
        JobJnlLine.Validate("Journal Batch Name", BatchName);
        JobJnlLine.SetRange("Journal Template Name", JobJnlLine."Journal Template Name");
        JobJnlLine.SetRange("Journal Batch Name", JobJnlLine."Journal Batch Name");
        if JobJnlLine.FindLast() then
            NextLineNo := JobJnlLine."Line No." + 10000
        else
            NextLineNo := 10000;

        if JobDiffBuffer[1].Find('-') then
            repeat
                if JobDiffBuffer[1].Quantity <> 0 then begin
                    Clear(JobJnlLine);
                    JobJnlLine."Journal Template Name" := TemplateName;
                    JobJnlLine."Journal Batch Name" := BatchName;
                    JobJnlTemplate.Get(TemplateName);
                    JobJnlBatch.Get(TemplateName, BatchName);
                    JobJnlLine."Source Code" := JobJnlTemplate."Source Code";
                    JobJnlLine."Reason Code" := JobJnlBatch."Reason Code";
                    JobJnlLine.DontCheckStdCost();
                    JobJnlLine.Validate("Job No.", JobDiffBuffer[1]."Job No.");
                    JobJnlLine.Validate("Job Task No.", JobDiffBuffer[1]."Job Task No.");
                    JobJnlLine.Validate("Posting Date", PostingDate);
                    JobJnlLine.Validate(Type, JobDiffBuffer[1].Type);
                    JobJnlLine.Validate("No.", JobDiffBuffer[1]."No.");
                    JobJnlLine.Validate("Variant Code", JobDiffBuffer[1]."Variant Code");
                    JobJnlLine.Validate("Unit of Measure Code", JobDiffBuffer[1]."Unit of Measure code");
                    JobJnlLine.Validate("Location Code", JobDiffBuffer[1]."Location Code");
                    if JobDiffBuffer[1].Type = JobDiffBuffer[1].Type::Resource then
                        JobJnlLine.Validate("Work Type Code", JobDiffBuffer[1]."Work Type Code");
                    JobJnlLine."Document No." := DocNo;
                    JobJnlLine.Validate(Quantity, JobDiffBuffer[1].Quantity);
                    JobJnlLine.Validate("Unit Price", JobDiffBuffer[1]."Line Amount" / JobDiffBuffer[1].Quantity);
                    JobJnlLine."Line No." := NextLineNo;
                    NextLineNo := NextLineNo + 10000;
                    JobJnlLine.Insert(true);
                    OnPostDiffBufferOnAfterInsertJobJnlLine(JobJnlLine, JobDiffBuffer[1]);
                    LineNo := LineNo + 1;
                end;
            until JobDiffBuffer[1].Next() = 0;
        Commit();
        if LineNo = 0 then
            Message(Text001)
        else
            Message(Text000, LineNo);
    end;

    procedure BatchError(PostingDate: Date; DocNo: Code[20])
    var
        GLEntry: Record "G/L Entry";
    begin
        if PostingDate = 0D then
            Error(Text004, GLEntry.FieldCaption("Posting Date"));
        if DocNo = '' then
            Error(Text004, GLEntry.FieldCaption("Document No."));
    end;

    procedure EndCreateInvoice(NoOfInvoices: Integer)
    begin
        Commit();
        if NoOfInvoices <= 0 then
            Message(Text005);
        if NoOfInvoices = 1 then
            Message(Text006);
        if NoOfInvoices > 1 then
            Message(Text007, NoOfInvoices);
    end;

    procedure CalculateActualToBudget(var Job: Record Job; JT: Record "Job Task"; var JobDiffBuffer2: Record "Job Difference Buffer"; var JobDiffBuffer3: Record "Job Difference Buffer"; CurrencyType: Option LCY,FCY)
    var
        JobPlanningLine: Record "Job Planning Line";
        JobLedgEntry: Record "Job Ledger Entry";
    begin
        ClearAll();
        Clear(JobDiffBuffer);
        Clear(JobDiffBuffer2);
        Clear(JobDiffBuffer3);

        JobDiffBuffer[1].DeleteAll();
        JobDiffBuffer2.DeleteAll();
        JobDiffBuffer3.DeleteAll();

        JT.Find();
        JobPlanningLine.SetRange("Job No.", JT."Job No.");
        JobPlanningLine.SetRange("Job Task No.", JT."Job Task No.");
        JobPlanningLine.SetFilter("Planning Date", Job.GetFilter("Planning Date Filter"));

        JobLedgEntry.SetRange("Job No.", JT."Job No.");
        JobLedgEntry.SetRange("Job Task No.", JT."Job Task No.");
        JobLedgEntry.SetFilter("Posting Date", Job.GetFilter("Posting Date Filter"));

        if JobPlanningLine.Find('-') then
            repeat
                InsertDiffBuffer(JobLedgEntry, JobPlanningLine, 0, CurrencyType);
            until JobPlanningLine.Next() = 0;

        if JobLedgEntry.Find('-') then
            repeat
                InsertDiffBuffer(JobLedgEntry, JobPlanningLine, 1, CurrencyType);
            until JobLedgEntry.Next() = 0;

        if JobDiffBuffer[1].Find('-') then
            repeat
                if JobDiffBuffer[1]."Entry type" = JobDiffBuffer[1]."Entry type"::Budget then begin
                    JobDiffBuffer2 := JobDiffBuffer[1];
                    JobDiffBuffer2.Insert();
                end else begin
                    JobDiffBuffer3 := JobDiffBuffer[1];
                    JobDiffBuffer3."Entry type" := JobDiffBuffer3."Entry type"::Budget;
                    JobDiffBuffer3.Insert();
                end;
            until JobDiffBuffer[1].Next() = 0;
    end;

    local procedure InsertDiffBuffer(var JobLedgEntry: Record "Job Ledger Entry"; var JobPlanningLine: Record "Job Planning Line"; LineType: Option Schedule,Usage; CurrencyType: Option LCY,FCY)
    begin
        if LineType = LineType::Schedule then
            with JobPlanningLine do begin
                if Type = Type::Text then
                    exit;
                if not "Schedule Line" then
                    exit;
                JobDiffBuffer[1].Type := Type;
                JobDiffBuffer[1]."No." := "No.";
                JobDiffBuffer[1]."Entry type" := JobDiffBuffer[1]."Entry type"::Budget;
                JobDiffBuffer[1]."Unit of Measure code" := "Unit of Measure Code";
                JobDiffBuffer[1]."Work Type Code" := "Work Type Code";
                JobDiffBuffer[1].Quantity := Quantity;
                if CurrencyType = CurrencyType::LCY then begin
                    JobDiffBuffer[1]."Total Cost" := "Total Cost (LCY)";
                    JobDiffBuffer[1]."Line Amount" := "Line Amount (LCY)";
                end else begin
                    JobDiffBuffer[1]."Total Cost" := "Total Cost";
                    JobDiffBuffer[1]."Line Amount" := "Line Amount";
                end;
                JobDiffBuffer[2] := JobDiffBuffer[1];
                if JobDiffBuffer[2].Find() then begin
                    JobDiffBuffer[2].Quantity :=
                      JobDiffBuffer[2].Quantity + JobDiffBuffer[1].Quantity;
                    JobDiffBuffer[2]."Total Cost" :=
                      JobDiffBuffer[2]."Total Cost" + JobDiffBuffer[1]."Total Cost";
                    JobDiffBuffer[2]."Line Amount" :=
                      JobDiffBuffer[2]."Line Amount" + JobDiffBuffer[1]."Line Amount";
                    JobDiffBuffer[2].Modify();
                end else
                    JobDiffBuffer[1].Insert();
            end;

        if LineType = LineType::Usage then
            with JobLedgEntry do begin
                if "Entry Type" <> "Entry Type"::Usage then
                    exit;
                JobDiffBuffer[1].Type := Type;
                JobDiffBuffer[1]."No." := "No.";
                JobDiffBuffer[1]."Entry type" := JobDiffBuffer[1]."Entry type"::Usage;
                JobDiffBuffer[1]."Unit of Measure code" := "Unit of Measure Code";
                JobDiffBuffer[1]."Work Type Code" := "Work Type Code";
                JobDiffBuffer[1].Quantity := Quantity;
                if CurrencyType = CurrencyType::LCY then begin
                    JobDiffBuffer[1]."Total Cost" := "Total Cost (LCY)";
                    JobDiffBuffer[1]."Line Amount" := "Line Amount (LCY)";
                end else begin
                    JobDiffBuffer[1]."Total Cost" := "Total Cost";
                    JobDiffBuffer[1]."Line Amount" := "Line Amount";
                end;
                JobDiffBuffer[2] := JobDiffBuffer[1];
                if JobDiffBuffer[2].Find() then begin
                    JobDiffBuffer[2].Quantity :=
                      JobDiffBuffer[2].Quantity + JobDiffBuffer[1].Quantity;
                    JobDiffBuffer[2]."Total Cost" :=
                      JobDiffBuffer[2]."Total Cost" + JobDiffBuffer[1]."Total Cost";
                    JobDiffBuffer[2]."Line Amount" :=
                      JobDiffBuffer[2]."Line Amount" + JobDiffBuffer[1]."Line Amount";
                    JobDiffBuffer[2].Modify();
                end else
                    JobDiffBuffer[1].Insert();
            end;
    end;

    procedure GetCurrencyCode(var Job: Record Job; Type: Option "0","1","2","3"; CurrencyType: Option "Local Currency","Foreign Currency"): Text[50]
    var
        GLSetup: Record "General Ledger Setup";
        CurrencyCode: Code[20];
    begin
        GLSetup.Get();
        if CurrencyType = CurrencyType::"Local Currency" then
            CurrencyCode := GLSetup."LCY Code"
        else
            if Job."Currency Code" <> '' then
                CurrencyCode := Job."Currency Code"
            else
                CurrencyCode := GLSetup."LCY Code";
        exit(SelectStr(Type + 1, Text009) + ' (' + CurrencyCode + ')');
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeJobPlanningLineInsert(var JobPlanningLine: Record "Job Planning Line")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforePostDiffBuffer(var JobDiffBuffer: array[2] of Record "Job Difference Buffer" temporary; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeTransferToPlanningLine(var JobLedgerEntry: Record "Job Ledger Entry")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnCreateJTOnBeforeAssigneJobDiffBuffer2(var JobDiffBuffer: array[2] of Record "Job Difference Buffer" temporary; JobPlanningLine: Record "Job Planning Line")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnPostDiffBufferOnAfterInsertJobJnlLine(var JobJnlLine: Record "Job Journal Line"; var JobDiffBuffer: Record "Job Difference Buffer" temporary)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnPostDiffBufferOnBeforeModify(var JobLedgEntry: Record "Job Ledger Entry"; var JobDiffBuffer: Record "Job Difference Buffer" temporary)
    begin
    end;
}

