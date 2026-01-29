import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../storage/local_storage.dart';

/// WebSocket 消息类型
enum WSMessageType {
  /// 连接成功
  connected,
  /// 日程更新
  scheduleUpdate,
  /// 任务更新
  taskUpdate,
  /// 提醒通知
  reminder,
  /// 心跳
  ping,
  /// 错误
  error,
  /// 未知
  unknown,
}

/// WebSocket 消息
class WSMessage {
  final WSMessageType type;
  final Map<String, dynamic>? data;
  final String? error;
  final DateTime timestamp;

  WSMessage({
    required this.type,
    this.data,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WSMessage.fromJson(Map<String, dynamic> json) {
    WSMessageType type;
    switch (json['type']) {
      case 'connected':
        type = WSMessageType.connected;
        break;
      case 'schedule_update':
        type = WSMessageType.scheduleUpdate;
        break;
      case 'task_update':
        type = WSMessageType.taskUpdate;
        break;
      case 'reminder':
        type = WSMessageType.reminder;
        break;
      case 'ping':
        type = WSMessageType.ping;
        break;
      case 'error':
        type = WSMessageType.error;
        break;
      default:
        type = WSMessageType.unknown;
    }

    return WSMessage(
      type: type,
      data: json['data'],
      error: json['error'],
    );
  }
}

/// WebSocket 连接状态
enum WSConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// WebSocket 客户端服务
class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  
  String? _serverUrl;
  String? _userId;
  
  WSConnectionState _connectionState = WSConnectionState.disconnected;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  
  final _messageController = StreamController<WSMessage>.broadcast();
  final _connectionStateController = StreamController<WSConnectionState>.broadcast();

  /// 消息流
  Stream<WSMessage> get messages => _messageController.stream;

  /// 连接状态流
  Stream<WSConnectionState> get connectionState => _connectionStateController.stream;

  /// 当前连接状态
  WSConnectionState get currentState => _connectionState;

  /// 是否已连接
  bool get isConnected => _connectionState == WSConnectionState.connected;

  /// 初始化
  Future<void> initialize(LocalStorage storage) async {
    _serverUrl = storage.getServerUrl();
    _userId = storage.getUserId();
  }

  /// 设置服务器地址
  void setServerUrl(String url) {
    _serverUrl = url;
  }

  /// 设置用户 ID
  void setUserId(String userId) {
    _userId = userId;
  }

  /// 连接到服务器
  Future<void> connect() async {
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      debugPrint('WebSocket: 未配置服务器地址');
      return;
    }

    if (_connectionState == WSConnectionState.connecting ||
        _connectionState == WSConnectionState.connected) {
      return;
    }

    _updateConnectionState(WSConnectionState.connecting);

    try {
      // 将 http/https 转换为 ws/wss
      String wsUrl = _serverUrl!;
      if (wsUrl.startsWith('https://')) {
        wsUrl = 'wss://${wsUrl.substring(8)}';
      } else if (wsUrl.startsWith('http://')) {
        wsUrl = 'ws://${wsUrl.substring(7)}';
      }
      
      // 添加 WebSocket 路径和用户 ID
      final uri = Uri.parse('$wsUrl/ws');
      final wsUri = uri.replace(queryParameters: {
        if (_userId != null) 'user_id': _userId,
      });

      debugPrint('WebSocket: 正在连接 $wsUri');
      
      _channel = WebSocketChannel.connect(wsUri);
      
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _updateConnectionState(WSConnectionState.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();
      
      debugPrint('WebSocket: 连接成功');
    } catch (e) {
      debugPrint('WebSocket: 连接失败 - $e');
      _updateConnectionState(WSConnectionState.error);
      _scheduleReconnect();
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    _stopHeartbeat();
    _cancelReconnect();
    
    await _subscription?.cancel();
    _subscription = null;
    
    await _channel?.sink.close();
    _channel = null;
    
    _updateConnectionState(WSConnectionState.disconnected);
    debugPrint('WebSocket: 已断开连接');
  }

  /// 发送消息
  void send(Map<String, dynamic> message) {
    if (!isConnected || _channel == null) {
      debugPrint('WebSocket: 未连接，无法发送消息');
      return;
    }

    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('WebSocket: 发送消息失败 - $e');
    }
  }

  /// 发送心跳
  void _sendPing() {
    send({'type': 'ping'});
  }

  /// 处理接收到的消息
  void _onMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String);
      final message = WSMessage.fromJson(json);
      
