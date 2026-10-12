import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/llama_cpp_backend.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/slider_number_setting.dart';

class LlamaCppBackendSettings extends StatefulWidget {
  const LlamaCppBackendSettings({super.key});

  @override
  State<LlamaCppBackendSettings> createState() =>
      _LlamaCppBackendSettingsState();
}

class _LlamaCppBackendSettingsState extends State<LlamaCppBackendSettings> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final running = context.read<EngineRuntimeProvider>().isRunning;
      context.read<ServerConfigProvider>().loadLlamaCppBackends(
        allowProcess: !running,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServerConfigProvider>();
    final running = context.select<EngineRuntimeProvider, bool>(
      (runtime) => runtime.isRunning,
    );
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final probe = provider.llamaCppProbe;
    final probeKnown =
        provider.llamaCppBackendsResolved && !provider.loadingLlamaCppBackends;
    final savedUnavailable =
        probeKnown &&
        provider.llamaCppBackendError == null &&
        ServerLaunchSettings.supportedLlamaCppBackends.contains(
          provider.llamaCppBackend,
        ) &&
        switch (provider.llamaCppBackend) {
          LlamaCppBackend.opencl => !probe.openclAvailable,
          LlamaCppBackend.hexagon => !probe.hexagonAvailable,
          _ => false,
        };
    return SettingsSection(
      key: const Key('llama_cpp_backend_settings'),
      title: l10n.llamaCppBackendTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.llamaCppBackendNextStart,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  key: const Key('llama_cpp_backend_refresh'),
                  tooltip: l10n.llamaCppBackendRefresh,
                  onPressed: provider.loadingLlamaCppBackends || running
                      ? null
                      : () => provider.loadLlamaCppBackends(force: true),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (running)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.llamaCppBackendStopServer,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (provider.loadingLlamaCppBackends) const LinearProgressIndicator(),
          if (provider.llamaCppBackendError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.llamaCppBackendProbeFailed,
                style: TextStyle(color: colors.error),
              ),
            ),
          if (savedUnavailable)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.llamaCppBackendSavedUnavailable,
                style: TextStyle(color: colors.error),
              ),
            ),
          for (final backend
              in ServerLaunchSettings.supportedLlamaCppBackends) ...[
            if (backend != LlamaCppBackend.cpu) const Divider(height: 1),
            _backendTile(context, provider, backend, probe, probeKnown),
          ],
          _detectedDevices(context, probe, probeKnown),
          if (provider.llamaCppBackend != LlamaCppBackend.cpu) ...[
            const Divider(height: 1),
            SliderNumberSetting(
              key: const Key('llama_cpp_gpu_layers'),
              label: l10n.llamaCppGpuLayers,
              description: l10n.llamaCppGpuLayersDescription,
              value: provider.llamaCppGpuLayers,
              min: ServerLaunchSettings.minLlamaCppGpuLayers,
              max: ServerLaunchSettings.maxLlamaCppGpuLayers,
              divisions:
                  ServerLaunchSettings.maxLlamaCppGpuLayers -
                  ServerLaunchSettings.minLlamaCppGpuLayers,
              onChanged: provider.updateLlamaCppGpuLayers,
            ),
          ],
        ],
      ),
    );
  }

  Widget _backendTile(
    BuildContext context,
    ServerConfigProvider provider,
    LlamaCppBackend backend,
    LlamaCppDeviceProbeResult probe,
    bool probeKnown,
  ) {
    final l10n = context.l10n;
    final selectable = switch (backend) {
      LlamaCppBackend.cpu => true,
      LlamaCppBackend.opencl => probeKnown && probe.openclAvailable,
      LlamaCppBackend.hexagon => probeKnown && probe.hexagonAvailable,
    };
    final selected = provider.llamaCppBackend == backend;
    return ListTile(
      key: Key('llama_cpp_backend_${backend.name}'),
      contentPadding: EdgeInsets.zero,
      enabled: selectable,
      selected: selected,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(_name(l10n, backend)),
      subtitle: Text(_description(l10n, backend, selectable, probeKnown)),
      onTap: selectable ? () => provider.updateLlamaCppBackend(backend) : null,
    );
  }

  String _name(AppLocalizations l10n, LlamaCppBackend backend) {
    return switch (backend) {
      LlamaCppBackend.cpu => l10n.llamaCppBackendCpu,
      LlamaCppBackend.opencl => l10n.llamaCppBackendOpencl,
      LlamaCppBackend.hexagon => l10n.llamaCppBackendHexagon,
    };
  }

  String _description(
    AppLocalizations l10n,
    LlamaCppBackend backend,
    bool selectable,
    bool probeKnown,
  ) {
    if (probeKnown && !selectable) {
      return l10n.llamaCppBackendUnavailable;
    }
    return switch (backend) {
      LlamaCppBackend.cpu => l10n.llamaCppBackendCpuDescription,
      LlamaCppBackend.opencl => l10n.llamaCppBackendOpenclDescription,
      LlamaCppBackend.hexagon => l10n.llamaCppBackendHexagonDescription,
    };
  }

  /// What the probe actually saw.
  ///
  /// The old copy asserted "Snapdragon 8 Gen 2 and above" whether or not the
  /// device qualified, so a phone with no usable HTP got the same sentence as
  /// one that does. The number that decides this is what `--list-devices`
  /// printed, so that is what the row shows, verbatim and expandable.
  Widget _detectedDevices(
    BuildContext context,
    LlamaCppDeviceProbeResult probe,
    bool probeKnown,
  ) {
    final l10n = context.l10n;
    final found = <String>[
      if (probe.openclAvailable) 'OpenCL — ${probe.openclDeviceName}',
      if (probe.hexagonAvailable) 'Hexagon — ${probe.hexagonDeviceName}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.llamaCppDetectedDevices,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.inkTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (!probeKnown)
            Text(
              l10n.llamaCppBackendRefresh,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else if (found.isEmpty)
            Text(
              l10n.llamaCppDetectedNone,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final line in found)
              Text(
                line,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.accent,
                ),
              ),
          if (probe.rawOutput.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _RawOutputToggle(raw: probe.rawOutput),
          ],
        ],
      ),
    );
  }
}

/// Collapsed to one line until asked. The raw listing is the only way to tell
/// an absent HTP device from an unsupported one, and it is never something
/// anyone wants to read by default.
class _RawOutputToggle extends StatefulWidget {
  const _RawOutputToggle({required this.raw});

  final String raw;

  @override
  State<_RawOutputToggle> createState() => _RawOutputToggleState();
}

class _RawOutputToggleState extends State<_RawOutputToggle> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              _open
                  ? l10n.llamaCppDetectedHideRaw
                  : l10n.llamaCppDetectedShowRaw,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.accent,
                decoration: TextDecoration.underline,
                decorationColor: context.accent,
              ),
            ),
          ),
        ),
        if (_open)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4, bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.surfaceSunken,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              widget.raw.trim(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
                height: 1.4,
                color: context.inkSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
