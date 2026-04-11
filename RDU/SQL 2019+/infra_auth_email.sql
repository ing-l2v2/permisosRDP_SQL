USE [master]
GO
IF OBJECT_ID('dbo.infra_auth_email', 'U') IS NOT NULL
    DROP TABLE dbo.infra_auth_email;
GO
CREATE TABLE dbo.infra_auth_email (
    Id INT IDENTITY(1,1) PRIMARY KEY,            -- Clave primaria autoincremental
    fecha_correo DATETIME NOT NULL,              -- Fecha/hora del correo
    coduser_solic VARCHAR(10) NOT NULL,                        -- Numero del solicitante
    usr_solic VARCHAR(128) NOT NULL,             -- Nombre del solicitante
    coduser_auth VARCHAR(10) NOT NULL,                    -- Numero del aprobador
    usr_auth VARCHAR(128) NOT NULL,              -- Nombre del aprobador
    asunto NVARCHAR(MAX) NOT NULL,              -- Asunto del correo
    txt_solicitud NVARCHAR(MAX) NOT NULL,       -- Detalle completo de la solicitud (correo)
    txt_auth NVARCHAR(MAX) NOT NULL,            -- Detalle completo de la aprobación (correo)
    fecha_ins DATETIME NOT NULL DEFAULT GETDATE(),
    consumo INT NOT NULL DEFAULT 0,             -- Contador o flag de consumo
    CONSTRAINT UQ_solicitud UNIQUE (fecha_correo, usr_solic)  -- Evita duplicados
);
CREATE NONCLUSTERED INDEX IX_infra_auth_email_fecha_usr
ON dbo.infra_auth_email (fecha_ins, usr_solic)
INCLUDE (coduser_solic, coduser_auth, usr_auth);
CREATE NONCLUSTERED INDEX IX_infra_auth_email_fecha_coduser
ON dbo.infra_auth_email (fecha_ins, coduser_solic)
INCLUDE (usr_solic, coduser_auth, usr_auth);

SELECT * FROM dbo.infra_auth_email WHERE fecha_correo = @fecha AND @usr_solic;

exec sp_help infra_auth_email;
INSERT INTO infra_auth_email (fecha_correo, numreg_solic, usr_solic, numreg_auth, usr_auth, asunto, txt_solicitud, txt_auth) 
VALUES ('2026-03-24 12:14:03','','sbriones','','wgarcia','Re: Solicitud de Acceso',
'De: sbriones@fidenslat.com <sbriones@fidenslat.com> ** Enviado: Tuesday, March 24, 2026 2:10:59 PM ** Para: Wilmer Garcia <wgarcia@fidens-insurtech.com> ** Cc: ''Infraestructura'' <infraestructura@fidenslat.com> ** Asunto: Solicitud de Acceso  **   ** Buen día Wilmer, **   ** Solicto acceso RDP Admin a Zurich UAT para actualizar ambiente. **   **',
'Ok ** Obtener Outlook para iOS <https://aka.ms/o0ukef>  **');

SELECT COD_USER FROM ProyFidens.dbo.SYS_ACCOUNT WHERE TXT_ACC = 'sbriones'
SELECT COD_USER FROM ProyFidens.dbo.SYS_ACCOUNT WHERE TXT_ACC = 'wgarcia';

DECLARE @fecha DATETIME = '2026-03-24 12:14:03';
DECLARE @usuario VARCHAR(50) = 'sbriones';
DECLARE @usuario_auth VARCHAR(50) = 'wgarcia';
DECLARE @asunto NVARCHAR(max) = N'Re: Solicitud de Acceso';
DECLARE @txt_solicitud NVARCHAR(max) = N'De: sbriones@fidenslat.com <sbriones@fidenslat.com> ** Enviado: Tuesday, March 24, 2026 2:10:59 PM ** Para: Wilmer Garcia <wgarcia@fidens-insurtech.com> ** Cc: ''Infraestructura'' <infraestructura@fidenslat.com> ** Asunto: Solicitud de Acceso  **   ** Buen día Wilmer, **   ** Solicto acceso RDP Admin a Zurich UAT para actualizar ambiente. **   **';
DECLARE @txt_auth NVARCHAR(max) = 'Ok ** Obtener Outlook para iOS <https://aka.ms/o0ukef>  **';

INSERT INTO infra_auth_email (fecha_correo, coduser_solic, usr_solic, coduser_auth, usr_auth, asunto, txt_solicitud, txt_auth)
SELECT @fecha, (SELECT COD_USER FROM ProyFidens.dbo.SYS_ACCOUNT WHERE TXT_ACC = @usuario) AS coduser_solic, @usuario, (SELECT COD_USER FROM ProyFidens.dbo.SYS_ACCOUNT WHERE TXT_ACC = @usuario_auth), @usuario_auth, @asunto, @txt_solicitud, @txt_auth;

select * from infra_auth_email;


