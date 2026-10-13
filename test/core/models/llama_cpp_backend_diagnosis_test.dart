import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/llama_cpp_backend.dart';

void main() {
  // "No device" and "the probe failed" are different problems with different
  // fixes. Collapsing them is what sends people looking for a phone that
  // already has an Adreno in it.
  group('accelerator diagnosis', () {
    test('an available backend needs no explanation', () {
      const result = LlamaCppDeviceProbeResult(
        openclDeviceName: 'Adreno (TM) 825',
      );
      final diagnosis = result.diagnose(LlamaCppBackend.opencl);
      expect(diagnosis.isAvailable, isTrue);
      expect(diagnosis.hint, isNull);
    });

    test('CPU is always available', () {
      const result = LlamaCppDeviceProbeResult();
      expect(result.diagnose(LlamaCppBackend.cpu).isAvailable, isTrue);
    });

    test('OpenCL with no platforms is not the same as no OpenCL', () {
      // The exact log from the device this was reported on.
      const result = LlamaCppDeviceProbeResult(
        rawOutput: 'ggml_opencl: platform IDs not available.\n',
      );
      final diagnosis = result.diagnose(LlamaCppBackend.opencl);

      expect(diagnosis.isAvailable, isFalse);
      expect(diagnosis.status, AcceleratorStatus.noDevicesFound);
      expect(diagnosis.reason, contains('platform IDs'));
      // The hardware is there; the loader just found no ICD to talk to.
      expect(diagnosis.hint, contains('ICD'));
    });

    // A stub shipped in the APK would link and export nothing, which is the
    // single most likely cause on a device that plainly has a GPU.
    test('a libOpenCL.so that would not load is a probe failure', () {
      const result = LlamaCppDeviceProbeResult(
        rawOutput:
            'ggml_opencl: failed to load libOpenCL.so: cannot locate symbol\n',
      );
      final diagnosis = result.diagnose(LlamaCppBackend.opencl);

      expect(diagnosis.status, AcceleratorStatus.probeFailed);
      expect(diagnosis.hint, contains('stub'));
    });

    // Recorded verbatim from the same device. The symbol moved between NDK
    // versions, so a build expecting the new one fails on the old library.
    test('the Hexagon symbol failure is named exactly', () {
      const result = LlamaCppDeviceProbeResult(
        rawOutput:
            '/vendor/lib64/libcdsprpc.so: undefined symbol: '
            'android::binder2os::get_trace_enabled_tags()\n',
      );
      final diagnosis = result.diagnose(LlamaCppBackend.hexagon);

      expect(diagnosis.status, AcceleratorStatus.probeFailed);
      expect(diagnosis.reason, contains('get_trace_enabled_tags'));
      expect(diagnosis.hint, contains('NDK'));
    });

    test('a probe that could not run at all says so', () {
      const result = LlamaCppDeviceProbeResult(error: 'ProcessException');
      final diagnosis = result.diagnose(LlamaCppBackend.hexagon);

      expect(diagnosis.status, AcceleratorStatus.probeFailed);
      expect(diagnosis.reason, 'ProcessException');
    });

    test('an unrecognised failure still points at the raw output', () {
      const result = LlamaCppDeviceProbeResult(rawOutput: 'something odd');
      final diagnosis = result.diagnose(LlamaCppBackend.opencl);

      expect(diagnosis.isAvailable, isFalse);
      expect(diagnosis.hint, contains('probe output'));
    });

    test('a backend that works is not diagnosed by another failure', () {
      // The raw output may mention a broken OpenCL while Hexagon is fine.
      const result = LlamaCppDeviceProbeResult(
        hexagonDeviceName: 'Qualcomm HTP (QNN)',
        rawOutput: 'ggml_opencl: platform IDs not available.',
      );
      expect(result.diagnose(LlamaCppBackend.hexagon).isAvailable, isTrue);
      expect(result.diagnose(LlamaCppBackend.opencl).isAvailable, isFalse);
    });
  });

  group('resolve', () {
    test('falls back to CPU when the wanted backend is not there', () {
      const result = LlamaCppDeviceProbeResult(
        rawOutput: 'ggml_opencl: platform IDs not available.',
      );
      expect(
        result.resolve(LlamaCppBackend.opencl),
        LlamaCppBackend.cpu,
      );
    });

    test('keeps a backend that is available', () {
      const result = LlamaCppDeviceProbeResult(
        hexagonDeviceName: 'Qualcomm HTP (QNN)',
      );
      expect(result.resolve(LlamaCppBackend.hexagon), LlamaCppBackend.hexagon);
    });
  });
}
