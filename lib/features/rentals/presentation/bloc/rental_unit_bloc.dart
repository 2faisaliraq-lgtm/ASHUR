import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/rental_unit_entity.dart';
import '../../domain/entities/rental_units_page.dart';
import '../../domain/repositories/rental_unit_repository.dart';
import '../../domain/usecases/create_rental_unit.dart';
import '../../domain/usecases/delete_rental_unit.dart';
import '../../domain/usecases/get_available_rental_units.dart';
import '../../domain/usecases/get_rental_units.dart';
import '../../domain/usecases/get_rental_units_stream.dart';
import '../../domain/usecases/update_rental_unit.dart';
import 'rental_unit_event.dart';
import 'rental_unit_state.dart';

class RentalUnitBloc extends Bloc<RentalUnitEvent, RentalUnitState> {
  RentalUnitBloc({
    required this.getRentalUnits,
    required this.getRentalUnitsStream,
    required this.getAvailableRentalUnits,
    required this.createRentalUnit,
    required this.updateRentalUnit,
    required this.deleteRentalUnit,
    required this.repository,
  }) : super(const RentalUnitInitial()) {
    on<LoadRentalUnitsEvent>(_onLoadRentalUnits);
    on<StartRentalUnitsStreamEvent>(_onStartRentalUnitsStream);
    on<StopRentalUnitsStreamEvent>(_onStopRentalUnitsStream);
    on<CreateRentalUnitEvent>(_onCreateRentalUnit);
    on<UpdateRentalUnitEvent>(_onUpdateRentalUnit);
    on<DeleteRentalUnitEvent>(_onDeleteRentalUnit);
    on<LoadAvailableRentalUnitsEvent>(_onLoadAvailableRentalUnits);
    on<LoadMoreRentalUnitsEvent>(_onLoadMoreRentalUnits);
  }

  final GetRentalUnits getRentalUnits;
  final GetRentalUnitsStream getRentalUnitsStream;
  final GetAvailableRentalUnits getAvailableRentalUnits;
  final CreateRentalUnit createRentalUnit;
  final UpdateRentalUnit updateRentalUnit;
  final DeleteRentalUnit deleteRentalUnit;
  final RentalUnitRepository repository;

  StreamSubscription? _rentalUnitsStreamSubscription;
  DocumentSnapshot<Object?>? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // ⚠️ ملاحظة ذرية للمبرمجين المستقبليين (تحقق
  // 2026-10-11، أُعيد التحقق 2026-10-12): كل
  // عمليات الوحدات ذرية في المستودع (خريطة
  // الذرية في rental_unit_repository_impl.dart):
  // الإنشاء معاملة تمنع الكتابة فوق وحدة
  // موجودة، والتحديث معاملة تحمي حالة الوحدة
  // المؤجرة، والحذف معاملة تمنع حذف وحدة
  // مؤجرة بلا سباق بين الفحص والحذف.
  // لا تُضف كتابة حالة وحدة منفصلة هنا أبداً
  // — أي تغيير لحالة الوحدة المرتبط بعقد يحدث
  // داخل معاملة العقد (createRental/
  // updateRental/deleteRental).

  Future<void> _onLoadRentalUnits(
    LoadRentalUnitsEvent event,
    Emitter<RentalUnitState> emit,
  ) async {
    emit(const RentalUnitLoading());
    final result = await getRentalUnits(event.organizationEmail);
    result.fold(
      (failure) => emit(RentalUnitError(failure.message)),
      (units) => emit(RentalUnitLoaded(units)),
    );
  }

