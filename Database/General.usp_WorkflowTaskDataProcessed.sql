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