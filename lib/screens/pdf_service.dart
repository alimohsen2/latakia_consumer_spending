import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/util.dart';
import '../data/models.dart';

/// يفصل أسماء المراقبين المكتوبة في حقل واحد إلى قائمة أسماء.
List<String> _splitInspectors(String raw) => raw
    .split(RegExp(r'[,،;\n]+'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList(growable: false);

/// يبني محضر الضبط بصيغة PDF وفق النموذج الورقي المعتمد.
///
/// المحضر يُخرج دائماً في صفحة واحدة: يُبنى المحتوى بارتفاعه الطبيعي ثم
/// يُوضع داخل [pw.FittedBox]، فإن تجاوز ارتفاع A4 صُغّر بنسبة تحافظ على
/// وضوحه، وإن كان أقصر بقي بحجمه الطبيعي دون تكبير.
Future<Uint8List> buildReportPdf(Report r, Taxpayer? t) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'),
  );
  final theme = pw.ThemeData.withFont(base: font, bold: bold);
  final doc = pw.Document(
    theme: theme,
    compress: true,
    title: 'محضر ضبط مخالفة ${r.serial}',
    author: 'دائرة الإنفاق الاستهلاكي',
    creator: 'نظام متابعة الإنفاق الاستهلاكي',
  );

  const blank = '..........';
  const grey = PdfColor.fromInt(0xFF8E9995);
  const rule = PdfColor.fromInt(0xFFB9C2BE);

  String value(String? v) => (v == null || v.trim().isEmpty) ? blank : v.trim();

  final dateParts = fmtDate(r.date).split('/');
  final time = fmtDT(r.date).split(' ').last;
  const weekdays = [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];
  final dayPeriod = r.date.hour < 12 ? 'صباحاً' : 'مساءً';
  final weekday = weekdays[r.date.weekday % 7];

  final taxpayerName = value(t?.name);
  final taxpayerAddress = value(t?.address);
  final taxpayerOwner = value(t?.owner);
  final taxpayerProfession = value(t?.profession);

  // ---- أحجام متكيّفة مع عدد المخالفات وعدد المراقبين ----
  final violationCount = math.max(r.items.length, 13);
  final violationRowHeight = violationCount <= 13
      ? 19.0
      : violationCount <= 18
          ? 16.0
          : 13.5;

  final inspectorNames = _splitInspectors(r.inspectors);
  final inspectorSlots = math.max(inspectorNames.length, 2);
  final inspectorColumns = inspectorSlots <= 4
      ? 2
      : inspectorSlots <= 9
          ? 3
          : 4;
  final inspectorRows = (inspectorSlots / inspectorColumns).ceil();
  final inspectorCellHeight = inspectorRows <= 1
      ? 58.0
      : inspectorRows == 2
          ? 50.0
          : inspectorRows == 3
              ? 44.0
              : 40.0;
  const authorityRowHeight = 58.0;

  // ---- أنماط النص ----
  final body = pw.TextStyle(font: font, fontSize: 9.4, lineSpacing: 2.2);
  final bodyBold = pw.TextStyle(font: bold, fontSize: 9.4, lineSpacing: 2.2);
  final small = pw.TextStyle(font: font, fontSize: 8.2, lineSpacing: 1.4);
  final smallBold = pw.TextStyle(font: bold, fontSize: 8.2, lineSpacing: 1.4);
  final tiny = pw.TextStyle(font: font, fontSize: 7.2, lineSpacing: 1.2);
  final tinyBold = pw.TextStyle(font: bold, fontSize: 7.2, lineSpacing: 1.2);

  // ---- الترويسة ----
  final header = pw.Table(
    columnWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(1),
    },
    children: [
      pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.top,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final line in const [
                'الجمهورية العربية السورية',
                'وزارة المالية',
                'الهيئة العامة للضرائب والرسوم',
                'مديرية مالية ..........',
                'قسم الواردات',
                'دائرة الإنفاق الاستهلاكي',
              ])
                pw.Text(line, style: bodyBold),
            ],
          ),
          pw.Padding(
            padding: const pw.EdgeInsetsDirectional.only(start: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'رقم  ${r.serial.trim().isEmpty ? blank : r.serial.trim()}',
                  style: bodyBold,
                ),
                pw.SizedBox(height: 2),
                pw.Container(width: 74, height: .7, color: rule),
              ],
            ),
          ),
        ],
      ),
    ],
  );

  // ---- صفوف المخالفات ----
  pw.Widget violationRow(int index) {
    final hasItem = index < r.items.length;
    final item = hasItem ? r.items[index] : null;
    return pw.Container(
      height: violationRowHeight,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
      alignment: pw.AlignmentDirectional.centerStart,
      child: hasItem
          ? pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(
                  width: 18,
                  child: pw.Text(
                    '${index + 1}.',
                    style: tiny.copyWith(color: grey),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    item!.type,
                    style: small,
                    maxLines: 2,
                  ),
                ),
                if (item.article.trim().isNotEmpty)
                  pw.SizedBox(
                    width: 64,
                    child: pw.Text(
                      'المادة ${item.article}',
                      style: tiny,
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                pw.SizedBox(
                  width: 74,
                  child: pw.Text(
                    '${money(item.fine)} ل.س',
                    style: smallBold,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            )
          : pw.SizedBox(),
    );
  }

  final violationsTable = pw.Table(
    columnWidths: {0: const pw.FlexColumnWidth(1)},
    border: pw.TableBorder(
      bottom: pw.BorderSide(width: .6, color: rule),
      horizontalInside: pw.BorderSide(width: .5, color: rule),
    ),
    children: [
      for (var i = 0; i < violationCount; i++)
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.full,
          children: [violationRow(i)],
        ),
    ],
  );

  // ---- خلية التوقيع القابلة للتكرار ----
  pw.Widget signatureCell({
    required String title,
    required double height,
    String? name,
    String? caption,
  }) {
    final hasName = name != null && name.trim().isNotEmpty;
    return pw.Container(
      height: height,
      padding: const pw.EdgeInsetsDirectional.only(
          start: 5, end: 5, top: 3, bottom: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(title, style: tinyBold, textAlign: pw.TextAlign.center),
          if (caption != null)
            pw.Text(caption, style: tiny, textAlign: pw.TextAlign.center),
          if (hasName) ...[
            pw.SizedBox(height: 1),
            pw.Text(
              name.trim(),
              style: smallBold,
              textAlign: pw.TextAlign.center,
              maxLines: 2,
            ),
          ],
          pw.Spacer(),
          pw.Container(height: .6, color: rule),
        ],
      ),
    );
  }

  pw.Widget inspectorGrid() {
    final rows = <pw.TableRow>[];
    for (var start = 0; start < inspectorSlots; start += inspectorColumns) {
      final cells = <pw.Widget>[];
      for (var column = 0; column < inspectorColumns; column++) {
        final index = start + column;
        if (index < inspectorSlots) {
          cells.add(signatureCell(
            title: 'اسم المراقب وتوقيعه',
            name: index < inspectorNames.length ? inspectorNames[index] : null,
            height: inspectorCellHeight,
          ));
        } else {
          cells.add(pw.SizedBox(height: inspectorCellHeight));
        }
      }
      rows.add(pw.TableRow(children: cells));
    }
    return pw.Table(
      columnWidths: {
        for (var i = 0; i < inspectorColumns; i++)
          i: const pw.FlexColumnWidth(1),
      },
      children: rows,
    );
  }

  final signatureBlock = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      inspectorGrid(),
      pw.SizedBox(height: 2),
      pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            children: [
              signatureCell(
                title: 'رئيس الشعبة الميدانية وتوقيعه',
                name: r.fieldHead,
                height: authorityRowHeight,
              ),
              signatureCell(
                title: 'مصدّق',
                caption: 'رئيس دائرة الإنفاق الاستهلاكي',
                name: r.deptHead,
                height: authorityRowHeight,
              ),
            ],
          ),
        ],
      ),
    ],
  );

  final servedBlock = pw.Padding(
    padding: const pw.EdgeInsetsDirectional.only(start: 2, end: 12, top: 2),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('المتبلغ : ${value(r.servedName)}', style: smallBold),
        pw.SizedBox(height: 3),
        pw.Text('الصفة : ${value(r.servedCapacity)}', style: smallBold),
        pw.SizedBox(height: 3),
        pw.Text(
          'الأب : ${value(r.servedFather)}   الأم : ${value(r.servedMother)}',
          style: smallBold,
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'الرقم الوطني / ${value(r.servedNationalNo)}',
          style: smallBold,
        ),
        pw.SizedBox(height: 10),
        pw.Text('التوقيع :', style: smallBold),
        pw.SizedBox(height: 28),
      ],
    ),
  );

  final servedAndSignatures = pw.Table(
    columnWidths: {
      0: const pw.FlexColumnWidth(42),
      1: const pw.FlexColumnWidth(58),
    },
    children: [
      pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.top,
        children: [servedBlock, signatureBlock],
      ),
    ],
  );

  const pageMargin = pw.EdgeInsets.fromLTRB(38, 30, 38, 24);
  final contentWidth =
      PdfPageFormat.a4.width - pageMargin.left - pageMargin.right;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pageMargin,
      textDirection: pw.TextDirection.rtl,
      theme: theme,
      build: (context) => pw.FittedBox(
        fit: pw.BoxFit.contain,
        alignment: pw.Alignment.topCenter,
        child: pw.SizedBox(
          width: contentWidth,
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              header,
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'محضر ضبط مخالفة المرسوم التشريعي رقم /11/ لعام 2015',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 13.2,
                    lineSpacing: 1,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(height: .8, color: rule),
              pw.SizedBox(height: 5),
              pw.Text(
                'في تمام الساعة $time من $dayPeriod يوم $weekday الواقع في '
                '${dateParts[2]} من شهر ${dateParts[1]} لعام ${dateParts[0]}',
                style: body,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'نحن الموقعون أدناه العاملون في دائرة الإنفاق الاستهلاكي لدى مديرية مالية محافظة .......... '
                'بناء على الأمر الإداري رقم ${value(r.orderNo)} تاريخ ${value(r.orderDate)} '
                'الصادر عن السيد مدير المالية وأثناء جولتنا الميدانية لمراقبة تنفيذ أحكام '
                'المرسوم التشريعي رقم /11/ لعام 2015 م لدى منشأة $taxpayerName الكائنة في '
                '$taxpayerAddress المسجلة باسم السيد $taxpayerOwner والذي يمارس مهنة '
                '$taxpayerProfession وبنتيجة تدقيق الفواتير والسجلات العائدة للمومأ إليه وحساب الرسم تبين ما يلي:',
                style: body,
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 6),
              violationsTable,
              if (r.items.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Align(
                  alignment: pw.AlignmentDirectional.centerStart,
                  child: pw.Text(
                    'إجمالي قيمة الضبط: ${money(r.total)} ل.س',
                    style: smallBold,
                  ),
                ),
              ],
              pw.SizedBox(height: 7),
              pw.Text(
                'تلي المحضر على السيد ${value(r.servedName)} بصفته ${value(r.servedCapacity)} '
                'للمنشأة المذكورة فتفهم وأقر بما ورد فيه وبناءً عليه تم ختم المحضر أصولاً '
                'في تمام الساعة .......... من يوم .......... الواقع في .......... من شهر .......... لعام ..........',
                style: body,
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 8),
              servedAndSignatures,
              pw.SizedBox(height: 8),
              pw.Container(height: .8, color: rule),
              pw.SizedBox(height: 4),
              pw.Text(
                'يحق للمكلف الاعتراض على الضبط خلال سبعة أيام من التاريخ الذي يلي تاريخ تبلغه الضبط',
                style: smallBold,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'ينظم المحضر على ثلاث نسخ، الأولى للدوائر المالية ترفق مع تقرير الجولة الميدانية '
                'والثانية للمكلف والثالثة تعتبر أرومة.',
                style: tiny,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return doc.save();
}

Future<void> printReportPdf(Uint8List bytes, String name) =>
    Printing.layoutPdf(onLayout: (_) async => bytes, name: name);

/// بطاقة أرشيف ورقية تُطبع وتُلصق على ملف المحضر أو صندوق الأرشيف.
Future<Uint8List> buildArchiveLabelPdf(
    Report r, Taxpayer? t, String qrData) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'),
  );
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: bold));

  pw.Widget line(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.SizedBox(
              width: 110,
              child: pw.Text('$k:',
                  style: pw.TextStyle(font: bold, fontSize: 10))),
          pw.Expanded(
              child: pw.Text(v.isEmpty ? '.............' : v,
                  style: const pw.TextStyle(fontSize: 10))),
        ]),
      );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.all(20),
      build: (ctx) => pw
          .Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('دائرة الإنفاق الاستهلاكي',
              style: pw.TextStyle(font: bold, fontSize: 12)),
          pw.Text('شعبة الأرشيف',
              style: pw.TextStyle(font: bold, fontSize: 12)),
        ]),
        pw.SizedBox(height: 4),
        pw.Divider(),
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.2)),
            child: pw.Text(
                'بطاقة أرشيف محضر رقم ${r.serial.isEmpty ? '—' : r.serial}',
                style: pw.TextStyle(font: bold, fontSize: 14)),
          ),
        ),
        pw.SizedBox(height: 10),
        line('المنشأة', t?.name ?? ''),
        line('الرقم الضريبي', t?.taxNo ?? ''),
        line('تاريخ المحضر', fmtDate(r.date)),
        line('قيمة الضبط', '${money(r.total)} ل.س'),
        line('الحالة', r.status),
        line('مرجع الملف', r.archiveRef),
        line('رقم الصندوق', r.archiveBox),
        line('عدد المرفقات', '${r.attachments.length}'),
        line('أُرشف بواسطة',
            r.archivedBy.isEmpty ? '.............' : r.archivedBy),
        line(
            'تاريخ الأرشفة',
            r.archivedAt.isEmpty
                ? '.............'
                : fmtDate(DateTime.tryParse(r.archivedAt) ?? DateTime.now())),
        if (r.archiveNotes.isNotEmpty) line('ملاحظات', r.archiveNotes),
        pw.Spacer(),
        pw.Divider(),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('توقيع أمين الأرشيف: ......................',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 8),
                  pw.Text('لا يُخرج الملف من الأرشيف إلا بموجب إخراج موقّع.',
                      style: const pw.TextStyle(fontSize: 8)),
                ]),
          ),
          pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrData,
              width: 72,
              height: 72),
        ]),
      ]),
    ),
  );
  return doc.save();
}
