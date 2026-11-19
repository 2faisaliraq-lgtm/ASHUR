import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/shelf_entity.dart';
import '../repositories/shelf_repository.dart';

/// Use case للحصول على الرفوف
class GetShelvesSimple
    implements UseCase<List<ShelfEntity>, GetShelvesSimpleParams> {
  const GetShelvesSimple(this.repository);

  final ShelfRepository repository;

  @override
  Future<Either<Failure, List<ShelfEntity>>> call(
    GetShelvesSimpleParams params,
  ) async {
    return repository.getShelves(
      organizationEmail: params.organizationEmail,
      zone: params.zone,
      isActive: params.isActive,
    );
  }
}

/// معاملات الحصول على الرفوف
class GetShelvesSimpleParams extends Equatable {
  const GetShelvesSimpleParams({
    required this.organizationEmail,
    this.zone,
    this.isActive,
  });

  final String organizationEmail;
  final String? zone;
  final bool? isActive;

  @override
  List<Object?> get props => [organizationEmail, zone, isActive];
}
