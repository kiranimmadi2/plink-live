import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:mime/mime.dart';
import '../location services/gemini_service.dart';

class FileAnalysisService {
  static final FileAnalysisService _instance = FileAnalysisService._internal();
  factory FileAnalysisService() => _instance;
  FileAnalysisService._internal();

  final GeminiService _geminiService = GeminiService();

  /// Pick and analyze a file
  Future<FileAnalysisResult?> pickAndAnalyzeFile() async {
    return _pickAndAnalyzeWithType(FileType.any, null);
  }

  /// Pick and analyze an image file (for OCR, chart analysis)
  Future<FileAnalysisResult?> pickAndAnalyzeImage() async {
    debugPrint('🖼️ FileAnalysisService: Opening image picker...');
    return _pickAndAnalyzeWithType(FileType.image, null);
  }

  /// Pick and analyze a PDF file
  Future<FileAnalysisResult?> pickAndAnalyzePdf() async {
    debugPrint('📄 FileAnalysisService: Opening PDF picker...');
    return _pickAndAnalyzeWithType(FileType.custom, ['pdf']);
  }

  /// Pick and analyze a document file (TXT, DOC)
  Future<FileAnalysisResult?> pickAndAnalyzeDocument() async {
    debugPrint('📝 FileAnalysisService: Opening document picker...');
    return _pickAndAnalyzeWithType(FileType.custom, [
      'txt',
      'doc',
      'docx',
      'rtf',
    ]);
  }

  /// Pick and analyze a spreadsheet file (CSV)
  Future<FileAnalysisResult?> pickAndAnalyzeSpreadsheet() async {
    debugPrint('📊 FileAnalysisService: Opening spreadsheet picker...');
    return _pickAndAnalyzeWithType(FileType.custom, ['csv', 'xlsx', 'xls']);
  }

