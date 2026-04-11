/*
select @@SERVERNAME
SELECT @@SERVERNAME AS SQLServerName;
SELECT SERVERPROPERTY('ServerName') AS ServerPropertyName;
SELECT SERVERPROPERTY('MachineName') AS MachineName;
SELECT SERVERPROPERTY('InstanceName') AS InstanceName;
SELECT srvid, srvname, * FROM msdb.dbo.sysservers;
Usar srvname en @server_name = 'ESE_NOMBRE'
@server_name = 'WIN-N158D1CONEK'
*/

USE msdb;
GO

DECLARE @jobId UNIQUEIDENTIFIER;

-- Si el job ya existe, eliminarlo primero
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Infra_SQL_Revocar_Permisos')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = N'Infra_SQL_Revocar_Permisos';
END

EXEC sp_add_job
     @job_name = N'Infra_SQL_Revocar_Permisos',
     @enabled = 1,
     @notify_level_eventlog = 0,
     @description = N'Revoca permisos temporales vencidos cada 15 minutos',
     @delete_level = 0,
     @job_id = @jobId OUTPUT;


------------------------------------------------------------
-- PASO DEL JOB
------------------------------------------------------------
EXEC sp_add_jobstep
    @job_id = @jobId,
    @step_name = N'Revocar permisos vencidos',
    @subsystem = N'TSQL',
    @command = N'EXEC master.dbo.sp_infra_revocar_permisos_expirados;',
    @retry_attempts = 0,
    @retry_interval = 0;


------------------------------------------------------------
-- HORARIO CADA 5 MINUTOS
------------------------------------------------------------
EXEC sp_add_jobschedule
    @job_id = @jobId,
    @name = N'Ejecucion_cada_15_min',
    @freq_type = 4,        -- diario
    @freq_interval = 1,
    @freq_subday_type = 4, -- minutos
    @freq_subday_interval = 15,
    @active_start_time = 000000;


EXEC sp_add_jobserver
    @job_id = @jobId,
    @server_name = @@SERVERNAME;
GO
