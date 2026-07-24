import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../providers/insights_provider.dart';

class PdfReportGenerator {
  static Future<Uint8List> generateReportPdf(CustomReportData report) async {
    final pdf = pw.Document();

    final dateFormat = DateFormat('MMM d, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 2);
    final periodStr = '${dateFormat.format(report.startDate)} - ${dateFormat.format(report.endDate)}';
    final generatedStr = dateFormat.format(report.generatedAt);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // ── Header Banner ──
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal900,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BudgetLite Financial Report',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Report Period: $periodStr',
                        style: const pw.TextStyle(
                          color: PdfColors.teal100,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generated',
                        style: const pw.TextStyle(
                          color: PdfColors.teal200,
                          fontSize: 10,
                        ),
                      ),
                      pw.Text(
                        generatedStr,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // ── Summary Cards Grid ──
            pw.Row(
              children: [
                _buildPdfSummaryCard(
                  'Total Income',
                  currencyFormat.format(report.totalIncome),
                  PdfColors.green700,
                  PdfColors.green50,
                ),
                pw.SizedBox(width: 12),
                _buildPdfSummaryCard(
                  'Total Spent',
                  currencyFormat.format(report.totalSpent),
                  PdfColors.red700,
                  PdfColors.red50,
                ),
                pw.SizedBox(width: 12),
                _buildPdfSummaryCard(
                  'Net Savings',
                  currencyFormat.format(report.netSavings),
                  report.netSavings >= 0 ? PdfColors.blue700 : PdfColors.orange700,
                  report.netSavings >= 0 ? PdfColors.blue50 : PdfColors.orange50,
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // ── Secondary Stats Strip ──
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfStatItem('Total Transactions', '${report.transactionCount}'),
                  _buildPdfStatItem('Current No-Spend Streak', '${report.currentNoSpendStreak} days'),
                  _buildPdfStatItem('Longest Streak', '${report.longestNoSpendStreak} days'),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // ── Category Breakdown Table ──
            pw.Text(
              'Spending by Category',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
            pw.SizedBox(height: 8),
            report.byCategory.isEmpty
                ? pw.Text('No category spending recorded for this date range.',
                    style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10))
                : pw.TableHelper.fromTextArray(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
                    cellStyle: const pw.TextStyle(fontSize: 10),
                    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    headers: ['Category', 'Txn Count', 'Amount Spent', '% of Total'],
                    data: report.byCategory.map((c) {
                      final pct = report.totalSpent > 0 ? (c.amount / report.totalSpent * 100) : 0.0;
                      return [
                        c.categoryName,
                        '${c.count}',
                        currencyFormat.format(c.amount),
                        '${pct.toStringAsFixed(1)}%',
                      ];
                    }).toList(),
                  ),
            pw.SizedBox(height: 24),

            // ── Monthly Breakdown Table ──
            if (report.byMonth.isNotEmpty) ...[
              pw.Text(
                'Monthly Summary Breakdown',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                headers: ['Month', 'Income', 'Spent', 'Net Saved', 'Txns'],
                data: report.byMonth.map((m) {
                  final net = m.income - m.spent;
                  return [
                    m.monthLabel,
                    currencyFormat.format(m.income),
                    currencyFormat.format(m.spent),
                    currencyFormat.format(net),
                    '${m.count}',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 24),
            ],

            // ── Footer ──
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated by BudgetLite — Offline-first Budgeting App',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page 1 of 1',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfSummaryCard(
    String title,
    String amount,
    PdfColor textColor,
    PdfColor bgColor,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: textColor, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                color: textColor,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              amount,
              style: pw.TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPdfStatItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }
}
