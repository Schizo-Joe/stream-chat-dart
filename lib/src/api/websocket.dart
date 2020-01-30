import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'web_socket_channel_stub.dart'
    if (dart.library.html) 'web_socket_channel_html.dart'
    if (dart.library.io) 'web_socket_channel_io.dart';
import '../models/event.dart';
import '../models/user.dart';

typedef EventHandler = void Function(Event);

// TODO: improve error path for the connect() method
// TODO: make sure we pass an error with a stacktrace
// TODO: parse error even
// TODO: make sure parsing the event data is handled correctly
// TODO: if parsing an error into an event fails we should not hide the original error
// TODO: implement reconnection logic
class WebSocket {
  final String baseUrl;
  final User user;
  final Map<String, String> connectParams;
  final Map<String, dynamic> connectPayload;
  final EventHandler handler;
  final Logger logger;

  WebSocket({
    this.baseUrl,
    this.user,
    this.connectParams,
    this.connectPayload,
    this.handler,
    this.logger,
  });

  Event decodeEvent(String source) => Event.fromJson(json.decode(source));

  Future<Event> connect() {
    final completer = Completer<Event>();
    final qs = Map<String, String>.from(connectParams);

    final data = Map<String, dynamic>.from(connectPayload);

    data["user_details"] = user.toJson();
    qs["json"] = json.encode(data);

    final uri = Uri.https(baseUrl, "connect", qs);
    final path = uri.toString().replaceFirst("https", "wss");

    logger.info('connecting to $path');

    bool resolved = false;

    final channel = connectWebSocket(path);
    channel.stream.listen((data) {
      final event = decodeEvent(data);
      if (resolved) {
        handler(event);
      } else {
        resolved = true;
        logger.info('connection estabilished');
        completer.complete(event);
      }
    }, onError: (error) {
      logger.severe('error connecting');
      completer.completeError(error);
    });
    return completer.future;
  }
}