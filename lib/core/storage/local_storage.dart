import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../llm/models/message.dart';

/// 存储键常量
class StorageKeys {
  static const String settingsBox = 'settings';
  static const String messagesBox = 'messages';
  static const String conversationsBox = 'conversations';
  
  // Settings keys
  static const String activeProvider = 'active_provider';
  static const String apiKeys = 'api_keys';
  static const String activeModel = 'active_model';
  static const String theme = 'theme';
  static const String seedColor = 'seed_color';
  static const String serverUrl = 'server_url';
  static const String userId = 'user_id';
  static const String lastSyncTime = 'last_sync_time';
  static const String useBackendLLM = 'use_backend_llm';
}

/// 本地存储服务
class LocalStorage {
  late Box _settingsBox;
  late Box _messagesBox;
  late Box _conversationsBox;
  bool _initialized = false;

  /// 初始化存储
  Future<void> initialize() async {
    if (_initialized) return;
    
    _settingsBox = await Hive.openBox(StorageKeys.settingsBox);
    _messagesBox = await Hive.openBox(StorageKeys.messagesBox);
    _conversationsBox = await Hive.openBox(StorageKeys.conversationsBox);
    _initialized = true;
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('LocalStorage 未初始化，请先调用 initialize()');
    }
  }

  // ========== 设置相关 ==========

  /// 获取当前活跃的提供商
  String getActiveProvider() {
    _ensureInitialized();
    return _settingsBox.get(StorageKeys.activeProvider, defaultValue: 'deepseek');
  }

  /// 设置当前活跃的提供商
  Future<void> setActiveProvider(String provider) async {
    _ensureInitialized();
    await _settingsBox.put(StorageKeys.activeProvider, provider);
  }

  /// 获取所有 API Keys
  Map<String, String> getApiKeys() {
    _ensureInitialized();
    final data = _settingsBox.get(StorageKeys.apiKeys);
    if (data == null) return {};
    return Map<String, String>.from(data);
  }

  /// 设置 API Key
  Future<void> setApiKey(String provider, String apiKey) async {
    _ensureInitialized();
    final keys = getApiKeys();
    keys[provider] = apiKey;
    await _settingsBox.put(StorageKeys.apiKeys, keys);
  }

  /// 获取提供商对应的模型
  String? getActiveModel(String provider) {
    _ensureInitialized();
    final models = _settingsBox.get(StorageKeys.activeModel);
    if (models == null) return null;
    return (models as Map)[provider];
  }

  /// 设置提供商对应的模型
  Future<void> setActiveModel(String provider, String model) async {
    _ensureInitialized();
    final models = _settingsBox.get(StorageKeys.activeModel) ?? {};
    models[provider] = model;
    await _settingsBox.put(StorageKeys.activeModel, models);
  }

  /// 获取主题模式
  String getTheme() {
    _ensureInitialized();
    return _settingsBox.get(StorageKeys.theme, defaultValue: 'system');
  }

  /// 设置主题模式
  Future<void> setTheme(String theme) async {
    _ensureInitialized();
    await _settingsBox.put(StorageKeys.theme, theme);
  }

  /// 获取主题色
  int? getSeedColor() {
    _ensureInitialized();
    return _settingsBox.get(StorageKeys.seedColor);
  }

  /// 设置主题色
  Future<void> setSeedColor(int colorValue) async {
    _ensureInitialized();
    await _settingsBox.put(StorageKeys.seedColor, colorValue);
  }

  // ========== 服务器相关 ==========

  /// 获取服务器地址
  String? getServerUrl() {
    _ensureInitialized();
    return _settingsBox.get(StorageKeys.serverUrl);
  }

  /// 设置服务器地址
  Future<void> setServerUrl(String url) async {
    _ensureInitialized();
    await _settingsBox.put(StorageKeys.serverUrl, url);
  }

  /// 获取用户 ID
  String? getUserId() {
    _ensureInitialized();
    return _settingsBox.get(StorageKeys.userId);
  }

  /// 设置用户 ID
  Future<void> setUserId(String userId) async {
    _ensureInitialized();
    await _settingsBox.put(StorageKeys.userId, userId);
  }

  /// 获取最后同步时间
  DateTime? getLastSyncTime() {
    _ensureInitialized();
    final str = _settingsBox.get(StorageKeys.lastSyncTime);
    if (str == null) return null;
    return DateTime.parse(str);
  }

  /// 设置最后同步时间
  Future<void> setLastSyncTime(DateTime time) async {
    _ensureInitialized();
    await _settingsBox.put(StorageKeys.lastSyncTime, time.toIso8601String());
  }

  /// 是否使用后端 LLM
  bool getUseBackendLLM() {
    _ensureInitialized();
    return _settingsBox.get(StorageKeys.useBackendLLM, defaultValue: false);
  }

  /// 设置是否使用后端 LLM
  Future<void> setUseBackendLLM(bool value) async {
    _ensureInitialized();
    await _settingsBox.put(StorageKeys.useBackendLLM, value);
  }

  // ========== 对话相关 ==========

  /// 获取当前对话 ID
  String? getCurrentConversationId() {
    _ensureInitialized();
    return _conversationsBox.get('current_id');
  }

  /// 设置当前对话 ID
  Future<void> setCurrentConversationId(String id) async {
    _ensureInitialized();
    await _conversationsBox.put('current_id', id);
  }

  /// 获取对话列表
  List<Map<String, dynamic>> getConversations() {
    _ensureInitialized();
    final list = _conversationsBox.get('list');
    if (list == null) return [];
    return List<Map<String, dynamic>>.from(
      (list as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  /// 添加对话
  Future<void> addConversation(String id, String title) async {
    _ensureInitialized();
    final list = getConversations();
    list.insert(0, {
      'id': id,
      'title': title,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    await _conversationsBox.put('list', list);
  }

  /// 更新对话标题
  Future<void> updateConversationTitle(String id, String title) async {
    _ensureInitialized();
    final list = getConversations();
    final index = list.indexWhere((c) => c['id'] == id);
    if (index != -1) {
      list[index]['title'] = title;
      list[index]['updated_at'] = DateTime.now().toIso8601String();
      await _conversationsBox.put('list', list);
    }
  }

  /// 删除对话
  Future<void> deleteConversation(String id) async {
    _ensureInitialized();
    final list = getConversations();
    list.removeWhere((c) => c['id'] == id);
    await _conversationsBox.put('list', list);
    await _messagesBox.delete(id);
  }

  // ========== 消息相关 ==========

  /// 获取对话的消息列表
  List<Message> getMessages(String conversationId) {
    _ensureInitialized();
    final data = _messagesBox.get(conversationId);
    if (data == null) return [];
    return (data as List).map((m) {
      return Message.fromJson(Map<String, dynamic>.from(m));
    }).toList();
  }

  /// 保存消息列表
  Future<void> saveMessages(String conversationId, List<Message> messages) async {
    _ensureInitialized();
    final data = messages.map((m) => {
      ...m.toJson(),
      'id': m.id,
      'timestamp': m.timestamp.toIso8601String(),
    }).toList();
    await _messagesBox.put(conversationId, data);
  }

  /// 添加消息
  Future<void> addMessage(String conversationId, Message message) async {
    _ensureInitialized();
    final messages = getMessages(conversationId);
    messages.add(message);
    await saveMessages(conversationId, messages);
  }

  /// 更新最后一条消息
  Future<void> updateLastMessage(String conversationId, Message message) async {
    _ensureInitialized();
    final messages = getMessages(conversationId);
    if (messages.isNotEmpty) {
      messages[messages.length - 1] = message;
      await saveMessages(conversationId, messages);
    }
  }

  /// 清空存储
  Future<void> clear() async {
    _ensureInitialized();
    await _settingsBox.clear();
    await _messagesBox.clear();
    await _conversationsBox.clear();
  }
}

/// 全局存储实例 Provider
final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage();
});
