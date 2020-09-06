import 'package:analytics_event/analytics_event.dart';
import 'package:authpass/bloc/analytics_io.dart'
    if (dart.library.html) 'package:authpass/bloc/analytics_html.dart';
import 'package:authpass/env/_base.dart';
import 'package:authpass/ui/screens/password_list.dart';
import 'package:authpass/utils/platform.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:string_literal_finder_annotations/string_literal_finder_annotations.dart';
import 'package:usage/usage.dart' as usage;

part 'analytics.g.dart';
part 'analytics_ua.dart';

final _logger = Logger('analytics');

class Analytics {
  Analytics({@required this.env}) {
    _init();
  }

  static void trackError(String description, bool fatal) {
    _errorGa?.sendException(description, fatal: fatal);
  }

  final Env env;
  final AnalyticsEvents events = _$AnalyticsEvents();

  usage.Analytics _ga;
  final List<VoidCallback> _gaQ = [];

  /// global analytics tracker we use for error reporting.
  static usage.Analytics _errorGa;
  static const _gaPropertyMapping = <String, String>{
    'platform': 'cd1',
    'userType': 'cd2',
    'device': 'cd3',
  };

  Future<void> _init() async {
    if (env.secrets.analyticsGoogleAnalyticsId != null) {
      if (AuthPassPlatform.isAndroid) {
        const miscChannel = MethodChannel('app.authpass/misc');
        final isFirebaseTestLab =
            await miscChannel.invokeMethod<bool>('isFirebaseTestLab');
        if (isFirebaseTestLab) {
          _logger.info(
              'running in firebase test lab. not initializing analytics.');
          return;
        }
      }

      final info = await env.getAppInfo();

      String platformVersion;
      String deviceInfo;
      if (AuthPassPlatform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        platformVersion = androidInfo.version.release;
        deviceInfo = androidInfo.model;
      } else if (AuthPassPlatform.isIOS) {
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        platformVersion = iosInfo.systemVersion;
      }
      final userAgent = _createUserAgent(
          platformVersion: platformVersion, deviceInfo: deviceInfo);
      _logger.fine(
          'Got PackageInfo: ${info.appName}, ${info.buildNumber}, ${info.packageName} - '
          'UserAgent: $userAgent');

      _ga = await analyticsCreate(
        env.secrets.analyticsGoogleAnalyticsId,
        info.appName,
        '${info.version}+${info.buildNumber}',
        userAgent: userAgent,
      );
//      _ga.onSend.listen((event) {
//        _logger.finer('analytics send: $event');
//      });
      _ga.setSessionValue('ua', userAgent);
      _errorGa = _ga;
      _ga.setSessionValue(
          _gaPropertyMapping['platform'], AuthPassPlatform.operatingSystem);
      // set application id to package name.
      _ga.setSessionValue('aid', info.packageName);

      for (final cb in _gaQ) {
        cb();
      }
      _gaQ.clear();
    } else {
      _logger.info('No analytics Id defined. Not tracking anything.');
    }

    _logger.finest('Registering analytics tracker.');
    events.registerTracker((event, params) {
      final eventParams = <String, String>{};
      int value;
      var category = 'track';

      final labelParams = <String>[];
      for (final entry in params.entries) {
        final customKey = _gaPropertyMapping[entry.key];
//        _logger.fine('entry.key: ${entry.key} = ${entry.value.runtimeType}');
        if (entry.key == 'value' && entry.value is int) {
          value = entry.value as int;
        } else if (entry.key == 'category' && entry.value is String) {
          category = entry.value as String;
        } else if (entry.key == 'action' && entry.value is String) {
          event = entry.value as String;
        } else if (customKey == null) {
          labelParams.add('${entry.key}=${entry.value}');
        } else {
          eventParams[customKey] = entry.value?.toString();
        }
      }
      labelParams.sort();

      final label = labelParams.join(',');
//      _amplitude?.logEvent(name: event, properties: params);
      _sendEvent(
        category,
        event,
        label: label,
        value: value,
        parameters: eventParams,
      );
    });
  }

  void trackScreen(@NonNls String screenName) {
    _requireGa((ga) {
      _logger.finer('trackScreen($screenName)');
      ga.sendScreenView(screenName);
    });
  }

