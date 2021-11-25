use BeyondDB
GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		AEK
-- Create date: 2021/11/08
-- Description:	Retrieve data to be processed #248URF2021
-- =============================================
CREATE PROCEDURE General.usp_WorkflowTaskDataProcessed
	@WorkflowType varchar(20)
AS
BEGIN

	IF(@WorkflowType = 'Policy')
	BEGIN
		select WTWorkflowTaskDataID, ReferenceNo
		from PolicyInsurance.WTWorkflowTaskData 
		where IsProcess = 0 
		and RowStatus = 0
		order by WTWorkflowTaskDataID
	END
	ELSE
	BEGIN
		select WTWorkflowTaskDataID, ReferenceNo
		from Claim.WTWorkflowTaskData 
		where IsProcess = 0 
		and RowStatus = 0
		order by WTWorkflowTaskDataID
	END
	
END
GO

GRANT EXEC ON General.usp_WorkflowTaskDataProcessed TO PUBLIC
GO