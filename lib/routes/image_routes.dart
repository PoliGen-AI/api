import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:api_dart/storage/mongodb_store.dart';
import 'package:api_dart/util/auth_middleware.dart';

class ImageRoutes {
  ImageRoutes() : _store = MongoDBStore() {
    final String? apiKey = Platform.environment['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('GEMINI_API_KEY environment variable is required');
    }
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
  }

  final MongoDBStore _store;
  late final GenerativeModel _model;

  Router get router {
    final Router r = Router();
    // Apply auth as a middleware to preserve path params
    final Router authed = Router();
    authed.post('/generate', _generate);
    authed.get('/file/<id>', _getFile);
    r.mount('/', requireAuth(authed));
    return r;
  }

  Future<Response> _generate(Request req) async {
    final Map<String, dynamic> body = await _readJson(req);
    final String? prompt = body['prompt']?.toString();
    if (prompt == null || prompt.isEmpty) {
      return _bad('prompt is required');
    }

    final String userEmail = req.context['email'] as String;

    try {
      // Use Gemini to enhance the prompt for better image generation
      final String enhancedPrompt = await _enhancePromptWithGemini(prompt);

      // For demonstration, we'll use a simple approach with available image processing
      // In a production environment, you would integrate with a proper image generation service
      final Uint8List imageData = await _generateImageFromEnhancedPrompt(
        enhancedPrompt,
        width: 512,
        height: 512,
      );

      final String fileName =
          '$userEmail-${DateTime.now().millisecondsSinceEpoch}.png';

      // Save to MongoDB GridFS
      final String id = await _store.saveImage(
        userEmail: userEmail,
        prompt: prompt,
        imageData: imageData,
        fileName: fileName,
      );

      return Response.ok(
        jsonEncode({'id': id, 'path': 'image/file/$id'}),
        headers: _json,
      );
    } catch (e) {
      print('Error generating image: $e');
      return _bad('Failed to generate image: ${e.toString()}');
    }
  }

  Future<Response> _getFile(Request req, String id) async {
    final Uint8List? imageData = await _store.getImageData(id);
    if (imageData == null) {
      return Response.notFound(
        jsonEncode({'error': 'not found'}),
        headers: _json,
      );
    }

    return Response.ok(imageData, headers: const {'content-type': 'image/png'});
  }

  Future<String> _enhancePromptWithGemini(String originalPrompt) async {
    try {
      final response = await _model.generateContent([
        Content.text(
          'Take this image description and enhance it to be more detailed and vivid for image generation: "$originalPrompt". '
          'Make it more descriptive, add visual details, lighting, mood, and style elements. '
          'Return only the enhanced description without any additional commentary.',
        ),
      ]);

      final enhancedPrompt = response.text ?? originalPrompt;
      return enhancedPrompt.trim();
    } catch (e) {
      print('Error enhancing prompt with Gemini: $e');
      // Return original prompt if enhancement fails
      return originalPrompt;
    }
  }

  Future<Uint8List> _generateImageFromEnhancedPrompt(
    String enhancedPrompt, {
    required int width,
    required int height,
  }) async {
    // Create a more sophisticated image based on the enhanced prompt
    final img.Image base = img.Image(width: width, height: height);

    // Use the enhanced prompt to generate more sophisticated patterns
    final int promptHash = enhancedPrompt.hashCode;
    final List<String> words = enhancedPrompt.split(' ');
    final int wordCount = words.length;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Create more complex patterns based on the enhanced prompt
        final int baseNoise = ((x * 31 + y * 17 + promptHash) % 255);
        final int wordInfluence = (x * 7 + y * 11 + wordCount * 13) % 255;
        final int combined = ((baseNoise + wordInfluence) ~/ 2) % 255;

        // Add some variation based on prompt characteristics
        final int r = (combined + (promptHash % 50)) % 255;
        final int g = (combined + (wordCount * 10 % 50)) % 255;
        final int b = (combined + (enhancedPrompt.length * 5 % 50)) % 255;

        base.setPixelRgb(x, y, r, g, b);
      }
    }

    // Add a simple visual indicator based on the enhanced prompt
    // In a real implementation, you would use a proper image generation service
    final int textHash = enhancedPrompt.hashCode;
    for (int i = 0; i < 10; i++) {
      final int x = (textHash + i * 50) % (width - 20) + 10;
      final int y = (textHash + i * 30) % (height - 20) + 10;
      final int color = (textHash + i * 100) % 255;
      base.setPixelRgb(x, y, color, (color + 85) % 255, (color + 170) % 255);
    }

    return img.encodePng(base);
  }
}

Future<Map<String, dynamic>> _readJson(Request req) async {
  final String body = await req.readAsString();
  if (body.isEmpty) return <String, dynamic>{};
  return jsonDecode(body) as Map<String, dynamic>;
}

Response _bad(String message) =>
    Response(400, body: jsonEncode({'error': message}), headers: _json);

const Map<String, String> _json = {
  'content-type': 'application/json; charset=utf-8',
};
