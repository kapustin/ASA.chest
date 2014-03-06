CREATE OR REPLACE FUNCTION "ch"."processEmptyRequest"(
    @code long varchar default isnull(nullif(replace(http_header('Authorization'), 'Bearer ', ''),''), http_variable('authorization:'))
)
returns xml
begin

    declare @result xml;
    declare @isPushAuth BOOL;
    declare @uacID int;
    
    set @uacID = uac.accountInfo(@code);
    set @isPushAuth = 0;
    
    if exists (
        select 1 where uac.accountInfo(@code) regexp '.*(@upushauth)$'
    ) then
        
        set @isPushAuth = 1;
        
        set @result = (
            select top 1 xmldata
            from ch.entity
            where author = uac.accountInfo(@code)
              and name = 'STGTSettings'
            order by ts desc
        );
        
    end if;
    
    if @result is not null then
        return @result;
    end if;
    
    set @result = xmlelement('d'
        , xmlattributes ('STGTSettings' as "name")
        , xmlconcat(
            
            (select top 1 (
                select xmlagg(xmldatum)
                    from openxml(xmlData,'*/*') with (
                        name varchar(32) '@name'
                        , xmldatum xml '@mp:xmltext'
                    ) where name not in (
                        'ts'
                        , 'distanceFilter', 'requiredAccuracy', 'timeFilter'
                        , 'syncInterval', 'fetchLimit', 'syncServerURI'
                        , 'trackerAutoStart', 'trackerStartTime'
                        , 'trackerFinishTime', 'checkingBattery','localAccessToSettings','transterLogs'
                    )
                    
                ) as xmlData
                
                from ch.entity
                where name = 'STGTSettings'
                order by id
            )
            
            , xmlelement(
                'double'
                , xmlattributes ('distanceFilter' as "name")
                , if @isPushAuth = 1 then 15 else 35 endif
            )
            , xmlelement(
                'double'
                , xmlattributes ('timeFilter' as "name")
                , 8
            )
            , xmlelement(
                'double'
                , xmlattributes ('requiredAccuracy' as "name")
                , 50
            )
            , xmlelement(
                'double'
                , xmlattributes ('fetchLimit' as "name")
                , 20
            )
            , xmlelement(
                'double'
                , xmlattributes ('syncInterval' as "name")
                , 240
            )
            , xmlelement(
                'string'
                , xmlattributes ('syncServerURI' as "name")
                , 'https://asa0.unact.ru/chest'
            )
            , xmlelement(
                'double'
                , xmlattributes ('trackerAutoStart' as "name")
                , if @isPushAuth = 1 then 0 else 1 endif
            )
            , xmlelement(
                'double'
                , xmlattributes ('trackerStartTime' as "name")
                , 7
            )
            , xmlelement(
                'double'
                , xmlattributes ('trackerFinishTime' as "name")
                , 21
            ) 
            , xmlelement(
                'double'
                , xmlattributes ('checkingBattery' as "name")
                , 0
            )
            , xmlelement(
                'double'
                , xmlattributes ('localAccessToSettings' as "name")
                , 0
            )
            , xmlelement(
                'double'
                , xmlattributes ('transterLogs' as "name")
                , 1
            )
            , xmlelement(
                'string'
                , xmlattributes ('supportedApplicationVersions' as "name")
                , '2.4.1R,2.4.2R' --'any'
            )
            , xmlelement(
                'string'
                , xmlattributes ('lastApplicationVarsion' as "name")
                , '2.4.2R'/*if @uacID in (71,73,6) then '2.4.0T1' else '2.4.0R' endif*/
            )
            , xmlelement(
                'double'
                , xmlattributes ('transterLogsPriority' as "name")
                , if @uacID = 73 then 15 else 100 endif
            )
    ));
    
    set @result = (
        select
            xmlelement('d'
                , xmlattributes ('STGTSettings' as "name")
                , xmlagg(
                    if r.[key] is not null
                    then xmlelement(
                        if isnumeric(r.value) = 1
                        then 'double'
                        else 'string' endif,
                        xmlattributes(r.[key] as "name"), r.value)
                    else t.xmldatum endif
                )
            )
        from openxml(@result,'/*/*') with (
                name varchar(32) '@name',
                xmldatum xml '@mp:xmltext'
            ) as t
        left outer join uac.roleData(@code,'STGTSettings') as r on t.name = r.[key]
    );

    return @result;
    
end
