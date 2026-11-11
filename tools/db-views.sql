/* ======================================================================================
   Database inventory: views and their columns
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Type:      Tool (not part of the query library; it is not published on the site)
   Purpose:   Lists every view in the database with its columns and data types, so queries
              that use Infinite Campus views (v_AttDayDetail_Exact and so on) can be
              checked against the real column names. Companion to db-inventory.sql, which
              covers tables.
   Output:    One row per view column. Names and data types only: it reads the database
              catalog and never opens a view, so no record values are returned.
   Tables:    sys.views, sys.schemas, sys.columns, sys.types
   Params:    none
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file, paste it into IC's data extract tool, and save the
   result as CSV.
   ====================================================================================== */

SELECT s.name AS [Schema], v.name AS [View], c.name AS [Column], c.column_id AS [Column Order],
       ISNULL(bt.name, ut.name) AS [Data Type],
       CASE WHEN bt.name IN (N'nchar', N'nvarchar') AND c.max_length > 0 THEN c.max_length / 2 ELSE c.max_length END AS [Max Length]
FROM sys.views v
JOIN sys.schemas s     ON s.schema_id = v.schema_id
JOIN sys.columns c     ON c.object_id = v.object_id
JOIN sys.types ut      ON ut.user_type_id = c.user_type_id
LEFT JOIN sys.types bt ON bt.user_type_id = c.system_type_id      -- base type behind an alias type
WHERE v.is_ms_shipped = 0
ORDER BY s.name, v.name, c.column_id;
