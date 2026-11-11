/* ======================================================================================
   #145  Resolution mix
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  CampusView KPIs
   Type:      KPI · Run Monthly
   Purpose:   Counts this year's behavior resolutions by resolution type per school, with
              each type's share of the school's resolutions.
   Output:    One row per school per resolution type: code, resolutions, school
              resolutions, percent of school
   Tables:    SchoolYear, BehaviorResolution, BehaviorResType, Calendar, School
   Params:    @endYear, @schoolID  (change them in the PARAMETERS block below)
   Check:     Resolutions with no type show as (no type recorded) and those whose type ID is
              not in BehaviorResType show as (unrecognised type), so the rows for a school
              add up to all of its resolutions. The school is the one on the resolution's
              own calendar.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
-- ===========================================================================

WITH res AS (   -- every resolution this year with its type bucket
    SELECT c.schoolID, s.name AS schoolName, c.endYear,
           CASE WHEN r.typeID IS NULL  THEN '(no type recorded)'
                WHEN rt.typeID IS NULL THEN '(unrecognised type)'
                ELSE rt.name END AS resType,
           rt.code AS resCode
    FROM BehaviorResolution r
    JOIN Calendar c ON c.calendarID = r.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    LEFT JOIN BehaviorResType rt ON rt.typeID = r.typeID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
)
SELECT schoolID AS [School ID], schoolName AS [School], endYear AS [School Year],
       resType AS [Resolution Type], resCode AS [Resolution Code],
       COUNT(*) AS [Resolutions],
       SUM(COUNT(*)) OVER (PARTITION BY schoolID) AS [School Resolutions],
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY schoolID) AS decimal(5,1)) AS [Percent of School]
FROM res
GROUP BY schoolID, schoolName, endYear, resType, resCode
ORDER BY schoolName, [Resolutions] DESC, resType;
