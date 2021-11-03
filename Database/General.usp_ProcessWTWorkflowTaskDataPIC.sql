use BeyondDB
GO
-- ================================================
-- Template generated from Template Explorer using:
-- Create Procedure (New Menu).SQL
--
-- Use the Specify Values for Template Parameters 
-- command (Ctrl-Shift-M) to fill in the parameter 
-- values below.
--
-- This block of comments will not be included in
-- the definition of the procedure.
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
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
	@WorkflowType varchar(20)
AS
BEGIN
	
	DECLARE @StartDate datetime = '1900-01-01',
		@WorkflowStageDescription varchar(50),
		@WTWorkflowTaskDataID bigint,
		@tmpID bigint,
		@StatusCode varchar(5)

	IF(@WorkflowType = 'Policy')
	BEGIN
		--UPDATE WTWORKFLOWTASKDATA
		SELECT TOP 1 @StartDate = B.CreatedDate FROM PolicyInsurance.WorkflowTask A
		INNER JOIN PolicyInsurance.WorkflowTaskAssignment B ON A.WorkflowTaskID = B.WorkflowTaskID		
		WHERE ReferenceNo=@ReferenceNo ORDER BY WorkflowTaskAssignmentID

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
			StartDate = @StartDate,
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
				inner join #tmpRELBG B on A.Actor = B.Actor
				where A.WorkFlowTaskAssignmentID < B.WorkFlowTaskAssignmentID and A.WorkFlowAssignmentStatusCode = 'ASS'
			)		

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
			FROM #tmpWF_Policy
			WHERE WorkFlowAssignmentStatusCode = 'ASS'
			
			--ambil statuscode workflow terakhir
			select top 1 @StatusCode = WorkFlowAssignmentStatusCode
			from #tmpWF_Policy
			order by WorkflowTaskAssignmentID desc

			--Update PIC User Open
			UPDATE PolicyInsurance.WTWorkflowDataPIC
			SET IsOpen = 1, ItemOpenedDate = TMP.WTACreatedDate
			FROM PolicyInsurance.WTWorkflowDataPIC PIC
				INNER JOIN #tmpWF_Policy TMP on PIC.PICUser = TMP.Actor
			WHERE PIC.ReferenceNo = @ReferenceNo 
				AND TMP.WorkFlowAssignmentStatusCode = 'IOP'
				AND @StatusCode <> 'REL' -- tidak update IsOpen jika statuscode terakhir Release

			DROP TABLE #tmpWF_Policy
		END
	END
	ELSE
	BEGIN
		--UPDATE WTWORKFLOWTASKDATA
		SELECT TOP 1 @StartDate = B.CreatedDate FROM Claim.WorkflowTask A
		INNER JOIN Claim.WorkflowTaskAssignment B ON A.WorkflowTaskID = B.WorkflowTaskID		
		WHERE ReferenceNo=@ReferenceNo ORDER BY WorkflowTaskAssignmentID

		--select @WorkflowStageDescription = StageDescription
		--FROM Claim.WorkflowStage
		--WHERE StageCode = @WorkflowStageCode
		--and RowStatus = 0

		select top 1 @WTWorkflowTaskDataID = WTWorkflowTaskDataID
		FROM Claim.WTWorkflowTaskData
		WHERE ReferenceNo = @ReferenceNo
		and RowStatus = 0
		ORDER BY WTWorkflowTaskDataID desc

		UPDATE Claim.WTWorkflowTaskData
		SET SerialNo = @SerialNo,
			CanvasName = @CanvasName,
			WorkflowStageCode = @WorkflowStageCode,
			WorkflowStageDescription = @WorkflowStageCode,
			Folio = @Folio,
			Originator = @Originator,
			Status = @Status,
			StartDate = @StartDate,
			IsProcess = 1,
			ModifiedBy = 'System',
			ModifiedDate = GETDATE()
		WHERE WTWorkflowTaskDataID = @WTWorkflowTaskDataID

		--INSERT WTWORKFLOWDATAPIC
		IF NOT EXISTS (select 1 from Claim.WTWorkflowDataPIC where ReferenceNo = @ReferenceNo)
		BEGIN
			--ambil semua worklist yg status assigned
			SELECT WorkflowTaskAssignmentID,WorkFlowAssignmentStatusCode, Actor, B.CreatedDate As WTACreatedDate
			into #tmpWF_Claim
			FROM Claim.WorkflowTask A
			INNER JOIN Claim.WorkflowTaskAssignment B ON A.WorkflowTaskID = B.WorkflowTaskID
			INNER JOIN General.WorkFlowAssignmentStatus C ON B.WorkflowAssignmentStatusID = C.WorkFlowAssignmentStatusID
			WHERE ReferenceNo=@ReferenceNo 
			ORDER BY WorkflowTaskAssignmentID

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
				inner join #tmpRELBG_Claim B on A.Actor = B.Actor
				where A.WorkFlowTaskAssignmentID < B.WorkFlowTaskAssignmentID and A.WorkFlowAssignmentStatusCode = 'ASS'
			)		

			--Insert ke table Claim.WTWorkflowDataPIC
			INSERT Claim.WTWorkflowDataPIC
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
			FROM #tmpWF_Claim
			WHERE WorkFlowAssignmentStatusCode = 'ASS'
			
			--ambil statuscode workflow terakhir
			select top 1 @StatusCode = WorkFlowAssignmentStatusCode
			from #tmpWF_Claim
			order by WorkflowTaskAssignmentID desc

			--Update PIC User Open
			UPDATE Claim.WTWorkflowDataPIC
			SET IsOpen = 1, ItemOpenedDate = TMP.WTACreatedDate
			FROM PolicyInsurance.WTWorkflowDataPIC PIC
				INNER JOIN #tmpWF_Claim TMP on PIC.PICUser = TMP.Actor
			WHERE PIC.ReferenceNo = @ReferenceNo 
				AND TMP.WorkFlowAssignmentStatusCode = 'IOP'
				AND @StatusCode <> 'REL' -- tidak update IsOpen jika statuscode terakhir Release

			DROP TABLE #tmpWF_Claim
		END
	END

	SELECT LEFT(@SerialNo,CHARINDEX('_',@SerialNo) - 1) as ProcInstID
END
GO

GRANT EXEC ON General.usp_ProcessWTWorkflowTaskDataPIC TO PUBLIC
GO