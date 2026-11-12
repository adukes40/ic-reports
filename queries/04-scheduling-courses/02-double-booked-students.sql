/* ======================================================================================
   #43  Double-booked students
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Scheduling & courses
   Type:      Validation · Priority 1 · Run BOY
   Purpose:   Students rostered on @asOf into two or more sections that meet in the same
              period of the same term and period schedule (day).
   Output:    One row per student, term and period: number of sections and which ones
   Tables:    SchoolYear, Trial, Calendar, School, Roster, Section, Course,
              SectionPlacement, Term, Period, PeriodSchedule, Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Only rosters active on @asOf are compared, in every term of the year.
              Intended overlaps (pull-out services, lunch or advisory sharing a period)
              will show.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH placed AS (   -- one row per student, section, term and period for rosters active on @asOf
    SELECT DISTINCT r.personID, t.calendarID, sp.termID, sp.periodID, se.sectionID,
           co.number + '-' + CAST(se.number AS varchar(6)) + ' ' + co.name AS sectionLabel
    FROM Trial t
    JOIN Calendar c ON c.calendarID = t.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    JOIN Roster   r ON r.trialID    = t.trialID
    JOIN Section se ON se.sectionID = r.sectionID
    JOIN Course  co ON co.courseID  = se.courseID
    JOIN SectionPlacement sp ON sp.sectionID = se.sectionID
    WHERE t.active = 1
      AND c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND (r.startDate IS NULL OR r.startDate <= @asOf)
      AND (r.endDate IS NULL OR r.endDate >= @asOf)
),
clash AS (   -- student, term and period combinations holding more than one section
    SELECT personID, calendarID, termID, periodID,
           COUNT(*) AS sections,
           STRING_AGG(CAST(sectionLabel AS varchar(max)), '; ') WITHIN GROUP (ORDER BY sectionLabel) AS sectionList
    FROM placed
    GROUP BY personID, calendarID, termID, periodID
    HAVING COUNT(*) > 1
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year], g.grade AS [Grade],
       tm.name AS [Term], ps.name AS [Period Schedule], pd.name AS [Period],
       k.sections AS [Sections], k.sectionList AS [Section List],
       'Rostered into ' + CAST(k.sections AS varchar(10)) + ' sections in the same term and period' AS [Issue]
FROM clash k
JOIN Calendar c        ON c.calendarID = k.calendarID
JOIN School   s        ON s.schoolID   = c.schoolID
JOIN Term tm           ON tm.termID    = k.termID
JOIN Period pd         ON pd.periodID  = k.periodID
JOIN PeriodSchedule ps ON ps.periodScheduleID = pd.periodScheduleID
JOIN Person p          ON p.personID   = k.personID
JOIN [Identity] i      ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 e.grade             -- latest enrollment in that calendar
             FROM Enrollment e
             WHERE e.personID = k.personID AND e.calendarID = k.calendarID
             ORDER BY e.startDate DESC) g
ORDER BY s.name, i.lastName, i.firstName, tm.seq, ps.seq, pd.seq;
