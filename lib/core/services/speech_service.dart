import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../storage/local_storage.dart';

/// 语音识别状态
enum SpeechStatus {
  /// 未初始化
  uninitialized,
  /// 就绪
  ready,
  /// 正在听取
  listening,
  /// 处理中
  processing,
  /// 错误
  error,
  /// 不可用
  unavailable,
}

/// TTS 状态
enum TtsStatus {
  /// 未初始化
  uninitialized,
  /// 就绪
  ready,
  /// 播放中
  playing,
  /// 暂停
  paused,
  /// 错误
  error,
}

/// 语音服务
class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  SpeechStatus _speechStatus = SpeechStatus.uninitialized;
  TtsStatus _ttsStatus = TtsStatus.uninitialized;
  
  String _lastWords = '';
  String _lastError = '';
  double _soundLevel = 0.0;
  
  // TTS 设置
  double _ttsVolume = 1.0;
  double _ttsPitch = 1.0;
  double _ttsRate = 0.5;
  String _ttsLanguage = 'zh-CN';
  String? _ttsVoice;
  
  // 回调
  Function(String)? onResult;
  Function(String)? onPartialResult;
  Function(SpeechStatus)? onStatusChange;
  Function(double)? onSoundLevel;
  Function(TtsStatus)? onTtsStatusChange;
  
  /// 语音识别状态
  SpeechStatus get speechStatus => _speechStatus;
  
  /// TTS 状态
  TtsStatus get ttsStatus => _ttsStatus;
  
  /// 最后识别的文字
  String get lastWords => _lastWords;
  
  /// 最后错误
  String get lastError => _lastError;
  
  /// 当前音量
  double get soundLevel => _soundLevel;
  
  /// 是否正在听取
  bool get isListening => _speechStatus == SpeechStatus.listening;
  
  /// 是否正在播放
  bool get isPlaying => _ttsStatus == TtsStatus.playing;

  /// 初始化语音服务
  Future<bool> initialize() async {
    // 初始化语音识别
    final speechAvailable = await _initSpeechToText();
    
    // 初始化 TTS
    await _initTts();
    
    return speechAvailable;
  }
  
  /// 初始化语音识别
  Future<bool> _initSpeechToText() async {
    try {
      // 检查麦克风权限
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _speechStatus = SpeechStatus.unavailable;
        _lastError = '麦克风权限被拒绝';
        return false;
      }
      
      final available = await _speechToText.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
        debugLogging: kDebugMode,
      );
      
      if (available) {
        _speechStatus = SpeechStatus.ready;
        debugPrint('SpeechService: 语音识别初始化成功');
      } else {
        _speechStatus = SpeechStatus.unavailable;
        _lastError = '语音识别不可用';
        debugPrint('SpeechService: 语音识别不可用');
      }
      
      return available;
    } catch (e) {
      _speechStatus = SpeechStatus.error;
      _lastError = e.toString();
      debugPrint('SpeechService: 初始化失败 - $e');
      return false;
    }
  }
  
  /// 初始化 TTS
  Future<void> _initTts() async {
    try {
      // 设置回调
      _flutterTts.setStartHandler(() {
        _ttsStatus = TtsStatus.playing;
        onTtsStatusChange?.call(_ttsStatus);
      });
      
      _flutterTts.setCompletionHandler(() {
        _ttsStatus = TtsStatus.ready;
        onTtsStatusChange?.call(_ttsStatus);
      });
      
      _flutterTts.setCancelHandler(() {
        _ttsStatus = TtsStatus.ready;
        onTtsStatusChange?.call(_ttsStatus);
      });
      
      _flutterTts.setPauseHandler(() {
        _ttsStatus = TtsStatus.paused;
        onTtsStatusChange?.call(_ttsStatus);
      });
      
      _flutterTts.setContinueHandler(() {
        _ttsStatus = TtsStatus.playing;
        onTtsStatusChange?.call(_ttsStatus);
      });
      
      _flutterTts.setErrorHandler((msg) {
        _ttsStatus = TtsStatus.error;
        _lastError = msg;
        onTtsStatusChange?.call(_ttsStatus);
      });
      
      // 设置语言
      await _flutterTts.setLanguage(_ttsLanguage);
      await _flutterTts.setVolume(_ttsVolume);
      await _flutterTts.setPitch(_ttsPitch);
      await _flutterTts.setSpeechRate(_ttsRate);
      
      // 获取可用语音
      final voices = await _flutterTts.getVoices as List<dynamic>?;
      if (voices != null && voices.isNotEmpty) {
        // 尝试找到中文语音
        for (final voice in voices) {
          final voiceMap = voice as Map<Object?, Object?>;
          final locale = voiceMap['locale'] as String?;
          if (locale != null && locale.startsWith('zh')) {
            _ttsVoice = voiceMap['name'] as String?;
            if (_ttsVoice != null) {
              await _flutterTts.setVoice({'name': _ttsVoice!, 'locale': locale});
              break;
            }
          }
        }
      }
      
      _ttsStatus = TtsStatus.ready;
      debugPrint('SpeechService: TTS 初始化成功');
    } catch (e) {
      _ttsStatus = TtsStatus.error;
      _lastError = e.toString();
      debugPrint('SpeechService: TTS 初始化失败 - $e');
    }
  }
  
  /// 开始语音识别
  Future<void> startListening({
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
  }) async {
    if (_speechStatus == SpeechStatus.uninitialized ||
        _speechStatus == SpeechStatus.unavailable) {
      debugPrint('SpeechService: 语音识别未就绪');
      return;
    }
    
    // 如果 TTS 正在播放，先停止
    if (_ttsStatus == TtsStatus.playing) {
      await stopSpeaking();
    }
    
    _lastWords = '';
    _updateSpeechStatus(SpeechStatus.listening);
    
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: listenFor ?? const Duration(seconds: 30),
      pauseFor: pauseFor ?? const Duration(seconds: 3),
      localeId: localeId ?? 'zh_CN',
      onSoundLevelChange: _onSoundLevelChange,
      cancelOnError: true,
      partialResults: true,
      listenMode: ListenMode.confirmation,
    );
  }
  
  /// 停止语音识别
  Future<void> stopListening() async {
    await _speechToText.stop();
    _updateSpeechStatus(SpeechStatus.ready);
  }
  
  /// 取消语音识别
  Future<void> cancelListening() async {
    await _speechToText.cancel();
    _lastWords = '';
    _updateSpeechStatus(SpeechStatus.ready);
  }
  
  /// 语音识别结果回调
  void _onSpeechResult(SpeechRecognitionResult result) {
    _lastWords = result.recognizedWords;
    
    if (result.finalResult) {
      _updateSpeechStatus(SpeechStatus.processing);
      onResult?.call(_lastWords);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_speechStatus == SpeechStatus.processing) {
          _updateSpeechStatus(SpeechStatus.ready);
        }
      });
    } else {
      onPartialResult?.call(_lastWords);
    }
  }
  
  /// 语音识别错误回调
  void _onSpeechError(SpeechRecognitionError error) {
    _lastError = error.errorMsg;
    _updateSpeechStatus(SpeechStatus.error);
    debugPrint('SpeechService: 识别错误 - ${error.errorMsg}');
    
    // 短暂延迟后恢复就绪状态
    Future.delayed(const Duration(seconds: 2), () {
      if (_speechStatus == SpeechStatus.error) {
        _updateSpeechStatus(SpeechStatus.ready);
      }
    });
  }
  
  /// 语音识别状态回调
  void _onSpeechStatus(String status) {
    debugPrint('SpeechService: 状态变化 - $status');
    if (status == 'done' && _speechStatus == SpeechStatus.listening) {
      _updateSpeechStatus(SpeechStatus.ready);
    }
  }
  
  /// 音量变化回调
  void _onSoundLevelChange(double level) {
    _soundLevel = level;
    onSoundLevel?.call(level);
  }
  
  /// 更新语音状态
  void _updateSpeechStatus(SpeechStatus status) {
    _speechStatus = status;
    onStatusChange?.call(status);
  }
  
  /// 朗读文本
  Future<void> speak(String text) async {
    if (_ttsStatus == TtsStatus.uninitialized ||
        _ttsStatus == TtsStatus.error) {
      debugPrint('SpeechService: TTS 未就绪');
      return;
    }
    
    // 如果正在听取，先停止
    if (_speechStatus == SpeechStatus.listening) {
      await stopListening();
    }
    
    await _flutterTts.speak(text);
  }
  
  /// 停止朗读
  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }
  
  /// 暂停朗读
  Future<void> pauseSpeaking() async {
    await _flutterTts.pause();
  }
  
  /// 设置 TTS 音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    _ttsVolume = volume.clamp(0.0, 1.0);
    await _flutterTts.setVolume(_ttsVolume);
  }
  
  /// 设置 TTS 语速 (0.0 - 1.0)
  Future<void> setSpeechRate(double rate) async {
    _ttsRate = rate.clamp(0.0, 1.0);
    await _flutterTts.setSpeechRate(_ttsRate);
  }
  
  /// 设置 TTS 音调 (0.5 - 2.0)
  Future<void> setPitch(double pitch) async {
    _ttsPitch = pitch.clamp(0.5, 2.0);
    await _flutterTts.setPitch(_ttsPitch);
  }
  
  /// 设置语言
  Future<void> setLanguage(String language) async {
    _ttsLanguage = language;
    await _flutterTts.setLanguage(language);
  }
  
  /// 获取可用语言列表
  Future<List<String>> getAvailableLanguages() async {
    final languages = await _flutterTts.getLanguages as List<dynamic>?;
    return languages?.map((e) => e.toString()).toList() ?? [];
  }
  
  /// 获取可用语音列表
  Future<List<Map<String, String>>> getAvailableVoices() async {
    final voices = await _flutterTts.getVoices as List<dynamic>?;
    if (voices == null) return [];
    
    return voices.map((v) {
      final voice = v as Map<Object?, Object?>;
      return {
        'name': voice['name']?.toString() ?? '',
        'locale': voice['locale']?.toString() ?? '',
      };
    }).toList();
  }
  
  /// TTS 设置
  double get ttsVolume => _ttsVolume;
  double get ttsRate => _ttsRate;
  double get ttsPitch => _ttsPitch;
  String get ttsLanguage => _ttsLanguage;
  
  /// 释放资源
  Future<void> dispose() async {
    await _speechToText.cancel();
    await _flutterTts.stop();
  }
}

