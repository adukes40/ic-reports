/* ======================================================================================
   #3  Grade level not in calendar
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Enrollment & census
   Type:      Validation · Priority 1 · Run BOY
   Purpose:   Current-year enrollments whose grade isn't set up in that calendar and
              schedule structure.
   Output:    One row per enrollment: grade, dates, grades the calendar offers, issue
   Tables:    Calendar, School, Enrollment, GradeLevel, Person, Identity
   Params:    @endYear, @schoolID  (change them in the PARAMETERS block below)
   Check:     Compares Enrollment.grade to GradeLevel.name for the same calendar and
              structure.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
-- ===========================================================================

SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       e.grade AS [Grade], e.serviceType AS [Service Type],
       CONVERT(date, e.startDate) AS [Start Date], CONVERT(date, e.endDate) AS [End Date],
       (SELECT STRING_AGG(g2.name, ', ') WITHIN GROUP (ORDER BY g2.seq)
          FROM GradeLevel g2
         WHERE g2.calendarID = e.calendarID AND g2.structureID = e.structureID) AS [Grades Offered],
       CASE WHEN NULLIF(LTRIM(RTRIM(e.grade)), '') IS NULL THEN 'Enrollment has no grade'
            ELSE 'Grade not set up in this calendar' END AS [Issue]
FROM Enrollment e
JOIN Calendar c ON c.calendarID = e.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = e.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND NOT EXISTS (SELECT 1 FROM GradeLevel g
                  WHERE g.calendarID = e.calendarID AND g.structureID = e.structureID
                    AND g.name = e.grade)
ORDER BY s.name, e.grade, i.lastName;
