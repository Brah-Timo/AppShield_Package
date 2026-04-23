// lib/src/models/feature_model.dart

class AppFeature {
  const AppFeature({
    required this.key,
    required this.displayName,
    this.description,
    this.iconName,
    this.isEnabled = false,
    this.requiredPlan,
  });

  final String  key;
  final String  displayName;
  final String? description;
  final String? iconName;
  final bool    isEnabled;
  final String? requiredPlan;

  AppFeature copyWith({bool? isEnabled}) => AppFeature(
        key:          key,
        displayName:  displayName,
        description:  description,
        iconName:     iconName,
        isEnabled:    isEnabled ?? this.isEnabled,
        requiredPlan: requiredPlan,
      );

  @override
  String toString() => 'AppFeature(key: $key, enabled: $isEnabled)';
}
