import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class JsonStore {
  JsonStore();

  Future<Directory> _dataDir() async {
    final Directory dir = Directory(p.join(Directory.current.path, 'data'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _usersFile() async {
    final Directory dir = await _dataDir();
    final File file = File(p.join(dir.path, 'users.json'));
    if (!await file.exists()) {
      await file.writeAsString(
        jsonEncode(<String, dynamic>{'users': <Map<String, dynamic>>[]}),
      );
    }
    return file;
  }

  Future<File> _imagesFile() async {
    final Directory dir = await _dataDir();
    final File file = File(p.join(dir.path, 'images.json'));
    if (!await file.exists()) {
      await file.writeAsString(
        jsonEncode(<String, dynamic>{'images': <Map<String, dynamic>>[]}),
      );
    }
    return file;
  }

  Future<Directory> imagesDir() async {
    final Directory dir = Directory(
      p.join(Directory.current.path, 'data', 'images'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // Users
  Future<bool> userExists(String email) async {
    final List<Map<String, dynamic>> users = await _readUsers();
    return users.any((Map<String, dynamic> u) => u['email'] == email);
  }

  Future<Map<String, dynamic>?> getUser(String email) async {
    final List<Map<String, dynamic>> users = await _readUsers();
    try {
      return users.firstWhere((Map<String, dynamic> u) => u['email'] == email);
    } catch (_) {
      return null;
    }
  }

  Future<void> createUser({
    required String email,
    required String passwordHash,
  }) async {
    final File f = await _usersFile();
    final Map<String, dynamic> obj =
        jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    final List<dynamic> users = obj['users'] as List<dynamic>;
    users.add(<String, dynamic>{'email': email, 'passwordHash': passwordHash});
    await f.writeAsString(jsonEncode(<String, dynamic>{'users': users}));
  }

  Future<List<Map<String, dynamic>>> _readUsers() async {
    final File f = await _usersFile();
    final Map<String, dynamic> obj =
        jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    return (obj['users'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  // Images
  Future<void> addImageRecord({
    required String userEmail,
    required String id,
    required String prompt,
    required String path,
  }) async {
    final File f = await _imagesFile();
    final Map<String, dynamic> obj =
        jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    final List<dynamic> images = obj['images'] as List<dynamic>;
    images.add(<String, dynamic>{
      'id': id,
      'email': userEmail,
      'prompt': prompt,
      'path': path,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await f.writeAsString(jsonEncode(<String, dynamic>{'images': images}));
  }

  Future<Map<String, dynamic>?> getImageRecord(String id) async {
    final File f = await _imagesFile();
    final Map<String, dynamic> obj =
        jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    final List<dynamic> images = obj['images'] as List<dynamic>;
    try {
      return images.cast<Map<String, dynamic>>().firstWhere(
        (Map<String, dynamic> i) => i['id'] == id,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUserImages(String email) async {
    final File f = await _imagesFile();
    final Map<String, dynamic> obj =
        jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    final List<Map<String, dynamic>> images = (obj['images'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    images.sort(
      (Map<String, dynamic> a, Map<String, dynamic> b) =>
          (b['createdAt'] as String).compareTo(a['createdAt'] as String),
    );
    return images
        .where((Map<String, dynamic> i) => i['email'] == email)
        .toList(growable: false);
  }
}
