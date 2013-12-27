/*Bosomykin 25.12.2013

*/
USE [master]
GO
EXEC master.dbo.sp_addlinkedserver 
    @server = N'ASU-03-MDMDEV', 
    @srvproduct=N'SQL Server' ;
GO
EXEC master.dbo.sp_addlinkedsrvlogin 
    @rmtsrvname = N'ASU-03-MDMDEV', 
    @useself = False , 
    @rmtuser  = N'bdo' ,
    @rmtpassword = '12345678';
GO

CREATE DATABASE DIR_FIAS;
GO

CREATE LOGIN TEST_FIAS 
    WITH PASSWORD = '12345678';

USE [DIR_FIAS]
GO

/****** Object:  Table [dbo].[INDEX_FIAS_ADDR]    Script Date: 12/26/2013 08:51:46 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[INDEX_FIAS_ADDR](
	[FIAS_ID] [nvarchar](36) NOT NULL,
	[FORMALADDR] [nvarchar](1000) NULL,
	[OFFADDR] [nvarchar](1000) NULL,
	[AOLEVEL] [tinyint] NULL,
	[INLINEADDR] [nvarchar](1000) NULL
) ON [PRIMARY]

GO

INSERT INTO [DIR_FIAS].[dbo].[INDEX_FIAS_ADDR] (
 [FIAS_ID]
 ,[AOLEVEL]
 )
select fias_id, aolevel  from (
SELECT obj.aoguid AS fias_id
 ,cast(obj.aolevel AS TINYINT) AS 'aolevel',
 ROW_NUMBER() over (partition by obj.aoguid order by obj.aolevel) rn
FROM [ASU-03-MDMDEV].FIAS.[dbo].[ADDROBJ] obj
WHERE obj.currstatus = 0) t
where t.rn = 1

GO

CREATE TABLE [dbo].[DICTIONARY](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[GROUP] [int] NULL,
	[VARNAME] [nvarchar](100) NULL,
	[VALUE] [nvarchar](20) NOT NULL,
) ON [PRIMARY]

GO

CREATE UNIQUE CLUSTERED INDEX [IDX_FIAS_IDFIAS] ON [dbo].[INDEX_FIAS_ADDR] 
(
	[FIAS_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

ALTER TABLE [dbo].[DICTIONARY] ADD PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

GO

INSERT INTO [DIR_FIAS].[dbo].[DICTIONARY] (
 [GROUP]
 ,[VARNAME]
 ,[VALUE]
 )
SELECT
 1 AS 'GROUP'
 ,'SHORTNAME' AS VARNAME
 ,sub.shortname AS VALUE
FROM (
 SELECT DISTINCT obj.shortname
 FROM [ASU-03-MDMDEV].FIAS.[dbo].[ADDROBJ] obj
 WHERE obj.currstatus = 0
  AND obj.shortname <> 'Чувашия'
 ) sub
 
 GO
 
CREATE USER TEST_FIAS FOR LOGIN TEST_FIAS;
GO 

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create FUNCTION [dbo].[getAddrFullInline] (@id nvarchar(36))
RETURNS nvarchar(200)
AS
BEGIN

declare @str nvarchar(200) = '';
declare @index nvarchar(10) = '';
SELECT 
@str = 
	CASE 
		WHEN aolevel < 4 THEN @str + offname + ' ' + shortname + '., '
		ELSE @str + shortname + '. ' + offname + ', '
    END,
@index = 
	case
		when aolevel > 4 THEN postalcode
		else @index
	end
FROM [dbo].[getAddrTableByAOGUID](@id)
if @index IS NOT NULL and len(@index) > 0 
	set @str = @str + @index
else
	set @str = STUFF(@str, len(@str) - 1, 3, '' ) 
return @str;
end;

GO

CREATE FUNCTION [dbo].[getAddrFullByAOGUID] (@id nvarchar(36))
RETURNS nvarchar(1000)
AS
BEGIN
	declare @result nvarchar(1000);
    with child_to_parents as (
	select street.* from [ASU-03-MDMDEV].FIAS.[dbo].[ADDROBJ] street
	where 
		street.aoguid = @id
		and street.currstatus = 0
	union all
	select obj.* from [ASU-03-MDMDEV].FIAS.[dbo].[ADDROBJ] obj, child_to_parents child
		where obj.aoguid = child.parentguid
        and obj.currstatus = 0
	)
select @result = (select 
cast(c.aolevel as tinyint) as 'aolevel', c.postalcode, c.shortname as shortname, c.offname as offname
from child_to_parents c
for xml path('adr'), root('xml'))

return @result;
end;

GO

Create FUNCTION [dbo].[getAddrByAOGUID] (@id nvarchar(36))
RETURNS TABLE
AS
RETURN 
(
    with child_to_parents as (
	select street.* from [ASU-03-MDMDEV].FIAS.[dbo].[ADDROBJ] street
	where 
		street.aoguid = @id
		and street.currstatus = 0
	union all
	select obj.* from [ASU-03-MDMDEV].FIAS.[dbo].[ADDROBJ] obj, child_to_parents child
		where obj.aoguid = child.parentguid
        and obj.currstatus = 0
)

select 
--c.plaincode,
--c.aoid, c.aoguid, c.parentguid, 
 upper(c.formalname) as formalname
--, c.offname, c.shortname
from child_to_parents c
--order by c.plaincode
--for xml path('')
);

GO

Create FUNCTION [dbo].[getAddrTableByAOGUID] (@id nvarchar(36))
RETURNS TABLE
AS
RETURN 
(
	with child_to_parents as (
	select street.* from [ASU-03-MDMDEV].FIAS.[dbo].[ADDROBJ] street
	where 
		street.aoguid = @id
		and street.currstatus = 0
	union all
	select obj.* from [ASU-03-MDMDEV].FIAS.[dbo].[ADDROBJ] obj, child_to_parents child
		where obj.aoguid = child.parentguid
        and obj.currstatus = 0
	)
select 
cast(c.aolevel as tinyint) as 'aolevel', 
c.postalcode as 'postalcode', 
c.shortname as shortname,
CASE
	WHEN c.offname is null THEN c.formalname
	ELSE c.offname
END AS 'offname'
from child_to_parents c
--for xml path('adr'), root('xml'))
);

GO 

CREATE FUNCTION [dbo].[getAddrFullFormalAddr] (@id nvarchar(36))
RETURNS nvarchar(200)
AS
BEGIN

declare @str nvarchar(200) = '';
declare @index nvarchar(10) = '';
SELECT 
@str = @str + offname + ' ',
@index = 
	case
		when aolevel > 4 THEN postalcode
		else @index
	end
FROM [dbo].[getAddrTableByAOGUID](@id)
if @index IS NOT NULL and len(@index) > 0 
	set @str = @str + @index
else
	set @str = rtrim(@str)
return @str;
end;

GO 

CREATE procedure [dbo].[UpdateFIAS] 
as
begin
declare @id nvarchar(36);
declare @frmInline nvarchar(1000);
declare @offInline nvarchar(1000);
declare @offXml nvarchar(1000);
declare frmCursor cursor for 
	select obj.fias_id 
	from dir_fias.dbo.index_fias_addr obj
	where obj.formaladdr is null
open frmCursor;
fetch next from frmCursor into @id
while (@@fetch_status <> -1)
begin
	begin transaction;
	set	@frmInline = [DIR_FIAS].[dbo].[getAddrFullFormalAddr] (@id)
	set @offInline = [DIR_FIAS].[dbo].[getAddrFullInline] (@id)
	set @offXml = [DIR_FIAS].[dbo].[getAddrFullByAOGUID] (@id)
	update dir_fias.dbo.index_fias_addr 
	set 
		formaladdr = @frmInline,
		offaddr = @offXml,
		inlineaddr = @offInline
	where fias_id = @id;
	commit transaction;
	fetch next from frmCursor into @id
end
close frmCursor;
DEALLOCATE frmCursor; 
end

GO

CREATE FULLTEXT CATALOG FIAS_FULLTEXT;

CREATE FULLTEXT INDEX ON dir_fias.dbo.index_fias_addr (formaladdr LANGUAGE 1049) KEY INDEX idx_fias_idfias ON FIAS_FULLTEXT
 WITH change_tracking manual

ALTER FULLTEXT INDEX ON dir_fias.dbo.index_fias_addr start FULL population
