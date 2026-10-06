import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillnote/widgets/app_ui.dart';

void main() {
  testWidgets(
    'title size stays fixed while the heading collapses and stays pinned',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageScrollView(
              title: '주변 약국',
              subtitle: '지도에서 찾고, 방문 전에 확인해요.',
              controller: controller,
              trailing: IconButton(
                tooltip: '지역 선택',
                onPressed: () => tapped = true,
                icon: const Icon(Icons.location_on_outlined),
              ),
              children: const [SizedBox(height: 1800)],
            ),
          ),
        ),
      );
      final title = find.byKey(const ValueKey('page-title-주변 약국'));
      final subtitle = find.byKey(const ValueKey('page-subtitle-주변 약국'));
      double fontSize() => tester.widget<Text>(title).style!.fontSize!;
      double opacity() => tester.widget<Opacity>(subtitle).opacity;
      expect(fontSize(), 30);
      expect(opacity(), 1);
      final initialLeft = tester.getTopLeft(title).dx;

      controller.jumpTo(24);
      await tester.pump();
      expect(fontSize(), 30);
      expect(opacity(), allOf(greaterThan(0), lessThan(1)));

      controller.jumpTo(200);
      await tester.pump();
      expect(fontSize(), 30);
      expect(opacity(), 0);
      final pinnedPosition = tester.getTopLeft(title);
      expect(pinnedPosition.dx, initialLeft);
      expect(pinnedPosition.dy, lessThan(24));
      controller.jumpTo(650);
      await tester.pump();
      expect(tester.getTopLeft(title), pinnedPosition);
      await tester.tap(find.byTooltip('지역 선택'));
      expect(tapped, isTrue);

      controller.jumpTo(0);
      await tester.pump();
      expect(fontSize(), 30);
      expect(opacity(), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('short pages stay still for drag and bouncing scroll behavior', (
    tester,
  ) async {
    for (final physics in const [
      ClampingScrollPhysics(),
      BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
    ]) {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageScrollView(
              title: '주변 약국',
              subtitle: '지도에서 찾고, 방문 전에 확인해요.',
              controller: controller,
              physics: physics,
              children: const [Text('가까운 약국 0곳')],
            ),
          ),
        ),
      );
      expect(controller.position.maxScrollExtent, 0);
      final title = find.byKey(const ValueKey('page-title-주변 약국'));
      final initialPosition = tester.getTopLeft(title);
      for (final delta in [120.0, -120.0]) {
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CustomScrollView)),
        );
        await gesture.moveBy(Offset(0, delta));
        await tester.pump();
        // Check during the gesture too: a bounce could settle back to zero.
        expect(controller.offset, 0, reason: '$physics');
        expect(tester.getTopLeft(title), initialPosition);
        await gesture.up();
        await tester.pumpAndSettle();
      }
      expect(tester.widget<Text>(title).style!.fontSize, 30);
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('page-subtitle-주변 약국')))
            .opacity,
        1,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'large text enables scrolling and shrinking it locks the page again',
    (tester) async {
      final controller = ScrollController();
      final scale = ValueNotifier<double>(1);
      addTearDown(controller.dispose);
      addTearDown(scale.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<double>(
            valueListenable: scale,
            builder: (context, value, _) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(value)),
              child: Scaffold(
                body: PageScrollView(
                  title: '내 약 상자',
                  subtitle: '약과 복용 일정을 한눈에 확인해요.',
                  controller: controller,
                  children: List.generate(
                    8,
                    (_) => const Text(
                      '등록한 약의 복용 일정과 수량을 확인해요.',
                      style: TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(controller.position.maxScrollExtent, 0);
      scale.value = 3;
      await tester.pumpAndSettle();
      expect(controller.position.maxScrollExtent, greaterThan(0));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      scale.value = 1;
      await tester.pumpAndSettle();
      expect(controller.position.maxScrollExtent, 0);
      expect(controller.offset, 0);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('page-title-내 약 상자')))
            .style!
            .fontSize,
        30,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'nested content scroll does not collapse the outer page heading',
    (tester) async {
      final nested = ScrollController();
      final outer = ScrollController();
      addTearDown(nested.dispose);
      addTearDown(outer.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageScrollView(
              title: '주변 약국',
              subtitle: '지도에서 찾고, 방문 전에 확인해요.',
              controller: outer,
              children: [
                SizedBox(
                  height: 200,
                  child: ListView(
                    controller: nested,
                    children: const [SizedBox(height: 1000)],
                  ),
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(nested.offset, greaterThan(0));
      expect(outer.offset, 0);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('page-title-주변 약국')))
            .style!
            .fontSize,
        30,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long headings fit large text and the safe area at every stage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    const heading = '약 묶음 만들기';
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: 32),
            textScaler: TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: PageScrollView(
            title: heading,
            subtitle: '함께 복용하는 약과 공통 일정을 정해요. 글자가 커도 모든 안내를 읽을 수 있어요.',
            trailing: IconButton(
              tooltip: '묶음 삭제',
              onPressed: () {},
              icon: const Icon(Icons.delete_outline),
            ),
            controller: controller,
            children: const [SizedBox(height: 2000)],
          ),
        ),
      ),
    );
    final title = find.byKey(const ValueKey('page-title-$heading'));
    final subtitle = find.text(
      '함께 복용하는 약과 공통 일정을 정해요. 글자가 커도 모든 안내를 읽을 수 있어요.',
    );
    final header = find
        .descendant(
          of: find.byType(SliverPersistentHeader),
          matching: find.byType(ClipRect),
        )
        .first;
    expect(
      tester.getBottomLeft(subtitle).dy,
      lessThanOrEqualTo(tester.getBottomLeft(header).dy),
    );
    for (final offset in [30.0, 70.0, 300.0, 700.0, 0.0]) {
      controller.jumpTo(offset);
      await tester.pump();
      expect(tester.widget<Text>(title).style!.fontSize, 30);
      expect(tester.getTopLeft(title).dy, greaterThanOrEqualTo(32));
      expect(
        tester.getBottomLeft(title).dy,
        lessThanOrEqualTo(tester.getBottomLeft(header).dy),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
