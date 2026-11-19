import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/render_warm_up.dart';

// The first start's head start for the GPU: it draws its scene off screen
// and finishes, whatever it meets.
void main() {
  testWidgets('draws its scene off screen and finishes', (tester) async {
    await tester.runAsync(RenderWarmUp.run);
  });
}
