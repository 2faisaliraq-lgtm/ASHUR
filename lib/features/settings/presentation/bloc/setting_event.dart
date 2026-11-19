part of 'setting_bloc.dart';

abstract class SettingEvent extends Equatable {
  const SettingEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettingsEvent extends SettingEvent {
  const LoadSettingsEvent({required this.organizationEmail});
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

class CreateSettingEvent extends SettingEvent {
  const CreateSettingEvent({required this.setting});
  final SettingEntity setting;

  @override
  List<Object?> get props => [setting];
}

class UpdateSettingEvent extends SettingEvent {
  const UpdateSettingEvent({required this.setting});
  final SettingEntity setting;

  @override
  List<Object?> get props => [setting];
}

class DeleteSettingEvent extends SettingEvent {
  const DeleteSettingEvent({
    required this.organizationEmail,
    required this.settingId,
  });
  final String organizationEmail;
  final String settingId;

  @override
  List<Object?> get props => [organizationEmail, settingId];
}

class LoadSettingByKeyEvent extends SettingEvent {
  const LoadSettingByKeyEvent({
    required this.organizationEmail,
    required this.key,
  });
  final String organizationEmail;
  final String key;

  @override
  List<Object?> get props => [organizationEmail, key];
}

class LoadSettingsByCategoryEvent extends SettingEvent {
  const LoadSettingsByCategoryEvent({
    required this.organizationEmail,
    required this.category,
  });
  final String organizationEmail;
  final String category;

  @override
  List<Object?> get props => [organizationEmail, category];
}

// Stream Events for Real-time Updates
class StartSettingsStreamEvent extends SettingEvent {
  const StartSettingsStreamEvent({
    required this.organizationEmail,
    this.limit,
  });
  final String organizationEmail;
  final int? limit;

  @override
  List<Object?> get props => [organizationEmail, limit];
}

class StartSettingsStatsStreamEvent extends SettingEvent {
  const StartSettingsStatsStreamEvent({required this.organizationEmail});
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

class StopSettingsStreamEvent extends SettingEvent {
  const StopSettingsStreamEvent();
}

class StopSettingsStatsStreamEvent extends SettingEvent {
  const StopSettingsStatsStreamEvent();
}

// Internal Events for Stream Data
class _SettingsStreamDataReceived extends SettingEvent {
  const _SettingsStreamDataReceived(this.result);
  final Either<Failure, List<SettingEntity>> result;

  @override
  List<Object?> get props => [result];
}

class _SettingsStreamErrorReceived extends SettingEvent {
  const _SettingsStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}

class _SettingsStatsStreamDataReceived extends SettingEvent {
  const _SettingsStatsStreamDataReceived(this.result);
  final Either<Failure, Map<String, int>> result;

  @override
  List<Object?> get props => [result];
}

class _SettingsStatsStreamErrorReceived extends SettingEvent {
  const _SettingsStatsStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}
