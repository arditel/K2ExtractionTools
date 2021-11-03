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
	@WorkflowType varchar(25),
	@UserLogID varchar(20) OUTPUT
AS
BEGIN
	
	DECLARE @tmpID bigint, @tmpIDAssigned bigint, @StatusCode varchar(5)

	IF(@WorkflowType = 'Policy')
	BEGIN
		--ambil semua worklist
		SELECT WorkflowTaskAssignmentID,WorkFlowAssignmentStatusCode,Actor 
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
		select top 1 @UserLogID =  Actor
		FROM #tmpWF_Policy
		WHERE WorkFlowAssignmentStatusCode = CASE WHEN @StatusCode = 'IOP' 
												THEN WorkFlowAssignmentStatusCode 
												ELSE 'ASS' 
											END
		order by WorkflowTaskAssignmentID desc	

		drop table #tmpWF_Policy
	END
	ELSE
	BEGIN
		--ambil semua worklist
		SELECT WorkflowTaskAssignmentID,WorkFlowAssignmentStatusCode, Actor
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

		--ambil statuscode workflow terakhir
		select top 1 @StatusCode = WorkFlowAssignmentStatusCode
		from #tmpWF_Claim
		order by WorkflowTaskAssignmentID desc

		--Select user assign terakhir
		select top 1 @UserLogID =  Actor
		FROM #tmpWF_Claim
		WHERE WorkFlowAssignmentStatusCode = CASE WHEN @StatusCode = 'IOP' 
												THEN WorkFlowAssignmentStatusCode 
												ELSE 'ASS' 
											END
		order by WorkflowTaskAssignmentID desc	

		drop table #tmpWF_Claim
	END
	
END
GO

GRANT EXEC ON General.usp_GetLastUserFromReferenceNo TO PUBLIC
GO