SELECT  
    CTA.AAC_IDENAAC AS NRO,
    SRV.ASE_IPPRIVADA AS SERVIDOR,
    CTA.ADM_IDPROY AS BD,
    LOWER(USR.TXT_ACC) AS USR,
    CONVERT(VARCHAR(10), CTA.ACC_FECHAFIN, 120) + ' ' + CTA.ACC_HORAFIN AS FFIN,
    -- CONVERT(VARCHAR(16), CTA.USU_SEG_FECHAINS, 120) AS FREG,
    CTA.AGE_SEG_CODIGO AS COD_USER,
    CTA.ESTADO,
    CTA.AAC_PERSMISO AS PERMISO,

    CASE WHEN LOWER(CTA.AAC_PERSMISO) LIKE '%rdp%' THEN
           CASE WHEN SRV.ASE_IPPRIVADA IN 
                 ('10.0.0.49','10.0.0.56','10.0.0.48','10.0.0.203',
                  '10.0.0.61','10.0.0.77','10.0.0.201')
                  THEN 'FIDENSLAT\' ELSE '.\' END
         ELSE '' END AS DOM,

    CASE WHEN LOWER(CTA.AAC_PERSMISO) LIKE '%rdp%' THEN 1 ELSE 0 END AS RDP,
    CASE WHEN LOWER(CTA.AAC_PERSMISO) LIKE '%sql%' THEN 1 ELSE 0 END AS SQL,
    CASE WHEN LOWER(CTA.AAC_PERSMISO) LIKE '%admin%' THEN 1 ELSE 0 END AS ADM,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
         AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% r %' OR LOWER( CTA.AAC_PERSMISO ) LIKE '%r%' )
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r / w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/ w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r /w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r, w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r,w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rwsp%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w, sp%'
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w, sm%'
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rwsm%'
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw sm%'
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw sp%' THEN 1 ELSE 0 END AS r,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
         AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% w %' OR LOWER( CTA.AAC_PERSMISO ) LIKE '% w %')
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r / w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/ w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r /w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r, w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r,w%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rwsp%' 
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w, sp%'
         AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw sp%' THEN 1 ELSE 0 END AS w,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
           AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% rw %' 
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%rw%'
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%r/w%'
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%r, w%'
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%r,w%'
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%r , w%'
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%r / w%'
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%r/ w%'
           OR LOWER(CTA.AAC_PERSMISO) LIKE '%r /w%')
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rwsp%' 
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rwsm%' 
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw sp%'
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw sm%'
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w, sp%' 
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w, sm%' 
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w sm%'
           AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w sp%' THEN 1 ELSE 0 END AS rw,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
      AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% sp %' 
      OR LOWER( CTA.AAC_PERSMISO ) LIKE '%sp%' )
      AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rwsp%' 
      AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%rw sp%'
      AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w, sp%'
      AND LOWER(CTA.AAC_PERSMISO) NOT LIKE '%r/w sp%' THEN 1 ELSE 0 END AS sp,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
      AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% rw sp%' 
      OR LOWER( CTA.AAC_PERSMISO ) LIKE '% rwsp%' 
      OR LOWER( CTA.AAC_PERSMISO ) LIKE '%rwsp %'
      OR LOWER(CTA.AAC_PERSMISO) LIKE '%r/w, sp%'
      OR LOWER( CTA.AAC_PERSMISO ) LIKE '% r/w sp %') THEN 1 ELSE 0 END AS rwsp,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
       AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% sp upd%' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% sm %' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% sp modif%') THEN 1 ELSE 0 END AS sm,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
       AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% rw sp upd%' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% rwsp upd %' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% rwsm %' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% rwsp modif %') THEN 1 ELSE 0 END AS rwsm,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
         AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% job%' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% jobs%') THEN 1 ELSE 0 END AS job,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
         AND LOWER( CTA.AAC_PERSMISO ) LIKE '% sysadmin %' THEN 1 ELSE 0 END AS sysad,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '%sql%'
         AND (LOWER( CTA.AAC_PERSMISO ) LIKE '% prf %' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% profil %'
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '%trace%') THEN 1 ELSE 0 END AS prf,

    CASE WHEN LOWER( CTA.AAC_PERSMISO ) LIKE '% owner %' 
       OR LOWER( CTA.AAC_PERSMISO ) LIKE '% propietario %' THEN 1 ELSE 0 END AS own,

    CASE WHEN MAIL.consumo=0 THEN '' ELSE MAIL.consumo END AS permitido
    
FROM ProyFidens.dbo.ADM_ACTIVACION_CUENTA CTA
JOIN ProyFidens.dbo.SYS_ACCOUNT USR ON CTA.AGE_SEG_CODIGO = USR.COD_USER AND USR.STATUS=1
JOIN ProyFidens.dbo.ADM_SERVIDOR SRV ON CTA.ASE_IDENASE = SRV.ASE_IDENASE AND SRV.ASE_ESTADO=1
LEFT OUTER JOIN master.dbo.infra_auth_email MAIL ON CTA.AGE_SEG_CODIGO=MAIL.coduser_solic 
    AND CTA.USU_SEG_FECHAINS<=MAIL.fecha_correo 
    AND MAIL.fecha_correo>=DATEADD(HOUR, -1, GETDATE())
    AND CTA.USU_SEG_FECHAINS >= DATEADD(HOUR, -1, MAIL.fecha_correo)
WHERE CTA.ACC_FECHAFIN >= CAST(GETDATE() AS date) AND
  CTA.ESTADO IN (1)
ORDER BY LOWER(USR.TXT_ACC) ASC, CTA.AAC_IDENAAC ASC;

De: Jorge Toledo jtoledo@fidens-insurtech.com **Enviado el: martes, 24 de marzo de 2026 16:29**Para: Infraestructura y Seguridad infraestructura@fidenslat.com**CC: Wilmer Garcia wgarcia@fidens-insurtech.com**Asunto: Acceso RDP server 103** **Estimados:**               Favor autorizar acceso RDP a server 103, para revisión de error con estados de pólizas inconsistentes.** **Wilmer:**               Favor tu aprobación.** **



