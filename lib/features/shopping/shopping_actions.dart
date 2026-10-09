import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> shareShopping(BuildContext context, String text) async {
  try {
    await SharePlus.instance.share(
      ShareParams(text: text, title: 'DinnerMap shopping list'),
    );
  } catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sharing is unavailable: $e. Use Copy list or export instead.',
          ),
        ),
      );
  }
}

Future<void> printShopping(BuildContext context, String text) async {
  try {
    final printable = text
        .replaceAll('•', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('⅓', '1/3')
        .replaceAll('⅔', '2/3')
        .replaceAll('⅛', '1/8')
        .replaceAll('⅜', '3/8')
        .replaceAll('⅝', '5/8')
        .replaceAll('⅞', '7/8');
    await Printing.layoutPdf(
      name: 'DinnerMap shopping list',
      onLayout: (format) async {
        final document = pw.Document();
        document.addPage(
          pw.MultiPage(
            pageFormat: format,
            build: (_) => [
              pw.Text(
                'DinnerMap',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              ...printable
                  .split('\n')
                  .map(
                    (line) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 5),
                      child: pw.Text(
                        line,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
            ],
          ),
        );
        return document.save();
      },
    );
  } catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Printing failed: $e. Export TXT or CSV instead.'),
        ),
      );
  }
}
