--use BeyondDB
--GO

--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO
---- =============================================
---- Author:		AEK
---- Create date: 2021/11/8
---- Description:	Insert to PolicyInsurance.WTWorkflowDataField or Claim.WTWorkflowDataField #0248URF2021
---- =============================================
CREATE PROCEDURE General.usp_InsertWTWorkflowDataField
	-- Add the parameters for the stored procedure here
	@ReferenceNo Varchar(50),
	@SerialNo varchar(10),
	@CanvasName varchar(100),
	@WorkflowStageCode varchar(8),
	@WorkflowStageDescription varchar(50),
	@DataFieldName varchar(255),
	@DataFieldValue varchar(max),
	@WorkflowType varchar(20)
AS
BEGIN
	IF(@WorkflowType = 'Policy')
	BEGIN
		DECLARE @WorkflowStageDescriptionPolicy VARCHAR(50)
		--Retrieve WorkflowStageDescription
		select @WorkflowStageDescriptionPolicy = StageDescription
		FROM PolicyInsurance.WorkflowStage
		WHERE StageCode = @WorkflowStageCode
		and RowStatus = 0

		--INSERT WTWORKFLOWDATAFIELD
		insert PolicyInsurance.WTWorkflowDataField
		(ReferenceNo,SerialNo,CanvasName,WorkflowStageCode,WorkflowStageDescription,DataFieldName,DataFieldValue,CreatedBy,CreateDate)
		VALUES 
		(
			@ReferenceNo,
			@SerialNo,
			@CanvasName,
			@WorkflowStageCode,
			@WorkflowStageDescriptionPolicy,
			@DataFieldName,
			@DataFieldValue,
			'System',
			GETDATE()
		)				
	END
	ELSE
	BEGIN		
		IF(@CanvasName = 'SPC Process' AND LEN(@WorkflowStageCode) = 0)
		BEGIN				
			SET @WorkflowStageCode = 'SCSSPC'
			SET @WorkflowStageDescription = 'Print SPC'
		END	

		--case claim unattached
		IF(@WorkflowStageCode = 'CLMUEA' 
					AND NOT EXISTS ( select 1 from Claim.WTWorkflowDataField 
												where SerialNo = @SerialNo 
													and CanvasName = @CanvasName
													and DataFieldName = @DataFieldName
													and DataFieldValue = @DataFieldValue ))
		BEGIN			
			select  @WorkflowStageCode = 'CLMPRC',
					@WorkflowStageDescription = 'Claim Process'
			from Claim.WTWorkflowTaskData 
			where SerialNo = @SerialNo AND WorkflowStageCode = 'CLMPRC'
		END

		DECLARE @EnumOfClaimTypeCode varchar(10),
				@isInsertTaskData bit = 1

		select @EnumOfClaimTypeCode  = EnumOfClaimTypeCode from Claim.Claims where ClaimNo = @ReferenceNo

		IF (@EnumOfClaimTypeCode = 'ATT' AND @WorkflowStageCode = 'CLMUEA')
			SET @isInsertTaskData = 0

		IF (@isInsertTaskData = 1 )
		BEGIN
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
	
END
GO

GRANT EXEC ON General.usp_InsertWTWorkflowDataField TO PUBLIC
GO