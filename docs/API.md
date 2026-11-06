# واجهة الخلفية المقترحة (REST)

## التخزين المحلي الحالي

النسخة الحالية تحفظ بيانات التطبيق بصيغة JSON عبر `SharedPreferences`، وتنتظر
الكتابات المتسلسلة وتعرض خطأً داخل التطبيق إذا فشل الحفظ. إذا تعذر تحليل البيانات
المحفوظة عند بدء التشغيل، يتوقف التحميل برسالة خطأ بدل استبدالها تلقائياً ببيانات
تجريبية. يظل التخزين محلياً للمنصة: بيانات الويب مرتبطة بأصل الصفحة (البروتوكول
والمضيف والمنفذ) وبملف المتصفح، وبيانات Windows مرتبطة بجهاز المستخدم. هذا لا
ينشئ قاعدة SQLite مشتركة ولا يغني عن تصدير نسخة احتياطية.

المتصفح لا يتصل بـ SQL Server مباشرة. ضع خلفية صغيرة (ASP.NET Core أو Node أو Dart Shelf) بين التطبيق وقاعدة البيانات.
كل ما يخص **القفل والتوقيع وسلسلة سجل العمليات** يجب أن يتم على الخادم لا في المتصفح.

| الطريقة | المسار | الوصف |
|---|---|---|
| POST | /auth/login | دخول، يعيد رمز جلسة (JWT) ينتهي بعد خمول |
| GET/POST/PUT | /taxpayers | بحث (q, mode, category, status)، إضافة، تعديل |
| POST | /taxpayers/{id}/status | تغيير حالة مع سبب |
| POST | /taxpayers/import | استيراد صفوف (JSON) مع تقرير الرفض |
| GET | /taxpayers/lookup?taxNo= | جلب بيانات مكلف من الواجهة الخارجية |
| GET/POST/PUT | /reports | المحاضر (المسودات فقط قابلة للتعديل) |
| POST | /reports/{id}/submit · approve · endorse · return | مسار الاعتماد |
| POST | /reports/{id}/lock | يحسب البصمة SHA-256 ويقفل ويعيد حمولة QR الموقّعة |
| POST | /reports/{id}/cancel | إلغاء بسبب مكتوب |
| GET | /verify?payload= | تحقق عام من QR (يعيد الحالة فقط دون تفاصيل المخالفة) |
| GET/PUT | /registers/violations · /registers/followups | السجلات |
| GET | /archive?q=&status=&division=&from=&to=&hasAttachments=&archived= | فهرس الأرشيف مع الفلاتر |
| PUT | /archive/{reportId} | تسجيل مرجع الملف والصندوق والملاحظات (لا يمسّ البصمة) |
| DELETE | /archive/{reportId} | إلغاء الموقع الأرشيفي (مسجّل في سجل العمليات) |
| GET | /taxpayers/{id}/attachments | صور أضبارة المكلف (وصف فقط، دون بايتات) |
| POST | /taxpayers/{id}/attachments | رفع صورة إلى أضبارة المكلف (multipart: file, kind, note) |
| DELETE | /taxpayers/{id}/attachments/{attachmentId} | حذف صورة من أضبارة المكلف مع تسجيل العملية |
| POST | /reports/{reportId}/attachments | رفع مرفق (multipart: file, kind, note) |
| GET | /attachments/{id} | تنزيل مرفق بعد التحقق من الصلاحية |
| DELETE | /attachments/{id} | حذف مرفق مع تسجيل العملية |
| GET | /field/drafts?mine=1 | مسودات المفتش الحالي على الخادم (اختياري) |
| POST | /field/sync | مزامنة مسودة ميدانية مع مرفقاتها (انظر docs/FIELD_APP.md) |
| GET | /field/sync/log | سجل محاولات المزامنة بيد المدير |
| GET/PUT | /statements?ym= | البيانات الشهرية |
| GET | /sales/{taxNo}?granularity=daily\|monthly\|yearly | مبيعات المكلف (وسيط للواجهة الخارجية) |
| GET | /alerts | تنبيهات المستخدم الحالي بحسب التوزيع |
| GET/PUT | /admin/permissions · /admin/routing · /admin/users | بيد مدير النظام فقط |
| GET/POST | /admin/serial-books | دفاتر الأرقام والتسويات |
| GET | /admin/audit · /admin/integrity | سجل العمليات وفحص السلامة |

## توقيع QR
الحمولة: `LTX1|<رقم المحضر>|<أول 16 خانة من البصمة>|<توقيع>`.
في هذه النسخة التجريبية التوقيع HMAC بمفتاح داخل الكود. في الإنتاج استخدم توقيعاً غير متماثل (Ed25519): المفتاح الخاص على الخادم فقط، والعام مدمج في التطبيق للتحقق دون إنترنت.

## المرفقات والأرشيف
- ملفات المرفقات **لا تمر** عبر JSON قاعدة البيانات؛ تُرفع multipart وتُخزَّن خارجها.
- حقول الأرشيف (`ArchiveRef`, `ArchiveBox`, `ArchiveNotes`, `ArchivedAt`, `ArchivedBy`)
  **لا تدخل في بصمة المحضر**؛ لأنها بيانات موقع وليست محتوى. تعديلها يُسجَّل في
  `AuditLog` فقط.
- يجب أن يتحقق الخادم من صلاحية `archive.edit` أو أن المستخدم من شعبة الأرشيف.
- عند حذف مرفق: احذف السجل ثم الملف، وسجّل العملية.

## أضبارة المكلف
- كل مكلف يملك أضبارة صور مستقلة في الجدول `TaxpayerAttachments` (أو عمود `TaxpayerId`
  في `Attachments` بدل `ReportId`).
- الصور أوصافها فقط داخل بيانات المكلف (`attachments` في JSON)، والبايتات في التخزين
  الخارجي، لذا لا تثقل نسخة البيانات ولا تدخل في أي بصمة.
- صلاحية الإدارة: من يملك `taxpayers.edit` أو من هو من شعبة الأرشيف (`Division='archive'`).
- حد المرفق في النسخة التجريبية 1.5 ميغابايت للصورة الواحدة.
- لا تحذف بايتات مرفق ما زال مرتبطاً بأي محضر أو مسودة ميدانية أو أضبارة مكلف.

## مزامنة الميدان
- `POST /field/sync` يستقبل مسودة كاملة (بيانات + مخالفات + ملفات).
- يجب أن يكون **Idempotent** بمفتاح `draftId`؛ إعادة الإرسال لا تُنشئ محضراً ثانياً.
- الخادم هو من يخصص الرقم التسلسلي ويتحقق من دفتر الأرقام.
- أعد `{ "ok": true, "reportId": "...", "serial": "..." }` عند النجاح.
- المرفقات: multipart أفضل من base64 داخل JSON في الإنتاج.
- الحمولة الكاملة والمثال في `docs/FIELD_APP.md`.

## استبدال البيانات التجريبية
- اكتب `HttpSalesApi implements SalesApi` في `lib/data/sales_api.dart` واستبدل `MockSalesApi` في `AppStore`.
- استبدل دوال `_save` و`_load` في `lib/data/store.dart` باستدعاءات الواجهة أعلاه.
