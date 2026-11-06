-- مخطط SQL Server لنظام أتمتة دائرة الإنفاق الاستهلاكي (مقترح للإنتاج)
-- ملاحظة: التطبيق الحالي يعمل على بيانات تجريبية في المتصفح. هذا المخطط هو هدف الانتقال إلى الخلفية.
CREATE TABLE dbo.Users (
  Id NVARCHAR(40) PRIMARY KEY, Name NVARCHAR(200) NOT NULL, Username NVARCHAR(100) NOT NULL UNIQUE,
  PasswordHash NVARCHAR(200) NOT NULL,            -- استخدم bcrypt أو argon2 على الخادم
  Role NVARCHAR(30) NOT NULL,                     -- sysadmin | sectionHead | deptHead | divisionHead | user
  Division NVARCHAR(20) NULL,                     -- field | office | archive
  ManagerId NVARCHAR(40) NULL REFERENCES dbo.Users(Id), Active BIT NOT NULL DEFAULT 1);

CREATE TABLE dbo.RolePermissions (Role NVARCHAR(30) NOT NULL, Permission NVARCHAR(60) NOT NULL, PRIMARY KEY (Role, Permission));
CREATE TABLE dbo.AlertRouting (AlertType NVARCHAR(40) NOT NULL, Target NVARCHAR(60) NOT NULL, PRIMARY KEY (AlertType, Target)); -- role:x | div:x | user:id

CREATE TABLE dbo.Taxpayers (
  Id NVARCHAR(40) PRIMARY KEY, Name NVARCHAR(300) NOT NULL, Owner NVARCHAR(300) NULL, Category NVARCHAR(60) NOT NULL,
  TaxNo NVARCHAR(40) NOT NULL UNIQUE, Address NVARCHAR(500) NULL, Profession NVARCHAR(200) NULL, Status NVARCHAR(30) NOT NULL);
CREATE TABLE dbo.TaxpayerStatusHistory (Id INT IDENTITY PRIMARY KEY, TaxpayerId NVARCHAR(40) NOT NULL REFERENCES dbo.Taxpayers(Id),
  ChangedAt DATETIME2 NOT NULL, FromStatus NVARCHAR(30), ToStatus NVARCHAR(30), Reason NVARCHAR(500), ChangedBy NVARCHAR(40));
CREATE TABLE dbo.MonthlyStatements (TaxpayerId NVARCHAR(40) NOT NULL, Ym CHAR(7) NOT NULL, Submitted BIT NOT NULL, SubmittedOn DATE NULL, PRIMARY KEY (TaxpayerId, Ym));

CREATE TABLE dbo.SerialBooks (Id NVARCHAR(40) PRIMARY KEY, FromNo INT NOT NULL, ToNo INT NOT NULL, Assignee NVARCHAR(200) NOT NULL, Closed BIT NOT NULL DEFAULT 0);
CREATE TABLE dbo.SerialReconciliations (BookId NVARCHAR(40) NOT NULL, No INT NOT NULL, Reason NVARCHAR(500) NOT NULL, PRIMARY KEY (BookId, No));

CREATE TABLE dbo.Reports (
  Id NVARCHAR(40) PRIMARY KEY, Serial NVARCHAR(20) NOT NULL UNIQUE, TaxpayerId NVARCHAR(40) NOT NULL REFERENCES dbo.Taxpayers(Id),
  IssuedAt DATETIME2 NOT NULL, OrderNo NVARCHAR(60), OrderDate NVARCHAR(30), Status NVARCHAR(30) NOT NULL, CreatedBy NVARCHAR(40), Division NVARCHAR(20),
  LateFeePct DECIMAL(9,2) NOT NULL DEFAULT 0, Total DECIMAL(18,2) NOT NULL DEFAULT 0,
  ServedName NVARCHAR(200), ServedCapacity NVARCHAR(100), ServedFather NVARCHAR(200), ServedMother NVARCHAR(200), ServedNationalNo NVARCHAR(30),
  Inspectors NVARCHAR(500), FieldHead NVARCHAR(200), CancelReason NVARCHAR(500), Fingerprint CHAR(64) NULL, PrintedAt DATETIME2 NULL,
  -- حقول سجل المخالفات (تُعدَّل بعد القفل):
  ServedDate NVARCHAR(30), ObjectionNo NVARCHAR(60), ObjectionDate NVARCHAR(30), ReferralDate NVARCHAR(30), Committee NVARCHAR(60), ReferralValue DECIMAL(18,2) NULL);
