class FeatureFlags {
  // Disable to skip network calls to RxNorm (returns empty results)
  static bool enableRxNormApi = true;

  // Disable to skip network calls to DailyMed (falls back to local SQLite cache instantly, or null if empty)
  static bool enableDailyMedApi = true;
}
