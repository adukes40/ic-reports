/* ======================================================================================
   #45  Section roster dates outside enrollment
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Scheduling & courses
   Type:      Validation · Priority 2 · Run Ongoing
   Purpose:   Roster rows in the active trial whose start date is before the student's
              enrollment start, or whose end date is after the enrollment end.
   Output:    One row per roster row: course, section, roster dates, enrollment dates
   Tables:    SchoolYear, Enrollment, Calendar, School, Trial, Roster, Section, Course,
              Person, Identity
   Params:    @endYear, @schoolID  (change them in the PARAMETERS block below)
   Check:     Only roster dates that are filled in are checked; a blank roster date means
              the section's own start or end. A roster date that falls in a gap between
              two enrollments in the same calendar is reported too. Open rosters left
              after a withdrawal are in the withdrawn-but-still-rostered query.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
-- ===========================================================================

WITH enr AS (   -- each student's first enrollment start and last enrollment end per calendar
    SELECT e.personID, e.calendarID, MAX(e.grade) AS grade,
           MIN(e.startDate) AS firstStart,
           CASE WHEN COUNT(*) = COUNT(e.endDate) THEN MAX(e.endDate) END AS lastEnd
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    WHERE c.endYear = @endYear
      AND ISNULL(e.noShow, 0) = 0
    GROUP BY e.personID, e.calendarID
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year], en.grade AS [Grade],
       co.number AS [Course Number], co.name AS [Course Name], se.number AS [Section Number],
       CONVERT(date, r.startDate) AS [Roster Start], CONVERT(date, r.endDate) AS [Roster End],
       CONVERT(date, en.firstStart) AS [Enrollment Start], CONVERT(date, en.lastEnd) AS [Enrollment End],
       CASE WHEN x.badStart = 1 AND x.badEnd = 1 THEN 'Roster start and end dates are outside the enrollment dates'
            WHEN x.badStart = 1 THEN 'Roster start date is outside the enrollment dates'
            ELSE 'Roster end date is outside the enrollment dates' END AS [Issue]
FROM enr en
JOIN Calendar c ON c.calendarID = en.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Trial    t ON t.calendarID = c.calendarID AND t.active = 1
JOIN Roster   r ON r.trialID = t.trialID AND r.personID = en.personID
JOIN Section se ON se.sectionID = r.sectionID
JOIN Course  co ON co.courseID  = se.courseID
JOIN Person   p ON p.personID   = en.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (SELECT
        CASE WHEN r.startDate IS NOT NULL AND NOT EXISTS (
                 SELECT 1 FROM Enrollment e
                 WHERE e.personID = en.personID AND e.calendarID = en.calendarID AND ISNULL(e.noShow, 0) = 0
                   AND e.startDate <= r.startDate AND (e.endDate IS NULL OR e.endDate >= r.startDate))
             THEN 1 ELSE 0 END AS badStart,
        CASE WHEN r.endDate IS NOT NULL AND NOT EXISTS (
                 SELECT 1 FROM Enrollment e
                 WHERE e.personID = en.personID AND e.calendarID = en.calendarID AND ISNULL(e.noShow, 0) = 0
                   AND e.startDate <= r.endDate AND (e.endDate IS NULL OR e.endDate >= r.endDate))
             THEN 1 ELSE 0 END AS badEnd) x
WHERE c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND (x.badStart = 1 OR x.badEnd = 1)
ORDER BY s.name, i.lastName, i.firstName, co.number;
