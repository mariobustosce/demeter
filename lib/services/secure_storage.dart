import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacén seguro de la app: Keystore en Android, Keychain en iOS.
///
/// En iOS lo guardado no sale del equipo: no va en copias ni pasa a otro
/// iPhone. En Android el backup está apagado en el manifest.
const FlutterSecureStorage secureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