  /// Internal method to pick and analyze files with specific type
  Future<FileAnalysisResult?> _pickAndAnalyzeWithType(
    FileType type,
    List<String>? extensions,
  ) async {
    try {
      debugPrint(
        '📁 FileAnalysisService: Opening file picker with type: $type, extensions: $extensions',
      );

      FilePickerResult? result;

      try {
        if (type == FileType.custom && extensions != null) {
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: extensions,
            allowMultiple: false,
            withData: true,
          );
        } else if (type == FileType.image) {
          result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: false,
            withData: true,
          );
        } else {
          result = await FilePicker.platform.pickFiles(
            type: FileType.any,
            allowMultiple: false,
            withData: true,
          );
        }
      } catch (e) {
        debugPrint('📁 FileAnalysisService: FilePicker error: $e');
        // Fallback to any type
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
          withData: true,
        );
      }

      if (result == null || result.files.isEmpty) {
        debugPrint('📁 FileAnalysisService: No file selected');
        return null;
      }

      final file = result.files.first;
      debugPrint('📁 FileAnalysisService: File selected: ${file.name}');
      debugPrint('📁 FileAnalysisService: File size: ${file.size} bytes');
      debugPrint('📁 FileAnalysisService: File extension: ${file.extension}');
      debugPrint('📁 FileAnalysisService: File path: ${file.path}');
      debugPrint('�� FileAnalysisService: Has bytes: ${file.bytes != null}');

      // Check file extension
      final extension =
          file.extension?.toLowerCase() ??
          file.name.split('.').last.toLowerCase();
      final supportedExtensions = [
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'gif',
        'webp',
        'bmp',
        'doc',
        'docx',
        'txt',
        'csv',
        'xlsx',
        'xls',
      ];

      if (!supportedExtensions.contains(extension)) {
        return FileAnalysisResult(
          success: false,
          error:
              'Unsupported file type: .$extension\n\nSupported: PDF, Images (PNG, JPG), Documents (TXT, DOC), Spreadsheets (CSV)',
        );
      }

      // Try bytes first (more reliable on mobile/web)
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        debugPrint(
          '📁 FileAnalysisService: Using file bytes directly (${file.bytes!.length} bytes)',
        );
        return await _analyzeFromBytes(file.bytes!, file.name);
      }

      // Fallback to file path
      if (file.path != null) {
        debugPrint('📁 FileAnalysisService: Analyzing file at: ${file.path}');
        return await analyzeFile(File(file.path!), file.name);
      }

      return FileAnalysisResult(
        success: false,
        error: 'Could not access file. Please try again.',
      );
    } catch (e, stackTrace) {
      debugPrint('📁 FileAnalysisService: Error picking file: $e');
      debugPrint('Stack trace: $stackTrace');
      return FileAnalysisResult(
        success: false,
        error: 'Error picking file: $e',
      );
    }
  }

  /// Analyze from bytes directly (for web or when path is not available)
  Future<FileAnalysisResult> _analyzeFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final extension = fileName.split('.').last.toLowerCase();
      debugPrint(
        '📁 Analyzing from bytes: $fileName ($extension), ${bytes.length} bytes',
      );

      if (_isPdf(extension)) {
        return await _analyzePdfFromBytes(bytes, fileName);
      } else if (_isImage(extension, '')) {
        return await _analyzeImageFromBytes(bytes, fileName);
      } else if (_isTextDocument(extension)) {
        return await _analyzeTextFromBytes(bytes, fileName);
      } else if (_isSpreadsheet(extension)) {
        return await _analyzeSpreadsheetFromBytes(bytes, fileName);
      }

      return FileAnalysisResult(
        success: false,
        error: 'Unsupported file type: $extension',
      );
    } catch (e) {
      return FileAnalysisResult(
        success: false,
        error: 'Error analyzing file: $e',
      );
    }
  }

  Future<FileAnalysisResult> _analyzePdfFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      debugPrint('📄 PDF: Processing ${bytes.length} bytes...');
      final document = PdfDocument(inputBytes: bytes);
      final StringBuffer extractedText = StringBuffer();
      int pageCount = document.pages.count;
      debugPrint('📄 PDF: Page count: $pageCount');

      // Extract text from each page
      for (int i = 0; i < pageCount; i++) {
        try {
          final PdfTextExtractor extractor = PdfTextExtractor(document);
          final String pageText = extractor.extractText(
            startPageIndex: i,
            endPageIndex: i,
          );
          extractedText.writeln('--- Page ${i + 1} ---');
          extractedText.writeln(pageText);
          extractedText.writeln();
          debugPrint(
            '📄 PDF: Page ${i + 1} extracted ${pageText.length} characters',
          );
        } catch (e) {
          debugPrint('📄 PDF: Error extracting page ${i + 1}: $e');
          extractedText.writeln('--- Page ${i + 1} ---');
          extractedText.writeln('[Error extracting text from this page]');
          extractedText.writeln();
        }
      }

      document.dispose();
      final text = extractedText.toString();
      debugPrint('📄 PDF: Total extracted ${text.length} characters');

      // Check if we got any meaningful text
      final cleanText = text.replaceAll(RegExp(r'--- Page \d+ ---'), '').trim();
      if (cleanText.isEmpty || cleanText.length < 20) {
        debugPrint('📄 PDF: No meaningful text found, might be image-based');
        return FileAnalysisResult(
          success: true,
          fileName: fileName,
          fileType: 'PDF',
          pageCount: pageCount,
          extractedText: '',
          summary:
              'This PDF contains $pageCount page(s) but no extractable text was found. It may be an image-based or scanned PDF. For scanned documents, consider using an OCR tool first.',
          keyPoints: [
            'PDF loaded successfully',
            '$pageCount page(s) detected',
            'No text could be extracted',
            'Possible reasons: Image-based PDF, scanned document, or protected content',
            'Tip: For scanned PDFs, use OCR software to convert to searchable PDF',
          ],
        );
      }

      // Detect potential tables in the text
      final detectedTables = _detectTablesInText(text);
      debugPrint('📄 PDF: Detected ${detectedTables.length} potential tables');

      // Send to Gemini for comprehensive analysis
      debugPrint('📄 PDF: Sending to Gemini for analysis...');
      final analysisPrompt =
          '''Analyze this PDF document named "$fileName".

Document Info:
- Pages: $pageCount
- Characters extracted: ${text.length}

Content:
${text.length > 15000 ? '${text.substring(0, 15000)}...[content truncated]' : text}

Please provide a comprehensive analysis including:
1. A detailed summary of the document content (2-3 paragraphs)
2. Key points and important takeaways (as bullet points)
3. If there are any tables in the document, extract and structure the data
4. Important numbers, dates, or statistics mentioned
5. The overall purpose/type of document (report, contract, manual, etc.)

Format your response as JSON:
{
  "summary": "detailed summary here...",
  "keyPoints": ["point 1", "point 2", "point 3", ...],
  "tables": [{"title": "Table Name", "data": [["Header1", "Header2"], ["Row1Col1", "Row1Col2"]]}] or null if no tables,
  "documentType": "type of document",
  "importantData": ["key statistic 1", "key date 2", ...]
}''';

      final analysis = await _getPdfGeminiAnalysis(analysisPrompt);
      debugPrint('📄 PDF: Analysis complete');

      // Combine detected tables with Gemini-extracted tables
      List<dynamic>? allTables = analysis['tables'] as List<dynamic>?;
      if (detectedTables.isNotEmpty &&
          (allTables == null || allTables.isEmpty)) {
        allTables = detectedTables;
      }

      // Build enhanced key points
      List<String> keyPoints = _parseKeyPoints(analysis['keyPoints']);
      if (analysis['importantData'] != null) {
        keyPoints.addAll(_parseKeyPoints(analysis['importantData']));
      }
      if (analysis['documentType'] != null) {
        keyPoints.insert(0, 'Document type: ${analysis['documentType']}');
      }

      return FileAnalysisResult(
        success: true,
        fileName: fileName,
        fileType: 'PDF',
        pageCount: pageCount,
        extractedText: text,
        summary: analysis['summary'] as String?,
        keyPoints: keyPoints,
        tables: allTables,
      );
    } catch (e, stackTrace) {
      debugPrint('📄 PDF Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return FileAnalysisResult(success: false, error: 'Error reading PDF: $e');
    }
  }

  /// Detect potential tables in extracted text
  List<List<List<String>>> _detectTablesInText(String text) {
    final List<List<List<String>>> tables = [];

    // Look for patterns that suggest tabular data
    final lines = text.split('\n');
    List<List<String>> currentTable = [];
    int consecutiveTabularLines = 0;

    for (final line in lines) {
      // Check if line has multiple values separated by tabs or multiple spaces
      final cells = line
          .split(RegExp(r'\t|  +'))
          .where((s) => s.trim().isNotEmpty)
          .toList();

      if (cells.length >= 2) {
        currentTable.add(cells.map((c) => c.trim()).toList());
        consecutiveTabularLines++;
      } else {
        // If we had a table going, save it
        if (consecutiveTabularLines >= 3 && currentTable.isNotEmpty) {
          tables.add(List.from(currentTable));
        }
        currentTable = [];
        consecutiveTabularLines = 0;
      }
    }

    // Check for remaining table
    if (consecutiveTabularLines >= 3 && currentTable.isNotEmpty) {
      tables.add(currentTable);
    }

    return tables;
  }

  /// Special Gemini analysis for PDF with better parsing
  Future<Map<String, dynamic>> _getPdfGeminiAnalysis(String prompt) async {
    try {
      debugPrint('🤖 Gemini PDF: Sending analysis request...');
      final response = await _geminiService.generateContent(prompt);

      if (response == null || response.isEmpty) {
        debugPrint('🤖 Gemini PDF: Response is null or empty');
        return {
          'summary':
              'AI analysis could not be generated. The PDF was processed but no summary is available.',
          'keyPoints': <String>[
            'PDF loaded successfully',
            'Text extracted',
            'AI analysis unavailable',
          ],
          'tables': null,
          'documentType': 'Unknown',
          'importantData': null,
        };
      }

      debugPrint('🤖 Gemini PDF: Got response (${response.length} chars)');

      try {
        String jsonStr = response;
        if (jsonStr.contains('```json')) {
          jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        } else if (jsonStr.contains('```')) {
          jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        }
        final decoded = json.decode(jsonStr);
        debugPrint('🤖 Gemini PDF: Successfully parsed JSON');
        return decoded;
      } catch (e) {
        debugPrint('🤖 Gemini PDF: Could not parse as JSON: $e');
        // Return the raw response as summary
        return {
          'summary': response,
          'keyPoints': <String>[],
          'tables': null,
          'documentType': 'Document',
          'importantData': null,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('🤖 Gemini PDF: Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'summary': 'Could not generate AI analysis: $e',
        'keyPoints': <String>[],
        'tables': null,
      };
    }
  }

  Future<FileAnalysisResult> _analyzeImageFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      debugPrint('🖼️ Image: Processing ${bytes.length} bytes...');
      final base64Image = base64Encode(bytes);
      final mimeType = lookupMimeType(fileName) ?? 'image/jpeg';

      final analysis = await _geminiService.analyzeImage(
        base64Image: base64Image,
        mimeType: mimeType,
        prompt: '''Analyze this image. Provide:
1. Description of what you see
2. Any text visible (OCR)
3. Chart/graph analysis if present
4. Key insights

Respond in JSON format:
{"description": "...", "extractedText": "...", "chartAnalysis": "...", "keyInsights": ["...", "..."]}''',
      );

      Map<String, dynamic> parsed = {
        'description': analysis,
        'keyInsights': <String>[],
      };
      try {
        String jsonStr = analysis;
        if (jsonStr.contains('```json')) {
          jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        } else if (jsonStr.contains('```')) {
          jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        }
        parsed = json.decode(jsonStr);
      } catch (_) {}

      return FileAnalysisResult(
        success: true,
        fileName: fileName,
        fileType: 'Image',
        extractedText: parsed['extractedText']?.toString() ?? '',
        summary: parsed['description']?.toString() ?? analysis,
        keyPoints: _parseKeyPoints(parsed['keyInsights']),
        chartAnalysis: parsed['chartAnalysis']?.toString(),
      );
    } catch (e) {
      debugPrint('🖼️ Image Error: $e');
      return FileAnalysisResult(
        success: false,
        error: 'Error analyzing image: $e',
      );
    }
  }

  Future<FileAnalysisResult> _analyzeTextFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final extension = fileName.split('.').last.toLowerCase();
      debugPrint(
        '📝 Document: Processing ${bytes.length} bytes, extension: $extension',
      );

      String text = '';

      if (extension == 'txt') {
        // Plain text file - decode as UTF-8
        debugPrint('📝 Document: Reading as plain text...');
        text = utf8.decode(bytes, allowMalformed: true);
        debugPrint('📝 Document: Decoded ${text.length} characters');
      } else if (extension == 'docx') {
        // DOCX is a ZIP file containing XML - try to extract text
        debugPrint('📝 Document: Attempting to extract text from DOCX...');
        text = await _extractTextFromDocx(bytes);
        debugPrint(
          '📝 Document: Extracted ${text.length} characters from DOCX',
        );
      } else if (extension == 'doc') {
        // DOC is old binary format - try basic extraction
        debugPrint('📝 Document: Attempting to extract text from DOC...');
        text = _extractTextFromDoc(bytes);
        debugPrint('📝 Document: Extracted ${text.length} characters from DOC');
      } else if (extension == 'rtf') {
        // RTF has embedded text we can try to extract
        debugPrint('📝 Document: Attempting to extract text from RTF...');
        text = _extractTextFromRtf(bytes);
        debugPrint('📝 Document: Extracted ${text.length} characters from RTF');
      } else {
        // Try generic text decode
        text = utf8.decode(bytes, allowMalformed: true);
      }

      if (text.trim().isEmpty) {
        return FileAnalysisResult(
          success: true,
          fileName: fileName,
          fileType: 'Document',
          extractedText: '',
          summary:
              'The document appears to be empty or the text could not be extracted. For DOC/DOCX files, try saving as TXT or PDF for better results.',
          keyPoints: [
            'Document loaded',
            'No extractable text found',
            'Tip: Save as TXT or PDF for better text extraction',
          ],
        );
      }

      debugPrint('📝 Document: Sending to Gemini for analysis...');
      final analysis = await _getGeminiAnalysis(
        text,
        'text document',
        fileName,
      );
      debugPrint('📝 Document: Analysis complete');

      return FileAnalysisResult(
        success: true,
        fileName: fileName,
        fileType: 'Document',
        extractedText: text,
        summary: analysis['summary'] as String?,
        keyPoints: _parseKeyPoints(analysis['keyPoints']),
      );
    } catch (e, stackTrace) {
      debugPrint('📝 Document Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return FileAnalysisResult(
        success: false,
        error: 'Error reading document: $e',
      );
    }
  }

  /// Extract text from DOCX file (ZIP with XML content)
  Future<String> _extractTextFromDocx(Uint8List bytes) async {
    try {
      // DOCX is a ZIP file, we need to extract document.xml
      // For simplicity, we'll try to find and extract readable text
      final String rawContent = latin1.decode(bytes);

      // Try to find XML content between tags
      final RegExp textPattern = RegExp(
        r'<w:t[^>]*>([^<]*)</w:t>',
        multiLine: true,
      );
      final matches = textPattern.allMatches(rawContent);

      if (matches.isNotEmpty) {
        final StringBuffer extractedText = StringBuffer();
        for (final match in matches) {
          if (match.group(1) != null) {
            extractedText.write(match.group(1));
            extractedText.write(' ');
          }
        }
        return extractedText.toString().trim();
      }

      // Fallback: try to extract any readable ASCII text
      return _extractReadableText(bytes);
    } catch (e) {
      debugPrint('📝 DOCX extraction error: $e');
      return _extractReadableText(bytes);
    }
  }

  /// Extract text from old DOC format (binary)
  String _extractTextFromDoc(Uint8List bytes) {
    try {
      // DOC files have text embedded in binary - try to extract readable portions
      return _extractReadableText(bytes);
    } catch (e) {
      debugPrint('📝 DOC extraction error: $e');
      return '';
    }
  }

  /// Extract text from RTF format
  String _extractTextFromRtf(Uint8List bytes) {
    try {
      String content = latin1.decode(bytes);

      // Remove RTF control words and groups
      content = content.replaceAll(RegExp(r'\\[a-z]+\d*\s?'), ' ');
      content = content.replaceAll(RegExp(r'[{}]'), '');
      content = content.replaceAll(RegExp(r'\s+'), ' ');

      return content.trim();
    } catch (e) {
      debugPrint('📝 RTF extraction error: $e');
      return _extractReadableText(bytes);
    }
  }

  /// Extract readable ASCII text from binary data
  String _extractReadableText(Uint8List bytes) {
    final StringBuffer text = StringBuffer();
    final StringBuffer currentWord = StringBuffer();

    for (int byte in bytes) {
      // Check if it's a printable ASCII character
      if (byte >= 32 && byte <= 126) {
        currentWord.writeCharCode(byte);
      } else if (byte == 10 || byte == 13) {
        // Newline
        if (currentWord.length > 2) {
          text.write(currentWord.toString());
          text.write(' ');
        }
        currentWord.clear();
      } else {
        // Non-printable character - check if we have a word
        if (currentWord.length > 2) {
          text.write(currentWord.toString());
          text.write(' ');
        }
        currentWord.clear();
      }
    }

    // Add any remaining word
    if (currentWord.length > 2) {
      text.write(currentWord.toString());
    }

    return text.toString().trim();
  }

  Future<FileAnalysisResult> _analyzeSpreadsheetFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      debugPrint('📊 Spreadsheet: Processing ${bytes.length} bytes...');
      final extension = fileName.split('.').last.toLowerCase();

      if (extension == 'xlsx' || extension == 'xls') {
        // Try to extract some readable content from Excel files
        debugPrint(
          '📊 Spreadsheet: Attempting to extract text from Excel file...',
        );
        final extractedText = _extractReadableText(bytes);

        if (extractedText.length > 50) {
          debugPrint(
            '📊 Spreadsheet: Extracted ${extractedText.length} characters from Excel',
          );
          final analysis = await _getGeminiAnalysis(
            extractedText,
            'Excel spreadsheet (partial extraction)',
            fileName,
          );

          return FileAnalysisResult(
            success: true,
            fileName: fileName,
            fileType: 'Spreadsheet (Excel)',
            extractedText: extractedText,
            summary:
                '${analysis['summary'] ?? ''}\n\nNote: For better results, please save the Excel file as CSV format.',
            keyPoints: [
              ..._parseKeyPoints(analysis['keyPoints']),
              'Tip: Convert to CSV for complete data extraction',
            ],
          );
        }

        return FileAnalysisResult(
          success: true,
          fileName: fileName,
          fileType: 'Spreadsheet (Excel)',
          extractedText: '',
          summary:
              'Excel files (.xlsx/.xls) have limited text extraction. For full data analysis, please save the file as CSV format.',
          keyPoints: [
            'Excel file detected',
            'Limited text extraction available',
            'Recommendation: Save as CSV for complete analysis',
          ],
        );
      }

      // CSV processing
      debugPrint('📊 Spreadsheet: Processing as CSV...');
      final content = utf8.decode(bytes, allowMalformed: true);
      debugPrint('📊 Spreadsheet: Decoded ${content.length} characters');

      final List<List<String>> tableData = _parseCSV(content);
      debugPrint('📊 Spreadsheet: Parsed ${tableData.length} rows');

      if (tableData.isEmpty) {
        return FileAnalysisResult(
          success: true,
          fileName: fileName,
          fileType: 'Spreadsheet',
          extractedText: content,
          summary: 'The CSV file appears to be empty or could not be parsed.',
          keyPoints: ['CSV file loaded', 'No data rows found'],
        );
      }

      // Create a summary of the data structure
      final columnCount = tableData.isNotEmpty ? tableData.first.length : 0;
      final dataPreview = _createDataPreview(tableData);

      debugPrint('📊 Spreadsheet: Sending to Gemini for analysis...');
      final analysisPrompt =
          '''
CSV Data Analysis Request:
- Rows: ${tableData.length}
- Columns: $columnCount
- Headers: ${tableData.isNotEmpty ? tableData.first.join(', ') : 'None'}

Data Preview:
$dataPreview

Please analyze this spreadsheet data and provide insights.
''';

      final analysis = await _getGeminiAnalysis(
        analysisPrompt,
        'CSV spreadsheet',
        fileName,
      );
      debugPrint('📊 Spreadsheet: Analysis complete');

      return FileAnalysisResult(
        success: true,
        fileName: fileName,
        fileType: 'Spreadsheet',
        extractedText: content,
        summary: analysis['summary'] as String?,
        keyPoints: _parseKeyPoints(analysis['keyPoints']),
        tables: [tableData],
        rowCount: tableData.length,
        columnCount: columnCount,
      );
    } catch (e, stackTrace) {
      debugPrint('📊 Spreadsheet Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return FileAnalysisResult(
        success: false,
        error: 'Error reading spreadsheet: $e',
      );
    }
  }

  /// Parse CSV content handling quoted fields
  List<List<String>> _parseCSV(String content) {
    final List<List<String>> result = [];
    final lines = content.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final List<String> row = [];
      bool inQuotes = false;
      StringBuffer currentField = StringBuffer();

      for (int i = 0; i < line.length; i++) {
        final char = line[i];

        if (char == '"') {
          inQuotes = !inQuotes;
        } else if (char == ',' && !inQuotes) {
          row.add(currentField.toString().trim());
          currentField = StringBuffer();
        } else {
          currentField.write(char);
        }
      }

      // Add the last field
      row.add(currentField.toString().trim());
      result.add(row);
    }

    return result;
  }

  /// Create a preview of the data for analysis
  String _createDataPreview(List<List<String>> tableData) {
    final StringBuffer preview = StringBuffer();
    final maxRows = tableData.length > 10 ? 10 : tableData.length;

    for (int i = 0; i < maxRows; i++) {
      preview.writeln('Row ${i + 1}: ${tableData[i].join(' | ')}');
    }

    if (tableData.length > 10) {
      preview.writeln('... and ${tableData.length - 10} more rows');
    }

    return preview.toString();
  }

  /// Analyze a file based on its type
  Future<FileAnalysisResult> analyzeFile(File file, String fileName) async {
    try {
      final mimeType = lookupMimeType(fileName) ?? '';
      final extension = fileName.split('.').last.toLowerCase();

      debugPrint(
        '📁 FileAnalysisService: Analyzing $fileName (ext: $extension, mime: $mimeType)',
      );

      if (_isPdf(extension)) {
        debugPrint('📁 FileAnalysisService: Processing as PDF');
        return await _analyzePdf(file, fileName);
      } else if (_isImage(extension, mimeType)) {
        debugPrint('📁 FileAnalysisService: Processing as Image');
        return await _analyzeImage(file, fileName);
      } else if (_isTextDocument(extension)) {
        debugPrint('📁 FileAnalysisService: Processing as Text Document');
        return await _analyzeTextDocument(file, fileName);
      } else if (_isSpreadsheet(extension)) {
        debugPrint('📁 FileAnalysisService: Processing as Spreadsheet');
        return await _analyzeSpreadsheet(file, fileName);
      } else {
        debugPrint('📁 FileAnalysisService: Unsupported file type: $extension');
        return FileAnalysisResult(
          success: false,
          error: 'Unsupported file type: $extension',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('📁 FileAnalysisService: Error analyzing file: $e');
      debugPrint('Stack trace: $stackTrace');
      return FileAnalysisResult(
        success: false,
        error: 'Error analyzing file: $e',
      );
    }
  }

  bool _isPdf(String extension) => extension == 'pdf';

  bool _isImage(String extension, String mimeType) {
    return ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].contains(extension) ||
        mimeType.startsWith('image/');
  }

  bool _isTextDocument(String extension) {
    return ['txt', 'doc', 'docx', 'rtf'].contains(extension);
  }

  bool _isSpreadsheet(String extension) {
    return ['csv', 'xlsx', 'xls'].contains(extension);
  }

  /// Extract text from PDF
  Future<FileAnalysisResult> _analyzePdf(File file, String fileName) async {
    try {
      debugPrint('📄 PDF: Reading file bytes...');
      final bytes = await file.readAsBytes();
      debugPrint('📄 PDF: File size: ${bytes.length} bytes');

      final document = PdfDocument(inputBytes: bytes);
      debugPrint('📄 PDF: Document loaded');

      final StringBuffer extractedText = StringBuffer();
      int pageCount = document.pages.count;
      debugPrint('📄 PDF: Page count: $pageCount');

      // Extract text from each page
      for (int i = 0; i < pageCount; i++) {
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        final String pageText = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        extractedText.writeln('--- Page ${i + 1} ---');
        extractedText.writeln(pageText);
        extractedText.writeln();
      }

      document.dispose();

      final text = extractedText.toString();
      debugPrint('📄 PDF: Extracted ${text.length} characters');

      // If no text extracted, return basic result
      if (text.trim().isEmpty ||
          text.replaceAll(RegExp(r'--- Page \d+ ---'), '').trim().isEmpty) {
        debugPrint('📄 PDF: No text found in PDF (might be image-based)');
        return FileAnalysisResult(
          success: true,
          fileName: fileName,
          fileType: 'PDF',
          pageCount: pageCount,
          extractedText: '',
          summary:
              'This PDF appears to be image-based or contains no extractable text. It has $pageCount page(s).',
          keyPoints: [
            'PDF loaded successfully',
            '$pageCount pages detected',
            'No text could be extracted (possibly image-based PDF)',
          ],
        );
      }

      // Use Gemini to analyze the content
      debugPrint('📄 PDF: Sending to Gemini for analysis...');
      final analysis = await _getGeminiAnalysis(text, 'PDF document', fileName);
      debugPrint('📄 PDF: Analysis complete');

      return FileAnalysisResult(
        success: true,
        fileName: fileName,
        fileType: 'PDF',
        pageCount: pageCount,
        extractedText: text,
        summary: analysis['summary'] as String?,
        keyPoints: _parseKeyPoints(analysis['keyPoints']),
        tables: analysis['tables'] as List<dynamic>?,
      );
    } catch (e, stackTrace) {
      debugPrint('📄 PDF: Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return FileAnalysisResult(success: false, error: 'Error reading PDF: $e');
    }
  }

  /// Analyze image using Gemini Vision
  Future<FileAnalysisResult> _analyzeImage(File file, String fileName) async {
    try {
      debugPrint('🖼️ Image: Reading file bytes...');
      final bytes = await file.readAsBytes();
      debugPrint('🖼️ Image: File size: ${bytes.length} bytes');

      final base64Image = base64Encode(bytes);
      final mimeType = lookupMimeType(fileName) ?? 'image/jpeg';
      debugPrint('🖼️ Image: MIME type: $mimeType');

      // Use Gemini to analyze the image
      debugPrint('🖼️ Image: Sending to Gemini Vision...');
      final analysis = await _geminiService.analyzeImage(
        base64Image: base64Image,
        mimeType: mimeType,
        prompt: '''Analyze this image in detail. Provide:
1. A comprehensive description of what you see
2. Any text visible in the image (OCR)
3. If there are charts/graphs, explain the data they represent
4. If there are tables, extract the data
5. Key insights or important information

Format your response as JSON with these fields:
- description: string (detailed description)
- extractedText: string (any text found in image)
- chartAnalysis: string (if charts present, otherwise null)
- tableData: array of objects (if tables present, otherwise null)
- keyInsights: array of strings''',
      );

      debugPrint('🖼️ Image: Got response from Gemini');

      Map<String, dynamic> parsedAnalysis = {};
      try {
        // Try to parse as JSON
        String jsonStr = analysis;
        if (jsonStr.contains('```json')) {
          jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        } else if (jsonStr.contains('```')) {
          jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        }
        parsedAnalysis = json.decode(jsonStr);
        debugPrint('🖼️ Image: Successfully parsed JSON response');
      } catch (e) {
        debugPrint(
          '🖼️ Image: Could not parse as JSON, using raw response: $e',
        );
        parsedAnalysis = {'description': analysis, 'keyInsights': <String>[]};
      }

      return FileAnalysisResult(
        success: true,
        fileName: fileName,
        fileType: 'Image',
        extractedText: parsedAnalysis['extractedText']?.toString() ?? '',
        summary: parsedAnalysis['description']?.toString() ?? analysis,
        keyPoints: _parseKeyPoints(parsedAnalysis['keyInsights']),
        tables: parsedAnalysis['tableData'] != null
            ? [parsedAnalysis['tableData']]
            : null,
        chartAnalysis: parsedAnalysis['chartAnalysis']?.toString(),
      );
    } catch (e, stackTrace) {
      debugPrint('🖼️ Image: Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return FileAnalysisResult(
        success: false,
        error: 'Error analyzing image: $e',
      );
    }
  }

  /// Analyze text document
  Future<FileAnalysisResult> _analyzeTextDocument(
    File file,
    String fileName,
  ) async {
    try {
      String text;
      final extension = fileName.split('.').last.toLowerCase();

      debugPrint('📝 Document: Reading file...');

      if (extension == 'txt') {
        text = await file.readAsString();
      } else {
        // For doc/docx, read as bytes and try to extract text
        final bytes = await file.readAsBytes();
        text = _extractTextFromBytes(bytes);
      }

      debugPrint('📝 Document: Extracted ${text.length} characters');

      if (text.trim().isEmpty) {
        return FileAnalysisResult(
          success: true,
          fileName: fileName,
          fileType: 'Document',
          extractedText: '',
          summary:
              'The document appears to be empty or the text could not be extracted.',
          keyPoints: ['Document loaded', 'No readable text found'],
        );
      }

      debugPrint('📝 Document: Sending to Gemini for analysis...');
      final analysis = await _getGeminiAnalysis(
        text,
        'text document',
        fileName,
      );

      return FileAnalysisResult(
        success: true,
        fileName: fileName,
        fileType: 'Document',
        extractedText: text,
        summary: analysis['summary'] as String?,
        keyPoints: _parseKeyPoints(analysis['keyPoints']),
      );
    } catch (e, stackTrace) {
      debugPrint('📝 Document: Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return FileAnalysisResult(
        success: false,
        error: 'Error reading document: $e',
      );
    }
  }

  /// Analyze spreadsheet (CSV)
  Future<FileAnalysisResult> _analyzeSpreadsheet(
    File file,
    String fileName,
  ) async {
    try {
      final extension = fileName.split('.').last.toLowerCase();
      String content;

      debugPrint('📊 Spreadsheet: Reading file...');

      if (extension == 'csv') {
        content = await file.readAsString();
      } else {
        // For xlsx/xls, inform user that only CSV is fully supported
        return FileAnalysisResult(
          success: false,
          error:
              'Excel files (.xlsx/.xls) require additional parsing. Please convert to CSV for full analysis.',
        );
      }

      debugPrint('📊 Spreadsheet: File size: ${content.length} characters');

      // Parse CSV
      final lines = content.split('\n');
      final List<List<String>> tableData = [];

      for (final line in lines) {
        if (line.trim().isNotEmpty) {
          tableData.add(line.split(',').map((e) => e.trim()).toList());
        }
      }

      debugPrint('📊 Spreadsheet: Parsed ${tableData.length} rows');

      debugPrint('📊 Spreadsheet: Sending to Gemini for analysis...');
      final analysis = await _getGeminiAnalysis(
        content,
        'spreadsheet/CSV',
        fileName,
      );

      return FileAnalysisResult(
        success: true,
        fileName: fileName,
        fileType: 'Spreadsheet',
        extractedText: content,
        summary: analysis['summary'] as String?,
        keyPoints: _parseKeyPoints(analysis['keyPoints']),
        tables: [tableData],
        rowCount: tableData.length,
        columnCount: tableData.isNotEmpty ? tableData.first.length : 0,
      );
    } catch (e, stackTrace) {
      debugPrint('📊 Spreadsheet: Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return FileAnalysisResult(
        success: false,
        error: 'Error reading spreadsheet: $e',
      );
    }
  }

  /// Extract text from bytes (basic implementation)
  String _extractTextFromBytes(Uint8List bytes) {
    try {
      // Try UTF-8 decoding
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      // Fallback to Latin1
      return latin1.decode(bytes);
    }
  }

  /// Parse key points from various formats
  List<String> _parseKeyPoints(dynamic keyPoints) {
    if (keyPoints == null) return <String>[];
    if (keyPoints is List) {
      return keyPoints.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  /// Get analysis from Gemini
  Future<Map<String, dynamic>> _getGeminiAnalysis(
    String content,
    String fileType,
    String fileName,
  ) async {
    try {
      // Truncate content if too long
      final truncatedContent = content.length > 15000
          ? '${content.substring(0, 15000)}...[content truncated]'
          : content;

      final prompt =
          '''Analyze this $fileType named "$fileName".

Content:
$truncatedContent

Provide a comprehensive analysis with:
1. A clear summary (2-3 paragraphs)
2. Key points/takeaways (bullet points)
3. If there's tabular data, identify and structure it
4. Any important insights

Format as JSON:
{
  "summary": "...",
  "keyPoints": ["point1", "point2", ...],
  "tables": null
}''';

      debugPrint('🤖 Gemini: Sending analysis request...');
      final response = await _geminiService.generateContent(prompt);

      if (response == null || response.isEmpty) {
        debugPrint('🤖 Gemini: Response is null or empty');
      } else {
        final previewLength = response.length > 100 ? 100 : response.length;
        debugPrint(
          '🤖 Gemini: Got response: ${response.substring(0, previewLength)}...',
        );
      }

      if (response == null || response.isEmpty) {
        debugPrint('🤖 Gemini: Response is null or empty');
        return {
          'summary':
              'AI analysis could not be generated. The file was processed but no summary is available.',
          'keyPoints': <String>[
            'File loaded successfully',
            'AI analysis unavailable',
          ],
          'tables': null,
        };
      }

      try {
        String jsonStr = response;
        if (jsonStr.contains('```json')) {
          jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        } else if (jsonStr.contains('```')) {
          jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        }
        final decoded = json.decode(jsonStr);
        debugPrint('🤖 Gemini: Successfully parsed JSON');
        return decoded;
      } catch (e) {
        debugPrint('🤖 Gemini: Could not parse as JSON: $e');
        // Return the raw response as summary
        return {'summary': response, 'keyPoints': <String>[], 'tables': null};
      }
    } catch (e, stackTrace) {
      debugPrint('🤖 Gemini: Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'summary': 'Could not generate AI analysis: $e',
        'keyPoints': <String>[],
        'tables': null,
      };
    }
  }
}

/// Result class for file analysis
class FileAnalysisResult {
  final bool success;
  final String? error;
  final String? fileName;
  final String? fileType;
  final int? pageCount;
  final int? rowCount;
  final int? columnCount;
  final String? extractedText;
  final String? summary;
  final List<String>? keyPoints;
  final List<dynamic>? tables;
  final String? chartAnalysis;

  FileAnalysisResult({
    required this.success,
    this.error,
    this.fileName,
    this.fileType,
    this.pageCount,
    this.rowCount,
    this.columnCount,
    this.extractedText,
    this.summary,
    this.keyPoints,
    this.tables,
    this.chartAnalysis,
  });

  @override
  String toString() {
    return 'FileAnalysisResult(success: $success, fileName: $fileName, fileType: $fileType, error: $error)';
  }
}