CREATE TABLE dbo.ReportItems (Id INT IDENTITY PRIMARY KEY, ReportId NVARCHAR(40) NOT NULL REFERENCES dbo.Reports(Id), Type NVARCHAR(200) NOT NULL, Article NVARCHAR(100), Fine DECIMAL(18,2) NOT NULL);
CREATE TABLE dbo.FollowUps (ReportId NVARCHAR(40) PRIMARY KEY REFERENCES dbo.Reports(Id), Data NVARCHAR(MAX) NOT NULL); -- JSON

-- سجل العمليات: متسلسل بالبصمات، للإضافة فقط
CREATE TABLE dbo.AuditLog (
  Id BIGINT IDENTITY PRIMARY KEY, Ts DATETIME2 NOT NULL, UserName NVARCHAR(200) NOT NULL, Action NVARCHAR(100) NOT NULL,
  Entity NVARCHAR(200) NOT NULL, Detail NVARCHAR(1000) NOT NULL, PrevHash CHAR(64) NOT NULL, Hash CHAR(64) NOT NULL);
GO
CREATE TRIGGER trg_AuditLog_ReadOnly ON dbo.AuditLog INSTEAD OF UPDATE, DELETE AS
BEGIN RAISERROR(N'سجل العمليات للقراءة فقط', 16, 1); END;
GO
-- منع حذف المحاضر نهائياً، ومنع تعديل الحقول الجوهرية بعد القفل
CREATE TRIGGER trg_Reports_NoDelete ON dbo.Reports INSTEAD OF DELETE AS
BEGIN RAISERROR(N'لا يُحذف المحضر. استخدم الإلغاء بسبب مكتوب', 16, 1); END;
GO
CREATE TRIGGER trg_Reports_Locked ON dbo.Reports AFTER UPDATE AS
BEGIN
  IF EXISTS (SELECT 1 FROM deleted d JOIN inserted i ON i.Id = d.Id
             WHERE d.Status = N'مقفل' AND (i.Serial <> d.Serial OR i.TaxpayerId <> d.TaxpayerId OR i.Total <> d.Total
               OR i.Fingerprint <> d.Fingerprint OR i.IssuedAt <> d.IssuedAt OR i.ServedName <> d.ServedName))
  BEGIN RAISERROR(N'المحضر مقفل ولا تُعدَّل بياناته', 16, 1); ROLLBACK TRANSACTION; END
END;
GO
-- توصية: حساب التطبيق بلا صلاحية UPDATE/DELETE على AuditLog، وحساب إدارة القاعدة منفصل.

-- ===================== الأرشيف والمرفقات (وحدة جديدة) =====================
-- حقول موقع الأرشيف. لا تدخل في بصمة المحضر ولا في Fingerprint.
ALTER TABLE dbo.Reports ADD
  ArchiveRef        NVARCHAR(100) NULL,
  ArchiveBox        NVARCHAR(60)  NULL,
  ArchiveNotes      NVARCHAR(500) NULL,
  ArchivedAt        DATETIME2     NULL,
  ArchivedBy        NVARCHAR(40)  NULL;
GO
CREATE INDEX IX_Reports_Archive ON dbo.Reports(ArchiveRef, ArchiveBox);
GO

-- المرفقات: الملف على القرص/التخزين، وهذا الوصف فقط في القاعدة.
CREATE TABLE dbo.Attachments (
  Id            NVARCHAR(40) PRIMARY KEY,
  ReportId      NVARCHAR(40) NOT NULL REFERENCES dbo.Reports(Id),
  FileName      NVARCHAR(300) NOT NULL,
  MimeType      NVARCHAR(120) NOT NULL,
  Kind          NVARCHAR(20)  NOT NULL DEFAULT N'document', -- photo | document
  SizeBytes     INT           NOT NULL,
  StoragePath   NVARCHAR(600) NOT NULL,        -- مسار داخلي لا يُعاد للمستخدم
  Sha256        CHAR(64)      NOT NULL,        -- لكشف تغيّر الملف
  Note          NVARCHAR(500) NULL,
  UploadedAt    DATETIME2     NOT NULL,
  UploadedBy    NVARCHAR(40)  NULL REFERENCES dbo.Users(Id),
  DeletedAt     DATETIME2     NULL,            -- حذف ناعم + سجل
  CONSTRAINT CK_Attachments_Size CHECK (SizeBytes > 0 AND SizeBytes <= 5242880)
);
GO
CREATE INDEX IX_Attachments_Report ON dbo.Attachments(ReportId) WHERE DeletedAt IS NULL;
GO
-- منع حذف المرفق نهائياً: استخدم DeletedAt والسجل
CREATE TRIGGER trg_Attachments_NoDelete ON dbo.Attachments INSTEAD OF DELETE AS
BEGIN RAISERROR(N'لا يُحذف المرفق نهائياً. استخدم DeletedAt', 16, 1);
END;
GO

