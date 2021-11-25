use BeyondDB
GO

/*POLICY*/
CREATE TABLE PolicyInsurance.WTWorkflowDataField
(
	WTWorkflowDataFieldID bigint IDENTITY(1,1) NOT NULL,
	ReferenceNo VARCHAR(50) NULL,
	SerialNo VARCHAR(10) NULL,
	CanvasName VARCHAR(100) NULL,
	WorkflowStageCode VARCHAR(8) NULL,
	WorkflowStageDescription VARCHAR(50) NULL,
	DataFieldName VARCHAR(255) NULL,
	DataFieldValue VARCHAR(MAX) NULL,
	CreatedBy VARCHAR(50) NOT NULL,
	CreateDate DATETIME NOT NULL,
	ModifiedBy VARCHAR(50) NULL,
	ModifiedDate DATETIME NULL,
	RowStatus smallint NOT NULL,
	CONSTRAINT [PK_WTWorkflowDataField] PRIMARY KEY CLUSTERED (WTWorkflowDataFieldID ASC) 
)
GO

ALTER TABLE PolicyInsurance.WTWorkflowDataField ADD  CONSTRAINT [DF_WTWorkflowDataField_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO

CREATE TABLE PolicyInsurance.WTWorkflowDataPIC
(
	WTWorkflowDataPICID bigint IDENTITY(1,1) NOT NULL,
	ReferenceNo VARCHAR(50) NULL,
	SerialNo VARCHAR(10) NULL,
	CanvasName VARCHAR(100) NULL,
	WorkflowStageCode VARCHAR(8) NULL,
	WorkflowStageDescription VARCHAR(50) NULL,
	PICUser VARCHAR(20) NULL,
	IsOpen BIT NULL,
	ItemOpenedDate datetime null,
	CreatedBy VARCHAR(50) NOT NULL,
	CreateDate DATETIME NOT NULL,
	ModifiedBy VARCHAR(50) NULL,
	ModifiedDate DATETIME NULL,
	RowStatus smallint NOT NULL,
	CONSTRAINT PK_WTWorkflowDataPIC PRIMARY KEY CLUSTERED (WTWorkflowDataPICID ASC)
)
GO

ALTER TABLE PolicyInsurance.WTWorkflowDataPIC ADD  CONSTRAINT [DF_WTWorkflowDataPIC_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE PolicyInsurance.WTWorkflowDataPIC ADD  CONSTRAINT [DF_WTWorkflowDataPIC_IsOpen]  DEFAULT (0) FOR [IsOpen]
GO

CREATE TABLE PolicyInsurance.WTWorkflowTaskData
(
	WTWorkflowTaskDataID bigint identity(1,1) not null,
	ReferenceNo VARCHAR(50) NULL,
	SerialNo VARCHAR(10) NULL,
	CanvasName VARCHAR(100) NULL,
	WorkflowStageCode VARCHAR(8) NULL,
	WorkflowStageDescription VARCHAR(50) NULL,
	Folio varchar(255) null,
	Originator varchar(100) null,
	Status varchar(10) null,
	StartDate datetime null,
	IsProcess smallint null,
	CreatedBy VARCHAR(50) not null,
	CreateDate DATETIME NOT NULL,
	ModifiedBy VARCHAR(50) NULL,
	ModifiedDate DATETIME NULL,
	RowStatus smallint NOT NULL,
	CONSTRAINT PK_WTWorkflowTaskData PRIMARY KEY CLUSTERED (WTWorkflowTaskDataID ASC)
)
GO

ALTER TABLE PolicyInsurance.WTWorkflowTaskData ADD CONSTRAINT [DF_WTWorkflowTaskData_RowStatus] DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE PolicyInsurance.WTWorkflowTaskData ADD CONSTRAINT [DF_WTWorkflowTaskData_IsProcess] DEFAULT ((0)) FOR [IsProcess]
GO


/*CLAIM*/
CREATE TABLE Claim.WTWorkflowDataField
(
	WTWorkflowDataFieldID bigint IDENTITY(1,1) NOT NULL,
	ReferenceNo VARCHAR(50) NULL,
	SerialNo VARCHAR(10) NULL,
	CanvasName VARCHAR(100) NULL,
	WorkflowStageCode VARCHAR(8) NULL,
	WorkflowStageDescription VARCHAR(50) NULL,
	DataFieldName VARCHAR(255) NULL,
	DataFieldValue VARCHAR(MAX) NULL,
	CreatedBy VARCHAR(50) NOT NULL,
	CreateDate DATETIME NOT NULL,
	ModifiedBy VARCHAR(50) NULL,
	ModifiedDate DATETIME NULL,
	RowStatus smallint NOT NULL,
	CONSTRAINT [PK_WTWorkflowDataField] PRIMARY KEY CLUSTERED (WTWorkflowDataFieldID ASC) 
)
GO

ALTER TABLE Claim.WTWorkflowDataField ADD CONSTRAINT [DF_WTWorkflowDataField_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO

CREATE TABLE Claim.WTWorkflowDataPIC
(
	WTWorkflowDataPICID bigint IDENTITY(1,1) NOT NULL,
	ReferenceNo VARCHAR(50) NULL,
	SerialNo VARCHAR(10) NULL,
	CanvasName VARCHAR(100) NULL,
	WorkflowStageCode VARCHAR(8) NULL,
	WorkflowStageDescription VARCHAR(50) NULL,
	PICUser VARCHAR(20) NULL,
	IsOpen BIT NULL,
	ItemOpenedDate datetime null,
	CreatedBy VARCHAR(50) NOT NULL,
	CreateDate DATETIME NOT NULL,
	ModifiedBy VARCHAR(50) NULL,
	ModifiedDate DATETIME NULL,
	RowStatus smallint NOT NULL,
	CONSTRAINT PK_WTWorkflowDataPIC PRIMARY KEY CLUSTERED (WTWorkflowDataPICID ASC)
)
GO

ALTER TABLE Claim.WTWorkflowDataPIC ADD  CONSTRAINT [DF_WTWorkflowDataPIC_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE Claim.WTWorkflowDataPIC ADD  CONSTRAINT [DF_WTWorkflowDataPIC_IsOpen]  DEFAULT (0) FOR [IsOpen]
GO

CREATE TABLE Claim.WTWorkflowTaskData
(
	WTWorkflowTaskDataID bigint identity(1,1) not null,
	ReferenceNo VARCHAR(50) NULL,
	SerialNo VARCHAR(10) NULL,
	CanvasName VARCHAR(100) NULL,
	WorkflowStageCode VARCHAR(8) NULL,
	WorkflowStageDescription VARCHAR(50) NULL,
	Folio varchar(255) null,
	Originator varchar(100) null,
	Status varchar(10) null,
	StartDate datetime null,
	IsProcess smallint null,
	CreatedBy VARCHAR(50) not null,
	CreateDate DATETIME NOT NULL,
	ModifiedBy VARCHAR(50) NULL,
	ModifiedDate DATETIME NULL,
	RowStatus smallint NOT NULL,
	CONSTRAINT PK_WTWorkflowTaskData PRIMARY KEY CLUSTERED (WTWorkflowTaskDataID ASC)
)
GO

ALTER TABLE Claim.WTWorkflowTaskData ADD CONSTRAINT [DF_WTWorkflowTaskData_RowStatus] DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE Claim.WTWorkflowTaskData ADD CONSTRAINT [DF_WTWorkflowTaskData_IsProcess] DEFAULT ((0)) FOR [IsProcess]
GO

CREATE TABLE General.WorklistSlotLog
(
	WorklistSlotLogID bigint identity(1,1) not null,
	ReferenceNo VARCHAR(50) null,
	WorkflowStage VARCHAR(50) null,
	WorkflowType VARCHAR(20) null,
	[HeaderID] [int] not null,
	[ProcInstID] [int] not null,
	[ActInstID] [int] null,
	[SlotFieldID] [int] null,
	[EventInstID] [int] null,
	[ActionerID] [int] null,
	[Status] [tinyint] not null,
	[Verify] [bit] null,
	[AllocDate] [datetime] null,
	CreatedBy VARCHAR(50) not null,
	CreatedDate DATETIME not null,
	ModifiedBy VARCHAR(50) null,
	ModifiedDate DATETIME null,
	RowStatus smallint not null,
	CONSTRAINT PK_WorklistSlotLog PRIMARY KEY CLUSTERED (WorklistSlotLogID ASC)
)
GO

ALTER TABLE General.WorklistSlotLog ADD CONSTRAINT [DF_WorklistSlotLog_RowStatus] DEFAULT (0) FOR [RowStatus]
GO
