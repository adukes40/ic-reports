/* ======================================================================================
   Database inventory: which tables and columns actually hold data
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Type:      Tool (not part of the query library; it is not published on the site)
   Purpose:   Lists every table and column in the database with how many rows it has and
              how many of them hold a value, so new queries get built against tables the
              district really uses.
   Output:    One row per column of every table that has rows, and one row per empty
              table. Names and counts only: no student, staff or any other record values
              are ever returned.
   Tables:    sys.tables, sys.schemas, sys.columns, sys.types, sys.partitions, then every
              table that has rows
   Params:    @tableLike, @sampleRows  (change them in the PARAMETERS block below)
   Check:     Reads every table once, so run it outside the school day. Tables bigger than
              @sampleRows are sampled, so their counts are estimates (Note says Sampled).
              It uses a loop and dynamic SQL; if the data extract tool refuses it, run it
              in SQL Server Management Studio or ask for the tables-only version.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file, paste it into IC's data extract tool, and save the
   result as CSV. Try @tableLike = N'Enroll%' first to see that it runs.
   ====================================================================================== */

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;   -- the XML step below needs it; some tools connect with it off

-- ===== PARAMETERS ==========================================================
DECLARE @tableLike  nvarchar(128) = N'%';      -- N'%' = every table; N'Enroll%' = only tables starting with Enroll
DECLARE @sampleRows bigint        = 200000;    -- tables with more rows than this are sampled; NULL = read every row (slow)
-- ===========================================================================

DECLARE @tab TABLE (objectID int PRIMARY KEY, schemaName sysname, tableName sysname,
                    tableRows bigint, sampled bit, fromSql nvarchar(600), note nvarchar(100) NULL);
DECLARE @col TABLE (objectID int, columnID int, columnName sysname, typeName sysname,
                    maxLength int, allowsNull bit, aggSql nvarchar(1000),
                    PRIMARY KEY (objectID, columnID));
DECLARE @res TABLE (objectID int, columnID int, rowsChecked bigint, filled bigint, varies int,
                    PRIMARY KEY (objectID, columnID));

INSERT INTO @tab (objectID, schemaName, tableName, tableRows, sampled, fromSql)
SELECT t.object_id, s.name, t.name, r.tableRows,
       CASE WHEN r.tableRows > @sampleRows THEN 1 ELSE 0 END,
       QUOTENAME(s.name) + N'.' + QUOTENAME(t.name)
       + CASE WHEN r.tableRows > @sampleRows
              THEN N' TABLESAMPLE (' + CAST(@sampleRows AS nvarchar(20)) + N' ROWS)' ELSE N'' END
       + N' WITH (NOLOCK)'                      -- never block the live system; counts may be a hair off
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
CROSS APPLY (SELECT ISNULL(SUM(p.rows), 0) AS tableRows
             FROM sys.partitions p
             WHERE p.object_id = t.object_id AND p.index_id IN (0, 1)) r
WHERE t.is_ms_shipped = 0
  AND t.name LIKE @tableLike;

