import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:authpass/bloc/app_data.dart';
import 'package:authpass/bloc/kdbx/file_content.dart';
import 'package:authpass/bloc/kdbx/file_source.dart';
import 'package:authpass/cloud_storage/cloud_storage_provider.dart';
import 'package:authpass/env/_base.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

final _logger = Logger('authpass.google_drive_bloc');

class GoogleDriveProvider
    extends CloudStorageProviderClientBase<AutoRefreshingAuthClient> {
  GoogleDriveProvider(
      {@required this.env, @required CloudStorageHelperBase helper})
      : super(helper: helper);

  final Env env;

  static const _scopes = [DriveApi.DriveScope];

  ClientId get _clientId =>
      ClientId(env.secrets.googleClientId, env.secrets.googleClientSecret);

  @override
  Future<AutoRefreshingAuthClient> clientFromAuthenticationFlow<
      TF extends UserAuthenticationPromptResult,
      UF extends UserAuthenticationPromptData<TF>>(prompt) async {
//    assert(prompt is PromptUserForCode<OAuthTokenResult, OAuthTokenFlowPromptData>);
//    final oAuthPrompt = prompt as PromptUserForCode<OAuthTokenResult, OAuthTokenFlowPromptData>;
    final client = await clientViaUserConsentManual(
        _clientId,
        _scopes,
        (uri) => oAuthTokenPrompt(
            prompt as PromptUserForCode<dynamic, dynamic>, uri));
    client.credentialUpdates.listen(_credentialsChanged);
    _credentialsChanged(client.credentials);
    _logger.finer('Finished user consent.');
    return client;
  }

  @override
  AutoRefreshingAuthClient clientWithStoredCredentials(String stored) {
    final accessCredentials = _parseAccessCredentials(stored);
    final client = autoRefreshingClient(_clientId, accessCredentials, Client());
    client.credentialUpdates.listen(_credentialsChanged);
    return client;
  }

  void _credentialsChanged(AccessCredentials credentials) {
    final jsonString = <String, dynamic>{
      'accessToken': _accessTokenToJson(credentials.accessToken),
      'refreshToken': credentials.refreshToken,
      'idToken': credentials.idToken,
      'scopes': credentials.scopes,
    };
    storeCredentials(json.encode(jsonString));
  }

  Map<String, dynamic> _accessTokenToJson(AccessToken at) => <String, dynamic>{
        'type': at.type,
        'data': at.data,
        'expiry': at.expiry.toString(),
      };

  AccessToken _accessTokenFromJson(Map<String, dynamic> map) {
    return AccessToken(
      map['type'] as String,
      map['data'] as String,
      DateTime.parse(map['expiry'] as String),
    );
  }

  AccessCredentials _parseAccessCredentials(String jsonString) {
    final map = json.decode(jsonString) as Map<String, dynamic>;
    return AccessCredentials(
      _accessTokenFromJson(map['accessToken'] as Map<String, dynamic>),
      map['refreshToken'] as String,
      (map['scopes'] as List).cast<String>(),
      idToken: map['idToken'] as String,
    );
  }

  @override
  bool get supportSearch => true;

  @override
  Future<SearchResponse> search({String name = 'kdbx'}) async {
    return _search(SearchQueryTerm(const SearchQueryField('name'),
        QOperator.contains, SearchQueryValueLiteral(name)));
  }

  Future<SearchResponse> _search(SearchQueryTerm search) async {
    final driveApi = DriveApi(await requireAuthenticatedClient());
    _logger.fine('Query: ${search.toQuery()}');
    final files = await driveApi.files.list(
      q: search.toQuery(),
    );
    _logger.fine(
        'Got file results (incomplete:${files.incompleteSearch}): ${files.files.map((f) => '${f.id}: ${f.name} (${f.mimeType})')}');
    return SearchResponse(
      (srb) => srb
        ..hasMore = files.nextPageToken != null
        ..results.addAll(
          files.files.map(
            (f) => CloudStorageEntity(
              (b) => b
                ..id = f.id
                ..type = f.mimeType == 'application/vnd.google-apps.folder'
                    ? CloudStorageEntityType.directory
                    : CloudStorageEntityType.file
                ..name = f.name,
            ),
          ),
        ),
    );
  }

  @override
  Future<SearchResponse> list({CloudStorageEntity parent}) {
    return _search(parent == null
        ? const SearchQueryTerm(SearchQueryValueLiteral('root'), QOperator.in_,
            SearchQueryField('parents'))
        : SearchQueryTerm(SearchQueryValueLiteral(parent.id), QOperator.in_,
            const SearchQueryField('parents')));
  }

  @override
  String get displayName => 'Google Drive';

  @override
  FileSourceIcon get displayIcon => FileSourceIcon.googleDrive;

  @override
  Future<FileContent> loadEntity(CloudStorageEntity file) async {
    final driveApi = DriveApi(await requireAuthenticatedClient());
    final dynamic response = await driveApi.files
        .get(file.id, downloadOptions: DownloadOptions.FullMedia);
    final media = response as Media;
    final bytes = BytesBuilder(copy: false);
    // ignore: prefer_foreach
    await for (final chunk in media.stream) {
      bytes.add(chunk);
    }
    return FileContent(bytes.toBytes());
  }

  @override
  Future<Map<String, dynamic>> saveEntity(CloudStorageEntity file,
      Uint8List bytes, Map<String, dynamic> previousMetadata) async {
    final driveApi = DriveApi(await requireAuthenticatedClient());
    final byteStream = ByteStream.fromBytes(bytes);
    final updatedFile = await driveApi.files.update(null, file.id,
        uploadMedia: Media(byteStream, bytes.lengthInBytes));
    _logger.fine('Successfully saved file ${updatedFile.name}');
    return <String, dynamic>{};
  }

  @override
  Future<FileSource> createEntity(
      CloudStorageSelectorSaveResult saveAs, Uint8List bytes) async {
    final driveApi = DriveApi(await requireAuthenticatedClient());
    final metadata = File();
    metadata.name = saveAs.fileName;
    if (saveAs.parent != null) {
      metadata.parents = [saveAs.parent?.id];
    }
    final byteStream = ByteStream.fromBytes(bytes);
    final newFile = await driveApi.files
        .create(metadata, uploadMedia: Media(byteStream, bytes.lengthInBytes));
    return toFileSource(
        CloudStorageEntity((b) => b
          ..id = newFile.id
          ..name = newFile.name
          ..type = CloudStorageEntityType.file).toSimpleFileInfo(),
        uuid: AppDataBloc.createUuid());
  }
}

