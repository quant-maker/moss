import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/llm/llm_router.dart';
import '../../core/storage/local_storage.dart';
import '../../core/services/api_client.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/websocket_service.dart';
import '../../core/services/speech_service.dart';
import '../../core/theme/theme_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final Map<String, TextEditingController> _apiKeyControllers = {};
  final TextEditingController _serverUrlController = TextEditingController();
  bool _initialized = false;
  bool _useBackendLLM = false;
  bool _isTestingConnection = false;
  bool? _connectionTestResult;

  @override
  void dispose() {
    for (final controller in _apiKeyControllers.values) {
      controller.dispose();
    }
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (_initialized) return;
    
    final storage = ref.read(localStorageProvider);
    await storage.initialize();
    final apiKeys = storage.getApiKeys();
    
    // 加载服务器配置
    _serverUrlController.text = storage.getServerUrl() ?? '';
    _useBackendLLM = storage.getUseBackendLLM();
    
    final providers = ref.read(llmRouterProvider).router.providers;
    for (final provider in providers) {
      _apiKeyControllers[provider.name] = TextEditingController(
        text: apiKeys[provider.name] ?? '',
      );
      
      // 恢复 API Key 到提供商
      if (apiKeys[provider.name] != null && apiKeys[provider.name]!.isNotEmpty) {
        ref.read(llmRouterProvider.notifier).setApiKey(
          provider.name,
          apiKeys[provider.name]!,
        );
      }
    }
    
    _initialized = true;
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final llmState = ref.watch(llmRouterProvider);
    final providers = llmState.router.providers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 服务器配置
          _buildSection(
            theme,
            title: '服务器配置',
            child: _buildServerSettings(theme),
          ),
          
          const SizedBox(height: 16),
          
          // 外观设置
          _buildSection(
            theme,
            title: '外观设置',
            child: _buildThemeSettings(theme),
          ),
          
          const SizedBox(height: 16),
          
          // LLM 提供商选择
          _buildSection(
            theme,
            title: 'AI 提供商',
            child: Column(
              children: [
                // 使用后端 LLM 开关
                SwitchListTile(
                  title: const Text('使用后端 LLM'),
                  subtitle: Text(
                    _useBackendLLM 
                        ? '通过自建服务器调用 LLM' 
                        : '直接调用 LLM API',
                  ),
                  value: _useBackendLLM,
                  onChanged: _serverUrlController.text.isNotEmpty
                      ? (value) => _setUseBackendLLM(value)
                      : null,
                ),
                const Divider(),
                ...providers.map((provider) => RadioListTile<String>(
                  title: Text(provider.displayName),
                  subtitle: Text(
                    provider.isConfigured ? '已配置' : '未配置 API Key',
                    style: TextStyle(
                      color: provider.isConfigured
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                  value: provider.name,
                  groupValue: llmState.activeProviderName,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(llmRouterProvider.notifier).switchProvider(value);
                      _saveActiveProvider(value);
                    }
                  },
                )),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // API Key 配置
          _buildSection(
            theme,
            title: 'API Key 配置',
            child: Column(
              children: providers.map((provider) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildApiKeyField(provider.name, provider.displayName),
              )).toList(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 模型选择
          _buildSection(
            theme,
            title: '模型选择',
            child: _buildModelSelector(llmState),
          ),
          
          const SizedBox(height: 16),
          
          // 数据同步
          _buildSection(
            theme,
            title: '数据同步',
            child: _buildSyncSettings(theme),
          ),
          
          const SizedBox(height: 16),
          
          // 语音设置
          _buildSection(
            theme,
            title: '语音设置',
            child: _buildSpeechSettings(theme),
          ),
          
          const SizedBox(height: 16),
          
          // 关于
          _buildSection(
            theme,
            title: '关于',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.smart_toy),
                  title: const Text('Moss 智能管家'),
                  subtitle: const Text('版本 1.0.0'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('支持的功能'),
                  subtitle: const Text('日程管理、打开APP、搜索、播放音乐、点外卖等'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // 危险操作
          _buildSection(
            theme,
            title: '数据管理',
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                  title: Text(
                    '清除所有数据',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  subtitle: const Text('删除所有对话历史和设置'),
                  onTap: () => _showClearDataDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(ThemeData theme, {required String title, required Widget child}) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          child,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildApiKeyField(String providerName, String displayName) {
    final controller = _apiKeyControllers[providerName];
    if (controller == null) return const SizedBox.shrink();
    
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: '$displayName API Key',
        hintText: '请输入 API Key',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.save),
          tooltip: '保存',
          onPressed: () => _saveApiKey(providerName, controller.text),
        ),
      ),
      onSubmitted: (value) => _saveApiKey(providerName, value),
    );
  }

  Widget _buildModelSelector(LLMRouterState llmState) {
    final activeProvider = llmState.router.activeProvider;
    final models = activeProvider.availableModels;
    
    return DropdownButtonFormField<String>(
      value: activeProvider.currentModel,
      decoration: InputDecoration(
        labelText: '${activeProvider.displayName} 模型',
        border: const OutlineInputBorder(),
      ),
      items: models.map((model) => DropdownMenuItem(
        value: model,
        child: Text(model),
      )).toList(),
      onChanged: (value) {
        if (value != null) {
          activeProvider.currentModel = value;
          _saveActiveModel(activeProvider.name, value);
          setState(() {});
        }
      },
    );
  }

  Future<void> _saveApiKey(String providerName, String apiKey) async {
    final storage = ref.read(localStorageProvider);
    await storage.setApiKey(providerName, apiKey);
    ref.read(llmRouterProvider.notifier).setApiKey(providerName, apiKey);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key 已保存')),
      );
    }
  }

  Future<void> _saveActiveProvider(String providerName) async {
    final storage = ref.read(localStorageProvider);
    await storage.setActiveProvider(providerName);
  }

  Future<void> _saveActiveModel(String providerName, String model) async {
    final storage = ref.read(localStorageProvider);
    await storage.setActiveModel(providerName, model);
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除数据'),
        content: const Text('此操作将删除所有对话历史和设置，且无法恢复。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final storage = ref.read(localStorageProvider);
              await storage.clear();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('数据已清除')),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }

  Widget _buildServerSettings(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _serverUrlController,
            decoration: InputDecoration(
              labelText: '服务器地址',
              hintText: 'http://192.168.1.100:8080',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.save),
                tooltip: '保存',
                onPressed: _saveServerUrl,
              ),
            ),
            onSubmitted: (_) => _saveServerUrl(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isTestingConnection ? null : _testConnection,
                  icon: _isTestingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_find),
                  label: const Text('测试连接'),
                ),
              ),
              const SizedBox(width: 16),
              if (_connectionTestResult != null)
                Icon(
                  _connectionTestResult! ? Icons.check_circle : Icons.error,
                  color: _connectionTestResult!
                      ? Colors.green
                      : theme.colorScheme.error,
                ),
            ],
          ),
          if (_connectionTestResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _connectionTestResult! ? '连接成功' : '连接失败',
                style: TextStyle(
                  color: _connectionTestResult!
                      ? Colors.green
                      : theme.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildThemeSettings(ThemeData theme) {
    final themeState = ref.watch(themeProvider);
    
    return Column(
      children: [
        // 主题模式选择
        ListTile(
          leading: Icon(
            _getThemeModeIcon(themeState.themeMode),
            color: theme.colorScheme.primary,
          ),
          title: const Text('主题模式'),
          subtitle: Text(_getThemeModeText(themeState.themeMode)),
          trailing: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {themeState.themeMode},
            onSelectionChanged: (Set<ThemeMode> modes) {
              if (modes.isNotEmpty) {
                ref.read(themeProvider.notifier).setThemeMode(modes.first);
              }
            },
          ),
        ),
        const Divider(),
        
        // 主题色选择
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('主题色'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ThemeState.presetColors.map((color) {
                  final isSelected = themeState.seedColor.value == color.value;
                  return GestureDetector(
                    onTap: () {
                      ref.read(themeProvider.notifier).setSeedColor(color);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getThemeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  Widget _buildSyncSettings(ThemeData theme) {
    final syncState = ref.watch(syncServiceProvider);
    final wsState = ref.watch(webSocketProvider);
    
    return Column(
      children: [
        ListTile(
          leading: Icon(
            _getSyncIcon(syncState.status),
            color: _getSyncColor(syncState.status, theme),
          ),
          title: const Text('数据同步'),
          subtitle: Text(_getSyncStatusText(syncState)),
          trailing: ElevatedButton(
            onPressed: syncState.status == SyncStatus.syncing
                ? null
                : () => _performSync(),
            child: syncState.status == SyncStatus.syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('立即同步'),
          ),
        ),
        const Divider(),
        ListTile(
          leading: Icon(
            _getWSIcon(wsState.connectionState),
            color: _getWSColor(wsState.connectionState, theme),
          ),
          title: const Text('实时连接'),
          subtitle: Text(_getWSStatusText(wsState.connectionState)),
          trailing: wsState.connectionState == WSConnectionState.connected
              ? TextButton(
                  onPressed: () => ref.read(webSocketProvider.notifier).disconnect(),
                  child: const Text('断开'),
                )
              : TextButton(
                  onPressed: _serverUrlController.text.isNotEmpty
                      ? () => ref.read(webSocketProvider.notifier).connect()
                      : null,
                  child: const Text('连接'),
                ),
        ),
      ],
    );
  }

  Widget _buildSpeechSettings(ThemeData theme) {
    final speechState = ref.watch(speechProvider);
    
    return Column(
      children: [
        // 语音识别状态
        ListTile(
          leading: Icon(
            _getSpeechStatusIcon(speechState.speechStatus),
            color: _getSpeechStatusColor(speechState.speechStatus, theme),
          ),
          title: const Text('语音识别'),
          subtitle: Text(_getSpeechStatusText(speechState.speechStatus)),
        ),
        const Divider(),
        
        // TTS 状态
        ListTile(
          leading: Icon(
            _getTtsStatusIcon(speechState.ttsStatus),
            color: _getTtsStatusColor(speechState.ttsStatus, theme),
          ),
          title: const Text('语音合成 (TTS)'),
          subtitle: Text(_getTtsStatusText(speechState.ttsStatus)),
        ),
        const Divider(),
        
        // 自动朗读开关
        SwitchListTile(
          title: const Text('自动朗读回复'),
          subtitle: const Text('AI 回复后自动朗读'),
          value: speechState.autoSpeak,
          onChanged: (value) {
            ref.read(speechProvider.notifier).setAutoSpeak(value);
          },
        ),
        const Divider(),
        
        // TTS 语速
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('语速'),
                  Text('${(speechState.ttsRate * 100).round()}%'),
                ],
              ),
              Slider(
                value: speechState.ttsRate,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: '${(speechState.ttsRate * 100).round()}%',
                onChanged: (value) {
                  ref.read(speechProvider.notifier).setSpeechRate(value);
                },
              ),
            ],
          ),
        ),
        
        // TTS 音调
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('音调'),
                  Text(speechState.ttsPitch.toStringAsFixed(1)),
                ],
              ),
              Slider(
                value: speechState.ttsPitch,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                label: speechState.ttsPitch.toStringAsFixed(1),
                onChanged: (value) {
                  ref.read(speechProvider.notifier).setPitch(value);
                },
              ),
            ],
          ),
        ),
        
        // TTS 音量
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('音量'),
                  Text('${(speechState.ttsVolume * 100).round()}%'),
                ],
              ),
              Slider(
                value: speechState.ttsVolume,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: '${(speechState.ttsVolume * 100).round()}%',
                onChanged: (value) {
                  ref.read(speechProvider.notifier).setVolume(value);
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 测试 TTS 按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: speechState.ttsStatus == TtsStatus.playing
                  ? () => ref.read(speechProvider.notifier).stopSpeaking()
                  : () => ref.read(speechProvider.notifier).speak('你好，我是 Moss 智能管家，很高兴为您服务。'),
              icon: Icon(
                speechState.ttsStatus == TtsStatus.playing
                    ? Icons.stop
                    : Icons.play_arrow,
              ),
              label: Text(
                speechState.ttsStatus == TtsStatus.playing
                    ? '停止'
                    : '测试语音',
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  IconData _getSpeechStatusIcon(SpeechStatus status) {
    switch (status) {
      case SpeechStatus.uninitialized:
        return Icons.mic_off;
      case SpeechStatus.ready:
        return Icons.mic;
      case SpeechStatus.listening:
        return Icons.mic;
      case SpeechStatus.processing:
        return Icons.hourglass_empty;
      case SpeechStatus.error:
        return Icons.error;
      case SpeechStatus.unavailable:
        return Icons.mic_off;
    }
  }

  Color _getSpeechStatusColor(SpeechStatus status, ThemeData theme) {
    switch (status) {
      case SpeechStatus.uninitialized:
        return Colors.grey;
      case SpeechStatus.ready:
        return Colors.green;
      case SpeechStatus.listening:
        return theme.colorScheme.primary;
      case SpeechStatus.processing:
        return theme.colorScheme.secondary;
      case SpeechStatus.error:
        return theme.colorScheme.error;
      case SpeechStatus.unavailable:
        return Colors.grey;
    }
  }

  String _getSpeechStatusText(SpeechStatus status) {
    switch (status) {
      case SpeechStatus.uninitialized:
        return '未初始化';
      case SpeechStatus.ready:
        return '就绪';
      case SpeechStatus.listening:
        return '正在听取...';
      case SpeechStatus.processing:
        return '处理中...';
      case SpeechStatus.error:
        return '错误';
      case SpeechStatus.unavailable:
        return '不可用';
    }
  }

  IconData _getTtsStatusIcon(TtsStatus status) {
    switch (status) {
      case TtsStatus.uninitialized:
        return Icons.volume_off;
      case TtsStatus.ready:
        return Icons.volume_up;
      case TtsStatus.playing:
        return Icons.volume_up;
      case TtsStatus.paused:
        return Icons.pause;
      case TtsStatus.error:
        return Icons.error;
    }
  }

  Color _getTtsStatusColor(TtsStatus status, ThemeData theme) {
    switch (status) {
      case TtsStatus.uninitialized:
        return Colors.grey;
      case TtsStatus.ready:
        return Colors.green;
      case TtsStatus.playing:
        return theme.colorScheme.primary;
      case TtsStatus.paused:
        return theme.colorScheme.secondary;
      case TtsStatus.error:
        return theme.colorScheme.error;
    }
  }

  String _getTtsStatusText(TtsStatus status) {
    switch (status) {
      case TtsStatus.uninitialized:
        return '未初始化';
      case TtsStatus.ready:
        return '就绪';
      case TtsStatus.playing:
        return '播放中...';
      case TtsStatus.paused:
        return '已暂停';
      case TtsStatus.error:
        return '错误';
    }
  }

  Future<void> _saveServerUrl() async {
    final url = _serverUrlController.text.trim();
    final storage = ref.read(localStorageProvider);
    await storage.setServerUrl(url);
    
    final apiClient = ref.read(apiClientProvider);
    await apiClient.setServerUrl(url);
    
    // 初始化后端路由器
    if (url.isNotEmpty) {
      ref.read(llmRouterProvider.notifier).initBackendRouter(apiClient);
    }
    
    // 更新 WebSocket 服务
    final wsService = ref.read(webSocketServiceProvider);
    wsService.setServerUrl(url);
    
    setState(() {
      _connectionTestResult = null;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('服务器地址已保存')),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final result = await apiClient.testConnection();
      
      if (mounted) {
        setState(() {
          _connectionTestResult = result;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Future<void> _setUseBackendLLM(bool value) async {
    final storage = ref.read(localStorageProvider);
    await storage.setUseBackendLLM(value);
    ref.read(llmRouterProvider.notifier).setUseBackendLLM(value);
    
    setState(() {
      _useBackendLLM = value;
    });
  }

  Future<void> _performSync() async {
    final result = await ref.read(syncServiceProvider.notifier).sync();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? '同步完成: ${result.schedulesUpdated} 个日程, ${result.tasksUpdated} 个任务'
                : '同步失败: ${result.error}',
          ),
        ),
      );
    }
  }

  IconData _getSyncIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Icons.sync;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.success:
        return Icons.check_circle;
      case SyncStatus.error:
        return Icons.error;
    }
  }

  Color _getSyncColor(SyncStatus status, ThemeData theme) {
    switch (status) {
      case SyncStatus.idle:
        return theme.iconTheme.color ?? Colors.grey;
      case SyncStatus.syncing:
        return theme.colorScheme.primary;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.error:
        return theme.colorScheme.error;
    }
  }

  String _getSyncStatusText(SyncServiceState state) {
    switch (state.status) {
      case SyncStatus.idle:
        if (state.lastSyncTime != null) {
          return '上次同步: ${_formatDateTime(state.lastSyncTime!)}';
        }
        return '未同步';
      case SyncStatus.syncing:
        return '正在同步...';
      case SyncStatus.success:
        return '同步成功';
      case SyncStatus.error:
        return '同步失败: ${state.error}';
    }
  }

  IconData _getWSIcon(WSConnectionState state) {
    switch (state) {
      case WSConnectionState.disconnected:
        return Icons.cloud_off;
      case WSConnectionState.connecting:
      case WSConnectionState.reconnecting:
        return Icons.cloud_sync;
      case WSConnectionState.connected:
        return Icons.cloud_done;
      case WSConnectionState.error:
        return Icons.cloud_off;
    }
  }

  Color _getWSColor(WSConnectionState state, ThemeData theme) {
    switch (state) {
      case WSConnectionState.disconnected:
        return Colors.grey;
      case WSConnectionState.connecting:
      case WSConnectionState.reconnecting:
        return theme.colorScheme.primary;
      case WSConnectionState.connected:
        return Colors.green;
      case WSConnectionState.error:
        return theme.colorScheme.error;
    }
  }

  String _getWSStatusText(WSConnectionState state) {
    switch (state) {
      case WSConnectionState.disconnected:
        return '未连接';
      case WSConnectionState.connecting:
        return '正在连接...';
      case WSConnectionState.reconnecting:
        return '正在重连...';
      case WSConnectionState.connected:
        return '已连接';
      case WSConnectionState.error:
        return '连接错误';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} 分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} 小时前';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
