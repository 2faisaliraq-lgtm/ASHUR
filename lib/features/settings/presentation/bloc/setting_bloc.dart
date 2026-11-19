import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/setting_entity.dart';
import '../../domain/usecases/create_setting.dart';
import '../../domain/usecases/delete_setting.dart';
import '../../domain/usecases/get_setting_by_key.dart';
import '../../domain/usecases/get_settings.dart';
import '../../domain/usecases/get_settings_by_category.dart';
import '../../domain/usecases/get_settings_stats_stream.dart';
import '../../domain/usecases/get_settings_stream.dart';
import '../../domain/usecases/update_setting.dart';

part 'setting_event.dart';
part 'setting_state.dart';

class SettingBloc extends Bloc<SettingEvent, SettingState> {
  SettingBloc({
    required this.getSettings,
    required this.createSetting,
    required this.updateSetting,
    required this.deleteSetting,
    required this.getSettingByKey,
    required this.getSettingsByCategory,
    required this.getSettingsStream,
    required this.getSettingsStatsStream,
  }) : super(SettingInitial()) {
    on<LoadSettingsEvent>(_onLoadSettings);
    on<CreateSettingEvent>(_onCreateSetting);
    on<UpdateSettingEvent>(_onUpdateSetting);
    on<DeleteSettingEvent>(_onDeleteSetting);
    on<LoadSettingByKeyEvent>(_onLoadSettingByKey);
    on<LoadSettingsByCategoryEvent>(_onLoadSettingsByCategory);

    // Stream event handlers
    on<StartSettingsStreamEvent>(_onStartSettingsStream);
    on<StartSettingsStatsStreamEvent>(_onStartSettingsStatsStream);
    on<StopSettingsStreamEvent>(_onStopSettingsStream);
    on<StopSettingsStatsStreamEvent>(_onStopSettingsStatsStream);
    on<_SettingsStreamDataReceived>(_onSettingsStreamDataReceived);
    on<_SettingsStreamErrorReceived>(_onSettingsStreamErrorReceived);
    on<_SettingsStatsStreamDataReceived>(_onSettingsStatsStreamDataReceived);
    on<_SettingsStatsStreamErrorReceived>(_onSettingsStatsStreamErrorReceived);
  }

  final GetSettings getSettings;
  final CreateSetting createSetting;
  final UpdateSetting updateSetting;
  final DeleteSetting deleteSetting;
  final GetSettingByKey getSettingByKey;
  final GetSettingsByCategory getSettingsByCategory;
  final GetSettingsStream getSettingsStream;
  final GetSettingsStatsStream getSettingsStatsStream;

  // Stream subscriptions
  StreamSubscription<dynamic>? _settingsStreamSubscription;
  StreamSubscription<dynamic>? _statsStreamSubscription;

  // Current data
  List<SettingEntity> _currentSettings = [];
  Map<String, int>? _currentStats;

  Future<void> _onLoadSettings(
    LoadSettingsEvent event,
    Emitter<SettingState> emit,
  ) async {
    emit(SettingLoading());
    final result = await getSettings(event.organizationEmail);
    result.fold(
      (failure) => emit(SettingError(failure.message)),
      (settings) => emit(SettingLoaded(settings: settings)),
    );
  }

  Future<void> _onCreateSetting(
    CreateSettingEvent event,
    Emitter<SettingState> emit,
  ) async {
    emit(SettingLoading());
    final result = await createSetting(
      CreateSettingParams(setting: event.setting),
    );
    result.fold((failure) => emit(SettingError(failure.message)), (setting) {
      emit(const SettingOperationSuccess('تم إنشاء الإعداد بنجاح'));
      emit(SettingCreated(setting: setting));
      // إعادة تحميل الإعدادات
      add(
        LoadSettingsEvent(organizationEmail: event.setting.organizationEmail),
      );
    });
  }

  Future<void> _onUpdateSetting(
    UpdateSettingEvent event,
    Emitter<SettingState> emit,
  ) async {
    emit(SettingLoading());
    final result = await updateSetting(
      UpdateSettingParams(setting: event.setting),
    );
    result.fold((failure) => emit(SettingError(failure.message)), (setting) {
      emit(const SettingOperationSuccess('تم تحديث الإعداد بنجاح'));
      emit(SettingUpdated(setting: setting));
      // إعادة تحميل الإعدادات
      add(
        LoadSettingsEvent(organizationEmail: event.setting.organizationEmail),
      );
    });
  }

  Future<void> _onDeleteSetting(
    DeleteSettingEvent event,
    Emitter<SettingState> emit,
  ) async {
    emit(SettingLoading());
    final result = await deleteSetting(
      DeleteSettingParams(
        organizationEmail: event.organizationEmail,
        settingId: event.settingId,
      ),
    );
    result.fold((failure) => emit(SettingError(failure.message)), (_) {
      emit(SettingDeleted());
      // إعادة تحميل الإعدادات
      add(LoadSettingsEvent(organizationEmail: event.organizationEmail));
    });
  }

