import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmbeddingCacheService {
  static final EmbeddingCacheService _instance = EmbeddingCacheService._internal();
  factory EmbeddingCacheService() => _instance;
  EmbeddingCacheService._internal();

  static const String _cacheKey = 'embedding_cache';
  static const int _maxCacheSize = 100; // Maximum number of cached embeddings
  static const Duration _cacheExpiry = Duration(hours: 24);
  
  SharedPreferences? _prefs;
  Map<String, CachedEmbedding> _memoryCache = {};

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCache();
  }

  Future<void> _loadCache() async {
    try {
      final cacheString = _prefs?.getString(_cacheKey);
      if (cacheString != null) {
        final Map<String, dynamic> cacheData = json.decode(cacheString);
        _memoryCache = cacheData.map((key, value) => 
          MapEntry(key, CachedEmbedding.fromJson(value)));
        
        // Clean expired entries
        _cleanExpiredEntries();
      }
    } catch (e) {
      debugPrint('Error loading embedding cache: $e');
      _memoryCache = {};
    }
  }

  Future<void> _saveCache() async {
    try {
      final cacheData = _memoryCache.map((key, value) => 
        MapEntry(key, value.toJson()));
      await _prefs?.setString(_cacheKey, json.encode(cacheData));
    } catch (e) {
      debugPrint('Error saving embedding cache: $e');
    }
  }

  void _cleanExpiredEntries() {
    final now = DateTime.now();
    _memoryCache.removeWhere((key, value) => 
      now.difference(value.timestamp) > _cacheExpiry);
  }

  void _enforceMaxSize() {
    if (_memoryCache.length > _maxCacheSize) {
      // Remove oldest entries
      final sortedEntries = _memoryCache.entries.toList()
        ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
      
      final entriesToRemove = sortedEntries.take(_memoryCache.length - _maxCacheSize);
      for (var entry in entriesToRemove) {
        _memoryCache.remove(entry.key);
      }
    }
  }

  String _generateKey(String text) {
    // Simple hash function for cache key
    final bytes = utf8.encode(text.toLowerCase().trim());
    var hash = 0;
    for (var byte in bytes) {
      hash = ((hash << 5) - hash + byte) & 0xFFFFFFFF;
    }
    return hash.toString();
  }

  Future<List<double>?> getEmbedding(String text) async {
    if (_prefs == null) await initialize();
    
    final key = _generateKey(text);
    final cached = _memoryCache[key];
    
    if (cached != null) {
      final now = DateTime.now();
      if (now.difference(cached.timestamp) <= _cacheExpiry) {
        cached.hitCount++;
        await _saveCache();
        return cached.embedding;
      } else {
        _memoryCache.remove(key);
      }
    }
    
    return null;
  }

  Future<void> cacheEmbedding(String text, List<double> embedding) async {
    if (_prefs == null) await initialize();
    
    final key = _generateKey(text);
    _memoryCache[key] = CachedEmbedding(
      text: text,
      embedding: embedding,
      timestamp: DateTime.now(),
      hitCount: 0,
    );
    
    _enforceMaxSize();
    await _saveCache();
  }

  Future<void> clearCache() async {
    _memoryCache.clear();
    await _prefs?.remove(_cacheKey);
  }

  Map<String, dynamic> getCacheStats() {
    _cleanExpiredEntries();
    
    int totalHits = 0;
    for (var entry in _memoryCache.values) {
      totalHits += entry.hitCount;
    }
    
    return {
      'totalEntries': _memoryCache.length,
      'totalHits': totalHits,
      'maxSize': _maxCacheSize,
      'expiryHours': _cacheExpiry.inHours,
    };
  }
}

class CachedEmbedding {
  final String text;
  final List<double> embedding;
  final DateTime timestamp;
  int hitCount;

  CachedEmbedding({
    required this.text,
    required this.embedding,
    required this.timestamp,
    this.hitCount = 0,
  });

  factory CachedEmbedding.fromJson(Map<String, dynamic> json) {
    return CachedEmbedding(
      text: json['text'],
      embedding: List<double>.from(json['embedding']),
      timestamp: DateTime.parse(json['timestamp']),
      hitCount: json['hitCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'embedding': embedding,
      'timestamp': timestamp.toIso8601String(),
      'hitCount': hitCount,
    };
  }
}

// Performance monitoring for cache
class CachePerformanceMonitor {
  static final Map<String, int> _cacheHits = {};
  static final Map<String, int> _cacheMisses = {};
  static DateTime _startTime = DateTime.now();

  static void recordHit(String operation) {
    _cacheHits[operation] = (_cacheHits[operation] ?? 0) + 1;
  }

  static void recordMiss(String operation) {
    _cacheMisses[operation] = (_cacheMisses[operation] ?? 0) + 1;
  }

  static Map<String, dynamic> getStats() {
    final runtime = DateTime.now().difference(_startTime);
    final totalHits = _cacheHits.values.fold(0, (a, b) => a + b);
    final totalMisses = _cacheMisses.values.fold(0, (a, b) => a + b);
    final total = totalHits + totalMisses;
    
    return {
      'runtime': runtime.toString(),
      'totalHits': totalHits,
      'totalMisses': totalMisses,
      'hitRate': total > 0 ? (totalHits / total * 100).toStringAsFixed(2) : '0.00',
      'operations': {
        'hits': _cacheHits,
        'misses': _cacheMisses,
      },
    };
  }

  static void reset() {
    _cacheHits.clear();
    _cacheMisses.clear();
    _startTime = DateTime.now();
  }
}