-- ===================== أضبارة المكلف (صور الأوراق الورقية) =====================
-- صورة لكل ورقة داخل أضبارة المكلف: سجل تجاري، هوية، إجازة، عقد إيجار...
-- الملف على القرص/التخزين، وهذا الوصف فقط في القاعدة. لا تدخل في أي بصمة.
CREATE TABLE dbo.TaxpayerAttachments (
  Id            NVARCHAR(40) PRIMARY KEY,
  TaxpayerId    NVARCHAR(40) NOT NULL REFERENCES dbo.Taxpayers(Id),
  FileName      NVARCHAR(300) NOT NULL,
  MimeType      NVARCHAR(120) NOT NULL,
  Kind          NVARCHAR(20)  NOT NULL DEFAULT N'photo', -- photo | document
  SizeBytes     INT           NOT NULL,
  StoragePath   NVARCHAR(600) NOT NULL,        -- مسار داخلي لا يُعاد للمستخدم
  Sha256        CHAR(64)      NOT NULL,        -- لكشف تغيّر الصورة
  Note          NVARCHAR(500) NULL,            -- نوع الورقة: سجل تجاري، هوية...
  UploadedAt    DATETIME2     NOT NULL,
  UploadedBy    NVARCHAR(40)  NULL REFERENCES dbo.Users(Id),
  DeletedAt     DATETIME2     NULL,
  CONSTRAINT CK_TaxpayerAttachments_Size CHECK (SizeBytes > 0 AND SizeBytes <= 1572864)
);
GO
CREATE INDEX IX_TaxpayerAttachments_Taxpayer ON dbo.TaxpayerAttachments(TaxpayerId) WHERE DeletedAt IS NULL;
GO
CREATE TRIGGER trg_TaxpayerAttachments_NoDelete ON dbo.TaxpayerAttachments INSTEAD OF DELETE AS
BEGIN RAISERROR(N'لا تُحذف صورة الأضبارة نهائياً. استخدم DeletedAt', 16, 1);
END;
GO
-- صلاحية الإدارة: taxpayers.edit أو Division='archive'، وتُسجَّل كل عملية في AuditLog.

