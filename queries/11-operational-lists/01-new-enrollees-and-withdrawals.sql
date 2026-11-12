/* ======================================================================================
   #118  New enrollees and withdrawals
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Operational lists
   Type:      List · Priority 1 · Run On request
   Purpose:   Everyone who entered or left a school in a date range, with school, grade and
              the start or end status. Used by front offices, counselors and nurses.
   Output:    One row per enrollment start or end in the range: direction (Entered / Left),
              date, grade, service type, start and end status, start and end dates
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity,
              EnrollmentStartStatusType, EnrollmentEndStatusType
   Params:    @endYear, @schoolID, @startDate, @endDate  (change them in the PARAMETERS
              block below)
   Check:     The default range is the last 7 days. A range that covers the first or last
              day of school lists every student. A student who changed schools shows twice:
              Left one school, Entered the other. Service type P = primary.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear   int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID  int  = NULL;   -- NULL = all schools
DECLARE @endDate   date = CONVERT(date, GETDATE());      -- last day of the range
DECLARE @startDate date = DATEADD(day, -7, @endDate);    -- first day of the range
-- ===========================================================================

WITH moves AS (   -- one row per enrollment start or end that falls in the date range
    SELECT e.enrollmentID, x.direction, x.moveDate
    FROM Enrollment e
    CROSS APPLY (VALUES ('Entered', e.startDate), ('Left', e.endDate)) x(direction, moveDate)
    WHERE ISNULL(e.noShow, 0) = 0
      AND x.moveDate >= @startDate AND x.moveDate < DATEADD(day, 1, @endDate)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year], e.grade AS [Grade],
       m.direction AS [Direction], CONVERT(date, m.moveDate) AS [Date],
       e.serviceType AS [Service Type],
       e.startStatus AS [Start Status], sst.name AS [Start Status Name],
       e.endStatus AS [End Status], est.name AS [End Status Name],
       CONVERT(date, e.startDate) AS [Start Date], CONVERT(date, e.endDate) AS [End Date]
FROM moves m
JOIN Enrollment e ON e.enrollmentID = m.enrollmentID
JOIN Calendar c   ON c.calendarID   = e.calendarID
JOIN School   s   ON s.schoolID     = c.schoolID
JOIN Person p     ON p.personID     = e.personID
JOIN [Identity] i ON i.identityID   = p.currentIdentityID
LEFT JOIN EnrollmentStartStatusType sst ON sst.typeID = e.localStartStatusTypeID
LEFT JOIN EnrollmentEndStatusType   est ON est.typeID = e.localEndStatusTypeID
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
ORDER BY s.name, m.direction, m.moveDate, i.lastName, i.firstName;
