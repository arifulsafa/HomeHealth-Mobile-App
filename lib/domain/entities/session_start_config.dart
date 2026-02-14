class SessionStartConfig {
  final String patientIdentifier;
  final List<String> formTypes;
  final String? notes;

  const SessionStartConfig({
    required this.patientIdentifier,
    required this.formTypes,
    this.notes,
  });
}

