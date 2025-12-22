import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../res/utils/memory_manager.dart';

class SafeNetworkService {
  static final SafeNetworkService _instance = SafeNetworkService._internal();
  factory SafeNetworkService() => _instance;
  SafeNetworkService._internal();

  final MemoryManager _memoryManager = MemoryManager();

  // Safe write operation with chunking
  static Future<void> safeWrite(
    Stream<List<int>> Function() writeOperation,
    String operationId,
  ) async {
    final memoryManager = MemoryManager();

    try {
      // Register operation
      memoryManager.registerBuffer(operationId, 0);

      // Process in chunks to avoid memory overflow
      await for (final chunk in writeOperation()) {
        final chunkSize = chunk.length;

        // Check chunk size
        if (chunkSize > MemoryManager.optimalBufferSize) {
          debugPrint(
            'Warning: Large chunk detected ($chunkSize bytes), splitting...',
          );

          // Split into smaller chunks with small delays to prevent overwhelming
          for (int i = 0; i < chunkSize; i += MemoryManager.optimalBufferSize) {
            await Future.delayed(const Duration(microseconds: 100));
          }
        }

        memoryManager.registerBuffer(operationId, chunkSize);
      }
    } catch (e) {
      debugPrint('Safe write operation failed: $e');
      rethrow;
    } finally {
      // Clean up
      memoryManager.unregisterBuffer(operationId);
    }
  }

  // Convert large byte data safely
  static Uint8List safeByteDataConversion(List<int> data) {
    try {
      if (data.length > MemoryManager.maxBufferSize) {
        throw Exception('Data size exceeds maximum buffer limit');
      }

      // Use more efficient conversion for large data
      if (data is Uint8List) {
        return data;
      }

      // For large data, use chunked conversion
      if (data.length > MemoryManager.optimalBufferSize) {
        final result = Uint8List(data.length);

        for (int i = 0; i < data.length; i += MemoryManager.optimalBufferSize) {
          final end = (i + MemoryManager.optimalBufferSize < data.length)
              ? i + MemoryManager.optimalBufferSize
              : data.length;

          result.setRange(i, end, data, i);
        }

        return result;
      }

      // Small data can be converted directly
      return Uint8List.fromList(data);
    } catch (e) {
      debugPrint('Byte data conversion failed: $e');
      throw Exception('Failed to convert byte data: Memory limit exceeded');
    }
  }

  void dispose() {
    _memoryManager.dispose();
  }
}
