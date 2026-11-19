import 'package:equatable/equatable.dart';

import '../../domain/entities/rental_unit_entity.dart';

abstract class RentalUnitEvent extends Equatable {
  const RentalUnitEvent();

  @override
  List<Object?> get props => [];
}

class LoadRentalUnitsEvent extends RentalUnitEvent {
  const LoadRentalUnitsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث تحميل المزيد من وحدات الإيجار (pagination)
class LoadMoreRentalUnitsEvent extends RentalUnitEvent {
  const LoadMoreRentalUnitsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

class StartRentalUnitsStreamEvent extends RentalUnitEvent {
  const StartRentalUnitsStreamEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

class StopRentalUnitsStreamEvent extends RentalUnitEvent {
  const StopRentalUnitsStreamEvent();
}

class CreateRentalUnitEvent extends RentalUnitEvent {
  const CreateRentalUnitEvent(this.unit);
  final RentalUnitEntity unit;

  @override
  List<Object?> get props => [unit];
}

class UpdateRentalUnitEvent extends RentalUnitEvent {
  const UpdateRentalUnitEvent(this.unit);
  final RentalUnitEntity unit;

  @override
  List<Object?> get props => [unit];
}

class DeleteRentalUnitEvent extends RentalUnitEvent {
  const DeleteRentalUnitEvent(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class LoadAvailableRentalUnitsEvent extends RentalUnitEvent {
  const LoadAvailableRentalUnitsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}
