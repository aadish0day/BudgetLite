import 'dart:async';
import 'package:flutter/services.dart';

/// Pairs an SMS body with its device arrival timestamp (millis since epoch).
class SmsMessage {
  final String body;
  final int timestamp;
  SmsMessage(this.body, this.timestamp);
}

/// Handles real UPI SMS receiving and inbox scanning via native Android bridge.
class SmsListenerService {
  static const _channel = MethodChannel('budget_lite/sms');
  static const _events = EventChannel('budget_lite/sms_events');

  static final SmsListenerService _instance = SmsListenerService._();
  factory SmsListenerService() => _instance;
  SmsListenerService._();

  StreamSubscription? _eventSub;

  /// Stream of received SMS in real-time (body + device timestamp).
  final StreamController<SmsMessage> _onSmsReceived =
      StreamController<SmsMessage>.broadcast();
  Stream<SmsMessage> get onSmsReceived => _onSmsReceived.stream;

  /// Stream of permission results.
  final StreamController<bool> _onPermissionResult =
      StreamController<bool>.broadcast();
  Stream<bool> get onPermissionResult => _onPermissionResult.stream;

  bool _listening = false;
  bool get isListening => _listening;

  /// Request both READ_SMS and RECEIVE_SMS permissions.
  Future<bool> requestPermission() async {
    try {
      await _channel.invokeMethod('requestSmsPermission');
      return true;
    } on MissingPluginException {
      return false;
    }
  }

  /// Check if SMS permissions are already granted.
  Future<bool> isPermissionGranted() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isSmsPermissionGranted');
      return result ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Start the native SMS broadcast receiver for real-time capture.
  /// Works on Android 9 and below. Returns true if listener started.
  Future<bool> startListening() async {
    if (_listening) return true;
    try {
      _eventSub ??= _events.receiveBroadcastStream().listen((event) {
        if (event is Map) {
          final type = event['type'] as String?;
          if (type == 'sms_received') {
            final body = event['body'] as String?;
            final timestamp = event['timestamp'] as int?;
            if (body != null) {
              _onSmsReceived
                  .add(SmsMessage(body, timestamp ?? DateTime.now().millisecondsSinceEpoch));
            }
          } else if (type == 'permission_result') {
            final granted = event['granted'] as bool? ?? false;
            _onPermissionResult.add(granted);
          }
        }
      });

      final started =
          await _channel.invokeMethod<bool>('startListening') ?? false;
      _listening = started;
      return started;
    } on MissingPluginException {
      return false;
    }
  }

  /// Stop the native broadcast receiver.
  Future<void> stopListening() async {
    try {
      await _channel.invokeMethod('stopListening');
    } on MissingPluginException {
      // ignore on non-Android platforms
    }
    _listening = false;
  }

  /// Scan the SMS inbox for recent UPI messages.
  /// Returns a list of [SmsMessage] with body and device timestamp.
  Future<List<SmsMessage>> scanInbox() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('scanInbox');
      if (result == null) return [];
      return result.map((e) {
        final map = e as Map<String, dynamic>;
        return SmsMessage(
          map['body'] as String,
          (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        );
      }).toList();
    } on MissingPluginException {
      return [];
    }
  }

  /// Dispose all resources.
  void dispose() {
    _eventSub?.cancel();
    _eventSub = null;
    _onSmsReceived.close();
    _onPermissionResult.close();
    _listening = false;
  }
}
