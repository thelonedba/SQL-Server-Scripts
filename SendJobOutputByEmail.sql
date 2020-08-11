USE master;
SET QUOTED_IDENTIFIER ON;
IF OBJECT_ID('SendJobOutput', 'P') IS NULL
    EXEC ('CREATE PROCEDURE SendJobOutput AS BEGIN SELECT 1 END');
GO
ALTER PROCEDURE SendJobOutput
    @StartDate INT,
    @StartTime INT,
    @job_name sysname,
    @recipients VARCHAR(MAX)
AS
BEGIN
    /*
    SP: SendJobOutput
    Parameters:
            @StartDate int - msdb-formatted date at which the job starts
            @StartTime int - msdb-formatted time at which the job starts
            @job_name sysname
            @recipients varchar(max) - string full of semi-colon-separated email addresses to get the output message
    Usage:
                To be used in a SQL Agent job step:
            declare @StartDate int = CONVERT(int, $(ESCAPE_NONE(STRTDT)));
            declare @StartTime int = CONVERT(int, $(ESCAPE_NONE(STRTTM)));
            declare @job_name sysname = '$(ESCAPE_NONE(JOBNAME))';
            declare @recipients varchar(max) = 'user@address.bar; someoneelse@foo.com';

            exec SendJobOutput @StartDate, @StartTime, @job_name, @recipients
*/
    DECLARE @StartDateTime DATETIME = msdb.dbo.agent_datetime(@StartDate, @StartTime);
    DECLARE @Subject sysname = N'Job output - ' + @job_name;
    DECLARE @job_id UNIQUEIDENTIFIER =
            (
                SELECT job_id FROM msdb.dbo.sysjobs WHERE name = @job_name
            );
    DECLARE @message NVARCHAR(MAX)
        = N'<html><body><table><tr><th>JobName</th><th>DateTime</th><th>Step Name</th><th>Message</th></tr>';
    DECLARE @results NVARCHAR(MAX) = N'';
    SELECT @results = @results + STUFF(
                                 (
                                     SELECT j.name AS TD,
                                            '',
                                            msdb.dbo.agent_datetime(run_date, run_time) AS TD,
                                            '',
                                            jh.step_name AS TD,
                                            '',
                                            message AS TD
                                     FROM msdb.dbo.sysjobs j
                                         INNER JOIN msdb.dbo.sysjobhistory jh
                                             ON j.job_id = jh.job_id
                                     WHERE 1 = 1
                                           AND msdb.dbo.agent_datetime(run_date, run_time) >= @StartDateTime
                                           AND jh.job_id = @job_id
                                     ORDER BY msdb.dbo.agent_datetime(run_date, run_time),
                                              step_id
                                     FOR XML PATH('TR'), ELEMENTS
                                 ),
                                 1,
                                 0,
                                 ''
                                      );
    SELECT @message = @message + @results + N'</table></body></html>';
    EXEC msdb.dbo.sp_send_dbmail @profile_name = 'DoNotReply - SQLMail', -- name of email profile already defined in msdb.dbo.sysmail_profile
                                 @recipients = @recipients,
                                 @subject = @Subject,
                                 @body_format = 'HTML',
                                 @body = @message;
END;
