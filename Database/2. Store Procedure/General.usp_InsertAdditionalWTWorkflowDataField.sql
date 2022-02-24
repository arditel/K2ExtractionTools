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
CREATE PROCEDURE General.usp_InsertAdditionalWTWorkflowDataField
	-- Add the parameters for the stored procedure here
	@ReferenceNo Varchar(50),
	@SerialNo varchar(10),	
	@WorkflowStageCode varchar(8),	
	@WorkflowType varchar(20)
AS
BEGIN
	--Additional data field
	DECLARE @TempDataField as TABLE
	(
		ReferenceNo varchar(50),
		SerialNo varchar(10),
		DataFieldName varchar(255),
		DataFieldValue varchar(max)
	)

	IF(@WorkflowType = 'Claim')
	BEGIN
		--Set CanvasName and WorkflowStageDescription
		DECLARE @CanvasName varchar(100),
				@WorkflowStageDescription varchar(50)

		SELECT TOP 1 @CanvasName = CanvasName
			,@WorkflowStageDescription = WorkflowStageDescription
		FROM Claim.WTWorkflowDataField
		WHERE ReferenceNo = @ReferenceNo
			AND SerialNo = @SerialNo
			AND WorkflowStageCode = @WorkflowStageCode

		IF(@WorkflowStageCode = 'SCSQAP') --Sub Claim Section QA Process
		BEGIN
			DECLARE @SubClaimSectionID varchar(100),
				@IsNeedQA varchar(5),
				@IsDocumentCompleted varchar(5),
				@SCSType varchar(3),
				@IsClaimInterim varchar(5),
				@ClaimCommercialDepartmentHeadUser varchar(25),
				@RevisionNo bigint,
				@LogIDHeadUser dbo.value
			
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
			
			INSERT INTO @TempDataField
			VALUES 
			(@ReferenceNo,@SerialNo,'SubClaimSectionID',@SubClaimSectionID),
			(@ReferenceNo,@SerialNo,'IsNeedQA',@IsNeedQA),
			(@ReferenceNo,@SerialNo,'IsDocumentCompleted',@IsDocumentCompleted),
			(@ReferenceNo,@SerialNo,'SCSType',@SCSType),
			(@ReferenceNo,@SerialNo,'IsClaimInterim',@IsClaimInterim),
			(@ReferenceNo,@SerialNo,'ClaimCommercialDepartmentHeadUser',@ClaimCommercialDepartmentHeadUser)

			--Merge to Claim.WTWorkflowDataField
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
		ELSE IF (@WorkflowStageCode = 'LNCREA') --Create LN
		BEGIN
			--Add datafield IsAutoCreateEstimation = False (default)
			INSERT INTO @TempDataField
			VALUES (@ReferenceNo,@SerialNo,'IsAutoCreateEstimation','False')	
			
			INSERT INTO Claim.WTWorkflowDataField (ReferenceNo, SerialNo, CanvasName, WorkflowStageCode, WorkflowStageDescription, DataFieldName, DataFieldValue, CreatedBy, CreateDate, RowStatus)
			SELECT ReferenceNo
				,SerialNo
				,@CanvasName
				,@WorkflowStageCode
				,@WorkflowStageDescription
				,DataFieldName
				,DataFieldValue
				,'System'
				,GETDATE()
				,0
			FROM @TempDataField T
			WHERE NOT EXISTS (
					SELECT 1
					FROM Claim.WTWorkflowDataField
					WHERE ReferenceNo = T.ReferenceNo
						AND SerialNo = T.SerialNo
						AND DataFieldName = T.DataFieldName
						AND RowStatus = 0
					)

			--Update value = 0 untuk field name RevisionNo jika value kosong
			UPDATE Claim.WTWorkflowDataField
			SET DataFieldValue = '0'
			WHERE ReferenceNo = @ReferenceNo
				AND SerialNo = @SerialNo
				AND DataFieldName = 'RevisionNo'
				AND LEN(LTRIM(RTRIM(DataFieldValue))) = 0
		END
	END
	
END
GO

GRANT EXEC ON General.usp_InsertAdditionalWTWorkflowDataField TO PUBLIC
GO