import 'package:authpass/bloc/analytics.dart';
import 'package:authpass/bloc/app_data.dart';
import 'package:authpass/bloc/kdbx_bloc.dart';
import 'package:authpass/env/_base.dart';
import 'package:authpass/l10n/app_localizations.dart';
import 'package:authpass/ui/common_fields.dart';
import 'package:authpass/ui/screens/select_file_screen.dart';
import 'package:authpass/utils/platform.dart';
import 'package:autofill_service/autofill_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_async_utils/flutter_async_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

final _logger = Logger('preferences');

class PreferencesScreen extends StatelessWidget {
  static Route<void> route() => MaterialPageRoute(
        settings: const RouteSettings(name: '/preferences'),
        builder: (context) => PreferencesScreen(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).preferenceTitle),
      ),
      body: Scrollbar(
        child: SingleChildScrollView(child: PreferencesBody()),
      ),
    );
  }
}

class PreferencesBody extends StatefulWidget {
  @override
  _PreferencesBodyState createState() => _PreferencesBodyState();
}

class _PreferencesBodyState extends State<PreferencesBody>
    with StreamSubscriberMixin {
  KdbxBloc _kdbxBloc;

  AutofillServiceStatus _autofillStatus;
  AutofillPreferences _autofillPrefs;

  AppDataBloc _appDataBloc;
  AppData _appData;
  Analytics _analytics;

  @override
  void initState() {
    super.initState();
    _doInit();
  }

  Future<void> _doInit() async {
    if (AuthPassPlatform.isWeb) {
      return;
    }
    final autofill = AutofillService();
    _autofillStatus = await autofill.status();
    if (_autofillStatus != AutofillServiceStatus.unsupported) {
      _autofillPrefs = await autofill.getPreferences();
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_kdbxBloc == null) {
      _kdbxBloc = Provider.of<KdbxBloc>(context);
      _appDataBloc = Provider.of<AppDataBloc>(context);
      _analytics = context.watch<Analytics>();
      handleSubscription(
          _appDataBloc.store.onValueChangedAndLoad.listen((appData) {
        setState(() {
          _appData = appData;
        });
      }));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_appData == null) {
      return const Text('loading');
    }
    final loc = AppLocalizations.of(context);
    final env = Provider.of<Env>(context);
    final commonFields = context.watch<CommonFields>();
    final locales = {
      null: loc.preferenceSystemDefault,
      'de': 'Deutsch', // NON-NLS
      'en': 'English', // NON-NLS
    };
    return Column(
      children: <Widget>[
        ...?(_autofillStatus == AutofillServiceStatus.unsupported ||
                _autofillPrefs == null
            ? null
            : [
                SwitchListTile(
                  secondary: const Icon(FontAwesomeIcons.iCursor),
                  title: Text(loc.preferenceEnableAutoFill),
                  subtitle: _autofillStatus == AutofillServiceStatus.unsupported
                      ? Text(loc.preferenceAutoFillDescription)
                      : null,
                  value: _autofillStatus == AutofillServiceStatus.enabled,
                  onChanged: _autofillStatus ==
                          AutofillServiceStatus.unsupported
                      ? null
                      : (val) async {
                          if (val) {
                            await AutofillService().requestSetAutofillService();
                          } else {
                            await AutofillService().disableAutofillServices();
                          }
                          await _doInit();
                        },
                ),
                SwitchListTile(
                  secondary: const Icon(FontAwesomeIcons.bug),
                  title: const Text('Enable debug'),
                  subtitle: const Text('Shows for every input field'),
                  value: _autofillPrefs.enableDebug,
                  onChanged: (val) async {
                    _logger.fine('Setting debug to $val');
                    await AutofillService()
                        .setPreferences(AutofillPreferences(enableDebug: val));
                    await _doInit();
                  },
                ),
              ]),
        ...?!AuthPassPlatform.isAndroid
            ? null
            : [
                SwitchListTile(
                  secondary: const Icon(Icons.camera_alt),
                  title: Text(loc.preferenceAllowScreenshots),
                  value: !_appData.secureWindowOrDefault,
                  onChanged: (value) {
                    _appDataBloc.update(
                        (builder, data) => builder.secureWindow = !value);
                    _analytics.events.trackPreferences(
                        setting: 'allowScreenshots', to: '$value');
                  },
                ),
              ],
        ListTile(
          leading: const Icon(FontAwesomeIcons.signOutAlt),
          title: Text(loc.lockAllFiles),
          onTap: () async {
            _kdbxBloc.closeAllFiles();
            await Navigator.of(context)
                .pushAndRemoveUntil(SelectFileScreen.route(), (_) => false);
          },
        ),
        ListTile(
          leading: const Icon(
            FontAwesomeIcons.lightbulb,
          ),
          title: Text(loc.preferenceTheme),
          trailing: _appData?.theme == null
              ? Text(loc.preferenceSystemDefault)
              : _appData?.theme == AppDataTheme.light
                  ? Text(loc.preferenceThemeLight)
                  : Text(loc.preferenceThemeDark),
          onTap: () async {
            if (_appData == null) {
              return;
            }
            final newTheme = await _appDataBloc.updateNextTheme();
            _analytics.events
                .trackPreferences(setting: 'theme', to: '$newTheme');
          },
        ),
        ValueSelectorTile(
          icon: const FaIcon(FontAwesomeIcons.arrowsAltH),
          title: Text(loc.preferenceVisualDensity),
          onChanged: (value) {
            _appDataBloc
                .update((builder, data) => builder.themeVisualDensity = value);
            _analytics.events
                .trackPreferences(setting: 'themeVisualDensity', to: '$value');
          },
          value: _appData.themeVisualDensity,
          minValue: -4,
          maxValue: 4,
          steps: 16,
        ),
        ValueSelectorTile(
          icon: const FaIcon(FontAwesomeIcons.textHeight),
          title: Text(loc.preferenceTextScaleFactor),
          onChanged: (value) {
            _appDataBloc
                .update((builder, data) => builder.themeFontSizeFactor = value);
            _analytics.events
                .trackPreferences(setting: 'themeFontSizeFactor', to: '$value');
          },
          value: _appData.themeFontSizeFactor,
          minValue: 0.5,
          maxValue: 2,
          valueForNull: 1,
          steps: 15,
        ),
        ...?!env.diacDefaultDisabled
            ? null
            : [
                SwitchListTile(
                    title: const Text('Opt in to in app news, surveys.'),
                    subtitle: const Text(
                        'Will occasionally send a network request to fetch news.'),
                    value: _appData.diacOptIn == true,
                    onChanged: (value) {
                      _appDataBloc
                          .update((builder, data) => builder.diacOptIn = value);
                    }),
              ],
        ListTile(
          leading: const FaIcon(FontAwesomeIcons.language),
          title: Text(loc.preferenceLanguage),
          trailing: Text(locales[_appData.localeOverride]),
          onTap: () async {
            final result = await showDialog<String>(
                context: context,
                builder: (_) => SelectLanguageDialog(
                      locales: locales,
                      localeOverride: _appData.localeOverride,
                    ));
            await _appDataBloc
                .update((builder, data) => builder.localeOverride = result);
            _analytics.events
                .trackPreferences(setting: 'localeOverride', to: '$result');
          },
        ),
        CheckboxListTile(
          value: _appData.fetchWebsiteIconsOrDefault,
          title: const Text('Dynamically load Icons'),
          subtitle: Text(
              'Will make http requests with the value in "${commonFields.url.displayName}" '
              'field to load website icons.'),
          isThreeLine: true,
          onChanged: (value) {
            _logger.fine('Changed to $value');
            _analytics.events
                .trackPreferences(setting: 'fetchWebsiteIcons', to: '$value');
            _appDataBloc
                .update((builder, data) => builder.fetchWebsiteIcons = value);
          },
          tristate: false,
        ),
      ],
    );
  }
}

