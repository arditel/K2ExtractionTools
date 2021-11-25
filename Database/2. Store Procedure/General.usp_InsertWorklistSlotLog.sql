USE BeyondDB
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		AEK
-- Create date: 2021/11/08
-- Description:	Backup WorklistSlot data #248URF2021
-- =============================================
CREATE PROCEDURE General.usp_InsertWorklistSlotLog
	-- Add the parameters for the stored procedure here
	@ReferenceNo VARCHAR(50),
	@WorkflowStage VARCHAR(50),
	@WorkflowType VARCHAR(20),
	@HeaderID int,
	@ProcInstID int,
	@ActInstID int,
	@SlotFieldID int,
	@EventInstID int,
	@ActionerID int,
	@Status tinyint,
	@Verify bit,
	@AllocDate datetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	Insert General.WorklistSlotLog
	(
		ReferenceNo,
		WorkflowStage,
		WorkflowType,
		[HeaderID],
		[ProcInstID],
		[ActInstID],
		[SlotFieldID],
		[EventInstID],
		[ActionerID],
		[Status],
		[Verify],
		[AllocDate],
		CreatedBy,
		CreatedDate
	)
	VALUES
	(
		@ReferenceNo,
		@WorkflowStage,
		@WorkflowType,
		@HeaderID,
		@ProcInstID,
		@ActInstID,
		@SlotFieldID,
		@EventInstID,
		@ActionerID,
		@Status,
		@Verify,
		@AllocDate,
		'System',
		GETDATE()
	)
END
GO

GRANT EXEC ON General.usp_InsertWorklistSlotLog TO PUBLIC
GO
