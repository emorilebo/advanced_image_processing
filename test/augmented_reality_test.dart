// The class under test is deprecated; these tests pin its no-op contract
// until removal in 0.4.0.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AR calls are safe no-ops that report failure', () async {
    expect(await AugmentedReality.startARSession(), isFalse);
    expect(
      await AugmentedReality.placeModel(
        modelPath: 'assets/models/cube.glb',
        position: [0.0, 0.0, -2.0],
      ),
      isFalse,
    );
    expect(AugmentedReality.isSessionRunning, isFalse);
  });
}
