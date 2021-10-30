--2301853275 - Ignatius Hansen

--1. Create a new job with the following detail:
USE [msdb]
GO

/****** Object:  Job [Cake Transaction Monthly Report]    Script Date: 7/6/2021 14:35:42 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 7/6/2021 14:35:42 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Cake Transaction Monthly Report', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Generate monthly report of all cake transactions that occur', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [LaNiceStep]    Script Date: 7/6/2021 14:35:42 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'LaNiceStep', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SELECT TransactionDate, [Total Item Sold] = (COUNT(dt.Quantity)),
[Gross Income] = (SUM (CakePrice * Quantity) - SUM(CakePrice * Discount / 100))

FROM Cake c
JOIN DetailTransaction dt ON c.CakeID = dt.CakeID
JOIN HeaderTransaction ht ON ht.TransactionID = dt.TransactionID
GROUP BY TransactionDate', 
		@database_name=N'LaNice', 
		@output_file_name=N'LaNiceReport.txt', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'LaNiceSchedule', 
		@enabled=0, 
		@freq_type=16, 
		@freq_interval=28, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=3, 
		@active_start_date=20210607, 
		@active_end_date=99991231, 
		@active_start_time=30000, 
		@active_end_time=235959, 
		@schedule_uid=N'45805a18-defc-4959-ba23-8dd9f7bc54e4'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

--2. Create a stored procedure named “DeleteCake” to delete data in Cake table in accordance with the CakeID inputted by user. The stored procedure parameter is CakeID. Validate CakeID inputted by the user must exists in Cake table. If it’s not, then show “Cake doesn't exist” message and no row will be deleted. Then, if the CakeID is exist, delete that data and show “Selected Cake has been deleted!” message.
GO
CREATE PROC DeleteCake @cakeid CHAR(5) AS
	IF EXISTS(SELECT * FROM Cake WHERE CakeID = @cakeid)
	BEGIN
		DELETE Cake WHERE CakeID = @cakeid
		PRINT 'Selected Cake has been deleted!'
	END
	ELSE
		PRINT 'Cake with ID ' + @cakeid + ' doesn''t exist'


--SELECT * FROM Cake WHERE CakeID ='CK005'

--BEGIN TRAN
--EXEC DeleteCake 'CK005'
--SELECT * FROM Cake WHERE CakeID ='CK005'
--ROLLBACK

--EXEC DeleteCake 'CK005'

--3. Create a stored procedure named “SalesReport” that contains a cursor to display the list of cake in “LaNice” database for the selected Cake. 
GO
ALTER PROC SalesReport @id char(5) AS
 DECLARE salesCur CURSOR
 FOR SELECT CakeName, CakePrice, CAST(Quantity AS numeric), Discount
  FROM Cake c 
  JOIN DetailTransaction dt ON c.CakeID = dt.CakeID
  JOIN HeaderTransaction ht ON ht.TransactionID = dt.TransactionID
  JOIN Staff s ON s.StaffID = ht.StaffID 
 WHERE ht.TransactionID = @id

 DECLARE @date varchar(30), @staffName VARCHAR(100)
 SET @date = (SELECT TransactionDate FROM HeaderTransaction ht
 JOIN Staff s ON ht.StaffID = s.StaffID WHERE TransactionID = @id)
 SET @staffName = (SELECT StaffName 
 FROM HeaderTransaction ht
 JOIN Staff s ON ht.StaffID = s.StaffID
 WHERE TransactionID = @id)

 OPEN salesCur
 DECLARE @cakeName VARCHAR(MAX), @cakePrice INT = 0, @quantity INT = 0, @discount INT = 0, @subTotal INT = 0, @totalPrice INT = 0, @totalSales INT = 0
  PRINT 'La Nice Cake Shop'
  PRINT '============================'
  PRINT 'Date: ' + @date
  PRINT 'Staff: ' + @staffName
  PRINT '----------------------------'
 
 FETCH NEXT FROM salesCur INTO @cakeName, @cakePrice, @quantity, @discount

 WHILE @@FETCH_STATUS = 0
 BEGIN
  SELECT 
   CakeName, CakePrice, CAST(Quantity AS numeric), Discount
  FROM Cake c 
  JOIN DetailTransaction dt ON c.CakeID = dt.CakeID
  JOIN HeaderTransaction ht ON ht.TransactionID = dt.TransactionID
  JOIN Staff s ON s.StaffID = ht.StaffID

  SET @subTotal = (@quantity * @cakePrice) - (@cakePrice * @quantity * @discount / 100)
  SET @totalPrice += @subTotal
  SET @totalSales += @quantity

  PRINT CAST(@quantity AS VARCHAR) + ' ' + @cakeName + ' @ ' + CAST (@cakePrice AS VARCHAR)
  PRINT 'Discount: ' + CAST(@discount AS VARCHAR) + '%'
  PRINT 'After Discount: ' + CAST(@subtotal AS VARCHAR)

  FETCH NEXT FROM salesCur INTO @cakeName, @cakePrice, @quantity, @discount
 END

 PRINT '------------------------------'
 PRINT 'Total Cake: ' + CAST (@totalSales AS VARCHAR)
 PRINT 'Total Price: ' + CAST(@totalPrice AS VARCHAR)

 CLOSE salesCur
 DEALLOCATE salesCur

 GO
 
EXEC SalesReport 'TR001'
	
EXEC SalesReport 'TR001'

		
--4. Create a trigger named “UpdateTrigger” to display the record before and after updating data from Cake for every time user does an update on the Cake table. Show “Cake Name”, “Cake Price” and “Cake Description” before and after updated data in the “Messages” tab.
GO
CREATE TRIGGER UpdateTrigger ON Cake
FOR UPDATE AS
	SELECT * FROM deleted
	UNION
	SELECT * FROM inserted 

	DECLARE @befName varchar(100), @aftName varchar(100), @befPrice VARCHAR(MAX), @aftPrice VARCHAR(MAX), @befDesc VARCHAR(MAX), @aftDesc VARCHAR(MAX)

	SET @befName = (SELECT CakeName FROM deleted)
	SET @aftName = (SELECT CakeName FROM inserted)
	SET @befPrice = (SELECT CakePrice FROM deleted)
	SET @aftPrice = (SELECT CakePrice FROM inserted)
	SET @befDesc = (SELECT CakeDescription FROM deleted)
	SET @aftDesc = (SELECT CakeDescription FROM inserted)

	IF EXISTS(SELECT * FROM deleted)
		BEGIN
			PRINT 'Update Cake'
			PRINT '==========='
			PRINT 'Name: ' + @befName + ' -> ' + @aftName
			PRINT 'Price: ' + @befPrice + ' -> ' + @aftPrice
			PRINT 'Name: ' + @befDesc + ' -> ' + @aftDesc
		END

--BEGIN TRAN
--UPDATE Cake
--SET
--CakeName = 'Chocolate Cake',
--CakePrice = 500000,
--CakeDescription = 'Chocolate cake or chocolate gâteau is a cake flavored with melted chocolate, cocoa powder, or both.'
---WHERE CakeID = 'CK003'
--ROLLBACK
