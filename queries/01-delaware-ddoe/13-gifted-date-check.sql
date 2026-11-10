/* ======================================================================================
   #13  Gifted date check
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Delaware DOE
   Type:      Validation · Priority 3 · Run Ongoing
   Purpose:   Gifted records whose identified date is after the start date, and students
              with more than one open Gifted record.
   Output:    One row per problem record: student, current school, grade, record dates,
              program area, issue
   Tables:    Calendar, School, Gifted, Enrollment, Person, Identity
   Params:    @endYear, @schoolID (current school)  (change them in the PARAMETERS block
              below)
   Check:     Students with no enrollment this year still appear, with a blank school,
              unless a school filter is set.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools (school = current primary enrollment)
-- ===========================================================================

WITH probs AS (
    SELECT g.personID, g.giftedID, g.startDate, g.endDate, g.identifiedDate, g.programArea,
           'Identified date is after start date' AS issue
    FROM Gifted g
    WHERE g.identifiedDate > g.startDate

    UNION ALL

    SELECT g.personID, g.giftedID, g.startDate, g.endDate, g.identifiedDate, g.programArea,
           'More than one open Gifted record'
    FROM Gifted g
    WHERE g.endDate IS NULL
      AND (SELECT COUNT(*) FROM Gifted g2 WHERE g2.personID = g.personID AND g2.endDate IS NULL) > 1
),
cur AS (
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear AND c.exclude = 0 AND s.exclude = 0
      AND e.serviceType = 'P'
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       cur.schoolID AS [School ID], cur.schoolName AS [School], cur.endYear AS [School Year], cur.grade AS [Grade],
       pr.giftedID AS [Gifted ID], pr.programArea AS [Program Area],
       CONVERT(date, pr.identifiedDate) AS [Identified Date],
       CONVERT(date, pr.startDate)      AS [Start Date],
       CONVERT(date, pr.endDate)        AS [End Date],
       pr.issue AS [Issue]
FROM probs pr
JOIN Person p ON p.personID = pr.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN cur ON cur.personID = pr.personID AND cur.rn = 1
WHERE (@schoolID IS NULL OR cur.schoolID = @schoolID)
ORDER BY cur.schoolName, pr.issue, i.lastName;
