import 'dart:async';
import 'dart:io';

import 'package:expense_app/features/ai/domain/gemma_assistant_engine.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GemmaModelStatus { notDownloaded, downloading, ready, error }

class ModelReleaseCoordinator {
  int _activeOperations = 0;
  bool _releaseRequested = false;
  Completer<void>? _pendingRelease;

  void beginOperation() {
    _activeOperations++;
  }

  Future<void> requestRelease(Future<void> Function() release) async {
    if (_activeOperations == 0) {
      await release();
      return;
    }
    _releaseRequested = true;
    return (_pendingRelease ??= Completer<void>()).future;
  }

  Future<void> finishOperation(Future<void> Function() release) async {
    if (_activeOperations == 0) return;
    _activeOperations--;
    if (_activeOperations != 0 || !_releaseRequested) return;

    final pending = _pendingRelease;
    _pendingRelease = null;
    _releaseRequested = false;
    try {
      await release();
      if (pending != null && !pending.isCompleted) pending.complete();
    } catch (error, stackTrace) {
      if (pending != null && !pending.isCompleted) {
        pending.completeError(error, stackTrace);
      }
      rethrow;
    }
  }
}

class GemmaModelState {
  const GemmaModelState({
    this.status = GemmaModelStatus.notDownloaded,
    this.progress = 0,
    this.error,
    this.cancelled = false,
  });

  final GemmaModelStatus status;
  final double progress;
  final String? error;
  final bool cancelled;

  GemmaModelState copyWith({
    GemmaModelStatus? status,
    double? progress,
    String? error,
    bool clearError = false,
    bool? cancelled,
  }) {
    return GemmaModelState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: clearError ? null : error ?? this.error,
      cancelled: cancelled ?? this.cancelled,
    );
  }
}