-- سجل أحداث الأرشيف: تسجيل موقع، إخراج مؤقت، إرجاع، إتلاف.
CREATE TABLE dbo.ArchiveEvents (
  Id          BIGINT IDENTITY PRIMARY KEY,
  ReportId    NVARCHAR(40) NOT NULL REFERENCES dbo.Reports(Id),
  EventType   NVARCHAR(30) NOT NULL,  -- locate | checkout | return | destroy
  Detail      NVARCHAR(500) NULL,
  ByUser      NVARCHAR(40)  NULL,
  AtTime      DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- ===================== العمل الميداني (وحدة جديدة) =====================
-- مسودات المفتشين كما وصلت من الأجهزة. حالة العرض والقراءة فقط بعد المزامنة.
CREATE TABLE dbo.FieldDrafts (
  Id              NVARCHAR(60) PRIMARY KEY,       -- DraftId من الجهاز (Idempotency)
  TaxpayerId      NVARCHAR(40) NULL REFERENCES dbo.Taxpayers(Id),
  TaxpayerName    NVARCHAR(300) NULL,
  TaxNo           NVARCHAR(40)  NULL,
  Address         NVARCHAR(500) NULL,
  Profession      NVARCHAR(200) NULL,
  SerialHint      NVARCHAR(20)  NULL,
  OrderNo         NVARCHAR(60)  NULL,
  OrderDate       NVARCHAR(30)  NULL,
  ServedName      NVARCHAR(200) NULL,
  ServedCapacity  NVARCHAR(100) NULL,
  ServedNationalNo NVARCHAR(30) NULL,
  Inspectors      NVARCHAR(500) NULL,
  FieldHead       NVARCHAR(200) NULL,
  LocationText    NVARCHAR(500) NULL,
  Lat             DECIMAL(9,6)  NULL,
  Lng             DECIMAL(9,6)  NULL,
  Notes           NVARCHAR(1000) NULL,
  Status          NVARCHAR(30)  NOT NULL,         -- draft | ready | synced | failed
  ReportId        NVARCHAR(40)  NULL REFERENCES dbo.Reports(Id),
  InspectorId     NVARCHAR(40)  NULL REFERENCES dbo.Users(Id),
  Division        NVARCHAR(20)  NULL,
  CreatedAt       DATETIME2     NOT NULL,
  UpdatedAt       DATETIME2     NOT NULL,
  SyncedAt        DATETIME2     NULL,
  Attempts        INT           NOT NULL DEFAULT 0,
  LastError       NVARCHAR(500) NULL,
  PayloadJson     NVARCHAR(MAX) NULL                -- نسخة كاملة للتدقيق
);
GO
CREATE TABLE dbo.FieldDraftItems (
  Id        BIGINT IDENTITY PRIMARY KEY,
  DraftId   NVARCHAR(60) NOT NULL REFERENCES dbo.FieldDrafts(Id),
  Type      NVARCHAR(200) NOT NULL,
  Article   NVARCHAR(100) NULL,
  Fine      DECIMAL(18,2) NOT NULL
);
GO
CREATE TABLE dbo.FieldSyncLog (
  Id        BIGINT IDENTITY PRIMARY KEY,
  DraftId   NVARCHAR(60) NOT NULL,
  DeviceId  NVARCHAR(100) NULL,
  UserId    NVARCHAR(40)  NULL,
  AtTime    DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
  Ok        BIT           NOT NULL,
  ReportId  NVARCHAR(40)  NULL,
  Message   NVARCHAR(500) NULL
);
GO
CREATE INDEX IX_FieldDrafts_Status ON dbo.FieldDrafts(Status, UpdatedAt);
GO
-- صلاحيات جديدة (تُدرج في جدول RolePermissions)
-- archive.view | archive.edit | archive.attachments
-- field.view | field.create | field.sync

-- ===================== الفلاتر المحفوظة والتنبيهات والإعدادات =====================
-- فلاتر قائمة المكلفين المحفوظة (لكل مستخدم أو عامة عندما يكون OwnerId = NULL).
CREATE TABLE dbo.SavedFilters (
  Id         NVARCHAR(40)  PRIMARY KEY,
  Name       NVARCHAR(200) NOT NULL,
  OwnerId    NVARCHAR(40)  NULL REFERENCES dbo.Users(Id),
  QueryJson  NVARCHAR(MAX) NOT NULL,   -- { q, mode, cat, status }
  CreatedAt  DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- سجل التنبيهات/المواعيد (انخفاض المبيعات، محضر بانتظار الاعتماد، موعد متابعة...).
CREATE TABLE dbo.AlertLog (
  Id         BIGINT IDENTITY PRIMARY KEY,
  AlertType  NVARCHAR(40)  NOT NULL,
  TaxpayerId NVARCHAR(40)  NULL REFERENCES dbo.Taxpayers(Id),
  ReportId   NVARCHAR(40)  NULL REFERENCES dbo.Reports(Id),
  Target     NVARCHAR(60)  NULL,       -- role:x | div:x | user:id
  Detail     NVARCHAR(500) NULL,
  AtTime     DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
  SeenAt     DATETIME2     NULL
);
GO
CREATE INDEX IX_AlertLog_Time ON dbo.AlertLog(AtTime DESC);
GO

-- إعدادات النظام (حدود التنبيه، نسب الغرامات، إعدادات الطباعة...).
CREATE TABLE dbo.AppSettings (
  SettingKey NVARCHAR(80)  PRIMARY KEY,
  Value      NVARCHAR(400) NOT NULL,
  UpdatedAt  DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
  UpdatedBy  NVARCHAR(40)  NULL REFERENCES dbo.Users(Id)
);
GO
