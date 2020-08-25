CREATE FUNCTION [dbo].[JobStepOutput]
(
    @StartDate INT,
    @StartTime INT,
    @job_name sysname,
    @step_id INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    /*
	FN: JobStepOutput
	Parameters:
			@StartDate int - msdb-formatted date at which the job starts
			@StartTime int - msdb-formatted time at which the job starts
			@job_name sysname
			@step_id int - step to look at.  If zero, then all.

	Usage:
			To be used in a SQL Agent job step:

			declare @StartDate int = CONVERT(int, $(ESCAPE_NONE(STRTDT)));
			declare @StartTime int = CONVERT(int, $(ESCAPE_NONE(STRTTM)));
			declare @job_name sysname = '$(ESCAPE_NONE(JOBNAME))';
			declare @StepID int = CONVERT(int, $(ESCAPE_NONE(STEPID))) - 1;

			select JobStepOutput(@StartDate, @StartTime, @job_name, @StepID)

*/

    DECLARE @StartDateTime DATETIME = msdb.dbo.agent_datetime(@StartDate, @StartTime);
    DECLARE @job_id UNIQUEIDENTIFIER =
            (
                SELECT job_id FROM msdb.dbo.sysjobs WHERE name = @job_name
            );
    DECLARE @EndDateTime DATETIME =
            (
                SELECT ISNULL(MIN(msdb.dbo.agent_datetime(run_date, run_time)), GETDATE())
                FROM msdb.dbo.sysjobhistory
                WHERE msdb.dbo.agent_datetime(run_date, run_time) > @StartDateTime
                      AND job_id = @job_id
            );

    DECLARE @results NVARCHAR(MAX) = N'';

    SELECT @results = STUFF(
    (
        SELECT message
        FROM msdb.dbo.sysjobs j
            INNER JOIN msdb.dbo.sysjobhistory jh
                ON j.job_id = jh.job_id
        WHERE 1 = 1
              AND msdb.dbo.agent_datetime(run_date, run_time) >= @StartDateTime
              AND msdb.dbo.agent_datetime(run_date, run_time) < @EndDateTime
              AND jh.job_id = @job_id
              AND
              (
                  (
                      jh.step_id = @step_id
                      AND @step_id >= 0
                  )
                  OR (@step_id = -1)
              )
        ORDER BY msdb.dbo.agent_datetime(run_date, run_time),
                 step_id
        FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'),
    1   ,
    0   ,
    ''
                           );

    RETURN (@results);

END;
GO
