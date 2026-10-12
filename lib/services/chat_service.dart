import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ChatService {
  ChatService({FirebaseFirestore? firestore, http.Client? client})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _client = client ?? http.Client();

  final FirebaseFirestore _firestore;
  final http.Client _client;

  static final Uri _workerUri = Uri.parse(
    'https://autisolve-chat-api.mahinkasukar6.workers.dev',
  );

  // Existing Firebase chat collection.
  CollectionReference<Map<String, dynamic>> _chatsFor(String uid) {
    return _firestore.collection('users').doc(uid).collection('chats');
  }

  // Create a new chat.
  Future<String> createChat({
    required String uid,
    required String childName,
  }) async {
    final doc = await _chatsFor(uid).add({
      'childName': childName,
      'title': 'New chat',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  // Save a user or assistant message.
  Future<void> saveMessage({
    required String uid,
    required String chatId,
    required String text,
    required bool fromUser,
  }) async {
    final chat = _chatsFor(uid).doc(chatId);

    await chat.collection('messages').add({
      'text': text,
      'fromUser': fromUser,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (fromUser && text.trim().isNotEmpty) {
      final title = text.trim();

      updates['title'] = title.length > 48
          ? '${title.substring(0, 48)}…'
          : title;
    }

    await chat.set(updates, SetOptions(merge: true));
  }

  // Load messages from an existing chat.
  Future<List<Map<String, dynamic>>> loadMessages({
    required String uid,
    required String chatId,
  }) async {
    final snapshot = await _chatsFor(uid)
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .get();

    return snapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data()};
    }).toList();
  }

  // Send a message and optional child context or attachment
  // to the Cloudflare Worker.
  Future<String> sendMessage({
    required String message,
    required String childName,
    String mode = 'normal',
    bool webSearch = false,
    Map<String, dynamic>? attachment,
    Map<String, dynamic>? childContext,
  }) async {
    final payload = <String, dynamic>{
      'message': message,
      'childName': childName,
      'mode': mode,
      'webSearch': webSearch,
    };

    // Child profile and recent activity context from Firebase.
    if (childContext != null && childContext.isNotEmpty) {
      payload['childContext'] = childContext;
    }

    // Validate and attach an optional file.
    if (attachment != null) {
      final rawBase64 = attachment['base64'];

      if (rawBase64 is! String || rawBase64.trim().isEmpty) {
        throw Exception('The attachment has no data. Please select it again.');
      }

      var base64Data = rawBase64.trim();

      // Remove a data URL prefix if one is present.
      if (base64Data.startsWith('data:')) {
        final commaIndex = base64Data.indexOf(',');

        if (commaIndex != -1) {
          base64Data = base64Data.substring(commaIndex + 1);
        }
      }

      base64Data = base64Data.replaceAll(RegExp(r'\s'), '');

      try {
        base64Decode(base64Data);
      } on FormatException {
        throw Exception(
          'The attachment data is invalid. Please select the file again.',
        );
      }

      final mimeType =
          attachment['mimeType']?.toString() ?? 'application/octet-stream';

      // Keep image types compatible with the existing Worker.
      if (mimeType.startsWith('image/') &&
          !const ['image/jpeg', 'image/png', 'image/webp'].contains(mimeType)) {
        throw Exception('Please upload a JPG, PNG, or WebP image.');
      }

      // Accept the file types handled by the existing Worker.
      if (!const [
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf',
        'text/plain',
      ].contains(mimeType)) {
        throw Exception('Supported files are JPG, PNG, WebP, PDF, and TXT.');
      }

      final attachmentBytes = base64Decode(base64Data);

      if (attachmentBytes.length > 3 * 1024 * 1024) {
        throw Exception('Please choose a file smaller than 3 MB.');
      }

      payload['attachment'] = {
        'name': attachment['name']?.toString() ?? 'attachment',
        'mimeType': mimeType,
        'base64': base64Data,
      };

      debugPrint(
        'AUTISOLVE: Attachment prepared; '
        'type=$mimeType, bytes=${attachmentBytes.length}',
      );
    }

    final encodedPayload = jsonEncode(payload);

    debugPrint(
      'AUTISOLVE: Sending request; '
      'hasAttachment=${attachment != null}, '
      'hasChildContext=${childContext != null && childContext.isNotEmpty}, '
      'requestBytes=${utf8.encode(encodedPayload).length}',
    );

    late final http.Response response;

    try {
      response = await _client
          .post(
            _workerUri,
            headers: const {'Content-Type': 'application/json'},
            body: encodedPayload,
          )
          .timeout(const Duration(seconds: 60));
    } on http.ClientException catch (e) {
      debugPrint('AUTISOLVE: Network error: $e');
      throw Exception(
        'Could not connect to the chatbot. Check your internet connection.',
      );
    } on Exception catch (e) {
      debugPrint('AUTISOLVE: Request failed: $e');
      rethrow;
    }

    debugPrint('AUTISOLVE: Worker HTTP status ${response.statusCode}');

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw Exception(
        'The chatbot returned an invalid response. Please try again.',
      );
    }

    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error']?.toString() ??
            'Chat service error ${response.statusCode}.',
      );
    }

    final reply = data['reply']?.toString().trim();

    if (reply == null || reply.isEmpty) {
      throw Exception(
        data['error']?.toString() ?? 'The chatbot returned an empty response.',
      );
    }

    return reply;
  }
}