  Future<void> _onLoadSettingByKey(
    LoadSettingByKeyEvent event,
    Emitter<SettingState> emit,
  ) async {
    emit(SettingLoading());
    final result = await getSettingByKey(
      GetSettingByKeyParams(
        organizationEmail: event.organizationEmail,
        key: event.key,
      ),
    );
    result.fold(
      (failure) => emit(SettingError(failure.message)),
      (setting) => emit(SettingByKeyLoaded(setting: setting)),
    );
  }

  Future<void> _onLoadSettingsByCategory(
    LoadSettingsByCategoryEvent event,
    Emitter<SettingState> emit,
  ) async {
    emit(SettingLoading());
    final result = await getSettingsByCategory(
      GetSettingsByCategoryParams(
        organizationEmail: event.organizationEmail,
        category: event.category,
      ),
    );
    result.fold(
      (failure) => emit(SettingError(failure.message)),
      (settings) => emit(SettingsByCategoryLoaded(settings: settings)),
    );
  }

  // Stream Event Handlers
  Future<void> _onStartSettingsStream(
    StartSettingsStreamEvent event,
    Emitter<SettingState> emit,
  ) async {
    await _settingsStreamSubscription?.cancel();

    // ⚠️ ملاحظة للمبرمجين المستقبليين: لا نرسل حالة تحميل عند
    // إعادة بدء الستريم إذا كانت البيانات موجودة لأنها تمزق
    // الواجهة وتغلق الكيبورد — الستريم سيوصل البيانات المحدثة
    final hasExistingData =
        state is SettingStreamActive || state is SettingLoaded;
    if (!hasExistingData) {
      emit(SettingLoading());
    }

    try {
      final stream = getSettingsStream(
        GetSettingsStreamParams(
          organizationEmail: event.organizationEmail,
          limit: event.limit,
        ),
      );

      _settingsStreamSubscription = stream.listen(
        (result) {
          add(_SettingsStreamDataReceived(result));
        },
        onError: (error) {
          add(_SettingsStreamErrorReceived('حدث خطأ غير متوقع'));
        },
      );
    } on Exception catch (_) {
      if (!emit.isDone) emit(SettingError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onStartSettingsStatsStream(
    StartSettingsStatsStreamEvent event,
    Emitter<SettingState> emit,
  ) async {
    await _statsStreamSubscription?.cancel();

    try {
      final stream = getSettingsStatsStream(event.organizationEmail);

      _statsStreamSubscription = stream.listen(
        (result) {
          add(_SettingsStatsStreamDataReceived(result));
        },
        onError: (error) {
          add(_SettingsStatsStreamErrorReceived('حدث خطأ غير متوقع'));
        },
      );
    } on Exception catch (_) {
      if (!emit.isDone) emit(SettingError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onStopSettingsStream(
    StopSettingsStreamEvent event,
    Emitter<SettingState> emit,
  ) async {
    await _settingsStreamSubscription?.cancel();
    _settingsStreamSubscription = null;
  }

  Future<void> _onStopSettingsStatsStream(
    StopSettingsStatsStreamEvent event,
    Emitter<SettingState> emit,
  ) async {
    await _statsStreamSubscription?.cancel();
    _statsStreamSubscription = null;
  }

  void _onSettingsStreamDataReceived(
    _SettingsStreamDataReceived event,
    Emitter<SettingState> emit,
  ) {
    event.result.fold((failure) => emit(SettingError(failure.message)), (
      settings,
    ) {
      _currentSettings = settings;
      emit(SettingStreamActive(settings: settings, stats: _currentStats));
    });
  }

  void _onSettingsStreamErrorReceived(
    _SettingsStreamErrorReceived event,
    Emitter<SettingState> emit,
  ) {
    emit(SettingError(event.error));
  }

  void _onSettingsStatsStreamDataReceived(
    _SettingsStatsStreamDataReceived event,
    Emitter<SettingState> emit,
  ) {
    event.result.fold((failure) => emit(SettingError(failure.message)), (
      stats,
    ) {
      _currentStats = stats;
      emit(SettingStreamActive(settings: _currentSettings, stats: stats));
    });
  }

  void _onSettingsStatsStreamErrorReceived(
    _SettingsStatsStreamErrorReceived event,
    Emitter<SettingState> emit,
  ) {
    emit(SettingError(event.error));
  }

  @override
  Future<void> close() async {
    await _settingsStreamSubscription?.cancel();
    _settingsStreamSubscription = null;
    await _statsStreamSubscription?.cancel();
    _statsStreamSubscription = null;
    return super.close();
  }
}
