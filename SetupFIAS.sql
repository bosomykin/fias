/*Bosomykin 25.12.2013
1. Создание линка на базу ФИАС в МДМ
2. Создание БД, Таблицы
3. Наполнение данными
*/

--1. Создание линка
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
--2. Создание базы
CREATE DATABASE DIR_FIAS;
GO