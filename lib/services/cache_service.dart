import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

/// High-performance in-memory cache service for embeddings and match results
/// Implements LRU (Least Recently Used) eviction policy
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // LRU cache for embeddings
  final LinkedHashMap<String, CachedEmbedding> _embeddingCache = LinkedHashMap();

  // LRU cache for match results
  final LinkedHashMap<String, CachedMatches> _matchCache = LinkedHashMap();

  // Statistics
  int _embeddingHits = 0;
  int _embeddingMisses = 0;
  int _matchHits = 0;
  int _matchMisses = 0;

  /// Store embedding in cache
  void cacheEmbedding(String text, List<double> embedding) {
    try {
      final key = _generateKey(text);

      // Remove if already exists (to update access time)
      if (_embeddingCache.containsKey(key)) {
        _embeddingCache.remove(key);
      }

      // Add to cache
      _embeddingCache[key] = CachedEmbedding(
        embedding: embedding,
        timestamp: DateTime.now(),
      );

      // Enforce cache size limit
      _enforceEmbeddingCacheLimit();
    } catch (e) {
      debugPrint('Error caching embedding: $e');
    }
  }

  /// Retrieve embedding from cache
  List<double>? getCachedEmbedding(String text) {
    try {
      final key = _generateKey(text);
      final cached = _embeddingCache[key];

      if (cached == null) {
        _embeddingMisses++;
        return null;
      }

      // Check if cache is still valid
      final age = DateTime.now().difference(cached.timestamp);
      if (age > ApiConfig.embeddingCacheDuration) {
        _embeddingCache.remove(key);
        _embeddingMisses++;
        return null;
      }

      // Move to end (most recently used)
      _embeddingCache.remove(key);
      _embeddingCache[key] = cached;

      _embeddingHits++;
      return cached.embedding;
    } catch (e) {
      debugPrint('Error retrieving cached embedding: $e');
      return null;
    }
  }

  /// Store match results in cache
  void cacheMatches(String postId, List<String> matchedPostIds, double score) {
    try {
      // Remove if already exists
      if (_matchCache.containsKey(postId)) {
        _matchCache.remove(postId);
      }

      // Add to cache
      _matchCache[postId] = CachedMatches(
        matchedPostIds: matchedPostIds,
        score: score,
        timestamp: DateTime.now(),
      );

      // Enforce cache size limit
      _enforceMatchCacheLimit();
    } catch (e) {
      debugPrint('Error caching matches: $e');
    }
  }

  /// Retrieve match results from cache
  CachedMatches? getCachedMatches(String postId) {
    try {
      final cached = _matchCache[postId];

      if (cached == null) {
        _matchMisses++;
        return null;
      }

      // Check if cache is still valid
      final age = DateTime.now().difference(cached.timestamp);
      if (age > ApiConfig.matchCacheDuration) {
        _matchCache.remove(postId);
        _matchMisses++;
        return null;
      }

      // Move to end (most recently used)
      _matchCache.remove(postId);
      _matchCache[postId] = cached;

      _matchHits++;
      return cached;
    } catch (e) {
      debugPrint('Error retrieving cached matches: $e');
      return null;
    }
  }

  /// Invalidate match cache for a specific post
  void invalidateMatchCache(String postId) {
    _matchCache.remove(postId);
  }

  /// Invalidate all match caches
  void invalidateAllMatchCaches() {
    _matchCache.clear();
  }

  /// Clear embedding cache
  void clearEmbeddingCache() {
    _embeddingCache.clear();
    _embeddingHits = 0;
    _embeddingMisses = 0;
  }

  /// Clear match cache
  void clearMatchCache() {
    _matchCache.clear();
    _matchHits = 0;
    _matchMisses = 0;
  }

  /// Clear all caches
  void clearAll() {
    clearEmbeddingCache();
    clearMatchCache();
  }

  /// Get cache statistics
  Map<String, dynamic> getStatistics() {
    return {
      'embedding_cache': {
        'size': _embeddingCache.length,
        'hits': _embeddingHits,
        'misses': _embeddingMisses,
        'hit_rate': _embeddingHits + _embeddingMisses > 0
            ? _embeddingHits / (_embeddingHits + _embeddingMisses)
            : 0.0,
      },
      'match_cache': {
        'size': _matchCache.length,
        'hits': _matchHits,
        'misses': _matchMisses,
        'hit_rate': _matchHits + _matchMisses > 0
            ? _matchHits / (_matchHits + _matchMisses)
            : 0.0,
      },
    };
  }

  /// Generate cache key from text
  String _generateKey(String text) {
    return text.trim().toLowerCase().hashCode.toString();
  }

  /// Enforce embedding cache size limit (LRU eviction)
  void _enforceEmbeddingCacheLimit() {
    while (_embeddingCache.length > ApiConfig.maxCacheSize) {
      // Remove oldest (first) entry
      _embeddingCache.remove(_embeddingCache.keys.first);
    }
  }

  /// Enforce match cache size limit (LRU eviction)
  void _enforceMatchCacheLimit() {
    while (_matchCache.length > ApiConfig.maxCacheSize) {
      // Remove oldest (first) entry
      _matchCache.remove(_matchCache.keys.first);
    }
  }

  /// Warm up cache with frequently used embeddings
  Future<void> warmupCache(List<String> texts, Future<List<double>> Function(String) generateEmbedding) async {
    try {
      for (final text in texts) {
        if (!_embeddingCache.containsKey(_generateKey(text))) {
          final embedding = await generateEmbedding(text);
          cacheEmbedding(text, embedding);
        }
      }
    } catch (e) {
      debugPrint('Error warming up cache: $e');
    }
  }

  /// Preload cache with batch embeddings
  void preloadEmbeddings(Map<String, List<double>> embeddings) {
    for (final entry in embeddings.entries) {
      cacheEmbedding(entry.key, entry.value);
    }
  }
}

/// Cached embedding data class
class CachedEmbedding {
  final List<double> embedding;
  final DateTime timestamp;

  CachedEmbedding({
    required this.embedding,
    required this.timestamp,
  });
}

/// Cached match results data class
class CachedMatches {
  final List<String> matchedPostIds;
  final double score;
  final DateTime timestamp;

  CachedMatches({
    required this.matchedPostIds,
    required this.score,
    required this.timestamp,
  });
}
