// Local compatibility patch for device configs.
//
// Some devices (e.g. Nexus Revo "XW-LW3") do not advertise their BLE local
// name, and the upstream device config only lists names for them. On platforms
// where the name cannot be resolved from the advertisement (Android, Linux),
// matching-by-name fails and the engine ignores the device. Adding the device's
// advertised service UUID to the specifier's advertised_services list allows
// matching by service UUID instead.
import 'dart:convert';

/// Injects any missing `advertised_services` entries into btle communication
/// specifiers listed here. Idempotent: running it on an already-patched
/// config is a no-op.
const Map<String, List<String>> kForcedAdvertisedServices = {
  'nexus-revo': ['0000c570-0000-1000-8000-00805f9b34fb'],
};

String patchDeviceConfigJson(String configJson) {
  Object? decoded;
  try {
    decoded = jsonDecode(configJson);
  } on FormatException {
    // Not valid JSON; pass through so the engine errors out on it as before.
    return configJson;
  }
  if (decoded is! Map<String, Object?>) {
    return configJson;
  }
  final protocols = decoded['protocols'];
  if (protocols is! Map<String, Object?>) {
    return configJson;
  }

  var patched = false;
  for (final entry in kForcedAdvertisedServices.entries) {
    final protocol = protocols[entry.key];
    if (protocol is! Map<String, dynamic>) {
      continue;
    }
    final communication = protocol['communication'];
    if (communication is! List) {
      continue;
    }
    for (final commEntry in communication) {
      if (commEntry is! Map<String, dynamic>) {
        continue;
      }
      final btle = commEntry['btle'];
      if (btle is! Map<String, dynamic>) {
        continue;
      }
      var advertised = btle['advertised_services'];
      if (advertised is! List<String>) {
        advertised = <String>[];
      }
      for (final uuid in entry.value) {
        if (!advertised.contains(uuid)) {
          advertised.add(uuid);
          patched = true;
        }
      }
      btle['advertised_services'] = advertised;
    }
  }

  if (!patched) {
    return configJson;
  }
  return jsonEncode(decoded);
}