abstract class SearchQueryAtom {
  String toQuery();
}

@immutable
class QOperator {
  const QOperator._(this.op);

  final String op;

  static const contains = QOperator._('contains');
  static const eq = QOperator._('=');
  static const in_ = QOperator._('in');
  static const and = QOperator._('and');
}

class SearchQueryField implements SearchQueryAtom {
  const SearchQueryField(this.fieldName);

  final String fieldName;

  @override
  String toQuery() => fieldName;
}

class SearchQueryValueLiteral implements SearchQueryAtom {
  const SearchQueryValueLiteral(this.value);

  final Object value;

  String _quoteValues(dynamic value) {
    if (value is String) {
      final escaped = value.replaceAllMapped(
          RegExp(r'''['\\]'''), (match) => '\\${match.group(0)}');
      return "'$escaped'";
    }
    if (value is List) {
      return '[${value.map((dynamic v) => _quoteValues(v)).join(',')}]';
    } else {
      throw StateError('Unsupported type. ${value.runtimeType}');
    }
  }

  @override
  String toQuery() => _quoteValues(value);
}

/// Search query terms
/// https://developers.google.com/drive/api/v3/search-files
/// https://developers.google.com/drive/api/v3/reference/query-ref
class SearchQueryTerm implements SearchQueryAtom {
  const SearchQueryTerm(this.left, this.operator, this.right);

  final SearchQueryAtom left;
  final QOperator operator;
  final SearchQueryAtom right;

  SearchQueryTerm operator &(SearchQueryTerm other) =>
      SearchQueryTerm(this, QOperator.and, other);

  @override
  String toQuery() {
    return '${left.toQuery()} ${operator.op} ${right.toQuery()}';
  }
}
