import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'package:medicine_reminder/utils/feature_flags.dart';

/// Represents structured drug label information extracted from DailyMed.
class DrugInfo {
  final String rxcui;
  final String? indicationsUsage;
  final String? dosageAdministration;
  final String? warnings;
  final String? adverseReactions;
  final String? rawIndicationsUsage;
  final String? rawDosageAdministration;
  final String? rawWarnings;
  final String? rawAdverseReactions;
  final int lastUpdated; // milliseconds since epoch

  DrugInfo({
    required this.rxcui,
    this.indicationsUsage,
    this.dosageAdministration,
    this.warnings,
    this.adverseReactions,
    this.rawIndicationsUsage,
    this.rawDosageAdministration,
    this.rawWarnings,
    this.rawAdverseReactions,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() => {
        'rxcui': rxcui,
        'indications_usage': indicationsUsage,
        'dosage_administration': dosageAdministration,
        'warnings': warnings,
        'adverse_reactions': adverseReactions,
        'raw_indications_usage': rawIndicationsUsage,
        'raw_dosage_administration': rawDosageAdministration,
        'raw_warnings': rawWarnings,
        'raw_adverse_reactions': rawAdverseReactions,
        'last_updated': lastUpdated,
      };

  factory DrugInfo.fromMap(Map<String, dynamic> map) {
    return DrugInfo(
      rxcui: map['rxcui'] as String,
      indicationsUsage: map['indications_usage'] as String?,
      dosageAdministration: map['dosage_administration'] as String?,
      warnings: map['warnings'] as String?,
      adverseReactions: map['adverse_reactions'] as String?,
      rawIndicationsUsage: map['raw_indications_usage'] as String?,
      rawDosageAdministration: map['raw_dosage_administration'] as String?,
      rawWarnings: map['raw_warnings'] as String?,
      rawAdverseReactions: map['raw_adverse_reactions'] as String?,
      lastUpdated: map['last_updated'] as int? ?? 0,
    );
  }

  /// Returns true if the cached data is older than [days].
  bool isStale({int days = 30}) {
    final age = DateTime.now().millisecondsSinceEpoch - lastUpdated;
    return age > Duration(days: days).inMilliseconds;
  }
}

/// Service to fetch drug label data from the DailyMed API and cache it.
class DailyMedService {
  static const String _baseUrl =
      'https://dailymed.nlm.nih.gov/dailymed/services/v2';
  static const Duration _timeout = Duration(seconds: 8);
  static const int _maxRetries = 3;
  static const int _stalenessThresholdDays = 30;

  final http.Client _client;
  final DatabaseService _dbService;

  DailyMedService({http.Client? client, DatabaseService? dbService})
      : _client = client ?? http.Client(),
        _dbService = dbService ?? DatabaseService();

  /// Fetches and caches drug info for a given rxcui.
  /// Returns cached data if fresh (<30 days old).
  /// Returns null if we cannot fetch and nothing is cached.
  Future<DrugInfo?> getDrugInfo(String rxcui) async {
    // 1. Check local cache first
    final cached = await _getCachedDrugInfo(rxcui);

    if (!FeatureFlags.enableDailyMedApi) {
      debugPrint(
          '[DailyMedService] API disabled via FeatureFlags. Returning offline cache.');
      return cached;
    }

    if (cached != null && !cached.isStale(days: _stalenessThresholdDays)) {
      return cached;
    }

    // 2. Try fetching from DailyMed
    try {
      final setId = await _findSetIdByRxcui(rxcui);
      if (setId == null) return cached; // Return stale data if available

      final drugInfo = await _fetchAndParseDrugLabel(rxcui, setId);
      if (drugInfo != null) {
        await _cacheDrugInfo(drugInfo);
        return drugInfo;
      }
    } catch (e) {
      debugPrint('[DailyMedService] Error fetching drug info for $rxcui: $e');
    }

    // 3. Return stale cache as last resort
    return cached;
  }

  /// Silently refreshes drug info in the background if it is stale.
  /// Call this on app launch or when viewing medicine details.
  Future<void> refreshIfStale(String rxcui) async {
    final cached = await _getCachedDrugInfo(rxcui);
    if (cached == null || cached.isStale(days: _stalenessThresholdDays)) {
      // Fire and forget — don't block
      getDrugInfo(rxcui);
    }
  }

  // ---- Private Methods ----

  /// Public helper used by save flows to persist setId with medicine records.
  Future<String?> getSetIdByRxcui(String rxcui) async {
    if (rxcui.trim().isEmpty) return null;
    return _findSetIdByRxcui(rxcui.trim());
  }

  /// Search DailyMed for an SPL setId using the RxCUI.
  Future<String?> _findSetIdByRxcui(String rxcui) async {
    try {
      final response = await _fetchWithRetry(
        '$_baseUrl/spls.json?rxcui=$rxcui',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['data'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          return results.first['setid']?.toString();
        }
      }
    } catch (e) {
      debugPrint('[DailyMedService] Failed to find setId for RxCUI $rxcui: $e');
    }
    return null;
  }

  /// Fetches the full drug label and parses it using a compute isolate.
  Future<DrugInfo?> _fetchAndParseDrugLabel(String rxcui, String setId) async {
    try {
      final response = await _fetchWithRetry(
        '$_baseUrl/spls/$setId.xml',
      );
      if (response.statusCode == 200) {
        // Parse on an isolate since DailyMed responses can be large
        final drugInfo = await compute(
          _parseSplXml,
          _ParseArgs(rxcui: rxcui, xmlString: response.body),
        );
        return drugInfo;
      }
    } catch (e) {
      debugPrint(
          '[DailyMedService] Failed to fetch label for setId $setId: $e');
    }
    return null;
  }

  /// Retry helper with exponential backoff.
  Future<http.Response> _fetchWithRetry(String url) async {
    int attempts = 0;
    while (attempts < _maxRetries) {
      try {
        final response = await _client.get(Uri.parse(url)).timeout(_timeout);
        if (response.statusCode >= 500) {
          throw Exception('Server error: ${response.statusCode}');
        }
        return response;
      } on TimeoutException {
        // Timeout should fail fast so callers can use cache/fallback quickly.
        rethrow;
      } catch (e) {
        attempts++;
        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    throw Exception('Max retries reached');
  }

  // ---- SQLite Cache Operations ----

  Future<DrugInfo?> _getCachedDrugInfo(String rxcui) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'drug_info',
      where: 'rxcui = ?',
      whereArgs: [rxcui],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DrugInfo.fromMap(rows.first);
  }

  Future<void> _cacheDrugInfo(DrugInfo info) async {
    final db = await _dbService.database;
    await db.insert(
      'drug_info',
      info.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void dispose() {
    _client.close();
  }
}

// ---- Isolate-safe Parsing ----

/// Data class to pass arguments to the compute isolate.
class _ParseArgs {
  final String rxcui;
  final String xmlString;
  _ParseArgs({required this.rxcui, required this.xmlString});
}

/// Top-level function for compute isolate. Parses the DailyMed SPL XML
/// using highly defensive parsing — missing or mutated sections are
/// silently omitted rather than throwing.
///
/// Returns null on total parse failure so that the caller falls through
/// to stale cache instead of overwriting good data with empty content.
DrugInfo? _parseSplXml(_ParseArgs args) {
  try {
    final doc = XmlDocument.parse(args.xmlString);

    // DailyMed SPL sections are nested inconsistently — be very defensive
    String? indicationsUsage;
    String? dosageAdministration;
    String? warnings;
    String? adverseReactions;
    String? rawIndicationsUsage;
    String? rawDosageAdministration;
    String? rawWarnings;
    String? rawAdverseReactions;

    // Find all <section> elements in the XML
    final sections = doc.findAllElements('section');

    for (final section in sections) {
      final titleNodes = section.findElements('title');
      if (titleNodes.isEmpty) continue;

      final title = titleNodes.first.innerText.toLowerCase();
      final rawText = section.innerText.trim();

      // Skip empty text
      if (rawText.isEmpty) continue;

      final cleanedText = _cleanSplText(rawText);
      final summarizedText = _extractLeadSentences(cleanedText);

      if (indicationsUsage == null &&
          (title.contains('indications') ||
              title.contains('usage') ||
              title.contains('uses'))) {
        indicationsUsage = summarizedText;
        rawIndicationsUsage = rawText;
      } else if (dosageAdministration == null &&
          (title.contains('dosage') ||
              title.contains('administration') ||
              title.contains('directions'))) {
        dosageAdministration = summarizedText;
        rawDosageAdministration = rawText;
      } else if (warnings == null && title.contains('warning')) {
        warnings = summarizedText;
        rawWarnings = rawText;
      } else if (adverseReactions == null &&
          (title.contains('adverse') || title.contains('side effect'))) {
        adverseReactions = summarizedText;
        rawAdverseReactions = rawText;
      }
    }

    // Only cache if we found at least one useful piece of information
    if (indicationsUsage == null &&
        dosageAdministration == null &&
        warnings == null &&
        adverseReactions == null) {
      return null;
    }

    return DrugInfo(
      rxcui: args.rxcui,
      indicationsUsage: indicationsUsage,
      dosageAdministration: dosageAdministration,
      warnings: warnings,
      adverseReactions: adverseReactions,
      rawIndicationsUsage: rawIndicationsUsage,
      rawDosageAdministration: rawDosageAdministration,
      rawWarnings: rawWarnings,
      rawAdverseReactions: rawAdverseReactions,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
    );
  } catch (e) {
    // Total parse failure — return null so the caller keeps stale cache
    return null;
  }
}

String _cleanSplText(String raw) {
  return raw
      .replaceAll(RegExp(r'\(\s*\d+\s*\)'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();
}

String _extractLeadSentences(String cleaned, {int count = 3}) {
  final sentences = cleaned
      .split(RegExp(r'(?<=[.!?])\s+'))
      .where((fragment) => fragment.trim().length >= 20)
      .take(count)
      .toList();

  if (sentences.isEmpty) {
    return cleaned;
  }

  return sentences.join(' ');
}
