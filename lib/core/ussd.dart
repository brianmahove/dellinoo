import 'dart:io';

import 'package:flutter/services.dart';

/// How [runUssd] went: the code ran directly (the EcoCash PIN prompt is
/// showing), the dialer opened with it filled in (call permission refused —
/// the customer taps call), or nothing could handle it.
enum UssdResult { called, dialer, failed }

const _channel = MethodChannel('com.dellinoo.app/ussd');

/// Whether this device can run USSD codes at all (Android only; iOS blocks
/// `*`/`#` in dial links).
bool get ussdSupported => Platform.isAndroid;

/// Dials [code] (e.g. `*153*1*1*0771234567*25#`) via MainActivity.kt.
Future<UssdResult> runUssd(String code) async {
  if (!ussdSupported) return UssdResult.failed;
  try {
    final result = await _channel.invokeMethod<String>('dial', {'code': code});
    return UssdResult.values.asNameMap()[result] ?? UssdResult.failed;
  } on PlatformException {
    return UssdResult.failed;
  } on MissingPluginException {
    return UssdResult.failed;
  }
}
