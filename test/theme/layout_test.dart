import 'package:kairos/theme/layout.dart';
import 'package:kairos/theme/tokens.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SizeClass', () {
    test('el marco del diseño es compacto', () {
      expect(SizeClass.forWidth(LayoutTokens.designWidth), SizeClass.compact);
    });

    test('los cortes del contrato son inclusivos por abajo', () {
      expect(SizeClass.forWidth(LayoutTokens.breakpointMedium - 1), SizeClass.compact);
      expect(SizeClass.forWidth(LayoutTokens.breakpointMedium), SizeClass.medium);
      expect(SizeClass.forWidth(LayoutTokens.breakpointExpanded - 1), SizeClass.medium);
      expect(SizeClass.forWidth(LayoutTokens.breakpointExpanded), SizeClass.expanded);
    });

    test('el riel entra en medium; los dos paneles solo en expanded', () {
      expect(SizeClass.compact.hasRail, isFalse);
      expect(SizeClass.medium.hasRail, isTrue);
      expect(SizeClass.medium.isExpanded, isFalse);
      expect(SizeClass.expanded.isExpanded, isTrue);
    });
  });
}
