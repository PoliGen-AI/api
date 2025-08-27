import 'dart:typed_data';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:uuid/uuid.dart';

import 'mongodb_config.dart';

class MongoDBStore {
  MongoDBStore();

  final Uuid _uuid = const Uuid();

  // Users methods
  Future<bool> userExists(String email) async {
    final Map<String, dynamic>? user = await MongoDBConfig.usersCollection
        .findOne(where.eq('email', email));
    return user != null;
  }

  Future<Map<String, dynamic>?> getUser(String email) async {
    return await MongoDBConfig.usersCollection.findOne(
      where.eq('email', email),
    );
  }

  Future<Map<String, dynamic>?> getUserById(ObjectId id) async {
    return await MongoDBConfig.usersCollection.findOne(where.id(id));
  }

  Future<void> createUser({
    required String name,
    required String email,
    required String passwordHash,
  }) async {
    final Map<String, dynamic> user = {
      'name': name,
      'email': email,
      'passwordHash': passwordHash,
      'createdAt': DateTime.now().toIso8601String(),
    };

    await MongoDBConfig.usersCollection.insertOne(user);
  }

  // Images methods using GridFS
  Future<String> saveImage({
    required String userEmail,
    required String prompt,
    required Uint8List imageData,
    required String fileName,
  }) async {
    final String id = _uuid.v4();

    // Save image data to GridFS
    final Stream<List<int>> stream = Stream<List<int>>.fromIterable([
      imageData,
    ]);
    final GridIn gridIn = await MongoDBConfig.gridFS.createFile(
      stream,
      fileName,
    );
    gridIn.contentType = 'image/png';
    await gridIn.save();
    final ObjectId gridFSId = gridIn.id;

    // Save metadata to images collection
    final Map<String, dynamic> imageRecord = {
      'id': id,
      'userEmail': userEmail,
      'prompt': prompt,
      'fileName': fileName,
      'gridFSId': gridFSId,
      'createdAt': DateTime.now().toIso8601String(),
    };

    await MongoDBConfig.imagesCollection.insertOne(imageRecord);

    return id;
  }

  Future<Map<String, dynamic>?> getImageRecord(String id) async {
    return await MongoDBConfig.imagesCollection.findOne(where.eq('id', id));
  }

  Future<Uint8List?> getImageData(String id) async {
    final Map<String, dynamic>? record = await getImageRecord(id);
    if (record == null) return null;

    final ObjectId gridFSId = record['gridFSId'] as ObjectId;

    // Read the file data directly from GridFS chunks
    final List<Map<String, dynamic>> chunks = await MongoDBConfig.gridFS.chunks
        .find(where.eq('files_id', gridFSId).sortBy('n'))
        .toList();

    if (chunks.isEmpty) return null;

    // Combine all chunks into a single Uint8List
    final List<int> allBytes = [];
    for (final Map<String, dynamic> chunk in chunks) {
      // Handle BsonBinary data properly
      final data = chunk['data'];
      Uint8List chunkData;

      if (data is BsonBinary) {
        // Convert BsonBinary to Uint8List
        chunkData = Uint8List.fromList(data.byteList);
      } else if (data is Uint8List) {
        // Already Uint8List
        chunkData = data;
      } else if (data is List<int>) {
        // Convert List<int> to Uint8List
        chunkData = Uint8List.fromList(data);
      } else {
        // Try to convert to string and then to bytes as fallback
        final String dataStr = data.toString();
        chunkData = Uint8List.fromList(dataStr.codeUnits);
      }

      allBytes.addAll(chunkData);
    }

    return Uint8List.fromList(allBytes);
  }

  Future<List<Map<String, dynamic>>> getUserImages(String email) async {
    final List<Map<String, dynamic>> images = await MongoDBConfig
        .imagesCollection
        .find(
          where.eq('userEmail', email).sortBy('createdAt', descending: true),
        )
        .toList();

    return images;
  }

  Future<void> deleteImage(String id) async {
    final Map<String, dynamic>? record = await getImageRecord(id);
    if (record != null) {
      final ObjectId gridFSId = record['gridFSId'] as ObjectId;

      // Delete from GridFS
      await MongoDBConfig.gridFS.files.deleteOne(where.id(gridFSId));
      await MongoDBConfig.gridFS.chunks.deleteMany(
        where.eq('files_id', gridFSId),
      );

      // Delete metadata
      await MongoDBConfig.imagesCollection.deleteOne(where.eq('id', id));
    }
  }
}
