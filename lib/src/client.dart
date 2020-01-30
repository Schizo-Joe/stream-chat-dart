import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'api/channel.dart';
import 'exceptions.dart';
import 'models/event.dart';
import 'api/requests.dart';
import 'api/responses.dart';
import 'models/message.dart';
import 'models/user.dart';
import 'api/websocket.dart';

typedef LogHandlerFunction = void Function(LogRecord record);

class Client {
  static const defaultBaseURL = "chat-us-east-1.stream-io-api.com";

  final Logger logger = Logger('HTTP');
  final Level logLevel;
  final String apiKey;
  final String baseURL;
  final Dio dioClient = Dio();

  LogHandlerFunction _logHandlerFunction;
  LogHandlerFunction get logHandlerFunction => _logHandlerFunction;

  final _controller = StreamController<Event>.broadcast();

  Stream get stream => _controller.stream;

  String _token;
  User _user;
  bool _anonymous;
  String _connectionId;
  WebSocket _ws;

  bool get hasConnectionId => _connectionId != null;

  Client(
    this.apiKey, {
    this.baseURL = defaultBaseURL,
    this.logLevel = Level.WARNING,
    LogHandlerFunction logHandlerFunction,
    Duration connectTimeout = const Duration(seconds: 6),
    Duration receiveTimeout = const Duration(seconds: 6),
  }) {
    _setupLogger(logHandlerFunction);
    _setupDio(receiveTimeout, connectTimeout);
  }

  void _setupDio(Duration receiveTimeout, Duration connectTimeout) {
    dioClient.options.baseUrl = Uri.https(baseURL, '').toString();
    dioClient.options.receiveTimeout = receiveTimeout.inMilliseconds;
    dioClient.options.connectTimeout = connectTimeout.inMilliseconds;
    dioClient.interceptors.add(InterceptorsWrapper(
      onRequest: (options) async {
        logger.info('''
    
          method: ${options.method}
          url: ${options.uri} 
          headers: ${options.headers}
          data: ${options.data.toString()}
    
        ''');
        options.queryParameters.addAll(commonQueryParams);
        options.headers.addAll(httpHeaders);
        return options;
      },
      onError: (error) async {
        logger.severe(error.message, error);
        return error;
      },
      onResponse: (response) async {
        if (response.statusCode != 200) {
          return dioClient.reject(ApiError(
            response.data,
            response.statusCode,
          ));
        }
        return response;
      },
    ));
  }

  void _setupLogger(LogHandlerFunction logHandlerFunction) {
    Logger.root.level = logLevel;

    _logHandlerFunction = logHandlerFunction;
    if (_logHandlerFunction == null) {
      _logHandlerFunction = (LogRecord record) {
        print(
            '(${record.time}) ${record.level.name}: ${record.loggerName} | ${record.message}');
        if (record.stackTrace != null) {
          print(record.stackTrace);
        }
      };
    }
    logger.onRecord.listen(_logHandlerFunction);
  }

  void dispose(filename) {
    dioClient.close();
    _controller.close();
  }

  Map<String, String> get httpHeaders => {
        "Authorization": _token,
        "stream-auth-type": _getAuthType(),
        "x-stream-client": getUserAgent(),
      };

  Future<Event> setUser(User user, String token) {
    _user = user;
    _token = token;
    _anonymous = false;
    return connect();
  }

  Stream<Event> on(String eventType) =>
      stream.where((event) => eventType == null || event.type == eventType);

  void handleEvent(Event event) => _controller.add(event);

  Future<Event> connect() async {
    _ws = WebSocket(
      baseUrl: baseURL,
      user: _user,
      connectParams: {
        "api_key": apiKey,
        "authorization": _token,
        "stream-auth-type": _getAuthType(),
      },
      connectPayload: {
        "user_id": _user.id,
        "server_determines_connection_id": true,
      },
      handler: handleEvent,
      logger: Logger('ws')..onRecord.listen(_logHandlerFunction),
    );

    final connectEvent = await _ws.connect();
    _connectionId = connectEvent.connectionId;
    return connectEvent;
  }

  Future<QueryChannelsResponse> queryChannels(
    QueryFilter filter,
    List<SortOption> sort,
    Map<String, dynamic> options,
  ) async {
    final Map<String, dynamic> defaultOptions = {
      "state": true,
      "watch": true,
      "presence": false,
    };

    Map<String, dynamic> payload = {
      "filter_conditions": filter,
      "sort": sort,
      "user_details": this._user,
    };

    payload.addAll(defaultOptions);

    if (options != null) {
      payload.addAll(options);
    }

    final response = await dioClient.get<String>(
      "/channels",
      queryParameters: {
        "payload": jsonEncode(payload),
      },
    );
    return decode<QueryChannelsResponse>(
      response.data,
      QueryChannelsResponse.fromJson,
    );
  }

  // Used to log errors and stacktrace in case of bad json deserialization
  T decode<T>(String j, T Function(Map<String, dynamic>) decoderFunction) {
    try {
      return decoderFunction(json.decode(j));
    } catch (error, stacktrace) {
      logger.severe('Error decoding response', error, stacktrace);
      rethrow;
    }
  }

  _getAuthType() => _anonymous ? 'anonymous' : 'jwt';

  // TODO: get the right version of the lib from the build toolchain
  getUserAgent() => "stream_chat_dart-client-0.0.1";

  Map<String, String> get commonQueryParams => {
        "user_id": _user.id,
        "api_key": apiKey,
        "connection_id": _connectionId,
      };

