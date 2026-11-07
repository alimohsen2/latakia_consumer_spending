import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latakia_consumer_spending/data/models.dart';
import 'package:latakia_consumer_spending/screens/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('matches the Word template page size and fits a one-page report',
      () async {
    final report = Report(
      id: 'report-test',
      serial: '123',
      taxpayerId: 'taxpayer-test',
      date: DateTime(2026, 11, 7, 10),
      items: [
        Violation(type: 'عدم إبراز الفواتير', article: '12', fine: 25000),
      ],
    );

    final bytes = await buildReportPdf(report, null);
    final pdf = latin1.decode(bytes, allowInvalid: true);

    expect(pdf, startsWith('%PDF-'));
    expect(
      pdf,
      matches(RegExp(r'/MediaBox\s*\[\s*0\s+0\s+595\.3\s+841\.9\s*\]')),
    );
    expect(pdf, matches(RegExp(r'/Count\s+1\b')));
  });

  test('fits reports with many violations and inspectors on one page',
      () async {
    final report = Report(
      id: 'dense-report-test',
      serial: '124',
      taxpayerId: 'taxpayer-test',
      date: DateTime(2026, 11, 7, 10),
      inspectors: List.generate(12, (index) => 'مراقب ${index + 1}').join('، '),
      items: List.generate(
        24,
        (index) => Violation(
          type: 'مخالفة تجريبية رقم ${index + 1}',
          article: '${index + 1}',
          fine: (index + 1) * 1000,
        ),
      ),
    );

    final bytes = await buildReportPdf(report, null);
    final pdf = latin1.decode(bytes, allowInvalid: true);

    expect(pdf, startsWith('%PDF-'));
    expect(pdf, matches(RegExp(r'/Count\s+1\b')));
  });
}