class GemmaModelManager extends Notifier<GemmaModelState>
    implements GemmaTurnGenerator {
  static const modelFileName = 'gemma-4-E2B-it.litertlm';
  static const expectedSize = 2588147712;
  static const modelRevision =
      '6e5c4f1e395deb959c494953478fa5cec4b8008f';
  static const modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/$modelRevision/$modelFileName';
  static const systemInstruction = '''
أنت مساعد مالي داخل تطبيق شخصي.
لا تخترع مبلغاً أو قسماً أو تاريخاً أو اسماً ناقصاً.
إذا نقصت معلومة لازمة، استدعِ ask_clarification بسؤال عربي قصير.
لا تحسب أي رصيد أو مجموع ولا تعرض أي رقم مالي من عندك؛ التطبيق وحده يقرأ قاعدة البيانات ويحسب النتائج.
لا تطلب ولا تتلقَّ بيانات مالية من قاعدة البيانات.
استخدم فقط الدوال المعروضة. لا تنفذ أي عملية بنفسك.
أخرج استدعاء دالة واحداً فقط أو سؤالاً قصيراً. لا تكتب شرحاً أو مقدمة.
''';

  CancelToken? _cancelToken;
  InferenceModel? _model;
  Timer? _idleTimer;
  final ModelReleaseCoordinator _releaseCoordinator = ModelReleaseCoordinator();

  @override
  GemmaModelState build() {
    unawaited(refresh());
    ref.onDispose(() {
      _idleTimer?.cancel();
      unawaited(releaseModel());
    });
    return const GemmaModelState();
  }

  Future<void> refresh() async {
    try {
      final installed = await FlutterEdgeAi.isModelInstalled(modelFileName);
      if (!installed) {
        state = const GemmaModelState();
        return;
      }
      final path = await FlutterEdgeAi.getModelPath(modelFileName);
      final length = await File(path).length();
      if (length != expectedSize) {
        state = const GemmaModelState(
          status: GemmaModelStatus.error,
          error: 'حجم ملف النموذج غير مطابق؛ احتفظ التطبيق بالملف ولم يشغّله. يمكنك حذفه يدوياً بعد التأكد.',
        );
        return;
      }
      state = const GemmaModelState(status: GemmaModelStatus.ready, progress: 100);
    } catch (_) {
      state = const GemmaModelState(
        status: GemmaModelStatus.error,
        error: 'تعذر التحقق من ملف النموذج.',
      );
    }
  }

  Future<void> download() async {
    if (state.status == GemmaModelStatus.downloading) return;
    _cancelToken = CancelToken();
    state = const GemmaModelState(
      status: GemmaModelStatus.downloading,
      progress: 0,
    );
    try {
      await FlutterEdgeAi.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      )
          .fromNetwork(
            modelUrl,
            expectedSize: expectedSize,
            foreground: true,
          )
          .withCancelToken(_cancelToken!)
          .withProgress((progress) {
            state = state.copyWith(
              status: GemmaModelStatus.downloading,
              progress: progress.toDouble().clamp(0, 100).toDouble(),
            );
          })
          .install();

      final path = await FlutterEdgeAi.getModelPath(modelFileName);
      final length = await File(path).length();
      if (length != expectedSize) {
        await FlutterEdgeAi.uninstallModel(modelFileName);
        throw StateError('Downloaded model size does not match the pinned size.');
      }
      state = const GemmaModelState(
        status: GemmaModelStatus.ready,
        progress: 100,
      );
    } catch (error) {
      if (CancelToken.isCancel(error)) {
        state = const GemmaModelState(
          status: GemmaModelStatus.notDownloaded,
          cancelled: true,
        );
      } else {
        state = const GemmaModelState(
          status: GemmaModelStatus.error,
          error: 'فشل تنزيل النموذج أو التحقق منه. لم يتم تفعيله.',
        );
      }
    } finally {
      _cancelToken = null;
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel('User cancelled download');
  }

  Future<void> deleteModel() async {
    await releaseModel();
    try {
      await FlutterEdgeAi.uninstallModel(modelFileName);
      state = const GemmaModelState();
    } catch (_) {
      state = const GemmaModelState(
        status: GemmaModelStatus.error,
        error: 'تعذر حذف النموذج.',
      );
    }
  }

  Future<InferenceModel> _getModel() async {
    _idleTimer?.cancel();
    if (_model == null || _model!.isClosed) {
      _model = await FlutterEdgeAi.getActiveModel(
        // 512 tokens is too small for the system prompt plus the finance tool schemas.
        // Keep a bounded 2K window to avoid the repeated ContextLimitException
        // while limiting memory use on 8 GB Android devices.
        maxTokens: 2048,
        // Prefer CPU on memory-constrained phones: Android GPUs share system RAM.
        preferredBackend: PreferredBackend.cpu,
        maxConcurrentSessions: 1,
      );
    }
    return _model!;
  }

  @override
  Future<GemmaModelOutput> generate(
    String userText,
    List<GemmaFunctionSpec> functions,
  ) async {
    if (state.status != GemmaModelStatus.ready) {
      throw StateError('Gemma model is not ready');
    }

    _releaseCoordinator.beginOperation();
    try {
      final model = await _getModel();
      final tools = functions
          .map((function) => Tool(
                name: function.name,
                description: function.description,
                parameters: {
                  'type': 'object',
                  'properties': function.properties,
                  'required': function.required,
                },
              ))
          .toList(growable: false);

      InferenceChat? chat;
      try {
        chat = await model.openChat(
          systemInstruction: systemInstruction,
          tools: tools,
          supportsFunctionCalls: true,
          toolChoice: ToolChoice.auto,
          maxOutputTokens: 256,
          temperature: 0,
          topK: 1,
        );
        await chat.addQueryChunk(Message.text(text: userText, isUser: true));
        String? functionName;
        Map<String, Object?>? arguments;
        var hasMultipleCalls = false;
        final text = StringBuffer();

        await for (final response in chat.generateChatResponseAsync().timeout(
              const Duration(seconds: 25),
            )) {
          if (response is FunctionCallResponse) {
            if (functionName != null) {
              hasMultipleCalls = true;
            } else {
              functionName = response.name;
              arguments = Map<String, Object?>.from(response.args);
            }
          } else if (response is ParallelFunctionCallResponse) {
            hasMultipleCalls = true;
          } else if (response is TextResponse) {
            text.write(response.token);
          }
        }

        if (hasMultipleCalls) return const GemmaModelOutput.multiple();
        if (functionName != null && arguments != null) {
          return GemmaModelOutput.call(functionName, arguments);
        }
        return GemmaModelOutput.text(text.toString());
      } finally {
        if (chat != null) await chat.close();
        _scheduleIdleRelease();
      }
    } catch (error) {
      if (error is ContextLimitException) {
        // The SDK rolls back the refused turn. This is an input/context-size
        // problem, not a failed model load; keep Gemma available for retry.
        state = GemmaModelState(
          status: GemmaModelStatus.ready,
          progress: 100,
          error: 'الطلب أطول من مساحة السياق المتاحة. اختصر الطلب وأعد المحاولة؛ النموذج ما زال جاهزاً.',
        );
      } else {
        state = GemmaModelState(
          status: GemmaModelStatus.error,
          error: 'تعذر تشغيل Gemma (${error.runtimeType}). تم الاحتفاظ بالنموذج؛ أغلق التطبيقات الأخرى وأعد المحاولة.',
        );
        try {
          unawaited(releaseModel());
        } catch (_) {
          // Preserve the inference error and let the app use its fallback.
        }
      }
      rethrow;
    } finally {
      await _releaseCoordinator.finishOperation(_closeModel);
    }
  }

  void _scheduleIdleRelease() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(minutes: 2), () {
      unawaited(releaseModel());
    });
  }

  Future<void> releaseModel() async {
    _idleTimer?.cancel();
    await _releaseCoordinator.requestRelease(_closeModel);
  }

  Future<void> _closeModel() async {
    final model = _model;
    _model = null;
    if (model != null && !model.isClosed) {
      await model.close();
    }
  }
}

final gemmaModelManagerProvider =
    NotifierProvider<GemmaModelManager, GemmaModelState>(
  GemmaModelManager.new,
);
