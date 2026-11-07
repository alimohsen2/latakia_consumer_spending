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
/// يُوضع داخل [pw.FittedBox]، فإن تجاوز مساحة النموذج صُغّر بنسبة تحافظ على
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
  const grey = PdfColor.fromInt(0xFF555555);
  const rule = PdfColor.fromInt(0xFFB9C2BE);
  const violationRule = PdfColor.fromInt(0xFF555555);

  String value(String? v) => (v == null || v.trim().isEmpty) ? blank : v.trim();

  final dateParts = fmtDate(r.date).split('/');
  final time = fmtTime12(r.date);
  const weekdays = [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];
  final weekday = weekdays[r.date.weekday % 7];

  final taxpayerName = value(t?.name);
  final taxpayerAddress = value(t?.address);
  final taxpayerOwner = value(t?.owner);
  final taxpayerProfession = value(t?.profession);

  // ---- أحجام متكيّفة مع عدد المخالفات وعدد المراقبين ----
  final violationCount = math.max(r.items.length, 13);
  final violationRowHeight = violationCount <= 13
      ? 20.0
      : violationCount <= 18
          ? 16.0
          : 13.5;

  final inspectorNames = _splitInspectors(r.inspectors);
  final inspectorSlots = math.max(inspectorNames.length, 2);
  const inspectorColumns = 2;
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
  final body = pw.TextStyle(font: font, fontSize: 12, lineSpacing: 6);
  final headerStyle = pw.TextStyle(font: bold, fontSize: 12, lineSpacing: 1.5);
  final dateStyle = pw.TextStyle(font: font, fontSize: 12, lineSpacing: 3);
  final signatureStyle = pw.TextStyle(font: bold, fontSize: 12, lineSpacing: 3);
  final smallBold = pw.TextStyle(font: bold, fontSize: 10.5, lineSpacing: 1.4);
  final tiny = pw.TextStyle(font: font, fontSize: 9, lineSpacing: 1.2);
  final footerNote = pw.TextStyle(font: bold, fontSize: 10, lineSpacing: 5);
  final servedStyle = pw.TextStyle(font: bold, fontSize: 12, lineSpacing: 3);
  final violationText = pw.TextStyle(font: font, fontSize: 10, lineSpacing: 1);
  final violationAmount =
      pw.TextStyle(font: bold, fontSize: 10, lineSpacing: 1);

  // ---- الترويسة ----
  final header = pw.Table(
    columnWidths: {
      0: const pw.FlexColumnWidth(1),
      1: const pw.FlexColumnWidth(2),
    },
    children: [
      pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.top,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsetsDirectional.only(start: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'رقم  ${r.serial.trim().isEmpty ? blank : r.serial.trim()}',
                  style: headerStyle,
                ),
                pw.SizedBox(height: 2),
                pw.Container(width: 74, height: .7, color: rule),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(right: 10),
            child: pw.Column(
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
                  pw.Text(line, style: headerStyle),
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
                    style: violationText,
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
                    style: violationAmount,
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
      bottom: const pw.BorderSide(
        width: .6,
        color: violationRule,
        style: pw.BorderStyle.dotted,
      ),
      horizontalInside: const pw.BorderSide(
        width: .6,
        color: violationRule,
        style: pw.BorderStyle.dotted,
      ),
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
          pw.Text(title, style: signatureStyle, textAlign: pw.TextAlign.center),
          if (caption != null)
            pw.Text(
              caption,
              style: signatureStyle,
              textAlign: pw.TextAlign.center,
            ),
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
      pw.Align(
        alignment: pw.AlignmentDirectional.center,
        child: pw.SizedBox(width: 275, child: inspectorGrid()),
      ),
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
                title: 'مصدّق',
                caption: 'رئيس دائرة الإنفاق الاستهلاكي',
                name: r.deptHead,
                height: authorityRowHeight,
              ),
              signatureCell(
                title: 'رئيس الشعبة الميدانية وتوقيعه',
                name: r.fieldHead,
                height: authorityRowHeight,
              ),
            ],
          ),
        ],
      ),
    ],
  );

  final servedBlock = pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(width: 1, color: PdfColors.black),
    ),
    padding: const pw.EdgeInsetsDirectional.only(
      start: 16,
      end: 24,
      top: 16,
      bottom: 16,
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('المتبلغ : ${value(r.servedName)}', style: servedStyle),
        pw.SizedBox(height: 6),
        pw.Text('الصفة : ${value(r.servedCapacity)}', style: servedStyle),
        pw.SizedBox(height: 6),
        pw.Text(
          'الأب : ${value(r.servedFather)}   الأم : ${value(r.servedMother)}',
          style: servedStyle,
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'الرقم الوطني / ${value(r.servedNationalNo)}',
          style: servedStyle,
        ),
        pw.SizedBox(height: 6),
        pw.Text('التوقيع :', style: servedStyle),
        pw.SizedBox(height: 28),
      ],
    ),
  );

  final servedAndSignatures = pw.Table(
    columnWidths: {
      0: const pw.FlexColumnWidth(58),
      1: const pw.FlexColumnWidth(42),
    },
    children: [
      pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.top,
        children: [signatureBlock, servedBlock],
      ),
    ],
  );

  const reportPageFormat = PdfPageFormat(595.3, 841.9);
  const pageMargin = pw.EdgeInsets.fromLTRB(50, 35, 50, 30);
  final contentWidth =
      reportPageFormat.width - pageMargin.left - pageMargin.right;

  doc.addPage(
    pw.Page(
      pageFormat: reportPageFormat,
      margin: pageMargin,
      textDirection: pw.TextDirection.rtl,
      theme: theme,
      build: (context) => pw.FittedBox(
        fit: pw.BoxFit.contain,
        alignment: pw.Alignment.topCenter,
        child: pw.SizedBox(
          width: contentWidth,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(right: 12),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                header,
                pw.SizedBox(height: 12),
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
                pw.SizedBox(height: 10),
                pw.Text(
                  'في تمام الساعة $time يوم $weekday الواقع في '
                  '${dateParts[2]} من شهر ${dateParts[1]} لعام ${dateParts[0]}',
                  style: dateStyle,
                ),
                pw.SizedBox(height: 3),
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
                pw.SizedBox(height: 3),
                violationsTable,
                pw.SizedBox(height: 10),
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
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(width: 1, color: PdfColors.black),
                    ),
                  ),
                  child: pw.Text(
                    'يحق للمكلف الاعتراض على الضبط خلال سبعة أيام من التاريخ الذي يلي تاريخ تبلغه الضبط',
                    style: signatureStyle,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'ينظم المحضر على ثلاث نسخ، الأولى للدوائر المالية ترفق مع تقرير الجولة الميدانية '
                  'والثانية للمكلف والثالثة تعتبر أرومة.',
                  style: footerNote,
                ),
              ],
            ),
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
