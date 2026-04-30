import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  Future<void> shareInvoicePdf({
    required String guestName,
    required String roomNumber,
    required String period,
    required int baseAmount,
    required int cgst,
    required int sgst,
    required int totalWithGst,
    required bool gstEnabled,
    int? mealPlanAmount,
    String? mealPlanName,
    required String status,
    String? paidAt,
    String? paymentMethod,
    String? hostelName,
    String? gstin,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('INVOICE',
                          style: pw.TextStyle(
                              fontSize: 26,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal)),
                      if (hostelName != null && hostelName.isNotEmpty)
                        pw.Text(hostelName,
                            style: const pw.TextStyle(fontSize: 13)),
                      if (gstin != null && gstin.isNotEmpty)
                        pw.Text('GSTIN: $gstin',
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                          color: status == 'paid'
                              ? PdfColors.green
                              : PdfColors.orange),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      status.toUpperCase(),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: status == 'paid'
                              ? PdfColors.green
                              : PdfColors.orange),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 16),
              // Bill to / period
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILLED TO',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey600,
                                letterSpacing: 1)),
                        pw.SizedBox(height: 4),
                        pw.Text(guestName,
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold)),
                        pw.Text('Room $roomNumber',
                            style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('PERIOD',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey600,
                                letterSpacing: 1)),
                        pw.SizedBox(height: 4),
                        pw.Text(period,
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold)),
                        if (paidAt != null && status == 'paid') ...[
                          pw.Text('Paid: $paidAt',
                              style: const pw.TextStyle(fontSize: 11)),
                          if (paymentMethod != null)
                            pw.Text(
                                'Via ${paymentMethod.toUpperCase()}',
                                style: const pw.TextStyle(fontSize: 11)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              // Line items
              pw.Table(
                border: pw.TableBorder.all(
                    color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.teal),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Description',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Amount',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11)),
                      ),
                    ],
                  ),
                  // Rent row
                  pw.TableRow(children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Monthly Rent',
                          style: const pw.TextStyle(fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Rs. $baseAmount',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 11)),
                    ),
                  ]),
                  // Meal plan
                  if (mealPlanAmount != null && mealPlanAmount > 0)
                    pw.TableRow(children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                            'Meal Plan${mealPlanName != null ? " – $mealPlanName" : ""}',
                            style: const pw.TextStyle(fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Rs. $mealPlanAmount',
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 11)),
                      ),
                    ]),
                  // GST rows
                  if (gstEnabled) ...[
                    pw.TableRow(children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('CGST (9%)',
                            style: const pw.TextStyle(fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Rs. $cgst',
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 11)),
                      ),
                    ]),
                    pw.TableRow(children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('SGST (9%)',
                            style: const pw.TextStyle(fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Rs. $sgst',
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 11)),
                      ),
                    ]),
                  ],
                  // Total row
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.teal50),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('TOTAL',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Rs. $totalWithGst',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 32),
              pw.Divider(color: PdfColors.grey200),
              pw.SizedBox(height: 8),
              pw.Text(
                'Generated by Sanctuary Hostel Management',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey400),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Invoice_${guestName.replaceAll(' ', '_')}_$period.pdf',
    );
  }
}
