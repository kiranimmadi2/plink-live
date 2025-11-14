/// Centralized API configuration
/// This file contains all API keys and configurations used throughout the app
class ApiConfig {
  // Private constructor to prevent instantiation
  ApiConfig._();

  /// Google Gemini API Key
  /// IMPORTANT: In production, use environment variables or secure storage
  /// Never commit API keys to version control
  static const String geminiApiKey = 'AIzaSyCSShfO46TT8DnYTGKzJ_-M4uQVGPlhscA';

  /// Gemini model names
  static const String geminiFlashModel = 'gemini-1.5-flash-latest';
  static const String geminiEmbeddingModel = 'text-embedding-004';

  /// API endpoints
  static const String geminiApiBaseUrl = 'https://generativelanguage.googleapis.com';

  /// Model configuration
  static const double temperature = 0.7;
  static const int topK = 40;
  static const double topP = 0.95;
  static const int maxOutputTokens = 1024;

  /// Embedding configuration
  static const int embeddingDimension = 768;

  /// Matching thresholds
  static const double semanticSimilarityThreshold = 0.7;
  static const double intentMatchWeight = 0.4;
  static const double semanticMatchWeight = 0.3;
  static const double locationMatchWeight = 0.15;
  static const double timeMatchWeight = 0.10;
  static const double keywordMatchWeight = 0.05;

  /// Cache configuration
  static const Duration embeddingCacheDuration = Duration(hours: 24);
  static const Duration matchCacheDuration = Duration(minutes: 30);
  static const int maxCacheSize = 1000;

  /// Firestore collection names
  static const String postsCollection = 'posts';
  static const String usersCollection = 'users';
  static const String matchesCollection = 'matches';
  static const String intentsCollection = 'intents';
  static const String embeddingsCollection = 'embeddings';
  static const String cacheCollection = 'cache';
}
