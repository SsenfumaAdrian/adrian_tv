import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provider credentials kept out of plain preferences.
class ProviderCredentials {
  const ProviderCredentials({required this.username, required this.password});

  final String username;
  final String password;

  Map<String, dynamic> toJson() => {'username': username, 'password': password};

  factory ProviderCredentials.fromJson(Map<String, dynamic> json) =>
      ProviderCredentials(
        username: json['username'] as String,
        password: json['password'] as String,
      );
}

abstract interface class CredentialsStore {
  Future<ProviderCredentials?> read(String sourceId);
  Future<void> write(String sourceId, ProviderCredentials credentials);
  Future<void> delete(String sourceId);
}

/// OS-backed encrypted storage (Keystore/Keychain/Windows DPAPI).
class SecureCredentialsStore implements CredentialsStore {
  SecureCredentialsStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _prefix = 'provider_credentials_';
  final FlutterSecureStorage _storage;

  @override
  Future<ProviderCredentials?> read(String sourceId) async {
    final raw = await _storage.read(key: '$_prefix$sourceId');
    if (raw == null) return null;
    return ProviderCredentials.fromJson(
      (jsonDecode(raw) as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<void> write(String sourceId, ProviderCredentials credentials) =>
      _storage.write(
        key: '$_prefix$sourceId',
        value: jsonEncode(credentials.toJson()),
      );

  @override
  Future<void> delete(String sourceId) =>
      _storage.delete(key: '$_prefix$sourceId');
}

/// Test/dev fallback that keeps credentials in memory only.
class InMemoryCredentialsStore implements CredentialsStore {
  final _map = <String, String>{};

  @override
  Future<ProviderCredentials?> read(String sourceId) async {
    final raw = _map[sourceId];
    return raw == null
        ? null
        : ProviderCredentials.fromJson(
            (jsonDecode(raw) as Map).cast<String, dynamic>(),
          );
  }

  @override
  Future<void> write(String sourceId, ProviderCredentials credentials) async {
    _map[sourceId] = jsonEncode(credentials.toJson());
  }

  @override
  Future<void> delete(String sourceId) async => _map.remove(sourceId);
}