  void trackGenericEvent(String category, String action,
          {String label, int value, Map<String, String> parameters}) =>
      _sendEvent(
        category,
        action,
        label: label,
        value: value,
        parameters: parameters,
      );

  void trackTiming(String variableName, int timeMs,
      {String category, String label}) {
    _requireGa((ga) {
      ga.sendTiming(variableName, timeMs, category: category, label: label);
      _logger.finest('timing($variableName, $timeMs, '
          'category: $category, label: $label)');
    });
  }

  void _sendEvent(String category, String action,
      {String label, int value, Map<String, String> parameters}) {
    _logger.finer(
        'event($category, $action, $label, $value) - parameters: $parameters');
    _requireGa((ga) {
      ga.sendEvent(category, action,
          label: label, value: value, parameters: parameters);
    });
  }

  void updateSizes({
    double viewportSizeWidth,
    double viewportSizeHeight,
    double displaySizeWidth,
    double displaySizeHeight,
    double devicePixelRatio,
  }) {
    _requireGa((ga) {
      ga.setSessionValue(
          'vp', '${viewportSizeWidth.round()}x${viewportSizeHeight.round()}');
      final sr = [displaySizeWidth, displaySizeHeight]
          .map((e) => (e / devicePixelRatio).round())
          .join('x');
      ga.setSessionValue('sr', sr);
    });
  }

  void _requireGa(void Function(usage.Analytics ga) callback) {
    if (_ga == null) {
      _gaQ.add(() => callback(_ga));
    } else {
      callback(_ga);
    }
  }
}

Future<String> deviceInfo() async {
  // get information about the current device.
  if (AuthPassPlatform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    return androidInfo.model;
  }
  if (AuthPassPlatform.isIOS) {
    final iosInfo = await DeviceInfoPlugin().iosInfo;
    return iosInfo.utsname.machine;
  }
  return 'unknown (${AuthPassPlatform.operatingSystem})';
}

abstract class AnalyticsEvents implements AnalyticsEventStubs {
  void trackLaunch();

  Future<void> trackInit(
          {@required String userType, @required int value}) async =>
      _trackInit(userType: userType, device: await deviceInfo(), value: value);

  void _trackInit({
    @required String userType,
    @required String device,
    @required int value,
  });

  void trackActionPressed({@required @NonNls String action});

  void trackCreateFile();

  void trackOpenFile({@required @NonNls String type});

  void trackOpenFile2(
      {@required @NonNls String generator, @required @NonNls String version});

  void trackSelectEntry({EntrySelectionType type});

  void trackCopyField({@required @NonNls String key});

  void trackAddField({@required @NonNls String key});

  void trackCloseAllFiles({int count});

  void trackUserType({@NonNls String userType});

  void trackCloseFile();

  /// weird case of empty password list.
  void trackPasswordListEmpty();

  void trackQuickUnlock({int value});

  void trackSave({@required String type, int value});
  void trackSaveCount({@required String generator, @required int value});

  void trackDrawerOpen();

  void trackAttachmentAction(String action, {String category = 'attachment'});
  void trackAttachmentAdd(
    AttachmentAddType action,
    String ext,
    int value, {
    String category = 'attachmentAdd',
  });

  void trackCloudAuth(
    CloudAuthAction action, {
    String label = 'auth',
    String category = 'cloud',
  });

  void trackGroupDelete(GroupDeleteResult result, {String category = 'group'});
  void trackGroupCreate({String category = 'group'});

  void trackPreferences({
    @required String setting,
    @required String to,
  }) =>
      _trackPreferences(action: setting, to: to, category: 'preferences');
  void _trackPreferences({
    @required String action,
    @required String to,
    String category,
  });

  void trackAutofillFilter({
    @required String filter,
    String category = 'autofill',
    String action = 'filter',
    @required int value,
  });
  void trackAutofillSelect({
    String category = 'autofill',
    String action = 'select',
  });

  void trackTryUnlock({
    @required TryUnlockResult action,
    @required String ext,
    @required String source,
    String category = 'tryUnlock',
  });
}

enum TryUnlockResult {
  success,
  invalidCredential,
  failure,
}

enum GroupDeleteResult {
  hasSubgroups,
  hasEntries,
  deleted,
  undo,
}

enum CloudAuthAction {
  authSend,
  authResend,
  authSuccess,
  authCanceled,
}

enum AttachmentAddType {
  success,
  canceled,
}