  Future<Event> setAnonymousUser() async {
    this._anonymous = true;
    final uuid = Uuid();
    this._user = User(uuid.v4());
    return connect();
  }

  Future<Event> setGuestUser(User user) async {
    _anonymous = true;
    final response = await dioClient
        .post<String>("/guest", data: {"user": user.toJson()})
        .then((res) => decode(res.data, SetGuestUserResponse.fromJson))
        .whenComplete(() => _anonymous = false);
    return setUser(response.user, response.accessToken);
  }

  // TODO disconnect
  Future<dynamic> disconnect() async => null;

  Future<QueryUsersResponse> queryUsers(
    QueryFilter filter,
    List<SortOption> sort,
    Map<String, dynamic> options,
  ) async {
    final Map<String, dynamic> defaultOptions = {
      "presence": this.hasConnectionId,
    };

    Map<String, dynamic> payload = {
      "filter_conditions": filter,
      "sort": sort,
    };

    payload.addAll(defaultOptions);

    if (options != null) {
      payload.addAll(options);
    }

    final response = await dioClient.get<String>(
      "/users",
      queryParameters: {
        "payload": jsonEncode(payload),
      },
    );
    return decode<QueryUsersResponse>(
      response.data,
      QueryUsersResponse.fromJson,
    );
  }

  Future<SearchMessagesResponse> search(
    QueryFilter filters,
    List<SortOption> sort,
    String query,
    PaginationParams paginationParams,
  ) async {
    final payload = {
      'filter_conditions': filters,
      'query': query,
      'sort': sort,
    };

    payload.addAll(paginationParams.toJson());

    final response = await dioClient
        .get<String>("/search", queryParameters: {'payload': payload});
    return decode<SearchMessagesResponse>(
        response.data, SearchMessagesResponse.fromJson);
  }

  Future<EmptyResponse> addDevice(String id, String pushProvider) async {
    final response = await dioClient.post<String>("/devices", data: {
      "id": id,
      "push_provider": pushProvider,
    });
    return decode<EmptyResponse>(response.data, EmptyResponse.fromJson);
  }

  Future<ListDevicesResponse> getDevices() async {
    final response = await dioClient.get<String>("/devices");
    return decode<ListDevicesResponse>(
        response.data, ListDevicesResponse.fromJson);
  }

  Future<EmptyResponse> removeDevice(String id) async {
    final response =
        await dioClient.delete<String>("/devices", queryParameters: {
      "id": id,
    });
    return decode(response.data, EmptyResponse.fromJson);
  }

  Channel channel(
    String type, {
    String id,
    Map<String, dynamic> custom,
  }) {
    return Channel(this, type, id, custom);
  }

  Future<UpdateUsersResponse> updateUser(User user) async {
    final response = await dioClient.post<String>("/users", data: {
      "users": {user.id: user.toJson()},
    });
    return decode<UpdateUsersResponse>(
        response.data, UpdateUsersResponse.fromJson);
  }

  Future<EmptyResponse> banUser(
    String targetUserID, [
    Map<String, dynamic> options = const {},
  ]) async {
    final data = Map<String, dynamic>.from(options)
      ..addAll({
        "target_user_id": targetUserID,
      });
    final response = await dioClient.post<String>(
      "/moderation/ban",
      data: data,
    );
    return decode(response.data, EmptyResponse.fromJson);
  }

  Future<EmptyResponse> unbanUser(
    String targetUserID, [
    Map<String, dynamic> options = const {},
  ]) async {
    final data = Map<String, dynamic>.from(options)
      ..addAll({
        "target_user_id": targetUserID,
      });
    final response = await dioClient.delete<String>(
      "/moderation/ban",
      queryParameters: data,
    );
    return decode(response.data, EmptyResponse.fromJson);
  }

  Future<EmptyResponse> muteUser(String targetID) async {
    final response = await dioClient.post<String>("/moderation/mute", data: {
      "target_id": targetID,
    });
    return decode(response.data, EmptyResponse.fromJson);
  }

  Future<EmptyResponse> unmuteUser(String targetID) async {
    final response = await dioClient.post<String>("/moderation/unmute", data: {
      "target_id": targetID,
    });
    return decode(response.data, EmptyResponse.fromJson);
  }

  Future<EmptyResponse> flagMessage(String messageID) async {
    final response = await dioClient.post<String>("/moderation/flag", data: {
      "target_message_id": messageID,
    });
    return decode(response.data, EmptyResponse.fromJson);
  }

  Future<EmptyResponse> unflagMessage(String messageID) async {
    final response = await dioClient.post<String>("/moderation/unflag", data: {
      "target_message_id": messageID,
    });
    return decode(response.data, EmptyResponse.fromJson);
  }

  Future<EmptyResponse> markAllRead() async {
    final response = await dioClient.post<String>("/channels/read");
    return decode(response.data, EmptyResponse.fromJson);
  }

  Future<UpdateMessageResponse> updateMessage(Message message) async {
    return dioClient
        .post<String>("/messages/${message.id}")
        .then((res) => decode(res.data, UpdateMessageResponse.fromJson));
  }

  Future<EmptyResponse> deleteMessage(String messageID) async {
    final response = await dioClient.delete<String>("/messages/$messageID");
    return decode(response.data, EmptyResponse.fromJson);
  }

  Future<GetMessageResponse> getMessage(String messageID) async {
    final response = await dioClient.get<String>("/messages/$messageID");
    return decode(response.data, GetMessageResponse.fromJson);
  }
}