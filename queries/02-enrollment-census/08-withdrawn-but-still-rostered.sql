/* ======================================================================================
   #22  Withdrawn but still rostered
   --------------------------------------------------------------------------------------
   Status:    Confirmed good
   Category:  Enrollment & census
   Type:      Validation · Priority 1 · Run Ongoing
   Purpose:   Active-trial roster rows left open, or ending after the student's last
              enrollment end in that calendar.
   Output:    One row per roster row: enrollment end, course, section, roster dates, issue
   Tables:    Calendar, School, Enrollment, Trial, Section, Course, Roster, Person, Identity
   Params:    @endYear, @schoolID  (change them in the PARAMETERS block below)
   Check:     Uses the latest enrollment end per calendar, so a re-enrolled student isn't
              flagged.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
-- ===========================================================================

WITH lastEnr AS (   -- each student's latest enrollment end per calendar
    SELECT e.personID, e.calendarID, MAX(e.grade) AS grade,
           MAX(e.endDate) AS lastEnd,
           MAX(CASE WHEN e.endDate IS NULL THEN 1 ELSE 0 END) AS stillEnrolled
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    WHERE c.endYear = @endYear
    GROUP BY e.personID, e.calendarID
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       le.grade AS [Grade],
       CONVERT(date, le.lastEnd) AS [Enrollment End],
       co.number AS [Course Number], co.name AS [Course Name], se.number AS [Section Number],
       CONVERT(date, r.startDate) AS [Roster Start], CONVERT(date, r.endDate) AS [Roster End],
       CASE WHEN r.endDate IS NULL THEN 'Roster still open after withdrawal'
            ELSE 'Roster ends after enrollment ended' END AS [Issue]
FROM lastEnr le
JOIN Calendar c ON c.calendarID = le.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Trial    t ON t.calendarID = c.calendarID AND t.active = 1
JOIN Roster   r ON r.trialID = t.trialID AND r.personID = le.personID
JOIN Section se ON se.sectionID = r.sectionID
JOIN Course  co ON co.courseID  = se.courseID
JOIN Person   p ON p.personID   = le.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE le.stillEnrolled = 0
  AND (r.endDate IS NULL OR r.endDate > le.lastEnd)
  AND (r.startDate IS NULL OR r.startDate <= le.lastEnd)
  AND c.exclude = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
ORDER BY s.name, i.lastName, co.number;
