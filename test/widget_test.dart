// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:dict_ce_view_demo/vocab_service.dart';

void main() {
  test('ebbinghausNextInterval returns expected intervals', () {
    expect(ebbinghausNextInterval(0, 1), 1);
    expect(ebbinghausNextInterval(1, 1), 3);
    expect(ebbinghausNextInterval(2, 1), 7);
    expect(ebbinghausNextInterval(3, 1), 14);
    expect(ebbinghausNextInterval(4, 10), 30);
  });
}
