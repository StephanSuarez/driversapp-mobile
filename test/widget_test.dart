import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driversapp/main.dart';

void main() {
  testWidgets('Verifica el arranque de DriversAppApp y el EnrutadorInicial', (WidgetTester tester) async {
    await tester.pumpWidget(const DriversAppApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}