use BeyondDB
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		AEK
-- Create date: 2021/11/08
-- Description:	Get last user workflow by reference no #0248URF2021
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
		AND A.RowStatus = 0
		AND B.RowStatus = 0
		AND C.RowStatus = 0
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
			and WTA.WorkFlowStage in ('Claim Process','Claim Unattached Approval')
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
				AND WorkFlowStage = 'Claim Process'
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

		--case claim unattached jika Actor lebih dari 1 user, maka ambil 1 user saja
		update #tmpWF_Claim 
		set Actor = CASE WHEN CHARINDEX(';',Actor) > 0 
						THEN convert(varchar(50),left(Actor, CHARINDEX(';',Actor)-1 )) 
						ELSE Actor 
					END 
		where WorkflowStage = 'Claim Unattached Approval'

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

		--jika 1 user punya lebih dari 1 worklist yang diassign
		select T.WorkFlowTaskAssignmentID, Actor,TF.WorkFlowStage ,WorkFlowAssignmentStatusCode
		into #tmpWF_Claim_Actor
		from #tmpWF_Claim_Final TF
		inner join #tmpWF_Claim T on T.WorkFlowTaskAssignmentID = TF.MaxWorkflowTaskAssignmentID		

		IF EXISTS (select 1 FROM #tmpWF_Claim_Actor TA
					INNER JOIN #tmpWF_Claim T on General.udf_removedomainfromuser(T.Actor) = General.udf_removedomainfromuser(TA.Actor) AND T.WorkFlowStage <> TA.WorkFlowStage )														
		BEGIN
			insert #tmpWF_Claim_Final
			select T.WorkFlowTaskAssignmentID,T.WorkFlowStage FROM #tmpWF_Claim_Actor TA
					INNER JOIN #tmpWF_Claim T on General.udf_removedomainfromuser(T.Actor) = General.udf_removedomainfromuser(TA.Actor) AND T.WorkFlowStage <> TA.WorkFlowStage
			WHERE NOT EXISTS (select 1 FROM #tmpWF_Claim_Actor TC WHERE General.udf_RemoveDomainFromUser(TC.Actor) = General.udf_RemoveDomainFromUser(T.Actor) AND TC.WorkFlowStage = T.WorkFlowStage )
		END

		--khusus untuk claim unattached, WorkflowStage "Claim Process" diupdate menjadi "Claim Unattached Approval" mengikuti kondisi di canvas k2
		IF EXISTS (select 1 from Claim.WorkFlowTask WT
							inner join Claim.WorkFlowTaskAssignment WTA on WT.WorkFlowTaskID = WTA.WorkFlowTaskID
							where WTA.WorkflowStage = 'Claim Unattached Approval'
							and WT.ReferenceNo = @ReferenceNo
							and WT.RowStatus = 0
							and WTA.RowStatus = 0)
		BEGIN
			IF NOT EXISTS (select 1 from @ClaimProcessUnAttached C
							inner join Claim.WorkFlowTaskAssignment WTA on C.ID = WTA.WorkFlowTaskAssignmentID
							INNER JOIN General.WorkFlowAssignmentStatus WFAS ON WFAS.WorkflowAssignmentStatusID = wta.WorkFlowAssignmentStatusID
						WHERE WFAS.WorkFlowAssignmentStatusCode = 'OUTST' 
							AND C.ID = (select MAX(ID) from @ClaimProcessUnAttached)
							AND WTA.WorkFlowStage = 'Claim Unattached Approval')
			BEGIN
				UPDATE #tmpWF_Claim SET WorkFlowStage = 'Claim Unattached Approval' WHERE WorkFlowStage = 'Claim Process'
			END
		END

		--Retrieve Final
		select WorkFlowStage, Actor 
		from #tmpWF_Claim 
		where WorkFlowTaskAssignmentID in (select MaxWorkflowTaskAssignmentID from #tmpWF_Claim_Final)
		order by WorkFlowTaskAssignmentID

		IF OBJECT_ID('tempdb..#tmpWF_Claim') is not null
			DROP TABLE #tmpWF_Claim		
		IF OBJECT_ID('tempdb..#tmpWF_Claim_Final') is not null
			DROP TABLE #tmpWF_Claim_Final
		IF OBJECT_ID('tempdb..#tmpWF_Claim_WorkflowStage') is not null
			DROP TABLE #tmpWF_Claim_WorkflowStage
		IF OBJECT_ID('tempdb..#tmpWF_Claim_Actor') is not null
			DROP TABLE #tmpWF_Claim_Actor
	END
	
END
GO

GRANT EXEC ON General.usp_GetLastUserFromReferenceNo TO PUBLIC
GO