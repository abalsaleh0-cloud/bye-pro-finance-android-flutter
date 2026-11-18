import 'package:expense_app/features/ai/data/gemma_model_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Gemma download size estimate', () {
    test('converts progress percentage to an estimated decimal MB counter', () {
      expect(GemmaModelManager.expectedDownloadMegabytes, 2588);
      expect(GemmaModelManager.estimatedDownloadedMegabytes(0), 0);
      expect(GemmaModelManager.estimatedDownloadedMegabytes(50), 1294);
      expect(GemmaModelManager.estimatedDownloadedMegabytes(100), 2588);
    });

    test('clamps invalid progress values to the file size bounds', () {
      expect(GemmaModelManager.estimatedDownloadedMegabytes(-5), 0);
      expect(GemmaModelManager.estimatedDownloadedMegabytes(120), 2588);
    });
  });

  group('Gemma multimodal memory guard', () {
    test('blocks devices below 6 GB RAM', () {
      expect(supportsGemmaMultimodalMemory(4096), isFalse);
      expect(supportsGemmaMultimodalMemory(6143), isFalse);
    });

    test('converts Android RAM bytes to megabytes before checking the 6 GB limit', () {
      expect(physicalRamMegabytesFromBytes(5 * 1024 * 1024 * 1024), 5120);
      expect(physicalRamMegabytesFromBytes(6 * 1024 * 1024 * 1024), 6144);
      expect(
        supportsGemmaMultimodalMemory(
          physicalRamMegabytesFromBytes(5 * 1024 * 1024 * 1024),
        ),
        isFalse,
      );
      expect(
        supportsGemmaMultimodalMemory(
          physicalRamMegabytesFromBytes(6 * 1024 * 1024 * 1024),
        ),
        isTrue,
      );
    });

    test('allows devices with at least 6 GB RAM or unknown RAM', () {
      expect(supportsGemmaMultimodalMemory(6144), isTrue);
      expect(supportsGemmaMultimodalMemory(8192), isTrue);
      expect(supportsGemmaMultimodalMemory(0), isFalse);
    });
  });

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
