/* ======================================================================================
   #115  Health conditions roster for staff
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Health & compliance
   Type:      List · Priority 2 · Run BOY
   Purpose:   For each section meeting on @asOf, the rostered students who have a current
              health condition flagged for staff. Shows the condition name and whether
              an action plan is on file, nothing else.
   Output:    One row per student, section and condition: course, section, teacher,
              condition, action plan (Yes / No)
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, Trial, Roster,
              Section, Course, SectionPlacement, Term, HealthCondition,
              HealthConditionList
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     IC has no action-plan checkbox on a health condition, so Action Plan = Yes
              when the condition's Instructions field is filled; confirm that is where
              your nurses record plans. Current condition = flagged, started, and not
              ended on @asOf (the Status field is not used). Sensitive: share each
              teacher only their own sections.
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
    SELECT e.personID, e.grade,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year], a.grade AS [Grade],
       co.number AS [Course Number], co.name AS [Course Name], se.number AS [Section Number],
       se.teacherDisplay AS [Teacher],
       COALESCE(hcl.description, hc.description) AS [Condition],
       CASE WHEN NULLIF(LTRIM(RTRIM(hc.instructions)), '') IS NOT NULL THEN 'Yes' ELSE 'No' END AS [Action Plan]
FROM Trial t
JOIN Calendar c  ON c.calendarID = t.calendarID
JOIN School   s  ON s.schoolID   = c.schoolID
JOIN Section  se ON se.trialID   = t.trialID
JOIN Course   co ON co.courseID  = se.courseID
JOIN Roster   r  ON r.sectionID  = se.sectionID
JOIN act      a  ON a.personID   = r.personID AND a.rn = 1
JOIN HealthCondition hc ON hc.personID = r.personID
LEFT JOIN HealthConditionList hcl ON hcl.typeID = hc.typeID
JOIN Person p     ON p.personID   = r.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE t.active = 1
  AND c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND (r.startDate IS NULL OR r.startDate <= @asOf)
  AND (r.endDate   IS NULL OR r.endDate   >= @asOf)
  AND EXISTS (SELECT 1 FROM SectionPlacement sp
              JOIN Term tm ON tm.termID = sp.termID
              WHERE sp.sectionID = se.sectionID
                AND (tm.startDate IS NULL OR tm.startDate <= @asOf)
                AND (tm.endDate   IS NULL OR tm.endDate   >= @asOf))
  AND hc.flagged = 1
  AND hc.startDate <= @asOf
  AND (hc.endDate IS NULL OR hc.endDate >= @asOf)
ORDER BY s.name, co.number, se.number, i.lastName, i.firstName;
