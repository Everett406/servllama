import 'dart:convert';

/// The built-in tools the model may call.
enum BuiltinTool {
  clock('current_time'),
  calculator('calculator'),
  knowledgeSearch('knowledge_search');

  const BuiltinTool(this.wireName);

  /// The name the model sees. Stable across renames of the enum case.
  final String wireName;

  static BuiltinTool? byWireName(String name) {
    for (final tool in values) {
      if (tool.wireName == name) return tool;
    }
    return null;
  }
}

/// Which of the built-in tools are switched on.
///
/// All on by default. A tool that silently stops working is worse than one
/// that was never there, and a switch nobody asked for is not worth being the
/// default — the point of the switches is that the user has them, not that
/// they start closed.
class ToolSettings {
  const ToolSettings({
    this.clock = true,
    this.calculator = true,
    this.knowledgeSearch = true,
  });

  final bool clock;
  final bool calculator;
  final bool knowledgeSearch;

  bool isEnabled(BuiltinTool tool) => switch (tool) {
    BuiltinTool.clock => clock,
    BuiltinTool.calculator => calculator,
    BuiltinTool.knowledgeSearch => knowledgeSearch,
  };

  ToolSettings copyWith({BuiltinTool? tool, bool? enabled}) => ToolSettings(
    clock: tool == BuiltinTool.clock ? (enabled ?? clock) : clock,
    calculator: tool == BuiltinTool.calculator
        ? (enabled ?? calculator)
        : calculator,
    knowledgeSearch: tool == BuiltinTool.knowledgeSearch
        ? (enabled ?? knowledgeSearch)
        : knowledgeSearch,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'clock': clock,
    'calculator': calculator,
    'knowledgeSearch': knowledgeSearch,
  };

  factory ToolSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ToolSettings();
    return ToolSettings(
      clock: json['clock'] is bool ? json['clock'] as bool : true,
      calculator: json['calculator'] is bool
          ? json['calculator'] as bool
          : true,
      knowledgeSearch: json['knowledgeSearch'] is bool
          ? json['knowledgeSearch'] as bool
          : true,
    );
  }

  String encode() => jsonEncode(toJson());
}