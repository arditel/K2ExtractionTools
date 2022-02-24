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
--ALTER PROCEDURE General.usp_InsertWTWorkflowDataField
BEGIN TRAN
update Claim.WTWorkflowTaskData set serialno = '186791_37' where WTWorkflowTaskDataID = 5
update Claim.WTWorkflowDataPIC  set serialno = '186791_37' where WTWorkflowDataPICID = 6

DECLARE
	-- Add the parameters for the stored procedure here
	@ReferenceNo Varchar(50) = '1800NHI00',
	@SerialNo varchar(10) = '186791_37',
	@CanvasName varchar(100) = 'Claim Process',
	@WorkflowStageCode varchar(8) = 'CLMUEA',
	@WorkflowStageDescription varchar(50) = 'Claim Unattached Approval',
	@DataFieldName varchar(255) = 'ReferenceNo',
	@DataFieldValue varchar(max) = '1800NHI00',
	@WorkflowType varchar(20) = 'Claim'
--AS
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

		select 'test',1 from Claim.WTWorkflowDataField 
												where SerialNo = @SerialNo 
													and CanvasName = @CanvasName
													and DataFieldName = @DataFieldName
													and DataFieldValue = @DataFieldValue

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

select @WorkflowStageCode '@WorkflowStageCode', @WorkflowStageDescription '@WorkflowStageDescription'

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

select * from Claim.WTWorkflowDataField where ReferenceNo = '1800NHI00'

ROLLBACK TRAN

--GRANT EXEC ON General.usp_InsertWTWorkflowDataField TO PUBLIC
--GO