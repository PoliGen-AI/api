import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';

class MongoDBConfig {
  static Db? _db;

  /// Initialize MongoDB connection
  static Future<void> initialize() async {
    final String mongoUrl =
        Platform.environment['MONGO_URL'] ??
        'mongodb://localhost:27017/api_dart_db';

    _db = Db(mongoUrl);
    await _db!.open();

    print('Connected to MongoDB: $mongoUrl');
  }

  /// Get database instance
  static Db get db {
    if (_db == null) {
      throw StateError('MongoDB not initialized. Call initialize() first.');
    }
    return _db!;
  }

  /// Get GridFS instance for file storage
  static GridFS get gridFS => GridFS(db);

  /// Get users collection
  static DbCollection get usersCollection => db.collection('users');

  /// Get images collection (for metadata)
  static DbCollection get imagesCollection => db.collection('images');

  /// Close database connection
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
