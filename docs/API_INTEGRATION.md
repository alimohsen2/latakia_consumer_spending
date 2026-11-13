# ربط المشروع بـ SQL Server 2022 Developer + .NET 8 API

هذا المستند يشرح كيف تربط المشروع فعليًا بـ SQL Server 2022 Developer (مجاني) مع API مبني على .NET 8.

**ملاحظة مهمة**: التطبيق حاليًا يعمل ببيانات تجريبية محفوظة في `SharedPreferences` داخل `AppStore`. الانتقال إلى الخادم يعني استبدال مصدر البيانات بالكامل (لا يوجد مسار API موجود الآن). لذلك النسخة التنفيذية تُقسّم على مرحلتين:

---

## المرحلة 1 — إنشاء قاعدة البيانات على الجهاز الحالي

### المتطلبات
- Windows مع صلاحيات **Administrator** (التثبيت لا يتم بحساب مستخدم عادي).
- مساحة 6–8 GB فارغة على القرص C.
- اتصال إنترنت مستقر (التنزيل ~3–4 GB).

### خطوات التثبيت (بإداري)
```powershell
winget install --id Microsoft.SQLServer.2022.Developer --source winget \
  --silent --accept-package-agreements --accept-source-agreements
```
أو من المتصفح: https://www.microsoft.com/sql-server/sql-server-downloads
→ اختر **Developer**، احفظ الملف، شغّله كمستخدم صلاحيات إداري.

بعد اكتمال التثبيت، تأكد من تشغيل الخدمة:
```powershell
Get-Service MSSQLSERVER | Select-Object Status, StartType
Start-Service MSSQLSERVER
```

> ملاحظة: التطبيق يحتاج TCP/IP للاتصال. فعّل TCP/IP من **SQL Server Configuration Manager**
> (SQL Server Network Configuration → Protocols for MSSQLSERVER → TCP/IP → Enable)، ثم أعد تشغيل الخدمة.

### إنشاء قاعدة البيانات وهوية التطبيق
في **SQL Server Management Studio** أو `sqlcmd`:

```sql
CREATE LOGIN latakia_app_login WITH PASSWORD = '<StrongPasswordHere>';
CREATE DATABASE latakia_consumer_spending;
GO
USE latakia_consumer_spending;
CREATE USER latakia_app FOR LOGIN latakia_app_login;
EXEC sp_addrolemember 'db_owner', 'latakia_app';  -- مؤقتًا؛ ضع db_datareader/db_datawriter لاحقًا
GO
```

ثم شغّل المخطط الجاهز:
```powershell
sqlcmd -S localhost -U latakia_app_login -P '<StrongPasswordHere>' -d latakia_consumer_spending -i docs\schema.sql
```

---

## المرحلة 2 — API وسيط بين Flutter و SQL Server

### لماذا API؟
لا يتصل Flutter مباشرة بـ SQL Server على الأجهزة العادية (لا driver أصلي، ويكشف سلسلة الاتصال). الأنسب خادم REST بسيط بـ .NET 8.

### بنية المشروع المقترحة
```
server/
  LatakiaApi/
    LatakiaApi.csproj         # net8.0, ASP.NET Core + EF Core SqlServer
    Program.cs                # WebApplication
    appsettings.json          # ConnectionStrings:DefaultConnection
    Data/                     # DbContext + entities (Users, Taxpayers, Reports, AuditLog...)
    Controllers/              # UsersController, TaxpayersController, ReportsController, AuditController
    Migrations/               # dotnet ef migrations
```

`Program.cs` مبسّط:
```csharp
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));
var app = builder.Build();
app.MapControllers();
app.Run();
```

`appsettings.json`:
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=latakia_consumer_spending;User Id=latakia_app_login;Password=<StrongPasswordHere>;TrustServerCertificate=True"
  }
}
```

### مثال endpoint
```csharp
[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase {
  private readonly AppDbContext _db;
  public UsersController(AppDbContext db) => _db = db;

  [HttpGet]
  public async Task<IActionResult> List() =>
      Ok(await _db.Users.Where(u => u.Active).Select(u => new { u.Id, u.Name, u.Username, u.Role }).ToListAsync());
}
```

---

## المرحلة 3 — تفعيل التطبيق على الخادم

غيّر `AppStore` في `lib/data/store.dart` من بيانات ثابتة إلى نداءات HTTP:

```dart
// بدل قراءة SharedPreferences
final resp = await http.get(Uri.parse('$apiBase/api/users'));
final list = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
```

كل دوال `_save()` تُستبدل بنداءات `POST/PUT` وهيات API.

---

## ملاحظات أمان
- لا تُخزّن كلمات المرور كنص؛ استخدم bcrypt/Argon2 في API.
- في الإنتاج، ضع API خلف HTTPS مع مصادقة JWT ويكون الـ DB خلف جدار حماية داخلي.
- استبدل `TrustServerCertificate=True` بشهادة داخلية موقّعة لاحقًا.

## ترتيب العمل المقترح
1. تثبيت SQL Server Developer (بإداري) → إنشاء DB → تشغيل `docs\schema.sql`.
2. إنشاء `server/LatakiaApi` بالـ .NET 8 (المثبّت القائم بالفعل — `Microsoft.DotNet.SDK.8`).
3. رحّل `_save()`/`load()` في `AppStore` إلى نداءات HTTP واحدة دومينًا.
4. اختبر الدخول والتغييرات الأساسية، ثم انقل تدريجياً.
