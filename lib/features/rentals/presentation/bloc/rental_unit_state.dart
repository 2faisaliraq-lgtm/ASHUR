import 'package:equatable/equatable.dart';

import '../../domain/entities/rental_unit_entity.dart';

abstract class RentalUnitState extends Equatable {
  const RentalUnitState();

  @override
  List<Object?> get props => [];
}

class RentalUnitInitial extends RentalUnitState {
  const RentalUnitInitial();
}

class RentalUnitLoading extends RentalUnitState {
  const RentalUnitLoading();
}

class RentalUnitLoaded extends RentalUnitState {
  const RentalUnitLoaded(this.units);
  final List<RentalUnitEntity> units;

  @override
  List<Object?> get props => [units];
}

/// حالة وحدات الإيجار النشطة مع التحديث الفوري
class RentalUnitsStreamActive extends RentalUnitState {
  const RentalUnitsStreamActive({
    required this.units,
    this.hasMoreData = false,
    this.isLoadingMore = false,
  });

  final List<RentalUnitEntity> units;
  final bool hasMoreData;
  final bool isLoadingMore;

  RentalUnitsStreamActive copyWith({
    List<RentalUnitEntity>? units,
    bool? hasMoreData,
    bool? isLoadingMore,
  }) {
    return RentalUnitsStreamActive(
      units: units ?? this.units,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [units, hasMoreData, isLoadingMore];
}

class RentalUnitOperationSuccess extends RentalUnitState {
  const RentalUnitOperationSuccess(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class RentalUnitError extends RentalUnitState {
  const RentalUnitError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
