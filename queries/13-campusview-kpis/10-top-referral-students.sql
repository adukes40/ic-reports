/* ======================================================================================
   #148  Top referral students
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  CampusView KPIs
   Type:      List · Run Monthly
   Purpose:   The students with the most offender referrals this year, with the date of
              their latest referral.
   Output:    One row per student: grade, school, offender referrals, latest referral date
   Tables:    SchoolYear, BehaviorRole, BehaviorEvent, BehaviorIncident, Calendar, School,
              Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @topN (50), @offenderRoles  (change them in the
              PARAMETERS block below)
   Check:     A referral is one event with the student in one of the @offenderRoles roles;
              the role names must match your BehaviorRole.role values. Each student is one
              row however many schools they attended: the count covers all schools, and
              School and Grade come from their latest enrollment this year (@schoolID
              filters on that school).
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear       int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID      int = NULL;   -- NULL = all schools
DECLARE @topN          int = 50;     -- how many students to return
DECLARE @offenderRoles varchar(200) = 'Offender';   -- role names counted as the offender, comma-separated
-- ===========================================================================

WITH ref AS (   -- one row per student per event where the student is an offender
    SELECT DISTINCT br.personID, be.eventID, bi.timestamp
    FROM BehaviorRole br
    JOIN BehaviorEvent be    ON be.eventID = br.eventID
    JOIN BehaviorIncident bi ON bi.incidentID = be.incidentID
    JOIN Calendar c          ON c.calendarID = be.calendarID
    JOIN School   s          ON s.schoolID   = c.schoolID
    WHERE br.role IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@offenderRoles, ','))
      AND c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
),
perStudent AS (   -- referral count and latest referral date per student
    SELECT personID, COUNT(*) AS referrals, MAX(timestamp) AS latestReferral
    FROM ref
    GROUP BY personID
)
SELECT TOP (@topN)
       p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       en.schoolID AS [School ID], en.schoolName AS [School], en.endYear AS [School Year], en.grade AS [Grade],
       ps.referrals AS [Offender Referrals],
       CONVERT(date, ps.latestReferral) AS [Latest Referral Date]
FROM perStudent ps
JOIN Person p     ON p.personID   = ps.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (SELECT TOP 1 c.schoolID, s.name AS schoolName, c.endYear, e.grade   -- latest enrollment this year, primary first
             FROM Enrollment e
             JOIN Calendar c ON c.calendarID = e.calendarID
             JOIN School   s ON s.schoolID   = c.schoolID
             WHERE e.personID = ps.personID
               AND c.endYear = @endYear
               AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
             ORDER BY CASE WHEN e.serviceType = 'P' THEN 0 ELSE 1 END, e.startDate DESC) en
WHERE (@schoolID IS NULL OR en.schoolID = @schoolID)
ORDER BY ps.referrals DESC, ps.latestReferral DESC, i.lastName, i.firstName;