-- One "has a value" count and one "more than one value" test per column, by kind of data type.
-- Blank text counts as empty. Only counts and a yes/no leave the table, never a value.
INSERT INTO @col (objectID, columnID, columnName, typeName, maxLength, allowsNull, aggSql)
SELECT c.object_id, c.column_id, c.name, ISNULL(bt.name, ut.name),
       CASE WHEN bt.name IN (N'nchar', N'nvarchar') AND c.max_length > 0 THEN c.max_length / 2 ELSE c.max_length END,
       c.is_nullable,
       CASE
         WHEN bt.name IN (N'char', N'varchar', N'nchar', N'nvarchar') AND c.max_length <> -1
           THEN N'COUNT_BIG(NULLIF(' + q.col + N', '''')) AS f' + q.id
              + N', CASE WHEN MIN(' + q.col + N') <> MAX(' + q.col + N') THEN 1 ELSE 0 END AS v' + q.id
         WHEN bt.name = N'bit'
           THEN N'COUNT_BIG(' + q.col + N') AS f' + q.id
              + N', CASE WHEN MIN(CAST(' + q.col + N' AS tinyint)) <> MAX(CAST(' + q.col + N' AS tinyint)) THEN 1 ELSE 0 END AS v' + q.id
         WHEN bt.name IN (N'tinyint', N'smallint', N'int', N'bigint', N'decimal', N'numeric', N'money',
                          N'smallmoney', N'float', N'real', N'date', N'datetime', N'datetime2',
                          N'smalldatetime', N'datetimeoffset', N'time', N'uniqueidentifier')
           THEN N'COUNT_BIG(' + q.col + N') AS f' + q.id
              + N', CASE WHEN MIN(' + q.col + N') <> MAX(' + q.col + N') THEN 1 ELSE 0 END AS v' + q.id
         ELSE   -- long text, binary, xml and other types MIN/MAX can't compare: filled only
                N'COUNT_BIG(CASE WHEN DATALENGTH(' + q.col + N') > 0 THEN 1 END) AS f' + q.id
              + N', CAST(NULL AS int) AS v' + q.id
       END
FROM sys.columns c
JOIN @tab t             ON t.objectID = c.object_id AND t.tableRows > 0
JOIN sys.types ut       ON ut.user_type_id = c.user_type_id
LEFT JOIN sys.types bt  ON bt.user_type_id = c.system_type_id      -- base type behind an alias type
CROSS APPLY (SELECT QUOTENAME(c.name) AS col, CAST(c.column_id AS nvarchar(10)) AS id) q;

DECLARE @objectID int, @fromSql nvarchar(600), @aggs nvarchar(max), @vals nvarchar(max), @sql nvarchar(max);

DECLARE tabs CURSOR LOCAL FAST_FORWARD FOR
    SELECT objectID, fromSql FROM @tab WHERE tableRows > 0 ORDER BY objectID;
OPEN tabs;
FETCH NEXT FROM tabs INTO @objectID, @fromSql;
WHILE @@FETCH_STATUS = 0
BEGIN
    -- one pass over the table computes every column's counts
    SELECT @aggs = (SELECT N', ' + aggSql FROM @col WHERE objectID = @objectID ORDER BY columnID
                    FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'),
           @vals = (SELECT N', (' + id + N', x.n, x.f' + id + N', x.v' + id + N')'
                    FROM (SELECT columnID, CAST(columnID AS nvarchar(10)) AS id FROM @col WHERE objectID = @objectID) k
                    ORDER BY columnID
                    FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)');
    SET @sql = N'SELECT ' + CAST(@objectID AS nvarchar(12)) + N', v.c, v.n, v.f, v.v'
             + N' FROM (SELECT COUNT_BIG(*) AS n' + @aggs + N' FROM ' + @fromSql + N') x'
             + N' CROSS APPLY (VALUES ' + STUFF(@vals, 1, 2, N'') + N') v(c, n, f, v);';
    BEGIN TRY
        INSERT INTO @res (objectID, columnID, rowsChecked, filled, varies)
        EXEC sys.sp_executesql @sql;
    END TRY
    BEGIN CATCH   -- error number only: an error message could quote a value from the table
        UPDATE @tab SET note = N'Could not read this table (SQL error ' + CAST(ERROR_NUMBER() AS nvarchar(10)) + N')'
        WHERE objectID = @objectID;
    END CATCH;
    FETCH NEXT FROM tabs INTO @objectID, @fromSql;
END;
CLOSE tabs;
DEALLOCATE tabs;

SELECT t.schemaName AS [Schema], t.tableName AS [Table], t.tableRows AS [Table Rows],
       c.columnName AS [Column], c.columnID AS [Column Order], c.typeName AS [Data Type],
       c.maxLength AS [Max Length], c.allowsNull AS [Allows Null],
       r.rowsChecked AS [Rows Checked], r.filled AS [Rows With A Value],
       CAST(100.0 * r.filled / NULLIF(r.rowsChecked, 0) AS decimal(5, 1)) AS [Percent Filled],
       r.varies AS [More Than One Value],
       CASE WHEN t.note IS NOT NULL THEN t.note
            WHEN t.tableRows = 0    THEN 'Empty table'
            WHEN t.sampled = 1      THEN 'Sampled'
            ELSE '' END AS [Note]
FROM @tab t
LEFT JOIN @col c ON c.objectID = t.objectID
LEFT JOIN @res r ON r.objectID = c.objectID AND r.columnID = c.columnID
ORDER BY t.schemaName, t.tableName, c.columnID;
