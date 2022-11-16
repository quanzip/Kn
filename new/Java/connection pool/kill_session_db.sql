WITH result AS (
    SELECT
        ss.username,
        se.sid,
        p.spid,
        ss.machine,
        ss.server,
        'alter system kill session '''
        || se.sid
        || ','
        || ss.serial#
        || ''';' kill_session
    FROM
        v$session    ss,
        v$sesstat    se,
        v$statname   sn,
        v$process    p
    WHERE
        se.statistic# = sn.statistic#
        AND name LIKE '%CPU used by this session%'
        AND se.sid = ss.sid
        AND ss.username IS NOT NULL
        AND paddr = addr
    ORDER BY
        value DESC
)
SELECT DISTINCT
    * from
    result
WHERE
    username = 'VOFFICE_KHDT';