import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gf2_wiki/ui/theme.dart';
import 'package:gf2_wiki/ui/widgets/common.dart';

void main() {
  testWidgets('Theme và widget cơ bản dựng được', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(
        body: Column(
          children: [
            Tag('精英人形', color: AppColors.rarityElite, icon: Icons.star_rounded),
            CornerBadge(1),
            EmptyState(message: 'Không có kết quả'),
          ],
        ),
      ),
    ));
    expect(find.text('精英人形'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('Không có kết quả'), findsOneWidget);
  });
}
