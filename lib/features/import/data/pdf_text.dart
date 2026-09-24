import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Lo que sale de un PDF: sus líneas de texto en orden de lectura y cuántas
/// páginas tenía. `lines` vacío con `pages > 0` es un PDF escaneado como
/// imagen: hay páginas pero no hay texto que leer.
class PdfTextResult {
  const PdfTextResult({
    required this.lines,
    required this.pages,
    this.positioned = const [],
    this.layout = '',
  });

  final List<String> lines;
  final int pages;

  /// Líneas con coordenadas, útil para parsers que necesitan la posición X
  /// (por ejemplo, para distinguir columnas de día en una tabla de horario).
  final List<PositionedLine> positioned;

  /// El texto con la disposición de la página (columnas alineadas con
  /// espacios). Es lo que se manda a Claude: en una retícula, la columna de
  /// cada celda dice el día, y en `lines` esa información se pierde.
  final String layout;

  bool get hasText => lines.any((l) => l.trim().isNotEmpty);
}

/// Una línea de texto con su posición en la página.
class PositionedLine {
  const PositionedLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.pageIndex,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final int pageIndex;
}

/// Espacios que no son el espacio normal: NBSP, espacios tipográficos y el
/// separador de palabra. Los PDF de servicios académicos los usan para alinear
/// columnas, y un `split(' ')` o un `startsWith('Aula. ')` fallan en silencio
/// si no se normalizan aquí.
final RegExp _exoticSpace = RegExp(r'[\u00a0\u1680\u2000-\u200a\u202f\u205f\u3000\ufeff]');

/// Deja una línea con espacios normales y sin relleno en los extremos.
String normalizeSpaces(String raw) =>
    raw.replaceAll(_exoticSpace, ' ').replaceAll(RegExp(r'[ \t]+'), ' ').trim();

/// Se lanza cuando el archivo no es un PDF legible (dañado, cifrado, o no es
/// un PDF).
class PdfUnreadableException implements Exception {
  const PdfUnreadableException(this.cause);
  final Object cause;

  @override
  String toString() => 'PdfUnreadableException: $cause';
}

/// Extrae el texto en el teléfono. Syncfusion es Dart puro, así que corre en
/// un isolate con `compute` y la interfaz no se congela con un PDF gordo.
abstract final class PdfText {
  static Future<PdfTextResult> extract(Uint8List bytes) => compute(_extract, bytes);

  static PdfTextResult _extract(Uint8List bytes) {
    final PdfDocument doc;
    try {
      doc = PdfDocument(inputBytes: bytes);
    } catch (e) {
      throw PdfUnreadableException(e);
    }
    try {
      final pages = doc.pages.count;
      final textLines = PdfTextExtractor(doc).extractTextLines();

      // Orden de lectura: página, luego de arriba abajo, luego de izquierda a
      // derecha. El extractor ya agrupa por renglón; solo hay que ordenarlos.
      textLines.sort((a, b) {
        if (a.pageIndex != b.pageIndex) return a.pageIndex.compareTo(b.pageIndex);
        final dy = a.bounds.top.compareTo(b.bounds.top);
        if (dy != 0) return dy;
        return a.bounds.left.compareTo(b.bounds.left);
      });

      // Guardamos la posición de cada línea para que el parser de columnas
      // pueda asignar cada celda al día correcto según su coordenada X.
      final positioned = textLines
          .where((l) => normalizeSpaces(l.text).isNotEmpty)
          .map((l) => PositionedLine(
                text: normalizeSpaces(l.text),
                left: l.bounds.left,
                top: l.bounds.top,
                right: l.bounds.right,
                pageIndex: l.pageIndex,
              ))
          .toList();

      var lines = textLines.map((l) => normalizeSpaces(l.text)).where((t) => t.isNotEmpty).toList();

      final plain = PdfTextExtractor(doc).extractText(layoutText: true);

      // Algunos PDF no traen estructura de renglón y el extractor devuelve una
      // sola línea por página. En ese caso el texto plano parte mejor.
      if (lines.length <= pages) {
        final split = plain
            .split(RegExp(r'\r?\n'))
            .map(normalizeSpaces)
            .where((l) => l.isNotEmpty)
            .toList();
        if (split.length > lines.length) lines = split;
      }

      return PdfTextResult(
        lines: lines,
        pages: pages,
        positioned: positioned,
        layout: plain.replaceAll(_exoticSpace, ' '),
      );
    } finally {
      doc.dispose();
    }
  }
}