/// 语音服务状态
class SpeechServiceState {
  final SpeechStatus speechStatus;
  final TtsStatus ttsStatus;
  final String recognizedText;
  final String partialText;
  final double soundLevel;
  final String? error;
  
  // TTS 设置
  final double ttsVolume;
  final double ttsRate;
  final double ttsPitch;
  final bool autoSpeak;

  SpeechServiceState({
    this.speechStatus = SpeechStatus.uninitialized,
    this.ttsStatus = TtsStatus.uninitialized,
    this.recognizedText = '',
    this.partialText = '',
    this.soundLevel = 0.0,
    this.error,
    this.ttsVolume = 1.0,
    this.ttsRate = 0.5,
    this.ttsPitch = 1.0,
    this.autoSpeak = false,
  });

  SpeechServiceState copyWith({
    SpeechStatus? speechStatus,
    TtsStatus? ttsStatus,
    String? recognizedText,
    String? partialText,
    double? soundLevel,
    String? error,
    double? ttsVolume,
    double? ttsRate,
    double? ttsPitch,
    bool? autoSpeak,
  }) {
    return SpeechServiceState(
      speechStatus: speechStatus ?? this.speechStatus,
      ttsStatus: ttsStatus ?? this.ttsStatus,
      recognizedText: recognizedText ?? this.recognizedText,
      partialText: partialText ?? this.partialText,
      soundLevel: soundLevel ?? this.soundLevel,
      error: error,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      autoSpeak: autoSpeak ?? this.autoSpeak,
    );
  }
  
