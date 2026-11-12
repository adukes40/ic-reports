/* ======================================================================================
   #90  Two open records for one program
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Special programs
   Type:      Validation · Priority 2 · Run Ongoing
   Purpose:   Active students with two or more open (no end date) records for the same
              program: program participation, EL, homeless, foster care, Section 504 or
              special ed status.
   Output:    One row per student per program: school, grade, program, number of open
              records, their start dates, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, ProgramParticipation, Program,
              Lep, Homeless, FosterCare, Section504, SpecialEDState, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Open means no end date (no exit date for EL; no end and no exit date for
              special ed status; 504 records with a did-not-qualify date are left out).
              Meal eligibility is not included because there are no meal eligibility
              records in IC here (POSEligibility is empty).
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per student on @asOf
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
),
openRec AS (   -- every open record, from program participation and each program's own table
    SELECT pp.personID, pp.programID AS programKey, CAST(pr.name AS varchar(60)) AS program,
           CONVERT(date, pp.startDate) AS startDate
    FROM ProgramParticipation pp
    JOIN Program pr ON pr.programID = pp.programID
    WHERE pp.endDate IS NULL
    UNION ALL
    SELECT l.personID, -1, 'EL', CONVERT(date, l.identifiedDate) FROM Lep l WHERE l.exitDate IS NULL
    UNION ALL
    SELECT h.personID, -2, 'Homeless', CONVERT(date, h.startDate) FROM Homeless h WHERE h.endDate IS NULL
    UNION ALL
    SELECT f.personID, -3, 'Foster care', CONVERT(date, f.startDate) FROM FosterCare f WHERE f.endDate IS NULL
    UNION ALL
    SELECT g.personID, -4, 'Section 504', CONVERT(date, g.startDate) FROM Section504 g
    WHERE g.endDate IS NULL AND g.dnqDate IS NULL
    UNION ALL
    SELECT ss.personID, -5, 'Special ed status', ss.startDate FROM SpecialEDState ss
    WHERE ss.endDate IS NULL AND ss.exitDate IS NULL
),
dup AS (   -- students with two or more open records for one program
    SELECT personID, programKey, program, COUNT(*) AS openRecords,
           STRING_AGG(COALESCE(CONVERT(varchar(10), startDate, 23), 'no date'), ', ')
               WITHIN GROUP (ORDER BY startDate) AS startDates
    FROM openRec
    GROUP BY personID, programKey, program
    HAVING COUNT(*) >= 2
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       d.program AS [Program], d.openRecords AS [Open Records], d.startDates AS [Start Dates],
       CAST(d.openRecords AS varchar(10)) + ' open records for the same program' AS [Issue]
FROM act a
JOIN dup d        ON d.personID   = a.personID
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE a.rn = 1
ORDER BY a.schoolName, d.program, a.grade, i.lastName, i.firstName;
