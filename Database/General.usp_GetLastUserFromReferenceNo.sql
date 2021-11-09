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
CREATE PROCEDURE General.usp_GetLastUserFromReferenceNo
	-- Add the parameters for the stored procedure here
	@ReferenceNo Varchar(50),
	@WorkflowType varchar(25)	
AS
BEGIN
	
	DECLARE @tmpID bigint, @tmpIDAssigned bigint, @StatusCode varchar(5)

	IF(@WorkflowType = 'Policy')
	BEGIN
		--ambil semua worklist
		SELECT WorkflowTaskAssignmentID,WorkFlowAssignmentStatusCode,Actor, WorkflowStageCode 
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
		
		--ambil statuscode workflow terakhir
		select top 1 @StatusCode = WorkFlowAssignmentStatusCode
		from #tmpWF_Policy
		order by WorkflowTaskAssignmentID desc

		--Select user assign terakhir
		select top 1 WorkflowStageCode as WorkflowStage,Actor
		FROM #tmpWF_Policy
		WHERE WorkFlowAssignmentStatusCode = CASE WHEN @StatusCode = 'IOP' 
												THEN WorkFlowAssignmentStatusCode 
												ELSE 'ASS' 
											END
		order by WorkflowTaskAssignmentID desc	

		IF OBJECT_ID('tempdb..#tmpWF_Policy') is not null
			drop table #tmpWF_Policy
	END
	ELSE
	BEGIN
		--ambil semua worklist
		SELECT WorkflowTaskAssignmentID,WorkFlowAssignmentStatusCode, Actor,B.WorkFlowStage, B.CreatedDate As WTACreatedDate
		into #tmpWF_Claim
		FROM Claim.WorkflowTask A
		INNER JOIN Claim.WorkflowTaskAssignment B ON A.WorkflowTaskID = B.WorkflowTaskID
		INNER JOIN General.WorkFlowAssignmentStatus C ON B.WorkflowAssignmentStatusID = C.WorkFlowAssignmentStatusID
		WHERE ReferenceNo=@ReferenceNo
		ORDER BY WorkflowTaskAssignmentID

		--ambil workflow terakhir sebelum assigned untuk masing2 workflowstage
		select ROW_NUMBER() OVER (ORDER BY WorkflowStage) as rowNum, MAX(WorkflowTaskAssignmentID) as MaxWorkflowTaskAssignmentID, WorkFlowStage
		into #tmpWF_Claim_WorkflowStage
		FROM #tmpWF_Claim 
		WHERE WorkFlowAssignmentStatusCode not in ('ASS','IOP','REL','RELBG','TO','RED','DEL')			
		GROUP BY WorkFlowStage

		Declare @i int = 1,
		@Count int,
		@WorkflowStage varchar(20),
		@RELBGData dbo.IDValues

		--count workflowstage
		select @Count = COUNT(1) FROM #tmpWF_Claim_WorkflowStage

		--looping masing2 workflowstage
		WHILE(@i <= @Count)
		BEGIN 
			--hapus worklist yg tidak digunakan
			Delete A
			FROM #tmpWF_Claim A
			INNER JOIN #tmpWF_Claim_WorkflowStage B on A.WOrkflowStage = B.WorkflowStage
			WHERE B.rowNum = @i
			AND A.WorkFlowTaskAssignmentID <= B.MaxWorkflowTaskAssignmentID

			SELECT @WorkflowStage = WorkFlowStage FROM #tmpWF_Claim_WorkflowStage where rowNum = @i

			--retrieve worklist dengan status Release (Background)
			insert @RELBGData
			select WorkFlowTaskAssignmentID,Actor	
			FROM #tmpWF_Claim
			WHERE WorkFlowAssignmentStatusCode = 'RELBG' --Release (Background)
			AND WorkFlowStage = @WorkflowStage

			--hapus worklist user dengan status Release (Background)
			Delete #tmpWF_Claim
			where WorkflowTaskAssignmentID in 
			(
				select A.WorkFlowTaskAssignmentID
				from #tmpWF_Claim A
				inner join @RELBGData B on A.Actor = B.Value
				where A.WorkFlowTaskAssignmentID < B.ID and A.WorkFlowAssignmentStatusCode = 'ASS'
				AND WorkFlowStage = @WorkflowStage
			)	

			DELETE @RELBGData
			SET @i = @i + 1
		END

		--Retrieve data jika worklist terakhir adalah Open maka ambil Actor yg open, jika bukan ambil actor terakhir yg assign
		;with cte_Last as
		(
			select max(WorkFlowTaskAssignmentID) as MaxWorkflowTaskAssignmentID, WorkFlowStage
			from #tmpWF_Claim
			group by WorkFlowStage
		),
		cte_Assign as
		(
			select max(WorkFlowTaskAssignmentID) as MaxWorkflowTaskAssignmentID, WorkFlowStage
			from #tmpWF_Claim
			where WorkflowAssignmentStatusCode = 'ASS'
			group by WorkFlowStage
		)
		select MAX(TMP.WorkFlowTaskAssignmentID) as MaxWorkflowTaskAssignmentID, TMP.WorkFlowStage
		into #tmpWF_Claim_Final
		from #tmpWF_Claim TMP
		LEFT JOIN cte_Last CL on TMP.WorkflowTaskAssignmentID = CL.MaxWorkflowTaskAssignmentID
		LEFT JOIN cte_Assign CA on TMP.WorkFlowTaskAssignmentID = CA.MaxWorkflowTaskAssignmentID
		WHERE ( CL.WorkFlowStage is not null OR CA.WorkFlowStage is not null)
		AND TMP.WorkFlowAssignmentStatusCode in ('IOP','ASS')
		GROUP BY TMP.WorkFlowStage

		--Retrieve Final
		select WorkFlowStage, Actor 
		from #tmpWF_Claim 
		where WorkFlowTaskAssignmentID in (select MaxWorkflowTaskAssignmentID from #tmpWF_Claim_Final)

		IF OBJECT_ID('tempdb..#tmpWF_Claim') is not null
			DROP TABLE #tmpWF_Claim
		IF OBJECT_ID('tempdb..#tmpWF_Claim_Exclude') is not null
			DROP TABLE #tmpWF_Claim_Exclude
		IF OBJECT_ID('tempdb..#tmpWF_Claim_Final') is not null
			DROP TABLE #tmpWF_Claim_Final
	END
	
END
GO

GRANT EXEC ON General.usp_GetLastUserFromReferenceNo TO PUBLIC
GO