------ Deployment

---- Deploy CLR DLL

-- Set up the database
sp_configure 'clr enabled', 1;       
GO       
RECONFIGURE;       
GO  

-- Register and test Power BI Stream C# CLR DLL (ASSEMBLY) -Change path according to your needs
drop PROCEDURE dbo.spSendPowerBiStream;
GO

drop ASSEMBLY PowerBiStream;
GO

create ASSEMBLY PowerBiStream     
        FROM 'C:\SQL2019\Shared\CLR\PowerBiStream\PowerBiStream.dll'     
        WITH PERMISSION_SET = UNSAFE;  
GO

CREATE PROCEDURE dbo.spSendPowerBiStream(@InValue float)     
AS EXTERNAL NAME PowerBiStream.StoredProcedures.spSendPowerBiStream; 
GO

EXEC dbo.spSendPowerBiStream @InValue = 20
GO

--------------------------------------------------------------------------

---- Deploy SQL Server Service Broker message queue and test-table

-- Set up messaging, further reading: https://www.sqlshack.com/using-the-sql-server-service-broker-for-asynchronous-processing/

ALTER DATABASE PdaStreaming 
SET ENABLE_BROKER
with rollback immediate; -- terminates all connections, otherwise db cannot be altered

CREATE MESSAGE TYPE NewInsert
AUTHORIZATION dbo
VALIDATION = None

CREATE CONTRACT postmessages
(NewInsert SENT BY ANY)

CREATE QUEUE InsertQueue
WITH STATUS = ON, RETENTION = OFF

CREATE SERVICE InsertTriggerAsyncService
AUTHORIZATION dbo 
ON QUEUE InsertQueue
(postmessages)

-- sample table with timestamp and trigger
CREATE TABLE [dbo].[Production] (
    [LineID] int NOT NULL IDENTITY(1,1) PRIMARY KEY,
	[Qty] int,
	[timestamp] datetime2
)

ALTER TABLE [dbo].[Production] ADD CONSTRAINT
DF_Production_Inserted DEFAULT GETDATE() FOR [timestamp]
GO

CREATE TRIGGER InsertAsyncTrigger
ON [dbo].[Production]
AFTER INSERT
AS
BEGIN
    DECLARE @XMLMessage XML

    --Creating the XML Message
    SELECT @XMLMessage = '<ID><LineID>' + CAST((SELECT @@Identity) AS NVARCHAR(MAX)) + '</LineID></ID>';
 
    DECLARE @Handle UNIQUEIDENTIFIER;
    
	--Sending the Message to the Queue
    BEGIN
        DIALOG CONVERSATION @Handle
        FROM SERVICE InsertTriggerAsyncService TO SERVICE 'InsertTriggerAsyncService' ON CONTRACT [postmessages]
    WITH ENCRYPTION = OFF;
 
    SEND ON CONVERSATION @Handle MESSAGE TYPE NewInsert(@XMLMessage);
END
GO

-- Activation stored procedure

-- =============================================
-- Author:		Martin Bubenheimer
-- Create date: 8/23/23
-- Description:	Stored procedure for activation upon new message in service broker queue
-- =============================================
CREATE PROCEDURE [dbo].[spMonitorStreamingQueue] 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Handle UNIQUEIDENTIFIER ;
	DECLARE @MessageType SYSNAME ;
	DECLARE @Message XML
	DECLARE @ID INT 
	DECLARE @TotalQty FLOAT

	WHILE (1=1)
	BEGIN

		BEGIN TRANSACTION;

		WAITFOR( RECEIVE TOP (1)  
		@Handle = conversation_handle,
		@MessageType = message_type_name,
		@Message = message_body FROM dbo.InsertQueue),TIMEOUT 1000
 
		IF (@@ROWCOUNT = 0)
		BEGIN
		    ROLLBACK TRANSACTION;
		    BREAK;
		END

		SET @ID = CAST(CAST(@Message.query('/ID/LineID/text()') AS NVARCHAR(MAX)) AS INT)
		SET @TotalQty = (SELECT SUM([Qty]) FROM [dbo].[Production] WHERE [LineID] <= @ID)

		IF @ID IS NOT NULL EXEC dbo.spSendPowerBiStream @InValue = @TotalQty

		COMMIT TRANSACTION;
	END
END
GO

-- Activate message consumer for async processing
ALTER QUEUE InsertQueue  
    WITH ACTIVATION (  
		STATUS = ON,
        PROCEDURE_NAME = spMonitorStreamingQueue,
		MAX_QUEUE_READERS = 1,
        EXECUTE AS SELF
	);  

-- test queue
INSERT INTO Production (Qty) VALUES (1)

-- check what's in the queue (if ACTIVATION is set up correctly, you won't see anything here)
SELECT service_name
,priority,
queuing_order,
service_contract_name,
message_type_name,
validation,
message_body,
message_enqueue_time,
status
FROM dbo.InsertQueue