  Future<void> _onLoadMoreRentalUnits(
    LoadMoreRentalUnitsEvent event,
    Emitter<RentalUnitState> emit,
  ) async {
    if (_isLoadingMore || !_hasMoreData) return;

    _isLoadingMore = true;

    try {
      final result = await repository.getRentalUnitsPaginated(
        organizationEmail: event.organizationEmail,
        limit: 20,
        lastDocument: _lastDocument,
      );

      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is RentalUnitsStreamActive) {
            emit(currentState.copyWith(isLoadingMore: false));
          }
          emit(RentalUnitError(failure.message));
        },
        (page) {
          if (page.units.isNotEmpty) {
            _lastDocument = page.lastDocument;
            final currentUnits = <RentalUnitEntity>[];
            final currentState = state;
            if (currentState is RentalUnitsStreamActive) {
              currentUnits.addAll(currentState.units);
            }
            currentUnits.addAll(page.units);
            _hasMoreData = page.units.length >= 20;

            emit(
              RentalUnitsStreamActive(
                units: currentUnits,
                hasMoreData: _hasMoreData,
                isLoadingMore: false,
              ),
            );
          } else {
            _hasMoreData = false;
            final currentState = state;
            if (currentState is RentalUnitsStreamActive) {
              emit(currentState.copyWith(hasMoreData: false, isLoadingMore: false));
            }
          }
          _isLoadingMore = false;
        },
      );
    } on Exception catch (_) {
      _isLoadingMore = false;
      final currentState = state;
      if (currentState is RentalUnitsStreamActive) {
        emit(currentState.copyWith(isLoadingMore: false));
      }
      emit(RentalUnitError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onStartRentalUnitsStream(
    StartRentalUnitsStreamEvent event,
    Emitter<RentalUnitState> emit,
  ) async {
    await _rentalUnitsStreamSubscription?.cancel();
    _lastDocument = null;
    _isLoadingMore = false;
    _hasMoreData = true;

    _rentalUnitsStreamSubscription =
        getRentalUnitsStream(event.organizationEmail).listen((result) {
          result.fold(
            (failure) {
              if (!isClosed) {
                add(LoadRentalUnitsEvent(event.organizationEmail));
              }
            },
            (units) {
              if (!isClosed) {
                emit(
                  RentalUnitsStreamActive(
                    units: units,
                    hasMoreData: _hasMoreData,
                    isLoadingMore: _isLoadingMore,
                  ),
                );
              }
            },
          );
        });
  }

  Future<void> _onStopRentalUnitsStream(
    StopRentalUnitsStreamEvent event,
    Emitter<RentalUnitState> emit,
  ) async {
    await _rentalUnitsStreamSubscription?.cancel();
    _rentalUnitsStreamSubscription = null;
  }

  Future<void> _onCreateRentalUnit(
    CreateRentalUnitEvent event,
    Emitter<RentalUnitState> emit,
  ) async {
    emit(const RentalUnitLoading());
    final result = await createRentalUnit(event.unit);
    result.fold(
      (failure) => emit(RentalUnitError(failure.message)),
      (_) => emit(const RentalUnitOperationSuccess('تم إنشاء الوحدة بنجاح')),
    );
  }

  Future<void> _onUpdateRentalUnit(
    UpdateRentalUnitEvent event,
    Emitter<RentalUnitState> emit,
  ) async {
    emit(const RentalUnitLoading());
    final result = await updateRentalUnit(event.unit);
    result.fold(
      (failure) => emit(RentalUnitError(failure.message)),
      (_) => emit(const RentalUnitOperationSuccess('تم تحديث الوحدة بنجاح')),
    );
  }

  Future<void> _onDeleteRentalUnit(
    DeleteRentalUnitEvent event,
    Emitter<RentalUnitState> emit,
  ) async {
    emit(const RentalUnitLoading());
    final result = await deleteRentalUnit(event.id);
    result.fold(
      (failure) => emit(RentalUnitError(failure.message)),
      (_) => emit(const RentalUnitOperationSuccess('تم حذف الوحدة بنجاح')),
    );
  }

  Future<void> _onLoadAvailableRentalUnits(
    LoadAvailableRentalUnitsEvent event,
    Emitter<RentalUnitState> emit,
  ) async {
    emit(const RentalUnitLoading());
    final result = await getAvailableRentalUnits(event.organizationEmail);
    result.fold(
      (failure) => emit(RentalUnitError(failure.message)),
      (units) => emit(RentalUnitLoaded(units)),
    );
  }

  @override
  Future<void> close() async {
    await _rentalUnitsStreamSubscription?.cancel();
    _rentalUnitsStreamSubscription = null;
    return super.close();
  }
}
