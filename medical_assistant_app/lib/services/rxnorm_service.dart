import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:medicine_reminder/utils/feature_flags.dart';

class RxNormService {
  static const String _baseUrl = 'https://rxnav.nlm.nih.gov/REST';
  static const Map<String, String> _synonyms = {
    'paracetamol': 'acetaminophen',
    'pethidine': 'meperidine',
    'adrenaline': 'epinephrine',
    'lignocaine': 'lidocaine',
    'frusemide': 'furosemide',
    'salbutamol': 'albuterol',
    'amoxycillin': 'amoxicillin',
    'noradrenaline': 'norepinephrine',
    'trimethoprim-sulfamethoxazole': 'co-trimoxazole',
  };

  // Timeout for API calls to prevent hanging the app when offline or slow network
  static const Duration _timeout = Duration(seconds: 5);
  static const int _maxRetries = 3;

  final http.Client _client;

  // In-session memory cache to prevent duplicate API calls on debounce
  final Map<String, List<Map<String, String>>> _searchCache = {};
  final Map<String, List<Map<String, dynamic>>> _interactionCache = {};

  RxNormService({http.Client? client}) : _client = client ?? http.Client();

  /// Helper to manage retries with exponential backoff on 5xx errors
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
        // Timeout should fail fast so callers can fall back quickly.
        rethrow;
      } catch (e) {
        attempts++;
        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    throw Exception('Max retries reached');
  }

  /// Searches the RxNorm database by string name.
  /// Returns a list of matched medical concepts (RxCUI and normalized names).
  Future<List<Map<String, String>>> searchRxCuiByName(String query) async {
    if (!FeatureFlags.enableRxNormApi) {
      debugPrint('[RxNormService] API disabled via FeatureFlags. Skipping search.');
      return [];
    }

    final sanitizedQuery = query.trim().toLowerCase();
    if (sanitizedQuery.isEmpty) return [];
    final resolvedQuery = _synonyms[sanitizedQuery] ?? sanitizedQuery;
    if (_searchCache.containsKey(sanitizedQuery)) {
      return _searchCache[sanitizedQuery]!;
    }

    try {
      final response = await _fetchWithRetry(
          '$_baseUrl/drugs.json?name=${Uri.encodeComponent(resolvedQuery)}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final conceptGroup =
            data['drugGroup']?['conceptGroup'] as List<dynamic>?;

        List<Map<String, String>> results = [];
        final Set<String> validTermTypes = {'IN', 'PIN', 'SCD', 'SBD'};

        if (conceptGroup != null) {
          for (var group in conceptGroup) {
            final tty = group['tty']?.toString() ?? '';
            if (validTermTypes.contains(tty)) {
              final concepts = group['conceptProperties'] as List<dynamic>?;
              if (concepts != null) {
                for (var concept in concepts) {
                  final rxcui = concept['rxcui']?.toString().trim() ?? '';
                  if (rxcui.isEmpty) continue;
                  results.add({
                    'rxcui': rxcui,
                    'name': concept['name']?.toString() ?? '',
                    'tty': tty,
                  });
                }
              }
            }
          }
        }

        // If exact match yielded zero valid results, try approximate
        if (results.isEmpty) {
          final approxResponse = await _fetchWithRetry(
              '$_baseUrl/approximateTerm.json?term=${Uri.encodeComponent(resolvedQuery)}&maxEntries=5');

          if (approxResponse.statusCode == 200) {
            final approxData = json.decode(approxResponse.body);
            final candidates =
                approxData['approximateGroup']?['candidate'] as List<dynamic>?;

            if (candidates != null) {
              final seenCandidateRxcuis = <String>{};
              for (var candidate in candidates) {
                final rxcui = candidate['rxcui']?.toString().trim();
                if (rxcui == null || rxcui.isEmpty) continue;
                if (!seenCandidateRxcuis.add(rxcui)) continue;

                // Fetch properties to get the actual name and tty for filtering
                try {
                  final propResponse = await _fetchWithRetry(
                      '$_baseUrl/rxcui/$rxcui/properties.json');
                  if (propResponse.statusCode == 200) {
                    final propData = json.decode(propResponse.body);
                    final props = propData['properties'];
                    if (props != null) {
                      final tty = props['tty']?.toString() ?? '';
                      // CRITICAL: Filter fuzzy results by validTermTypes just like exact search
                      if (validTermTypes.contains(tty)) {
                        results.add({
                          'rxcui': rxcui,
                          'name': props['name']?.toString() ?? '',
                          'tty': tty,
                        });
                      }
                    }
                  }
                } catch (e) {
                  continue; // Skip this candidate if properties fetch fails
                }
              }
            }
          }
        }

        // Sort explicitly: Ingredients (IN/PIN) first, then clinical/branded
        results.sort((a, b) {
          final aIsIngredient = a['tty'] == 'IN' || a['tty'] == 'PIN' ? 0 : 1;
          final bIsIngredient = b['tty'] == 'IN' || b['tty'] == 'PIN' ? 0 : 1;
          return aIsIngredient.compareTo(bIsIngredient);
        });

        _searchCache[sanitizedQuery] = results;
        return results;
      }
      return [];
    } catch (e) {
      // Log error (replace with robust logger in prod), gracefully fallback by returning empty list
      return [];
    }
  }

  /// Fetches properties of  /// Returns the canonical RxNorm name for an rxcui if found.
  Future<String?> getNormalizedName(String rxcui) async {
    if (!FeatureFlags.enableRxNormApi) return null;

    try {
      final response =
          await _fetchWithRetry('$_baseUrl/rxcui/$rxcui/properties.json');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['properties']?['name']?.toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetches ALL  /// Useful for checking drug class compatibility.
  Future<List<String>> getIngredients(String rxcui) async {
    if (!FeatureFlags.enableRxNormApi) return [];

    try {
      final response =
          await _fetchWithRetry('$_baseUrl/rxcui/$rxcui/related.json?tty=IN');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final conceptGroup =
            data['relatedGroup']?['conceptGroup'] as List<dynamic>?;

        List<String> ingredients = [];
        if (conceptGroup != null) {
          for (var group in conceptGroup) {
            final properties = group['conceptProperties'] as List<dynamic>?;
            if (properties != null) {
              for (var prop in properties) {
                final ingRxcui = prop['rxcui']?.toString().trim();
                if (ingRxcui != null && ingRxcui.isNotEmpty) {
                  ingredients.add(ingRxcui);
                }
              }
            }
          }
        }
        return ingredients.toSet().toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Checks interactions  /// the drug pair involved.
  Future<List<Map<String, dynamic>>> getInteractions(
      List<String> rxcuis) async {
    if (!FeatureFlags.enableRxNormApi) {
      debugPrint('[RxNormService] interaction API disabled. Falling back locally.');
      return [];
    }

    if (rxcuis.isEmpty || rxcuis.length < 2) return [];

    final normalizedRxcuis = rxcuis
        .map((rxcui) => rxcui.trim())
        .where((rxcui) => rxcui.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (normalizedRxcuis.length < 2) return [];

    final rxcuisJoined = normalizedRxcuis.join('+');
    if (_interactionCache.containsKey(rxcuisJoined)) {
      return _interactionCache[rxcuisJoined]!;
    }

    try {
      final response = await _fetchWithRetry(
          '$_baseUrl/interaction/list.json?rxcuis=$rxcuisJoined');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Map<String, dynamic>> parsedInteractions = [];

        if (data.containsKey('fullInteractionTypeGroup')) {
          final interactionGroups =
              data['fullInteractionTypeGroup'] as List<dynamic>;
          for (var group in interactionGroups) {
            final interactionTypes =
                group['fullInteractionType'] as List<dynamic>?;
            if (interactionTypes != null) {
              for (var type in interactionTypes) {
                final interactions = type['interactionPair'] as List<dynamic>?;
                if (interactions != null) {
                  for (var pair in interactions) {
                    String drugA = '';
                    String drugB = '';

                    final concepts =
                        pair['interactionConcept'] as List<dynamic>?;
                    if (concepts != null && concepts.length >= 2) {
                      drugA = concepts[0]['sourceConceptItem']?['name']
                              ?.toString() ??
                          '';
                      drugB = concepts[1]['sourceConceptItem']?['name']
                              ?.toString() ??
                          '';
                    }

                    parsedInteractions.add({
                      'description': pair['description']?.toString() ?? '',
                      'severity': pair['severity']?.toString() ??
                          'Unknown', // Safe default
                      'drugA': drugA,
                      'drugB': drugB,
                    });
                  }
                }
              }
            }
          }
        }
        _interactionCache[rxcuisJoined] = parsedInteractions;
        return parsedInteractions;
      }
      return [];
    } catch (e) {
      // Gracefully fail and return empty allowing Repository to fallback to local check
      return [];
    }
  }

  // Dispose of the client when done
  void dispose() {
    _client.close();
  }
}
