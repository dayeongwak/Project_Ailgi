import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/main.dart';

void main() {
  testWidgets('앱이 CalendarPage로 실행되는지 확인', (WidgetTester tester) async {
    // 앱 실행
    await tester.pumpWidget(const my_app());

    // CalendarPage의 제목이 보이는지 확인
    expect(find.text('Ailgi Calendar'), findsOneWidget);

    // 달력 위젯(TableCalendar)이 표시되는지 확인
    expect(find.byType(GridView), findsWidgets); // TableCalendar 내부는 Grid로 렌더링됨
  });
}
