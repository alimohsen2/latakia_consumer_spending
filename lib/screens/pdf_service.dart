import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/util.dart';
import '../data/models.dart';

/// يبني محضر الضبط بصيغة PDF وفق نموذج المحضر المعتمد.
/// يحمّل خط Tajawal من الإنترنت عند أول استخدام. لخط محلي ضع الملف في assets واستخدم pw.Font.ttf.
Future<Uint8List> buildReportPdf(Report r, Taxpayer? t) async {
  final font = await PdfGoogleFonts.tajawalRegular();
  final bold = await PdfGoogleFonts.tajawalBold();
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: bold));
  final bodyStyle = pw.TextStyle(font: font, fontSize: 10);
  const blank = '..........';
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
  final taxpayerName = t?.name.isNotEmpty == true ? t!.name : blank;
  final taxpayerAddress = t?.address.isNotEmpty == true ? t!.address : blank;
  final taxpayerOwner = t?.owner.isNotEmpty == true ? t!.owner : blank;
  final taxpayerProfession =
      t?.profession.isNotEmpty == true ? t!.profession : blank;

  pw.Widget signatureLine(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(label, style: bodyStyle),
            if (value.isNotEmpty) pw.Text(value, style: bodyStyle),
            pw.SizedBox(height: 15),
          ],
        ),
      );
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    textDirection: pw.TextDirection.rtl,
    margin: const pw.EdgeInsets.symmetric(horizontal: 34, vertical: 30),
    theme: pw.ThemeData.withFont(base: font, bold: bold),
    build: (ctx) => [
      pw.Table(
        border: pw.TableBorder.all(width: .7),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(7),
              child: pw.Column(
                children: [
                  for (final line in [
                    'الجمهورية العربية السورية',
                    'وزارة المالية',
                    'الهيئة العامة للضرائب والرسوم',
                    'مديرية مالية ..........',
                    'قسم الواردات',
                    'دائرة الإنفاق الاستهلاكي',
                  ])
                    pw.Text(line,
                        style: bodyStyle, textAlign: pw.TextAlign.center),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(7),
              child: pw.Text('رقم  ${r.serial.isEmpty ? blank : r.serial}',
                  style: bodyStyle, textAlign: pw.TextAlign.center),
            ),
          ]),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Center(
        child: pw.Text(
          'محضر ضبط مخالفة المرسوم التشريعي رقم /11/ لعام 2015',
          style: pw.TextStyle(font: bold, fontSize: 14),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'في تمام الساعة $time من $dayPeriod يوم $weekday الواقع في ${dateParts[2]} من شهر ${dateParts[1]} لعام ${dateParts[0]}',
        style: bodyStyle,
      ),
      pw.SizedBox(height: 5),
      pw.Text(
        'نحن الموقعون أدناه العاملون في دائرة الإنفاق الاستهلاكي لدى مديرية مالية محافظة .......... بناء على الأمر الإداري رقم ${r.orderNo.isEmpty ? blank : r.orderNo} تاريخ ${r.orderDate.isEmpty ? blank : r.orderDate} الصادر عن السيد مدير المالية وأثناء جولتنا الميدانية لمراقبة تنفيذ أحكام المرسوم التشريعي رقم /11/ لعام 2015 م لدى منشأة $taxpayerName الكائنة في $taxpayerAddress المسجلة باسم السيد $taxpayerOwner والذي يمارس مهنة $taxpayerProfession وبنتيجة تدقيق الفواتير والسجلات العائدة للمومأ إليه وحساب الرسم تبين ما يلي:',
        textAlign: pw.TextAlign.justify,
        style: bodyStyle,
      ),
      pw.SizedBox(height: 7),
      pw.Table(
        border: pw.TableBorder.all(width: .6),
        columnWidths: {0: const pw.FlexColumnWidth(1)},
        children: [
          for (var index = 0;
              index < (r.items.length > 13 ? r.items.length : 13);
              index++)
            pw.TableRow(children: [
              pw.Container(
                height: 23,
                alignment: pw.Alignment.centerRight,
                padding: const pw.EdgeInsets.symmetric(horizontal: 5),
                child: pw.Text(
                  index < r.items.length ? r.items[index].type : '',
                  style: bodyStyle,
                ),
              ),
            ]),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        'تلي المحضر على السيد ${r.servedName.isEmpty ? blank : r.servedName} بصفته ${r.servedCapacity.isEmpty ? blank : r.servedCapacity} للمنشأة المذكورة فتفهم وأقر بما ورد فيه وبناءً عليه تم ختم المحضر أصولاً في تمام الساعة .......... من يوم .......... الواقع في .......... من شهر .......... لعام ..........',
        textAlign: pw.TextAlign.justify,
        style: bodyStyle,
      ),
      pw.SizedBox(height: 6),
      pw.Table(
        border: pw.TableBorder.all(width: .7),
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(7),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(
                    'المتبلغ : ${r.servedName.isEmpty ? blank : r.servedName}',
                    style: bodyStyle,
                  ),
                  pw.Text(
                    'الصفة : ${r.servedCapacity.isEmpty ? blank : r.servedCapacity}',
                    style: bodyStyle,
                  ),
                  pw.Text(
                    'الأب : ${r.servedFather.isEmpty ? blank : r.servedFather}   الأم : ${r.servedMother.isEmpty ? blank : r.servedMother}',
                    style: bodyStyle,
                  ),
                  pw.Text(
                    'الرقم الوطني / ${r.servedNationalNo.isEmpty ? blank : r.servedNationalNo}',
                    style: bodyStyle,
                  ),
                  pw.SizedBox(height: 15),
                  pw.Text('التوقيع :', style: bodyStyle),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(7),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  signatureLine('اسم المراقب وتوقيعه', r.inspectors),
                  signatureLine('اسم المراقب وتوقيعه', ''),
                  signatureLine('رئيس الشعبة الميدانية وتوقيعه', r.fieldHead),
                  signatureLine(
                      'رئيس دائرة الإنفاق الإستهلاكي وتوقيعه', r.deptHead),
                ],
              ),
            ),
          ]),
        ],
      ),
      pw.SizedBox(height: 7),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                    'يحق للمكلف الاعتراض على الضبط خلال سبعة أيام من التاريخ الذي يلي تاريخ تبلغه الضبط',
                    style: bodyStyle),
                pw.Text(
                    'ينظم المحضر على ثلاث نسخ، الأولى للدوائر المالية ترفق مع تقرير الجولة الميدانية والثانية للمكلف والثالثة تعتبر أرومة.',
                    style: bodyStyle),
              ]),
        ),
      ]),
    ],
  ));
  return doc.save();
}

Future<void> printReportPdf(Uint8List bytes, String name) =>
    Printing.layoutPdf(onLayout: (_) async => bytes, name: name);

/// بطاقة أرشيف ورقية تُطبع وتُلصق على ملف المحضر أو صندوق الأرشيف.
Future<Uint8List> buildArchiveLabelPdf(
    Report r, Taxpayer? t, String qrData) async {
  final font = await PdfGoogleFonts.tajawalRegular();
  final bold = await PdfGoogleFonts.tajawalBold();
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
