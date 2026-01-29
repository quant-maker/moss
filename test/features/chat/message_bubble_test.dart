import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moss/core/llm/models/message.dart';
import 'package:moss/core/services/speech_service.dart';
import 'package:moss/features/chat/widgets/message_bubble.dart';

void main() {
  group('MessageBubble Widget', () {
    Widget createTestWidget(Widget child) {
      return ProviderScope(
        overrides: [
          speechProvider.overrideWith((ref) => MockSpeechNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: child,
            ),
          ),
        ),
      );
    }

    group('User Message', () {
      testWidgets('should display user message content', (tester) async {
        await tester.pumpWidget(createTestWidget(
          const MessageBubble(
            content: 'Hello, this is a test message',
            isUser: true,
          ),
        ));

        expect(find.text('Hello, this is a test message'), findsOneWidget);
      });

      testWidgets('should display user avatar', (tester) async {
        await tester.pumpWidget(createTestWidget(
          const MessageBubble(
            content: 'Test',
            isUser: true,
          ),
        ));

        expect(find.byIcon(Icons.person), findsOneWidget);
      });

      testWidgets('should align to the right', (tester) async {
        await tester.pumpWidget(createTestWidget(
          const MessageBubble(
            content: 'User message',
            isUser: true,
          ),
        ));

        final row = tester.widget<Row>(find.byType(Row).first);
        expect(row.mainAxisAlignment, MainAxisAlignment.end);
      });
    });

    group('Assistant Message', () {
      testWidgets('should display assistant message content', (tester) async {
        await tester.pumpWidget(createTestWidget(
          const MessageBubble(
            content: 'This is an AI response',
            isUser: false,
          ),
        ));

        expect(find.text('This is an AI response'), findsOneWidget);
      });

      testWidgets('should display AI avatar', (tester) async {
        await tester.pumpWidget(createTestWidget(
          const MessageBubble(
            content: 'AI message',
            isUser: false,
          ),
        ));

        expect(find.byIcon(Icons.smart_toy), findsOneWidget);
      });

      testWidgets('should align to the left', (tester) async {
        await tester.pumpWidget(createTestWidget(
          const MessageBubble(
            content: 'AI message',
            isUser: false,
          ),
        ));

        final row = tester.widget<Row>(find.byType(Row).first);
        expect(row.mainAxisAlignment, MainAxisAlignment.start);
      });

      testWidgets('should show action buttons for non-streaming AI message',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          const MessageBubble(
            content: 'AI message with buttons',
            isUser: false,
            isStreaming: false,
          ),
        ));

        await tester.pumpAndSettle();

        // Should show copy and volume buttons
        expect(find.byIcon(Icons.copy), findsOneWidget);
        expect(find.byIcon(Icons.volume_up), findsOneWidget);
      });

      testWidgets('should not show action buttons when streaming',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          const MessageBubble(
            content: 'Streaming...',
            isUser: false,
            isStreaming: true,
          ),
        ));

        // Should show loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Should not show action buttons
        expect(find.byIcon(Icons.copy), findsNothing);
      });
    });

    group('Streaming State', () {
      testWidgets('should show loading indicator when streaming',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          const MessageBubble(
            content: 'Loading content...',
            isUser: false,
            isStreaming: true,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should not show loading indicator when not streaming',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          const MessageBubble(
            content: 'Complete content',
            isUser: false,
            isStreaming: false,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('Tool Calls', () {
      testWidgets('should display tool calls', (tester) async {
        await tester.pumpWidget(createTestWidget(
          MessageBubble(
            content: '',
            isUser: false,
            toolCalls: [
              ToolCall(
                id: 'call_1',
                name: 'open_app',
                arguments: {'app_name': 'wechat'},
              ),
            ],
          ),
        ));

        expect(find.text('正在执行操作...'), findsOneWidget);
        expect(find.byIcon(Icons.build), findsOneWidget);
      });

      testWidgets('should display multiple tool calls', (tester) async {
        await tester.pumpWidget(createTestWidget(
          MessageBubble(
            content: '',
            isUser: false,
            toolCalls: [
              ToolCall(
                id: 'call_1',
                name: 'search',
                arguments: {'query': 'weather'},
              ),
              ToolCall(
                id: 'call_2',
                name: 'play_music',
                arguments: {'song': 'test'},
              ),
            ],
          ),
        ));

        expect(find.textContaining('search'), findsOneWidget);
        expect(find.textContaining('play_music'), findsOneWidget);
      });
    });

    group('Empty Content', () {
      testWidgets('should handle empty content gracefully', (tester) async {
        await tester.pumpWidget(createTestWidget(
          const MessageBubble(
            content: '',
            isUser: false,
          ),
        ));

        // Should not throw and should still render
        expect(find.byType(MessageBubble), findsOneWidget);
      });
    });

    group('Regenerate Callback', () {
      testWidgets('should show regenerate button when callback provided',
          (tester) async {
        bool regenerateCalled = false;

        await tester.pumpWidget(createTestWidget(
          MessageBubble(
            content: 'AI response',
            isUser: false,
            onRegenerate: () {
              regenerateCalled = true;
            },
          ),
        ));

        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.refresh), findsOneWidget);

        await tester.tap(find.byIcon(Icons.refresh));
        expect(regenerateCalled, true);
      });

      testWidgets('should not show regenerate button when no callback',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          const MessageBubble(
            content: 'AI response',
            isUser: false,
            onRegenerate: null,
          ),
        ));

        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.refresh), findsNothing);
      });
    });
  });
}

/// Mock Speech Notifier for testing
class MockSpeechNotifier extends StateNotifier<SpeechServiceState>
    implements SpeechServiceNotifier {
  MockSpeechNotifier()
      : super(SpeechServiceState(
          speechStatus: SpeechStatus.notListening,
          ttsStatus: TtsStatus.idle,
        ));

  @override
  Future<void> initialize() async {}

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stopSpeaking() async {}

  @override
  void setAutoSpeak(bool enabled) {}

  @override
  void setSpeechRate(double rate) {}

  @override
  void setPitch(double pitch) {}

  @override
  void setVolume(double volume) {}

  @override
  void clearRecognizedText() {}
}