class SelectLanguageDialog extends StatelessWidget {
  const SelectLanguageDialog({Key key, this.locales, this.localeOverride})
      : super(key: key);

  final Map<String, String> locales;
  final String localeOverride;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return SimpleDialog(
      title: Text(loc.preferenceSelectLanguage),
      children: locales.entries
          .map((e) => RadioListTile<String>(
                title: Text(e.value),
                value: e.key,
                groupValue: localeOverride,
                onChanged: (value) {
                  Navigator.of(context).pop(e.key);
                },
              ))
          .toList(),
    );
  }
}

class ValueSelectorTile extends StatelessWidget {
  const ValueSelectorTile({
    Key key,
    @required this.value,
    @required this.minValue,
    @required this.maxValue,
    @required this.steps,
    @required this.onChanged,
    this.icon,
    this.title,
    this.valueForNull = 0,
  })  : assert(minValue != null),
        assert(maxValue != null),
        assert(steps != null),
        assert(valueForNull != null),
        super(key: key);

  final Widget icon;
  final Widget title;
  final double value;
  final double valueForNull;
  final double minValue;
  final double maxValue;
  final int steps;
  final void Function(double value) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final density = theme.visualDensity;
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              icon,
              SizedBox(width: 32 + density.horizontal * 2),
              Expanded(
                child: DefaultTextStyle(
                  style: theme.textTheme.subtitle1,
                  child: title,
                ),
              ),
              Text(value == null
                  ? loc.preferenceDefault
                  : value.toStringAsFixed(2)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.minusSquare),
                onPressed: () => _updateValue(-1),
              ),
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.plusSquare),
                onPressed: () => _updateValue(1),
              ),
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.times),
                onPressed: () => onChanged(null),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _updateValue(int stepDirection) {
    assert(stepDirection != null);
    final v = value ?? valueForNull;
    final valueStep = (maxValue - minValue) / steps;
    final newValue =
        (v + valueStep * stepDirection).clamp(minValue, maxValue).toDouble();
    if (value != newValue) {
      onChanged(newValue);
    }
  }
}

class SliderSelector extends StatefulWidget {
  const SliderSelector({
    Key key,
    @required this.initialValue,
    @required this.minValue,
    @required this.maxValue,
    @required this.steps,
    @required this.onChanged,
  })  : assert(initialValue != null),
        assert(minValue != null),
        assert(maxValue != null),
        assert(steps != null),
        super(key: key);

  final double initialValue;
  final double minValue;
  final double maxValue;
  final int steps;
  final void Function(double value) onChanged;

  @override
  _SliderSelectorState createState() => _SliderSelectorState();
}

class _SliderSelectorState extends State<SliderSelector> {
  double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: _value,
      min: widget.minValue,
      max: widget.maxValue,
      divisions: widget.steps,
      onChanged: (value) {
        setState(() {
          _value = value;
          widget.onChanged(value);
        });
      },
    );
  }
}