      debugPrint('WebSocket: 收到消息 - ${message.type}');
      
      if (message.type == WSMessageType.ping) {
        // 响应心跳
        send({'type': 'pong'});
        return;
      }
      
      _messageController.add(message);
    } catch (e) {
      debugPrint('WebSocket: 解析消息失败 - $e');
    }
  }

  /// 处理错误
  void _onError(dynamic error) {
    debugPrint('WebSocket: 错误 - $error');
    _updateConnectionState(WSConnectionState.error);
    _messageController.add(WSMessage(
      type: WSMessageType.error,
      error: error.toString(),
    ));
  }

  /// 处理连接关闭
  void _onDone() {
    debugPrint('WebSocket: 连接已关闭');
    _stopHeartbeat();
    
    if (_connectionState != WSConnectionState.disconnected) {
      _updateConnectionState(WSConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// 更新连接状态
  void _updateConnectionState(WSConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  /// 启动心跳
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendPing();
    });
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 调度重连
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('WebSocket: 达到最大重连次数，停止重连');
      return;
    }

    _cancelReconnect();
    _updateConnectionState(WSConnectionState.reconnecting);
    
    final delay = _reconnectDelay * (_reconnectAttempts + 1);
    debugPrint('WebSocket: ${delay.inSeconds} 秒后尝试重连 (${_reconnectAttempts + 1}/$_maxReconnectAttempts)');
    
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      connect();
    });
  }

  /// 取消重连
  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// 重置重连计数
  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
  }

  /// 释放资源
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _connectionStateController.close();
  }
}

/// WebSocket 服务状态
class WebSocketState {
  final WSConnectionState connectionState;
  final List<WSMessage> recentMessages;

  WebSocketState({
    this.connectionState = WSConnectionState.disconnected,
    this.recentMessages = const [],
  });

  WebSocketState copyWith({
    WSConnectionState? connectionState,
    List<WSMessage>? recentMessages,
  }) {
    return WebSocketState(
      connectionState: connectionState ?? this.connectionState,
      recentMessages: recentMessages ?? this.recentMessages,
    );
  }
}

/// WebSocket 服务 Notifier
class WebSocketNotifier extends StateNotifier<WebSocketState> {
  final WebSocketService _service;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _stateSubscription;

  WebSocketNotifier(this._service) : super(WebSocketState()) {
    _init();
  }

  void _init() {
    _messageSubscription = _service.messages.listen(_onMessage);
    _stateSubscription = _service.connectionState.listen(_onStateChange);
  }

  void _onMessage(WSMessage message) {
    final messages = List<WSMessage>.from(state.recentMessages);
    messages.insert(0, message);
    // 只保留最近 50 条消息
    if (messages.length > 50) {
      messages.removeLast();
    }
    state = state.copyWith(recentMessages: messages);
  }

  void _onStateChange(WSConnectionState connectionState) {
    state = state.copyWith(connectionState: connectionState);
  }

  /// 连接
  Future<void> connect() => _service.connect();

  /// 断开
  Future<void> disconnect() => _service.disconnect();

  /// 是否已连接
  bool get isConnected => _service.isConnected;

  /// 发送消息
  void send(Map<String, dynamic> message) => _service.send(message);

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _stateSubscription?.cancel();
    super.dispose();
  }
}

/// WebSocket 服务实例
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

/// WebSocket 状态 Provider
final webSocketProvider = StateNotifierProvider<WebSocketNotifier, WebSocketState>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  return WebSocketNotifier(service);
});