  bool get isListening => speechStatus == SpeechStatus.listening;
  bool get isPlaying => ttsStatus == TtsStatus.playing;
  bool get isReady => speechStatus == SpeechStatus.ready;
}

/// 语音服务 Notifier
class SpeechServiceNotifier extends StateNotifier<SpeechServiceState> {
  final SpeechService _service;
  final LocalStorage? _storage;

  SpeechServiceNotifier(this._service, [this._storage]) 
      : super(SpeechServiceState()) {
    _init();
  }

  Future<void> _init() async {
    // 加载设置
    if (_storage != null) {
      await _loadSettings();
    }
    
    // 设置回调
    _service.onStatusChange = (status) {
      state = state.copyWith(speechStatus: status);
    };
    
    _service.onTtsStatusChange = (status) {
      state = state.copyWith(ttsStatus: status);
    };
    
    _service.onResult = (text) {
      state = state.copyWith(recognizedText: text, partialText: '');
    };
    
    _service.onPartialResult = (text) {
      state = state.copyWith(partialText: text);
    };
    
    _service.onSoundLevel = (level) {
      state = state.copyWith(soundLevel: level);
    };
    
    // 初始化服务
    await _service.initialize();
    
    state = state.copyWith(
      speechStatus: _service.speechStatus,
      ttsStatus: _service.ttsStatus,
    );
  }

