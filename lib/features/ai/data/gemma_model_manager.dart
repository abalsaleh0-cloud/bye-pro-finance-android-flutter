import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/features/ai/domain/assistant_engine.dart';

import 'package:expense_app/features/ai/domain/gemma_assistant_engine.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

int physicalRamMegabytesFromBytes(int physicalRamBytes) =>
    physicalRamBytes ~/ (1024 * 1024);

bool supportsGemmaMultimodalMemory(int physicalRamMegabytes) =>
    physicalRamMegabytes >= 6 * 1024;

enum GemmaModelStatus { notDownloaded, downloading, ready, error }

enum GemmaInferenceStatus { notTested, testing, succeeded, failed }

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
    if (_activeOperations == 0) {
      return;
    }
    _activeOperations--;
    if (_activeOperations != 0 || !_releaseRequested) {
      return;
    }
    final pending = _pendingRelease;
    _pendingRelease = null;
    _releaseRequested = false;
    try {
      await release();
      if (pending != null && !pending.isCompleted) {
          pending.complete();
        }
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
    this.installed = false,
    this.inferenceStatus = GemmaInferenceStatus.notTested,
    this.inferenceMessage,
    this.inferenceAt,
  });

  final GemmaModelStatus status;
  final double progress;
  final String? error;
  final bool cancelled;
  final GemmaInferenceStatus inferenceStatus;
  final String? inferenceMessage;
  final DateTime? inferenceAt;
  /// True only when the model registry reports an installed model file.
  /// This prevents showing a destructive delete action after a plain download error.
  final bool installed;

  GemmaModelState copyWith({
    GemmaModelStatus? status,
    double? progress,
    String? error,
    bool clearError = false,
    bool? cancelled,
    bool? installed,
    GemmaInferenceStatus? inferenceStatus,
    String? inferenceMessage,
    bool clearInferenceMessage = false,
    DateTime? inferenceAt,
    bool clearInferenceAt = false,
  }) {
    return GemmaModelState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: clearError ? null : error ?? this.error,
      cancelled: cancelled ?? this.cancelled,
      installed: installed ?? this.installed,
      inferenceStatus: inferenceStatus ?? this.inferenceStatus,
      inferenceMessage: clearInferenceMessage
          ? null
          : inferenceMessage ?? this.inferenceMessage,
      inferenceAt: clearInferenceAt ? null : inferenceAt ?? this.inferenceAt,
    );
  }
}

