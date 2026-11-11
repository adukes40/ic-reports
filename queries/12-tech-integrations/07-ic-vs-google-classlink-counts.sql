/* ======================================================================================
   #135  IC vs. Google / ClassLink counts
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Tech, integrations & security
   Type:      Validation · Priority 2 · Run Weekly
   Purpose:   The Infinite Campus side of a count comparison with Google or ClassLink:
              active students by school and grade, plus teachers with sections and active
              sections by school, and a district total.
   Output:    One row per school per grade (students only), one row per school with Grade
              = 'All' (students, teachers with sections, active sections), and one
              District total row
   Tables:    SchoolYear, Enrollment, Calendar, School, Trial, Section, Roster,
              SectionStaffHistory
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     This is only the IC half: pull the user and class counts from Google or
              ClassLink and compare them by hand. Students are counted once, at the school
              of their active primary enrollment. An active section is an active-trial
              section with at least one student rostered on @asOf, so sections for a later
              term count as soon as they have students. Teachers are the staff on those
              sections' staff history who are current on @asOf (all staff types); a teacher
              at two schools counts in each school but once in the District total.
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
    SELECT e.personID, c.schoolID, s.name AS schoolName, e.grade,
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
sec AS (   -- active-trial sections with at least one student rostered on @asOf
    SELECT se.sectionID, c.schoolID, s.name AS schoolName
    FROM Trial t
    JOIN Calendar c ON c.calendarID = t.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    JOIN Section se ON se.trialID   = t.trialID
    WHERE t.active = 1
      AND c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND EXISTS (SELECT 1 FROM Roster r
                  WHERE r.sectionID = se.sectionID AND r.trialID = t.trialID
                    AND (r.startDate IS NULL OR r.startDate <= @asOf)
                    AND (r.endDate IS NULL OR r.endDate >= @asOf))
),
teach AS (   -- staff current on those sections on @asOf
    SELECT DISTINCT sec.schoolID, h.personID
    FROM sec
    JOIN SectionStaffHistory h ON h.sectionID = sec.sectionID
    WHERE (h.startDate IS NULL OR h.startDate <= @asOf)
      AND (h.endDate IS NULL OR h.endDate >= @asOf)
),
sch AS (   -- every school that has students or sections
    SELECT schoolID, schoolName FROM act WHERE rn = 1
    UNION
    SELECT schoolID, schoolName FROM sec
)
SELECT a.schoolID AS [School ID], a.schoolName AS [School], @endYear AS [School Year],
       a.grade AS [Grade],
       COUNT(*) AS [Active Students],
       CAST(NULL AS int) AS [Teachers With Sections],
       CAST(NULL AS int) AS [Active Sections]
FROM act a
WHERE a.rn = 1
GROUP BY a.schoolID, a.schoolName, a.grade
UNION ALL
SELECT sch.schoolID, sch.schoolName, @endYear, 'All',
       (SELECT COUNT(*) FROM act a WHERE a.rn = 1 AND a.schoolID = sch.schoolID),
       (SELECT COUNT(*) FROM teach t WHERE t.schoolID = sch.schoolID),
       (SELECT COUNT(*) FROM sec WHERE sec.schoolID = sch.schoolID)
FROM sch
UNION ALL
SELECT NULL, 'District total', @endYear, 'All',
       (SELECT COUNT(*) FROM act a WHERE a.rn = 1),
       (SELECT COUNT(DISTINCT t.personID) FROM teach t),
       (SELECT COUNT(*) FROM sec)
ORDER BY CASE WHEN [School ID] IS NULL THEN 1 ELSE 0 END, [School],
         CASE WHEN [Grade] = 'All' THEN 1 ELSE 0 END, [Grade];
