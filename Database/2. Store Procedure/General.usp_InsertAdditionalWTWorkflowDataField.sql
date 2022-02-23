use BeyondDB
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		AEK
-- Create date: 2022/1/11
-- Description:	Insert additional data field #0248URF2021
-- =============================================
ALTER PROCEDURE General.usp_InsertAdditionalWTWorkflowDataField
	-- Add the parameters for the stored procedure here
	@ReferenceNo Varchar(50),
	@SerialNo varchar(10),	
	@WorkflowStageCode varchar(8),	
	@WorkflowType varchar(20)
AS
BEGIN

	IF(@WorkflowType = 'Claim')
	BEGIN
		IF(@WorkflowStageCode = 'SCSQAP') --Sub Claim Section QA Process
		BEGIN
			DECLARE @SubClaimSectionID varchar(100),
				@IsNeedQA varchar(5),
				@IsDocumentCompleted varchar(5),
				@SCSType varchar(3),
				@IsClaimInterim varchar(5),
				@ClaimCommercialDepartmentHeadUser varchar(25),
				@RevisionNo bigint,
				@LogIDHeadUser dbo.value,
				@CanvasName varchar(100),
				@WorkflowStageDescription varchar(50)
			
			SET @IsNeedQA = 'True'
			SET @IsDocumentCompleted = 'True'

			--Retrieve RevisionNo
			SELECT @RevisionNo = CASE WHEN ISNUMERIC(DataFieldValue) = 1 THEN CAST(DataFieldValue as bigint) ELSE 0 END,
				@CanvasName = CanvasName,
				@WorkflowStageDescription = WorkflowStageDescription
			FROM Claim.WTWorkflowDataField
			WHERE ReferenceNo = @ReferenceNo
				AND SerialNo = @SerialNo
				AND WorkflowStageCode = @WorkflowStageCode
				AND DataFieldName = 'RevisionNo'

			--Retrieve SubClaimSectionID, SCSType, IsClaimInterim
			SELECT @SubClaimSectionID = SubClaimSectionID,
				@SCSType = UPPER(EnumOfSubClaimSectionTypeCode),
				@IsClaimInterim = CASE WHEN IsFinalSettlement = 1
											THEN 'True'
										ELSE 'False'
										END
			FROM Claim.SubClaimSection
			WHERE SubClaimSectionNo = @ReferenceNo
				AND RevisionNo = @RevisionNo
				AND RowStatus = 0
			
			--Retrieve ClaimCommercialDepartmentHeadUser
			INSERT @LogIDHeadUser
			EXEC Claim.usp_RetrieveClaimCommercialDeptHeadBySubClaimSectionNo @SubClaimSectionNo = @ReferenceNo
			
			select @ClaimCommercialDepartmentHeadUser = value1 FROM @LogIDHeadUser

			--Additional data field
			DECLARE @TempDataField as TABLE
			(
				ReferenceNo varchar(50),
				SerialNo varchar(10),
				DataFieldName varchar(255),
				DataFieldValue varchar(max)
			)

			INSERT INTO @TempDataField
			VALUES 
			(@ReferenceNo,@SerialNo,'SubClaimSectionID',@SubClaimSectionID),
			(@ReferenceNo,@SerialNo,'IsNeedQA',@IsNeedQA),
			(@ReferenceNo,@SerialNo,'IsDocumentCompleted',@IsDocumentCompleted),
			(@ReferenceNo,@SerialNo,'SCSType',@SCSType),
			(@ReferenceNo,@SerialNo,'IsClaimInterim',@IsClaimInterim),
			(@ReferenceNo,@SerialNo,'ClaimCommercialDepartmentHeadUser',@ClaimCommercialDepartmentHeadUser)

			MERGE Claim.WTWorkflowDataField AS TARGET
			USING @TempDataField AS SOURCE ON TARGET.ReferenceNo = SOURCE.ReferenceNo 
												AND TARGET.SerialNo = SOURCE.SerialNo
												AND TARGET.DataFieldName = SOURCE.DataFieldName
												AND TARGET.RowStatus = 0
			WHEN NOT MATCHED BY TARGET THEN
				INSERT (ReferenceNo, SerialNo, CanvasName, WorkflowStageCode, WorkflowStageDescription, DataFieldName, DataFieldValue, CreatedBy, CreateDate, RowStatus)
				VALUES (SOURCE.ReferenceNo, SOURCE.SerialNo, @CanvasName, @WorkflowStageCode, @WorkflowStageDescription, SOURCE.DataFieldName, SOURCE.DataFieldValue, 'System', GETDATE(), 0)
			WHEN MATCHED THEN 
				UPDATE SET TARGET.DataFieldValue = SOURCE.DataFieldValue;

		END
	END
	
END
GO

GRANT EXEC ON General.usp_InsertAdditionalWTWorkflowDataField TO PUBLIC
GO