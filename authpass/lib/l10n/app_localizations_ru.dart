// ignore_for_file: omit_local_variable_types,unused_local_variable
// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: unnecessary_brace_in_string_interps

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get fieldUserName => 'Пользователь';

  @override
  String get fieldPassword => 'Пароль';

  @override
  String get fieldWebsite => 'Сайт';

  @override
  String get fieldTitle => 'Название';

  @override
  String get fieldTotp => 'One Time Password (Time Based)';

  @override
  String get selectKeepassFile => 'AuthPass - выберите KeePass файл';

  @override
  String get quickUnlockingFiles => 'Быстрая разблокировка файлов';

  @override
  String get selectKeepassFileLabel => 'Выберите файл KeePass (.kdbx).';

  @override
  String get openLocalFile => 'Открыть\nлокальный файл';

  @override
  String get openFile => 'Open File';

  @override
  String loadFrom(String cloudStorageName) {
    return 'Загрузить из ${cloudStorageName}';
  }

  @override
  String get loadFromUrl => 'Загрузить из URL';

  @override
  String get createNewKeepass => 'Впервые в KeePass?\nСоздать новую базу данных паролей';

  @override
  String get labelLastOpenFiles => 'Последние открытые файлы:';

  @override
  String get noFilesHaveBeenOpenYet => 'Файлы ещё не были открыты.';

  @override
  String get preferenceSelectLanguage => 'Выберите язык';

  @override
  String get preferenceLanguage => 'Язык';

  @override
  String get preferenceTextScaleFactor => 'Коэффициент размера текста';

  @override
  String get preferenceVisualDensity => 'Плотность';

  @override
  String get preferenceTheme => 'Тема';

  @override
  String get preferenceThemeLight => 'Светлая';

  @override
  String get preferenceThemeDark => 'Тёмная';

  @override
  String get preferenceSystemDefault => 'Системные настройки';

  @override
  String get preferenceDefault => 'По умолчанию';

  @override
  String get lockAllFiles => 'Заблокировать все открытые файлы';

  @override
  String get preferenceAllowScreenshots => 'Разрешить делать скриншоты приложения';

  @override
  String get preferenceEnableAutoFill => 'Включить автозаполнение';

  @override
  String get preferenceAutoFillDescription => 'Поддерживается с Android Oreo (8.0) или более поздней версии.';

  @override
  String get preferenceTitle => 'Настройки';

  @override
  String get aboutAppName => 'AuthPass';

  @override
  String get aboutLinkFeedback => 'Мы рады любым отзывам!';

  @override
  String get aboutLinkVisitWebsite => 'Не забудьте посетить наш сайт';

  @override
  String get aboutLinkGitHub => 'И исходный код проекта';

  @override
  String aboutLogFile(String logFilePath) {
    return 'Файл журнала: ${logFilePath}';
  }

  @override
  String get menuItemGeneratePassword => 'Сгенерировать пароль';

  @override
  String get menuItemPreferences => 'Настройки';

  @override
  String get menuItemOpenAnotherFile => 'Открыть другой файл';

  @override
  String get menuItemCheckForUpdates => 'Проверить обновления';

  @override
  String get menuItemSupport => 'Поддержка по Email';

  @override
  String get menuItemSupportSubtitle => 'Отправлять журналы по электронной почте/запрос о помощи.';

  @override
  String get menuItemHelp => 'Помощь';

  @override
  String get menuItemHelpSubtitle => 'Показать документацию';

  @override
  String get menuItemAbout => 'О программе';

  @override
  String get passwordPlainText => 'Показать пароль';

  @override
  String get generatorPassword => 'Пароль';

  @override
  String get generatePassword => 'Сгенерировать пароль';

  @override
  String get doneButtonLabel => 'Готово';

  @override
  String get useAsDefault => 'По умолчанию';

  @override
  String get characterSetLowerCase => 'Строчные буквы (а-я)';

  @override
  String get characterSetUpperCase => 'Прописные буквы (А-Я)';

  @override
  String get characterSetNumeric => 'Числа (0-9)';

  @override
  String get characterSetUmlauts => 'Умляуты (ä)';

  @override
  String get characterSetSpecial => 'Специальные (@%+)';

  @override
  String get length => 'Длина';

  @override
  String get customLength => 'Своя длина';

  @override
  String customLengthHelperText(Object customMinLength) {
    return 'Только для длины > ${customMinLength}';
  }

  @override
  String savedFiles(int numFiles, Object files) {
    final intl.NumberFormat numFilesNumberFormat = intl.NumberFormat.compactLong(
      locale: localeName,
      
    );
    final String numFilesString = numFilesNumberFormat.format(numFiles);

    return intl.Intl.pluralLogic(
      numFiles,
      locale: localeName,
      other: '${numFiles} files saved: ${files}',
    );
  }

  @override
  String get manageGroups => 'Manage Groups';

  @override
  String get lockFiles => 'Lock Files';

  @override
  String get searchHint => 'Search';

  @override
  String get clear => 'Clear';

  @override
  String get autofillFilterPrefix => 'Filter:';

  @override
  String get autofillPrompt => 'Select password entry for autofill.';

  @override
  String get copiedToClipboard => 'Скопировано в буфер обмена.';

  @override
  String get noTitle => '(no title)';

  @override
  String get noUsername => '(no username)';

  @override
  String get filterCustomize => 'Customize …';

  @override
  String get swipeCopyPassword => 'Copy Password';

  @override
  String get swipeCopyUsername => 'Copy Username';

  @override
  String get doneCopiedPassword => 'Copied password to clipboard.';

  @override
  String get doneCopiedUsername => 'Copied username to clipboard.';

  @override
  String get emptyPasswordVaultPlaceholder => 'You do not have any password in your database yet.';

  @override
  String get emptyPasswordVaultButtonLabel => 'Create your first Password';

  @override
  String unexpectedError(String error) {
    return 'Неожиданная ошибка: ${error}';
  }
}
