# Contributing to AuthPass

We appreciate any kind of contributions to AuthPass 😅️ 
[Check out the article on helping support AuthPass on our website.](https://authpass.app/docs/support-authpass-get-involved/)

If you want to contribute documentation or code, never hesitate to [get in contact](https://authpass.app/docs/about-authpass-password-manager/#getting-in-touch).

# Code

AuthPass is based on Flutter, so you should get familiar with the Dart programming language
as well as Flutter itself. You can checkout the Flutter website at https://flutter.dev/

If you have never used Flutter before you might [want to walk through a few codelabs](https://flutter.dev/docs/get-started/codelab) before getting into AuthPass.

## Cloning/Forking

AuthPass makes [heavy use of submodules right now](https://github.com/authpass/authpass/blob/master/.gitmodules). If you fork the repository you might experience a few
permission denied errors when you clone using ssh. To work around those you might need to add the follwing to your `~/.gitconfig`:

```
[url "https://github.com/"]
  insteadOf = git@github.com:
[url "git@github.com:"]
  pushInsteadOf = "https://github.com/"
```

(If you don't want it for all github repositories, you might only configure it for `github:hpoul/` and `github:authpass/`).

## Setup Development Environment

1. [Download Flutter](https://flutter.dev/docs/get-started/install) and make sure `flutter doctor` shows no errors.
   * Latest Flutter stable or beta channel should typically work, check out
     [authpass/_tools/install_flutter.sh](authpass/_tools/install_flutter.sh) for what's being used in the CI.
   * ⚠️ **NOTE**: Right now one extra step is required after installing flutter: in the flutter directory change to `flutter/dev/tools` and run: `flutter pub get`. See the (flutter issue #65023)[https://github.com/flutter/flutter/issues/65023] for details.
     otherwise you will stumble on errors like:
     ```flutter/dev/tools/localization/bin/gen_l10n.dart:7:8: Error: Error when reading '/flutter/.pub-cache/hosted/pub.dartlang.org/args-1.6.0/lib/args.dart': The system cannot find the path specified.```
2. Clone the repository `git clone https://github.com/authpass/authpass.git` (or better yet, create your own fork to make later creating Pull Requests easier).
3. Initialize submodules `git submodule update --init`
4. Change to the `authpass/` subdirectory:

    ```shell
    git clone https://github.com/authpass/authpass.git
    cd authpass/authpass
    ```
5. Launch AuthPass
    ```shell
    flutter run -t lib/env/development.dart
    ```

You are required to select a specific target file,
usually this will be `lib/env/development.dart`.

## Running on Android

For android you have to add an additional flavor:

```
flutter run --target=lib/env/development.dart --flavor=playstore
```


# Code Style

Make sure to follow common Dart coding conventions, and follow all lints provided
by `analysis_options.yaml` and [activate auto-formatting](https://flutter.dev/docs/development/tools/formatting) using `dartfmt`.

