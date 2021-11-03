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
CREATE PROCEDURE General.usp_InsertWTWorkflowDataField
	-- Add the parameters for the stored procedure here
	@ReferenceNo Varchar(50),
	@DataFieldName varchar(255),
	@DataFieldValue varchar(max),
	@WorkflowType varchar(20)
AS
BEGIN
	
	DECLARE @SerialNo varchar(10),
			@CanvasName varchar(100),
			@WorkflowStageCode varchar(8),
			@WorkflowStageDescription varchar(50)

	IF(@WorkflowType = 'Policy')
	BEGIN		
		--RETRIEVE WTWORKFLOWTASKDATA
		select 
			@SerialNo = SerialNo,
			@CanvasName = CanvasName,
			@WorkflowStageCode = WorkflowStageCode,
			@WorkflowStageDescription = WorkflowStageDescription
		FROM PolicyInsurance.WTWorkflowTaskData
		WHERE ReferenceNo = @ReferenceNo
		AND RowStatus = 0
		
		--INSERT WTWORKFLOWDATAFIELD
		insert PolicyInsurance.WTWorkflowDataField
		(ReferenceNo,SerialNo,CanvasName,WorkflowStageCode,WorkflowStageDescription,DataFieldName,DataFieldValue,CreatedBy,CreateDate)
		VALUES 
		(
			@ReferenceNo,
			@SerialNo,
			@CanvasName,
			@WorkflowStageCode,
			@WorkflowStageDescription,
			@DataFieldName,
			@DataFieldValue,
			'System',
			GETDATE()
		)				
	END
	ELSE
	BEGIN
		--RETRIEVE WTWORKFLOWTASKDATA
		select 
			@SerialNo = SerialNo,
			@CanvasName = CanvasName,
			@WorkflowStageCode = WorkflowStageCode,
			@WorkflowStageDescription = WorkflowStageDescription
		FROM Claim.WTWorkflowTaskData
		WHERE ReferenceNo = @ReferenceNo
		AND RowStatus = 0
		
		--INSERT WTWORKFLOWDATAFIELD
		insert Claim.WTWorkflowDataField
		(ReferenceNo,SerialNo,CanvasName,WorkflowStageCode,WorkflowStageDescription,DataFieldName,DataFieldValue,CreatedBy,CreateDate)
		VALUES 
		(
			@ReferenceNo,
			@SerialNo,
			@CanvasName,
			@WorkflowStageCode,
			@WorkflowStageDescription,
			@DataFieldName,
			@DataFieldValue,
			'System',
			GETDATE()
		)				
	END
	
END
GO

GRANT EXEC ON General.usp_InsertWTWorkflowDataField TO PUBLIC
GO