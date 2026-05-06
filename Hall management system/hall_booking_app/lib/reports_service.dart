import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class ReportsService {
  static Future<List<ChartData>> getRevenueData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/reports/revenue'));
      final data = jsonDecode(response.body) as List;
      return data.map((item) => ChartData(
        item['month'],
        item['revenue']?.toDouble() ?? 0,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Uint8List> generateRevenuePDF(List<ChartData> data) async {
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();
    final PdfTextElement textElement = PdfTextElement()
      ..text = 'Monthly Revenue Report - Shaadi Ghar'
      ..font = PdfStandardFont(PdfFontFamily.helvetica, 20)
      ..brush = PdfSolidBrush(PdfColor(0xFF7C2D47));
    textElement.draw(page: page, bounds: const Rect.fromLTWH(0, 0, 0, 0));

    // Add chart image or data table here
    final table = PdfTable(page);
    table.columns.add(count: 2);
    table.rows.add(view: PdfTableRow([
      PdfTableCell(text: 'Month', font: PdfStandardFont(PdfFontFamily.helvetica, 12)),
      PdfTableCell(text: 'Revenue (PKR)', font: PdfStandardFont(PdfFontFamily.helvetica, 12)),
    ]));

    for (final item in data) {
      table.rows.add(view: PdfTableRow([
        PdfTableCell(text: item.month),
        PdfTableCell(text: item.revenue.toStringAsFixed(0)),
      ]));
    }

    table.draw(page: page, bounds: const Rect.fromLTWH(20, 60, 550, 400));

    final List<int> bytes = await document.save();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> generateBookingsCSV() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/reports/bookings/csv'));
      return response.bodyBytes;
    } catch (e) {
      return Uint8List.fromList('No data'.codeUnits);
    }
  }
}

class ChartData {
  ChartData(this.month, this.revenue);
  final String month;
  final double revenue;
}

