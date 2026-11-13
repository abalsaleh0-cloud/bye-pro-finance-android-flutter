import 'package:expense_app/features/ai/data/gemma_model_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelReleaseCoordinator', () {
    test('defers release until the active inference operation finishes', () async {
      final coordinator = ModelReleaseCoordinator();
      var released = false;
      coordinator.beginOperation();

      final releaseFuture = coordinator.requestRelease(() async {
        released = true;
      });

      expect(released, isFalse);
      await coordinator.finishOperation(() async {
        released = true;
      });
      await releaseFuture;

      expect(released, isTrue);
    });

    test('releases immediately when no inference operation is active', () async {
      final coordinator = ModelReleaseCoordinator();
      var released = false;

      await coordinator.requestRelease(() async {
        released = true;
      });

      expect(released, isTrue);
    });

    test('waits for all active operations before releasing', () async {
      final coordinator = ModelReleaseCoordinator();
      var released = false;
      coordinator.beginOperation();
      coordinator.beginOperation();

      final releaseFuture = coordinator.requestRelease(() async {
        released = true;
      });
      await coordinator.finishOperation(() async {
        released = true;
      });
      expect(released, isFalse);

      await coordinator.finishOperation(() async {
        released = true;
      });
      await releaseFuture;
      expect(released, isTrue);
    });
  });
}
