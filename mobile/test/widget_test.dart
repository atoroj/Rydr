import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rydr/main.dart';

void main() {
  testWidgets('App arranca correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RydrApp()));
    // La app carga sin errores (verifica que no lance excepciones)
    expect(tester.takeException(), isNull);
  });
}
