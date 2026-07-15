// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// Importa utilitários de teste de widgets (WidgetTester, matchers, finders).
import 'package:flutter_test/flutter_test.dart';
// Importa o app principal para ser montado no ambiente de teste.
import 'package:gestopro_web/main.dart';

// Ponto de entrada dos testes; o runner do Flutter executa este main.
void main() {
  // Define um teste de widget de fumaça: renderiza o app e não deve falhar.
  testWidgets('GestoPro smoke test', (WidgetTester tester) async {
    // Monta a árvore com o widget raiz da aplicação no ambiente de teste.
    await tester.pumpWidget(const GestoProApp());
  });
}
