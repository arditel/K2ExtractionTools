use BeyondDB
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		AEK
-- Create date: 2021/11/08
-- Description:	Insert to WTWorkflowDataPIC #248URF2021
-- =============================================
CREATE PROCEDURE General.usp_ProcessWTWorkflowTaskDataPIC
	-- Add the parameters for the stored procedure here
	@ReferenceNo Varchar(50),
	@SerialNo varchar(10),
	@CanvasName varchar(100),
	@WorkflowStageCode varchar(8),
	@Folio varchar(255),
	@Originator varchar(100),
	@Status varchar(10),
	@WorkflowType varchar(20),
	@SubmitDate datetime,
	@WorkflowStage varchar(512)
AS
BEGIN
	
	DECLARE @WorkflowStageDescription varchar(50),
		@WTWorkflowTaskDataID bigint,
		@tmpID bigint,
		@StatusCode varchar(5),
		@DomainPrefix varchar(10)

	IF(@WorkflowType = 'Policy')
	BEGIN
		--UPDATE WTWORKFLOWTASKDATA		

		select @WorkflowStageDescription = StageDescription
		FROM PolicyInsurance.WorkflowStage
		WHERE StageCode = @WorkflowStageCode
		and RowStatus = 0

		select top 1 @WTWorkflowTaskDataID = WTWorkflowTaskDataID
		FROM PolicyInsurance.WTWorkflowTaskData
		WHERE ReferenceNo = @ReferenceNo
		and RowStatus = 0
		ORDER BY WTWorkflowTaskDataID desc

		UPDATE PolicyInsurance.WTWorkflowTaskData
		SET SerialNo = @SerialNo,
			CanvasName = @CanvasName,
			WorkflowStageCode = @WorkflowStageCode,
			WorkflowStageDescription = @WorkflowStageDescription,
			Folio = @Folio,
			Originator = @Originator,
			Status = @Status,
			StartDate = @SubmitDate,
			IsProcess = 1,
			ModifiedBy = 'System',
			ModifiedDate = GETDATE()
		WHERE WTWorkflowTaskDataID = @WTWorkflowTaskDataID

		--INSERT WTWORKFLOWDATAPIC
		IF NOT EXISTS (select 1 from PolicyInsurance.WTWorkflowDataPIC where ReferenceNo = @ReferenceNo)
		BEGIN
			--ambil semua worklist yg status assigned
			SELECT WorkflowTaskAssignmentID,WorkFlowAssignmentStatusCode, Actor, B.CreatedDate As WTACreatedDate
			into #tmpWF_Policy
			FROM PolicyInsurance.WorkflowTask A
			INNER JOIN PolicyInsurance.WorkflowTaskAssignment B ON A.WorkflowTaskID = B.WorkflowTaskID
			INNER JOIN General.WorkFlowAssignmentStatus C ON B.WorkflowAssignmentStatusID = C.WorkFlowAssignmentStatusID
			WHERE ReferenceNo=@ReferenceNo 
			ORDER BY WorkflowTaskAssignmentID

			--ambil workflow terakhir sebelum assigned
			select Top 1 @tmpID = WorkflowTaskAssignmentID
			FROM #tmpWF_Policy 
			WHERE WorkFlowAssignmentStatusCode not in ('ASS','IOP','REL','RELBG','TO','RED','DEL')			
			ORDER BY WorkflowTaskAssignmentID desc

			--Hapus workflow assigned sebelum @tmpID
			Delete #tmpWF_Policy where WorkflowTaskAssignmentID <= @tmpID
				
			select WorkFlowTaskAssignmentID,Actor
			into #tmpRELBG
			FROM #tmpWF_Policy
			WHERE WorkFlowAssignmentStatusCode = 'RELBG' --Release (Background)
		
			Delete #tmpWF_Policy
			where WorkflowTaskAssignmentID in 
			(
				select A.WorkFlowTaskAssignmentID
				from #tmpWF_Policy A
				inner join #tmpRELBG B on General.udf_RemoveDomainFromUser(A.Actor) = General.udf_RemoveDomainFromUser(B.Actor)
				where A.WorkFlowTaskAssignmentID < B.WorkFlowTaskAssignmentID and A.WorkFlowAssignmentStatusCode = 'ASS'
			)		

			--Get assigned actor
			SELECT DISTINCT Actor
			into #tmpASS_Policy
			FROM #tmpWF_Policy
			WHERE WorkFlowAssignmentStatusCode = 'ASS'
			
			--Get Domain Prefix
			select top 1 @DomainPrefix = LEFT(Actor,CHARINDEX('\',Actor,0)) FROM #tmpASS_Policy

			--Add user OOF
			insert #tmpASS_Policy
			select CONCAT(@DomainPrefix,EmpAct.LogID)
			from General.OutOfOffice OOF 
			inner join General.vActiveEmployeeInformation Emp on OOF.EmployeeID = emp.EmployeeID
			inner join General.vActiveEmployeeInformation EmpAct on EmpAct.EmployeeID = OOF.ActingEmployeeID
			where OOF.employeeid in (
				select EmployeeID from General.vactiveemployeeinformation 
				where logid in (select General.udf_removedomainfromuser(Actor) 
								from #tmpASS_Policy))
			and OOF.StartDate < GETDATE() 
			and OOF.EndDate > GETDATE()
			and OOF.ActiveStatusID = 1
			and OOF.RowStatus = 0

			--Insert ke table Policyinsurance.WTWorkflowDataPIC
			INSERT PolicyInsurance.WTWorkflowDataPIC
			(ReferenceNo,SerialNo,CanvasName,WorkflowStageCode,WorkflowStageDescription,PICUser,IsOpen,CreatedBy,CreateDate)
			SELECT DISTINCT 
				@ReferenceNo,
				@SerialNo,
				@CanvasName,
				@WorkflowStageCode,
				@WorkflowStageDescription,
				Actor,
				0,
				'System',
				GETDATE()
			FROM #tmpASS_Policy
			
			--ambil statuscode workflow terakhir
			select top 1 @StatusCode = WorkFlowAssignmentStatusCode
			from #tmpWF_Policy
			order by WorkflowTaskAssignmentID desc

			--Update PIC User Open
			UPDATE PolicyInsurance.WTWorkflowDataPIC
			SET IsOpen = 1, ItemOpenedDate = TMP.WTACreatedDate
			FROM PolicyInsurance.WTWorkflowDataPIC PIC
				INNER JOIN #tmpWF_Policy TMP on General.udf_RemoveDomainFromUser(PIC.PICUser) = General.udf_RemoveDomainFromUser(TMP.Actor)
			WHERE PIC.ReferenceNo = @ReferenceNo 
				AND TMP.WorkFlowAssignmentStatusCode = 'IOP'
				AND @StatusCode <> 'REL' -- tidak update IsOpen jika statuscode terakhir Release
			
			IF OBJECT_ID('tempdb..#tmpWF_Policy') is not null
				DROP TABLE #tmpWF_Policy
			IF OBJECT_ID('tempdb..#tmpASS_Policy') is not null
				DROP TABLE #tmpASS_Policy
		END
	END
	ELSE
	BEGIN
		DECLARE @WorkflowStageOri varchar(512)

		SET @WorkflowStageOri = @WorkflowStage

		IF(@CanvasName = 'SPC Process' AND LEN(@WorkflowStageCode) = 0)
		BEGIN				
			SET @WorkflowStageCode = 'SCSSPC'
			SET @WorkflowStage = 'Print SPC'
		END

		DECLARE @isClaimUnattached bit
			--@EnumOfClaimTypeCode varchar(10)
		SET @isClaimUnattached = 0

		--select @EnumOfClaimTypeCode  = EnumOfClaimTypeCode from Claim.Claims where ClaimNo = @ReferenceNo

		select @isClaimUnattached = 1
		FROM Claim.WTWorkflowTaskData 
		where ReferenceNo = @ReferenceNo and CanvasName = 'Claim Process' 
		AND exists (select 1 from Claim.WTWorkflowTaskData where WorkflowStageCode = 'CLMPRC' and ReferenceNo = @ReferenceNo)
		--AND @EnumOfClaimTypeCode <> 'ATT'
		
		--case claim unattached WorkflowStage yg pertama diproses adalah stage CLMPRC
		IF (@isClaimUnattached = 0 AND @CanvasName = 'Claim Process')
		BEGIN
			SET @WorkflowStageCode = 'CLMPRC'
			SET @WorkflowStage = 'Claim Process'

			SET @WorkflowStageOri = @WorkflowStage
		END
		
		IF EXISTS (select 1 FROM Claim.WTWorkflowTaskData where ReferenceNo = @ReferenceNo and WorkflowStageCode is null)
		BEGIN
			--UPDATE WTWORKFLOWTASKDATA		
			select top 1 @WTWorkflowTaskDataID = WTWorkflowTaskDataID
			FROM Claim.WTWorkflowTaskData
			WHERE ReferenceNo = @ReferenceNo
			and RowStatus = 0
			ORDER BY WTWorkflowTaskDataID desc			

			UPDATE Claim.WTWorkflowTaskData
			SET SerialNo = @SerialNo,
				CanvasName = @CanvasName,
				WorkflowStageCode = @WorkflowStageCode,
				WorkflowStageDescription = @WorkflowStage,
				Folio = @Folio,
				Originator = @Originator,
				Status = @Status,
				StartDate = @SubmitDate,
				IsProcess = 1,
				ModifiedBy = 'System',
				ModifiedDate = GETDATE()
			WHERE WTWorkflowTaskDataID = @WTWorkflowTaskDataID
		END
		ELSE IF NOT EXISTS (select 1 FROM Claim.WTWorkflowTaskData where ReferenceNo = @ReferenceNo and WorkflowStageDescription = @WorkflowStage)
		BEGIN			
			INSERT Claim.WTWorkflowTaskData (ReferenceNo, SerialNo, CanvasName, WorkflowStageCode, WorkflowStageDescription, Folio, Originator, Status, StartDate, IsProcess, CreatedBy,CreateDate,RowStatus)
			VALUES
			( @ReferenceNo, @SerialNo, @CanvasName, @WorkflowStageCode, @WorkflowStage, @Folio, @Originator, @Status, @SubmitDate, 1, 'System',GETDATE(),0)			
		END

		--INSERT WTWORKFLOWDATAPIC
		IF NOT EXISTS (select 1 from Claim.WTWorkflowDataPIC where ReferenceNo = @ReferenceNo and WorkflowStageDescription = @WorkflowStage)
		BEGIN
			--ambil semua worklist yg status assigned
			SELECT WorkflowTaskAssignmentID,WorkFlowAssignmentStatusCode, Actor, B.CreatedDate As WTACreatedDate
			into #tmpWF_Claim
			FROM Claim.WorkflowTask A
			INNER JOIN Claim.WorkflowTaskAssignment B ON A.WorkflowTaskID = B.WorkflowTaskID
			INNER JOIN General.WorkFlowAssignmentStatus C ON B.WorkflowAssignmentStatusID = C.WorkFlowAssignmentStatusID
			WHERE ReferenceNo=@ReferenceNo 
			AND B.WorkflowStage = @WorkflowStageOri
			ORDER BY WorkflowTaskAssignmentID

			--START kondisi claim unattached
			DECLARE @ClaimProcessUnAttached dbo.ids,
				@ClaimProcessUnAttachedAction dbo.ids2,
				@CountCPU int,
				@j int = 1
		
			insert @ClaimProcessUnAttachedAction
			select ROW_NUMBER() over (ORDER BY T.WorkflowTaskAssignmentID) as rn, T.WorkFlowTaskAssignmentID from #tmpWF_Claim T
				inner join Claim.WorkFlowTaskAssignment WTA on T.WorkFlowTaskAssignmentID = WTA.WorkFlowTaskAssignmentID
				where WTA.Action in ('NeedApproval','NoApproval')
				and WTA.WorkFlowStage = 'Claim Process'
				and WTA.RowStatus = 0
		
			select @CountCPU = count(1) from @ClaimProcessUnAttachedAction 

			WHILE (@j <= @CountCPU)
			BEGIN
				;WITH CTE AS
				(
					select ID2 from @ClaimProcessUnAttachedAction where ID1 = @j
				),
				CTE_ClaimProcessUnAttachedOutstage AS
				(
					select TOP 1 WorkFlowTaskAssignmentID FROM #tmpWF_Claim T 
					where WorkFlowTaskAssignmentID > (select ID2 from CTE) 
					AND @WorkflowStageOri = 'Claim Process'
					AND WorkFlowAssignmentStatusCode = 'OUTST'
					order by WorkFlowTaskAssignmentID
				)				
				insert into @ClaimProcessUnAttached
				select * from CTE
				UNION ALL
				select * from CTE_ClaimProcessUnAttachedOutstage				

				SET @j = @j + 1;
			END

			delete #tmpWF_Claim
			where WorkFlowTaskAssignmentID in (select id from @ClaimProcessUnAttached)
			--END kondisi claim unattached

			--ambil workflow terakhir sebelum assigned
			select Top 1 @tmpID = WorkflowTaskAssignmentID
			FROM #tmpWF_Claim 
			WHERE WorkFlowAssignmentStatusCode not in ('ASS','IOP','REL','RELBG','TO','RED','DEL')			
			ORDER BY WorkflowTaskAssignmentID desc

			--Hapus workflow assigned sebelum @tmpID
			Delete #tmpWF_Claim where WorkflowTaskAssignmentID <= @tmpID
				
			select WorkFlowTaskAssignmentID,Actor
			into #tmpRELBG_Claim
			FROM #tmpWF_Claim
			WHERE WorkFlowAssignmentStatusCode = 'RELBG' --Release (Background)
		
			Delete #tmpWF_Claim
			where WorkflowTaskAssignmentID in 
			(
				select A.WorkFlowTaskAssignmentID
				from #tmpWF_Claim A
				inner join #tmpRELBG_Claim B on General.udf_RemoveDomainFromUser(A.Actor) = General.udf_RemoveDomainFromUser(B.Actor)
				where A.WorkFlowTaskAssignmentID < B.WorkFlowTaskAssignmentID and A.WorkFlowAssignmentStatusCode = 'ASS'
			)		

			CREATE TABLE #tmpASS_Claim
			(
				Actor varchar(512)
			)

			--Get assigned actor
			IF (@WorkflowStageOri = 'Claim Unattached Approval')
			BEGIN 
				declare @ActorClaimUnattached as table
				(
					id int,
					Actor varchar(512)
				)
				
				DECLARE @iteration int,
					@countClaimUnattachedActor int,
					@Actor varchar(512)
				SET @iteration = 1
				SET @countClaimUnattachedActor = 0

				insert @ActorClaimUnattached
				select ROW_NUMBER() over(order by actor), Actor from
				(
					select distinct Actor from #tmpWF_Claim where WorkFlowAssignmentStatusCode = 'ASS'
				) as A

				select @countClaimUnattachedActor = count(1) from @ActorClaimUnattached

				WHILE(@iteration <= @countClaimUnattachedActor)
				BEGIN
					SET @Actor = ''
					select @Actor = Actor from @ActorClaimUnattached where id = @iteration

					insert #tmpASS_Claim
					select Data from General.udf_SplitString(@Actor,';')
					
					SET @iteration = @iteration + 1
				END				
			END
			ELSE
			BEGIN			
				INSERT #tmpASS_Claim
				SELECT DISTINCT Actor			
				FROM #tmpWF_Claim
				WHERE WorkFlowAssignmentStatusCode = 'ASS'
			END

			DELETE #tmpASS_Claim where Actor is null

			--Get Domain Prefix
			select top 1 @DomainPrefix = LEFT(Actor,CHARINDEX('\',Actor,0)) FROM #tmpASS_Claim

			DECLARE @EmployeeID dbo.IDS

			insert @EmployeeID
			select EmployeeID 			
			from General.vactiveemployeeinformation 
			where logid in (select General.udf_removedomainfromuser(Actor) 
								from #tmpASS_Claim)

			--Add user OOF
			insert #tmpASS_Claim
			select CONCAT(@DomainPrefix,EmpAct.LogID)
			from General.OutOfOffice OOF 			
			inner join General.vActiveEmployeeInformation EmpAct on EmpAct.EmployeeID = OOF.ActingEmployeeID
			inner join @EmployeeID emp on OOF.EmployeeID = emp.ID
			and OOF.StartDate < GETDATE() 
			and OOF.EndDate > GETDATE()
			and OOF.ActiveStatusID = 1
			and OOF.RowStatus = 0

			--Insert pic user k2admin untuk CLMPRC dan CLMUEA
			IF (@CanvasName = 'Claim Process' AND (@WorkflowStageCode = 'CLMPRC' OR @WorkflowStageCode = 'CLMUEA'))
			BEGIN
				insert #tmpASS_Claim
				values (CONCAT(@DomainPrefix,'k2admin'))
			END

			--Insert ke table Policyinsurance.WTWorkflowDataPIC
			INSERT Claim.WTWorkflowDataPIC
			(ReferenceNo,SerialNo,CanvasName,WorkflowStageCode,WorkflowStageDescription,PICUser,IsOpen,CreatedBy,CreateDate)
			SELECT DISTINCT 
				@ReferenceNo,
				@SerialNo,
				@CanvasName,
				@WorkflowStageCode,
				@WorkflowStage,
				Actor,
				0,
				'System',
				GETDATE()
			FROM #tmpASS_Claim
			
			--ambil statuscode workflow terakhir
			select top 1 @StatusCode = WorkFlowAssignmentStatusCode
			from #tmpWF_Claim
			order by WorkflowTaskAssignmentID desc

			--Update PIC User Open
			UPDATE Claim.WTWorkflowDataPIC
			SET IsOpen = 1, ItemOpenedDate = TMP.WTACreatedDate
			FROM Claim.WTWorkflowDataPIC PIC
				INNER JOIN #tmpWF_Claim TMP on General.udf_RemoveDomainFromUser(PIC.PICUser) = General.udf_RemoveDomainFromUser(TMP.Actor)
			WHERE PIC.ReferenceNo = @ReferenceNo 
				AND PIC.WorkflowStageDescription = @WorkflowStage
				AND TMP.WorkFlowAssignmentStatusCode = 'IOP'
				AND @StatusCode <> 'REL' -- tidak update IsOpen jika statuscode terakhir Release
			
			IF OBJECT_ID('tempdb..#tmpWF_Claim') is not null
				DROP TABLE #tmpWF_Claim
			IF OBJECT_ID('tempdb..#tmpASS_Claim') is not null
				DROP TABLE #tmpASS_Claim
			IF OBJECT_ID('tempdb..#tmpRELBG_Claim') is not null
				DROP TABLE #tmpRELBG_Claim
		END
	END

	SELECT LEFT(@SerialNo,CHARINDEX('_',@SerialNo) - 1) as ProcInstID
END
GO

GRANT EXEC ON General.usp_ProcessWTWorkflowTaskDataPIC TO PUBLIC
GO