enum LlamaCppBackend { cpu, opencl, hexagon }

/// What went wrong with an accelerator the user asked for.
enum AcceleratorStatus {
  available,

  /// The probe ran and reported no device.
  noDevicesFound,

  /// The probe ran and something failed on the way: a missing symbol, a
  /// library that would not load. Distinct from "no device" because the
  /// hardware may well be there.
  probeFailed,
}

/// A failure the user can act on, as opposed to a boolean.
class AcceleratorDiagnosis {
  const AcceleratorDiagnosis(this.status, {this.reason, this.hint});

  const AcceleratorDiagnosis.available()
    : this(AcceleratorStatus.available);

  final AcceleratorStatus status;
  final String? reason;
  final String? hint;

  bool get isAvailable => status == AcceleratorStatus.available;
}

class LlamaCppDeviceProbeResult {
  const LlamaCppDeviceProbeResult({
    this.openclDeviceName,
    this.hexagonDeviceName,
    this.rawOutput = '',
    this.error,
  });

  static const LlamaCppDeviceProbeResult cpuOnly = LlamaCppDeviceProbeResult();

  final String? openclDeviceName;
  final String? hexagonDeviceName;
  final String rawOutput;
  final String? error;

  bool get openclAvailable =>
      openclDeviceName != null && openclDeviceName!.isNotEmpty;
  bool get hexagonAvailable =>
      hexagonDeviceName != null && hexagonDeviceName!.isNotEmpty;

  LlamaCppBackend resolve(LlamaCppBackend selected) {
    final available = switch (selected) {
      LlamaCppBackend.cpu => true,
      LlamaCppBackend.opencl => openclAvailable,
      LlamaCppBackend.hexagon => hexagonAvailable,
    };
    return available ? selected : LlamaCppBackend.cpu;
  }

  /// Why a backend the user wanted is not available.
  ///
  /// "No device found" and "the device probe itself failed" are different
  /// problems with different fixes, and reporting them the same way is what
  /// sends people looking for a phone that already has an Adreno in it. The
  /// raw log is the only evidence either way, so it is read rather than
  /// discarded.
  AcceleratorDiagnosis diagnose(LlamaCppBackend wanted) {
    if (wanted == LlamaCppBackend.cpu || isAvailable(wanted)) {
      return const AcceleratorDiagnosis(AcceleratorStatus.available);
    }

    if (error != null && rawOutput.isEmpty) {
      return AcceleratorDiagnosis(
        AcceleratorStatus.probeFailed,
        reason: error!,
        // A probe that cannot run at all is usually a missing or unreadable
        // binary rather than a missing accelerator.
        hint: 'The device probe could not run. Check the server logs.',
      );
    }

    if (wanted == LlamaCppBackend.opencl) {
      if (rawOutput.contains('platform IDs not available')) {
        return const AcceleratorDiagnosis(
          AcceleratorStatus.noDevicesFound,
          reason: 'ggml_opencl: platform IDs not available.',
          hint:
              'OpenCL is compiled in but the loader found no ICD. Usually a '
              'driver that is present but not registered on this device.',
        );
      }
      if (rawOutput.contains('libOpenCL.so')) {
        return const AcceleratorDiagnosis(
          AcceleratorStatus.probeFailed,
          reason: 'libOpenCL.so could not be loaded.',
          hint:
              'The loader found a libOpenCL.so but refused it. A stub shipped '
              'in the APK would do this, because a stub links but exports '
              'nothing.',
        );
      }
    }

    if (wanted == LlamaCppBackend.hexagon) {
      if (rawOutput.contains('get_trace_enabled_tags')) {
        return const AcceleratorDiagnosis(
          AcceleratorStatus.probeFailed,
          reason: 'libcdsprpc.so: undefined symbol: '
              'android::binder2os::get_trace_enabled_tags().',
          hint:
              'The DSP RPC library this device ships is older than the '
              'build expects. The symbol moved between NDK versions.',
        );
      }
    }

    return AcceleratorDiagnosis(
      AcceleratorStatus.noDevicesFound,
      hint: 'No device was reported. The full probe output is below.',
    );
  }

  bool isAvailable(LlamaCppBackend backend) => switch (backend) {
    LlamaCppBackend.cpu => true,
    LlamaCppBackend.opencl => openclAvailable,
    LlamaCppBackend.hexagon => hexagonAvailable,
  };

  String? deviceNameFor(LlamaCppBackend resolved) {
    return switch (resolved) {
      LlamaCppBackend.opencl => openclDeviceName,
      LlamaCppBackend.hexagon => hexagonDeviceName,
      _ => null,
    };
  }
}

LlamaCppDeviceProbeResult parseLlamaCppListDevices(String output) {
  final lines = output.split('\n');
  var listing = false;
  String? openclName;
  String? hexagonName;
  for (final raw in lines) {
    final line = raw.trimRight();
    if (!listing) {
      if (line.contains('Available devices:')) {
        listing = true;
      }
      continue;
    }
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      if (openclName != null || hexagonName != null) {
        break;
      }
      continue;
    }
    if (trimmed == '(none)') {
      break;
    }
    final colon = trimmed.indexOf(':');
    if (colon <= 0) {
      break;
    }
    final name = trimmed.substring(0, colon).trim();
    if (name.isEmpty) {
      continue;
    }
    final upper = name.toUpperCase();
    if (hexagonName == null && upper.startsWith('HTP')) {
      hexagonName = name;
    } else if (openclName == null && upper.contains('OPENCL')) {
      openclName = name;
    }
  }
  return LlamaCppDeviceProbeResult(
    openclDeviceName: openclName,
    hexagonDeviceName: hexagonName,
    rawOutput: output,
  );
}