class GemmaModelManager extends Notifier<GemmaModelState>
    implements GemmaTurnGenerator {
  static const modelFileName = 'gemma-4-E2B-it.litertlm';
  static const expectedSize = 2588147712;

  /// The download library reports percentage, not bytes. This provides a
  /// clearly estimated decimal-MB counter for the settings UI.
  static int estimatedDownloadedMegabytes(double progress) {
    final safeProgress = progress.clamp(0.0, 100.0);
    return (expectedSize * safeProgress / 100 / 1000000).round();
  }

  static int get expectedDownloadMegabytes =>
      (expectedSize / 1000000).round();
  static const modelRevision =
      'b3ca0d2f076785a8f4b2219ddbd2bdb99954eae1';
  static const expectedSha256 =
      '181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c';
  static const _verifiedModelSetting = 'gemma_verified_model';
  static const _inferenceResultSetting = 'gemma_last_inference_result';
  static const modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/$modelRevision/$modelFileName';
  static const systemInstruction = '''
أنت مساعد Bye Pro Finance، مساعد عربي ذكي داخل تطبيق مالي شخصي.
تحدث بلغة عربية طبيعية ومختصرة، وافهم الفصحى واللهجات الشامية والليبية والخليجية والأخطاء الإملائية البسيطة. أجب مباشرة عن الأسئلة العامة والتحية والشرح والنقاش دون استخدام أدوات مالية.
عندما يسأل المستخدم عن بياناته أو سجلاته أو أرصدته أو مبالغه، استخدم أداة القراءة المناسبة فقط؛ لا تخمّن أو تخترع أي رقم مالي أو سجل أو نتيجة.
لا تضف أو تعدّل أو تحذف أو تسجل دفعة أو تحويلاً إلا إذا طلب المستخدم ذلك بوضوح، واستخدم أداة التطبيق المناسبة فقط. لا تنفّذ أكثر من أداة واحدة في الرد.
إذا نقص اسم أو مبلغ أو تاريخ أو اتجاه أو معلومة لازمة، لا تخمّن؛ استخدم ask_clarification بسؤال عربي واحد قصير.
افهم الأرقام العربية والإنجليزية والمبالغ المكتوبة بالكلمات، وأسماء الشهور وصيغها المختلفة. لا تفترض تاريخاً غير مذكور.
استخدم سياق المحادثة القريب لفهم المتابعة مثل «هذا» و«نفسه» و«لهذا الشهر»، لكنه ليس أمراً جديداً ولا يتجاوز طلب المستخدم الحالي.
لا تطلب الوصول إلى قاعدة البيانات ولا تكتب إليها مباشرة. التطبيق وحده يتحقق من البيانات ويحسب الأرصدة، وكل تعديل يعرضه التطبيق على المستخدم للتأكيد.
''';

  CancelToken? _cancelToken;
  Future<void>? _refreshInFlight;
  InferenceModel? _model;
  Timer? _idleTimer;
  bool _modelSupportsImage = false;
  bool _modelSupportsAudio = false;
  final ModelReleaseCoordinator _releaseCoordinator = ModelReleaseCoordinator();
  static Future<void>? _nativeInitialization;

  Future<void> _ensureNativeInitialized() {
    return _nativeInitialization ??= _initializeNativeEngine();
  }

  static Future<void> _initializeNativeEngine() async {
    try {
      await FlutterEdgeAi.initialize(
        inferenceEngines: const [LiteRtLmEngine()],
      );
    } catch (_) {
      _nativeInitialization = null;
      rethrow;
    }
  }

  @override
  GemmaModelState build() {
    // Wait until Riverpod has committed the initial state before refresh reads
    // notifier.state; invoking it directly inside build reads an uninitialized
    // provider and breaks screens that eagerly watch model status.
    unawaited(Future<void>.microtask(refresh));
    ref.onDispose(() {
      _idleTimer?.cancel();
      unawaited(releaseModel());
    });
    return const GemmaModelState();
  }

  String _describeError(Object error) {
    final detail = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (detail.isEmpty) return error.runtimeType.toString();
    final bounded = detail.length > 220 ? '${detail.substring(0, 220)}…' : detail;
    return '${error.runtimeType}: $bounded';
  }

  Future<void> refresh() {
    if (state.status == GemmaModelStatus.downloading) {
      return Future<void>.value();
    }
    final active = _refreshInFlight;
    if (active != null) return active;

    final operation = _refreshOnce();
    _refreshInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<void> _refreshOnce() async {
    if (state.status == GemmaModelStatus.downloading) return;
    var installed = false;
    try {
      // Register the LiteRT-LM engine before checking its model registry.
      // This is a lightweight SDK initialization; the 2.59 GB model is not
      // loaded into RAM here.
      await _ensureNativeInitialized();
      installed = await FlutterEdgeAi.isModelInstalled(modelFileName);
      if (state.status == GemmaModelStatus.downloading) return;
      if (!installed) {
        state = const GemmaModelState();
        return;
      }
      final path = await FlutterEdgeAi.getModelPath(modelFileName);
      final modelFile = File(path);
      final length = await modelFile.length();
      if (length != expectedSize) {
        state = const GemmaModelState(
          status: GemmaModelStatus.error,
          error: 'حجم ملف النموذج غير مطابق؛ لم يتم تشغيله. لا تحذف الملف قبل مراجعة سبب المشكلة.',
          installed: true,
        );
        return;
      }
      if (!await _verifyAndRememberModel(modelFile)) {
        state = const GemmaModelState(
          status: GemmaModelStatus.error,
          error: 'بصمة ملف Gemma غير مطابقة للنسخة المعتمدة. لم يتم تشغيل الملف.',
          installed: true,
        );
        return;
      }
      state = GemmaModelState(
        status: GemmaModelStatus.ready,
        progress: 100,
        installed: true,
      );
      await _restoreInferenceResult();
    } catch (error) {
      state = GemmaModelState(
        status: GemmaModelStatus.error,
        installed: installed,
        error: 'تعذر التحقق من ملف النموذج. التفاصيل: ${_describeError(error)}',
      );
    }
  }

  Future<void> download() async {
    if (state.status == GemmaModelStatus.downloading) {
      return;
    }
    final previouslyInstalled = state.installed;
    _cancelToken = CancelToken();
    state = GemmaModelState(
      status: GemmaModelStatus.downloading,
      progress: 0,
      installed: previouslyInstalled,
    );
    try {
      await _ensureNativeInitialized();
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
      final modelFile = File(path);
      final length = await modelFile.length();
      if (length != expectedSize) {
        await FlutterEdgeAi.uninstallModel(modelFileName);
        throw StateError('Downloaded model size does not match the pinned size.');
      }
      // Stream the multi-gigabyte file through SHA-256 without loading it all
      // into RAM. A same-size but corrupt file must never be marked ready.
      if (!await _verifyAndRememberModel(modelFile, forceHash: true)) {
        await FlutterEdgeAi.uninstallModel(modelFileName);
        throw StateError('Downloaded model SHA-256 does not match the pinned digest.');
      }
      state = const GemmaModelState(
        status: GemmaModelStatus.ready,
        progress: 100,
        installed: true,
      );
    } catch (error) {
      if (CancelToken.isCancel(error)) {
        state = GemmaModelState(
          status: GemmaModelStatus.notDownloaded,
          cancelled: true,
          installed: previouslyInstalled,
        );
      } else {
        state = GemmaModelState(
          status: GemmaModelStatus.error,
          installed: previouslyInstalled,
          error: 'فشل تنزيل النموذج أو التحقق منه. التفاصيل: ${_describeError(error)}',
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
      final installed = await FlutterEdgeAi.isModelInstalled(modelFileName);
      if (installed) {
        await FlutterEdgeAi.uninstallModel(modelFileName);
      }
      await ref
          .read(appDatabaseProvider)
          .writeSetting(_verifiedModelSetting, '');
      state = const GemmaModelState();
    } catch (_) {
      state = const GemmaModelState(
        status: GemmaModelStatus.error,
        error: 'تعذر حذف النموذج.',
      );
    }
  }

  Future<bool> _verifyAndRememberModel(
    File modelFile, {
    bool forceHash = false,
  }) async {
    final modified = await modelFile.lastModified();
    final verificationMarker =
        '$expectedSha256:$expectedSize:${modified.millisecondsSinceEpoch}';

    if (!forceHash) {
      try {
        final previous = await ref
            .read(appDatabaseProvider)
            .readSetting(_verifiedModelSetting);
        if (previous == verificationMarker) return true;
      } catch (_) {
        // A missing/corrupt settings store only means the file must be hashed.
      }
    }

    final digest = await sha256.bind(modelFile.openRead()).first;
    if (digest.toString() != expectedSha256) return false;

    try {
      await ref
          .read(appDatabaseProvider)
          .writeSetting(_verifiedModelSetting, verificationMarker);
    } catch (_) {
      // Keep the verified model usable; it will be re-hashed next time.
    }
    return true;
  }


  Future<void> _restoreInferenceResult() async {
    try {
      final raw = await ref
          .read(appDatabaseProvider)
          .readSetting(_inferenceResultSetting);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final statusName = decoded['status'];
      final message = decoded['message'];
      final timestamp = decoded['at'];
      final status = switch (statusName) {
        'succeeded' => GemmaInferenceStatus.succeeded,
        'failed' => GemmaInferenceStatus.failed,
        _ => GemmaInferenceStatus.notTested,
      };
      if (status == GemmaInferenceStatus.notTested) return;
      state = state.copyWith(
        inferenceStatus: status,
        inferenceMessage: message is String ? message : null,
        inferenceAt: timestamp is String ? DateTime.tryParse(timestamp) : null,
      );
    } catch (_) {
      // Diagnostics must never affect model availability.
    }
  }

  Future<void> _saveInferenceResult(
    GemmaInferenceStatus status,
    String message,
  ) async {
    final at = DateTime.now();
    state = state.copyWith(
      inferenceStatus: status,
      inferenceMessage: message,
      inferenceAt: at,
      clearError: true,
    );
    try {
      await ref.read(appDatabaseProvider).writeSetting(
        _inferenceResultSetting,
        jsonEncode({
          'status': status.name,
          'message': message,
          'at': at.toIso8601String(),
        }),
      );
    } catch (_) {
      // The current session still displays the result when persistence fails.
    }
  }

  Future<bool> testInference() async {
    if (state.inferenceStatus == GemmaInferenceStatus.testing) return false;
    if (state.status != GemmaModelStatus.ready) {
      await refresh();
    }
    if (state.status != GemmaModelStatus.ready) {
      await _saveInferenceResult(
        GemmaInferenceStatus.failed,
        'ملف Gemma غير جاهز للتشغيل. راجع حالة الملف أعلاه.',
      );
      return false;
    }

    state = state.copyWith(
      inferenceStatus: GemmaInferenceStatus.testing,
      clearInferenceMessage: true,
      clearInferenceAt: true,
    );
    try {
      final output = await generate(
        'أجب بجملة قصيرة تؤكد نجاح اختبار تشغيل Gemma.',
        const <GemmaFunctionSpec>[],
      );
      final response = output.text?.trim() ?? '';
      if (response.isEmpty || response.startsWith('{')) {
        await _saveInferenceResult(
          GemmaInferenceStatus.failed,
          'وصل التنفيذ إلى النموذج، لكنه لم يُرجع إجابة نصية صالحة.',
        );
        return false;
      }
      await _saveInferenceResult(
        GemmaInferenceStatus.succeeded,
        'نجح اختبار التشغيل المحلي. أنشأ Gemma إجابة فعلية على هذا الجهاز.',
      );
      return true;
    } catch (error) {
      await _saveInferenceResult(
        GemmaInferenceStatus.failed,
        'فشل اختبار تشغيل Gemma: ${_describeError(error)}. تم الاحتفاظ بملف النموذج كما هو.',
      );
      return false;
    }
  }

  Future<void> _checkMultimodalMemory(AssistantMedia? media) async {
    if (media == null || (!media.hasImage && !media.hasAudio)) {
      return;
    }
    final info = await DeviceInfoPlugin().androidInfo;
    final ramMegabytes = physicalRamMegabytesFromBytes(info.physicalRamSize);
    if (!supportsGemmaMultimodalMemory(ramMegabytes)) {
      throw const AssistantInputException('تحليل الصور والصوت يحتاج هاتفاً بذاكرة RAM لا تقل عن 6GB. يمكنك متابعة المحادثة النصية.');
    }
  }

  Future<InferenceModel> _getModel({
    required bool supportImage,
    required bool supportAudio,
  }) async {
    _idleTimer?.cancel();
    if (_model == null || _model!.isClosed) {
      await _ensureNativeInitialized();
      _model = await FlutterEdgeAi.getActiveModel(
        // maxTokens is the full KV-cache context (system prompt + selected
        // tool schemas + recent dialogue + user input + generated answer).
        // A 4K window gives Gemma room for normal turns without sending every
        // finance schema on every request; the engine also bounds chat history.
        maxTokens: 4096,
        // Prefer CPU on memory-constrained phones: Android GPUs share system RAM.
        preferredBackend: PreferredBackend.cpu,
        maxConcurrentSessions: 1,
        supportImage: supportImage,
        supportAudio: supportAudio,
      );
      _modelSupportsImage = supportImage;
      _modelSupportsAudio = supportAudio;
    }
    return _model!;
  }

  @override
  Future<GemmaModelOutput> generate(
    String userText,
    List<GemmaFunctionSpec> functions, {
    AssistantMedia? media,
  }) async {
    if (state.status != GemmaModelStatus.ready) {
      throw StateError('Gemma model is not ready');
    }

    await _checkMultimodalMemory(media);
    state = state.copyWith(
      inferenceStatus: GemmaInferenceStatus.testing,
      clearInferenceMessage: true,
      clearInferenceAt: true,
    );
    final supportImage = media?.hasImage ?? false;
    final supportAudio = media?.hasAudio ?? false;
    if (_model != null && !_model!.isClosed &&
        (_modelSupportsImage != supportImage || _modelSupportsAudio != supportAudio)) {
      try {
        await releaseModel();
      } catch (error) {
        state = state.copyWith(status: GemmaModelStatus.ready);
        await _saveInferenceResult(
          GemmaInferenceStatus.failed,
          'تعذر تهيئة جلسة Gemma: ${_describeError(error)}. ملف النموذج محفوظ ويمكن إعادة المحاولة.',
        );
        rethrow;
      }
    }
    _releaseCoordinator.beginOperation();
    try {
      final model = await _getModel(supportImage: supportImage, supportAudio: supportAudio);
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
          supportsFunctionCalls: tools.isNotEmpty,
          supportImage: supportImage,
          supportAudio: supportAudio,
          toolChoice: ToolChoice.auto,
          maxOutputTokens: 256,
          temperature: 0,
          topK: 1,
        );
        if (media?.imageBytes != null) {
          await chat.addQueryChunk(Message.withImage(text: userText, imageBytes: media!.imageBytes!, isUser: true));
        } else if (media?.audioBytes != null) {
          await chat.addQueryChunk(Message.withAudio(text: userText, audioBytes: media!.audioBytes!, isUser: true));
        } else {
          await chat.addQueryChunk(Message.text(text: userText, isUser: true));
        }
        String? functionName;
        Map<String, Object?>? arguments;
        var hasMultipleCalls = false;
        final text = StringBuffer();

        await for (final response in chat.generateChatResponseAsync().timeout(
              const Duration(seconds: 90),
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

        if (hasMultipleCalls) {
          await _saveInferenceResult(
            GemmaInferenceStatus.failed,
            'أعاد Gemma عدة استدعاءات متزامنة، ولم يعتمد التطبيق هذه النتيجة.',
          );
          return const GemmaModelOutput.multiple();
        }
        if (functionName != null && arguments != null) {
          await _saveInferenceResult(
            GemmaInferenceStatus.succeeded,
            'نجح تشغيل Gemma محلياً وأعاد إجراءً منظماً للتطبيق.',
          );
          return GemmaModelOutput.call(functionName, arguments);
        }
        final generatedText = text.toString().trim();
        if (generatedText.isEmpty) {
          await _saveInferenceResult(
            GemmaInferenceStatus.failed,
            'استُدعي Gemma لكنه لم يُنتج نصاً في هذه المحاولة.',
          );
          return const GemmaModelOutput.text('');
        }
        await _saveInferenceResult(
          GemmaInferenceStatus.succeeded,
          'نجح تشغيل Gemma محلياً وأنتج إجابة نصية.',
        );
        return GemmaModelOutput.text(generatedText);
      } finally {
        if (chat != null) {
          await chat.close();
        }
        _scheduleIdleRelease();
      }
    } catch (error) {
      if (error is ContextLimitException) {
        // The SDK rolls back the refused turn. This is an input/context-size
        // problem, not a failed model load; keep Gemma available for retry.
        state = state.copyWith(
          status: GemmaModelStatus.ready,
          progress: 100,
        );
        await _saveInferenceResult(
          GemmaInferenceStatus.failed,
          'تعذر إكمال الطلب لأن سياق المحادثة أطول من المساحة المتاحة. اختصر الطلب وأعد المحاولة.',
        );
      } else {
        // Keep the verified 2.59 GB file installed. Runtime errors are tracked
        // separately from file-integrity errors and can be retried in place.
        state = state.copyWith(status: GemmaModelStatus.ready);
        await _saveInferenceResult(
          GemmaInferenceStatus.failed,
          'تعذر تشغيل Gemma: ${_describeError(error)}. تم الاحتفاظ بملف النموذج ويمكن إعادة الاختبار.',
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
    _modelSupportsImage = false;
    _modelSupportsAudio = false;
    if (model != null && !model.isClosed) {
      await model.close();
    }
  }
}

final gemmaModelManagerProvider =
    NotifierProvider<GemmaModelManager, GemmaModelState>(
  GemmaModelManager.new,
);