  Future<void> _loadSettings() async {
    // TODO: 从 LocalStorage 加载 TTS 设置
  }

  /// 开始语音识别
  Future<void> startListening() async {
    state = state.copyWith(recognizedText: '', partialText: '');
    await _service.startListening();
  }

  /// 停止语音识别
  Future<void> stopListening() async {
    await _service.stopListening();
  }

  /// 取消语音识别
  Future<void> cancelListening() async {
    await _service.cancelListening();
    state = state.copyWith(recognizedText: '', partialText: '');
  }

  /// 朗读文本
  Future<void> speak(String text) async {
    await _service.speak(text);
  }

  /// 停止朗读
  Future<void> stopSpeaking() async {
    await _service.stopSpeaking();
  }

  /// 设置自动朗读
  void setAutoSpeak(bool value) {
    state = state.copyWith(autoSpeak: value);
  }

  /// 设置 TTS 音量
  Future<void> setVolume(double volume) async {
    await _service.setVolume(volume);
    state = state.copyWith(ttsVolume: volume);
  }

  /// 设置 TTS 语速
  Future<void> setSpeechRate(double rate) async {
    await _service.setSpeechRate(rate);
    state = state.copyWith(ttsRate: rate);
  }

  /// 设置 TTS 音调
  Future<void> setPitch(double pitch) async {
    await _service.setPitch(pitch);
    state = state.copyWith(ttsPitch: pitch);
  }

  /// 清空识别结果
  void clearRecognizedText() {
    state = state.copyWith(recognizedText: '', partialText: '');
  }
  
  /// 获取识别结果
  String get recognizedText => state.recognizedText;
  
  /// 是否正在听取
  bool get isListening => state.isListening;
  
  /// 是否正在播放
  bool get isPlaying => state.isPlaying;
  
  /// 是否自动朗读
  bool get autoSpeak => state.autoSpeak;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

/// 语音服务实例
final speechServiceProvider = Provider<SpeechService>((ref) {
  return SpeechService();
});

/// 语音服务状态 Provider
final speechProvider = StateNotifierProvider<SpeechServiceNotifier, SpeechServiceState>((ref) {
  final service = ref.watch(speechServiceProvider);
  final storage = ref.watch(localStorageProvider);
  return SpeechServiceNotifier(service, storage);
});
