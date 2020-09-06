import 'package:authpass/env/_base.dart';
import 'package:authpass/env/env.dart';

Future<void> main() async => await TestDriverEnv().start();

class TestDriverEnv extends EnvAppBase {
  TestDriverEnv() : super(EnvType.production);

  @override
  EnvSecrets get secrets => EnvSecrets.nullSecrets;

  @override
  bool get featureFetchWebsiteIconEnabledByDefault => true;
}
