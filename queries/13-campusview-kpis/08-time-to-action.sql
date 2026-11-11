/* ======================================================================================
   #146  Time to action / time to resolve
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  CampusView KPIs
   Type:      KPI · Run Monthly
   Purpose:   Per school, the mean and median days from the incident date to the date each
              resolution was assigned. Resolutions dated before their incident are counted
              separately and left out of the averages.
   Output:    One row per school: resolutions, resolutions used, negative durations
              excluded, total days, mean days, median days
   Tables:    SchoolYear, BehaviorResolution, BehaviorRole, BehaviorEvent, BehaviorIncident,
              Calendar, School
   Params:    @endYear, @schoolID  (change them in the PARAMETERS block below)
   Check:     Days run from BehaviorIncident.timestamp to BehaviorResolution.discAssignDate.
              A non-zero Negative Durations Excluded means resolutions dated before their
              incident; fix those dates. The school is the one on the event's calendar.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
-- ===========================================================================

WITH res AS (   -- one row per resolution: days from incident date to resolution assign date
    SELECT c.schoolID, s.name AS schoolName, c.endYear,
           DATEDIFF(day, bi.timestamp, r.discAssignDate) AS days
    FROM BehaviorResolution r
    JOIN BehaviorRole br     ON br.roleID = r.roleID
    JOIN BehaviorEvent be    ON be.eventID = br.eventID
    JOIN BehaviorIncident bi ON bi.incidentID = be.incidentID
    JOIN Calendar c          ON c.calendarID = be.calendarID
    JOIN School   s          ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
),
withMedian AS (   -- adds the school median over durations of zero days or more
    SELECT res.*,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CASE WHEN days >= 0 THEN days END)
               OVER (PARTITION BY schoolID) AS medianDays
    FROM res
)
SELECT schoolID AS [School ID], schoolName AS [School], endYear AS [School Year],
       COUNT(*) AS [Resolutions],
       SUM(CASE WHEN days >= 0 THEN 1 ELSE 0 END) AS [Resolutions Used],
       SUM(CASE WHEN days <  0 THEN 1 ELSE 0 END) AS [Negative Durations Excluded],
       SUM(CASE WHEN days >= 0 THEN days END)     AS [Total Days],
       CAST(AVG(CASE WHEN days >= 0 THEN 1.0 * days END) AS decimal(7,1)) AS [Mean Days],
       CAST(MAX(medianDays) AS decimal(7,1))      AS [Median Days]
FROM withMedian
GROUP BY schoolID, schoolName, endYear
ORDER BY schoolName;
