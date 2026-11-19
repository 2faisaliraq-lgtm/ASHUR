part of 'setting_bloc.dart';

abstract class SettingState extends Equatable {
  const SettingState();

  @override
  List<Object?> get props => [];
}

class SettingInitial extends SettingState {}

class SettingLoading extends SettingState {}

class SettingLoaded extends SettingState {
  const SettingLoaded({required this.settings});
  final List<SettingEntity> settings;

  @override
  List<Object?> get props => [settings];
}

class SettingCreated extends SettingState {
  const SettingCreated({required this.setting});
  final SettingEntity setting;

  @override
  List<Object?> get props => [setting];
}

class SettingUpdated extends SettingState {
  const SettingUpdated({required this.setting});
  final SettingEntity setting;

  @override
  List<Object?> get props => [setting];
}

class SettingDeleted extends SettingState {}

class SettingByKeyLoaded extends SettingState {
  const SettingByKeyLoaded({required this.setting});
  final SettingEntity? setting;

  @override
  List<Object?> get props => [setting];
}

class SettingsByCategoryLoaded extends SettingState {
  const SettingsByCategoryLoaded({required this.settings});
  final List<SettingEntity> settings;

  @override
  List<Object?> get props => [settings];
}

class SettingError extends SettingState {
  const SettingError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class SettingOperationSuccess extends SettingState {
  const SettingOperationSuccess(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

// Stream State for Real-time Updates
class SettingStreamActive extends SettingState {
  const SettingStreamActive({required this.settings, this.stats});

  final List<SettingEntity> settings;
  final Map<String, int>? stats;

  @override
  List<Object?> get props => [settings, stats];
}
