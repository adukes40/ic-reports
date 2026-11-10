/* ======================================================================================
   #14  Immunization compliance
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Delaware DOE
   Type:      List · Priority 2 · Run BOY
   Purpose:   Active students IC marks non-compliant, with vaccines short, exemptions on
              file and next dose due.
   Output:    One row per student: school, grade, vaccines short, list missing, exemptions,
              next dose due, last checked
   Tables:    Calendar, School, Enrollment, v_ImmComplianceStatusList, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Depends on IC's compliance job. If last checked is old, run the job first.
              Uses STRING_AGG (SQL Server 2017 or later).
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH act AS (
    SELECT e.enrollmentID, e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND e.serviceType = 'P'
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
),
nc AS (
    SELECT v.personID, v.enrollmentID, v.vaccineCode, v.vaccineAbbreviation,
           v.finalComplianceStatus, v.exemption, v.districtExemptionCode, v.stateExemptionCode,
           v.inProgressNextDoseDate, v.lastChecked
    FROM v_ImmComplianceStatusList v
    WHERE v.endYear = @endYear AND v.nonCompliant = 1
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       COUNT(*) AS [Vaccines Short],
       STRING_AGG(COALESCE(nc.vaccineAbbreviation, nc.vaccineCode), ', ') AS [Vaccines Missing],
       STRING_AGG(CASE WHEN nc.exemption = 1
                       THEN COALESCE(nc.vaccineAbbreviation, nc.vaccineCode) + ':' +
                            COALESCE(nc.stateExemptionCode, nc.districtExemptionCode, '?') END, ', ') AS [Exemptions On File],
       CONVERT(date, MIN(nc.inProgressNextDoseDate)) AS [Next Dose Due],
       CONVERT(date, MAX(nc.lastChecked))            AS [Compliance Last Checked]
FROM nc
JOIN act a ON a.enrollmentID = nc.enrollmentID
JOIN Person p ON p.personID = nc.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
GROUP BY p.studentNumber, i.lastName, i.firstName, a.schoolID, a.schoolName, a.endYear, a.grade
ORDER BY a.schoolName, a.grade, i.lastName;
