import 'package:authpass/main.dart';
import 'package:authpass/utils/platform.dart';
import 'package:built_value/built_value.dart';
import 'package:diac_client/diac_client.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:package_info/package_info.dart';

part '_base.g.dart';

final _logger = Logger('_base');

enum EnvType { production, development }

const _DEFAULT_APP_NAME = 'AuthPass';
const _DEFAULT_VERSION =
    String.fromEnvironment('AUTHPASS_VERSION', defaultValue: '1.0.0');
const _DEFAULT_BUILD_NUMBER =
    int.fromEnvironment('AUTHPASS_BUILD_NUMBER', defaultValue: 1);
const _DEFAULT_PACKAGE_NAME = String.fromEnvironment('AUTHPASS_PACKAGE_NAME',
    defaultValue: 'design.codeux.authpass.dev');

abstract class AppInfo implements Built<AppInfo, AppInfoBuilder> {
  factory AppInfo([void Function(AppInfoBuilder b) updates]) = _$AppInfo;
  AppInfo._();

  String get appName;
  String get version;
  int get buildNumber;
  String get packageName;

  String get versionLabel => '$version+$buildNumber';

  String get shortString => '$appName ($versionLabel)';
}

extension AppInfoDiac on AppInfo {
  DiacPackageInfo toDiacPackageInfo() => DiacPackageInfo(
        appName: appName,
        packageName: packageName,
        version: version,
        buildNumber: '$buildNumber',
      );
}

class EnvSecrets {
  const EnvSecrets({
    @required this.analyticsAmplitudeApiKey,
    @required this.analyticsGoogleAnalyticsId,
    @required this.googleClientId,
    @required this.googleClientSecret,
    @required this.dropboxKey,
    @required this.dropboxSecret,
    @required this.microsoftClientId,
    @required this.microsoftClientSecret,
  });

  static const nullSecrets = EnvSecrets(
    analyticsAmplitudeApiKey: null,
    analyticsGoogleAnalyticsId: null,
    googleClientId: null,
    googleClientSecret: null,
    dropboxKey: null,
    dropboxSecret: null,
    microsoftClientId: null,
    microsoftClientSecret: null,
  );

  final String analyticsAmplitudeApiKey;
  final String analyticsGoogleAnalyticsId;
  final String googleClientId;
  final String googleClientSecret;
  final String dropboxKey;
  final String dropboxSecret;
  final String microsoftClientId;
  final String microsoftClientSecret;
}

abstract class FeatureFlags
    implements Built<FeatureFlags, FeatureFlagsBuilder> {
  factory FeatureFlags([void Function(FeatureFlagsBuilder b) updates]) =
      _$FeatureFlags;
  FeatureFlags._();

  bool get authpassCloud;
  String get authpassCloudUri;
}

abstract class Env {
  Env(this.type) {
    value = this;
  }

  static const _ENV_STORAGE_NAMESPACE = 'AUTHPASS_STORAGE_NAMESPACE';

  static Env value;

  final EnvType type;
  EnvSecrets get secrets;

  String get diacEndpoint => 'https://cloud.authpass.app/diac';

  /// whether diac is disabled by default, and only enabled through opt-in.
  bool get diacDefaultDisabled => false;

//  String get oauthRedirectUri => 'authpass://oauth/code';
  String get oauthRedirectUri => oauthRedirectUriSupported
      // for clients not supporting https:// handling, it will redirect
      // to authpass://
      ? 'https://links.authpass.app/app/oauth/code'
      : null;
  bool get oauthRedirectUriSupported =>
      AuthPassPlatform.isIOS ||
      AuthPassPlatform.isAndroid ||
      AuthPassPlatform.isMacOS;

  Future<void> start() async {
    await startApp(this);
  }

  bool get isDebug => type == EnvType.development;

  String get name => runtimeType.toString();

  /// Allows having a "namespace" for different environments.
  /// e.g. for mac os to have a different configuration for
  /// debug build vs. production/app store build.
  String get storageNamespace => _storageNamespaceFromEnvironment;

  /// Support for dropbox, google drive.
  bool get featureCloudStorageProprietary => true;

  /// Support for WebDAV
  bool get featureCloudStorageWebDav => true;

  String get _storageNamespaceFromEnvironment =>
      AuthPassPlatform.environment[_ENV_STORAGE_NAMESPACE];

  final FeatureFlags featureFlags = FeatureFlags(
    (b) => b
      ..authpassCloud = true
      ..authpassCloudUri = 'https://cloud.authpass.app/',
  );

  Future<AppInfo> getAppInfo() async {
    final pi = await _getPackageInfo();
    return AppInfo((b) => b
      ..appName = pi?.appName ?? _DEFAULT_APP_NAME
      ..version = pi?.version ?? _DEFAULT_VERSION
      ..buildNumber =
          int.tryParse(pi?.buildNumber ?? '$_DEFAULT_BUILD_NUMBER') ??
              _DEFAULT_BUILD_NUMBER
      ..packageName = pi?.packageName ?? _DEFAULT_PACKAGE_NAME);
  }

  Future<PackageInfo> _getPackageInfo() async {
    try {
      // linux and windows don't support this right now.
      if (AuthPassPlatform.isWeb ||
          AuthPassPlatform.isLinux ||
          AuthPassPlatform.isWindows) {
        return null;
      }
      return await PackageInfo.fromPlatform();
    } on PlatformException catch (e, stackTrace) {
      _logger.severe('Error getting package info', e, stackTrace);
      return null;
    }
  }
}
