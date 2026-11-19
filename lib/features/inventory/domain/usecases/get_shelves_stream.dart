import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/shelf_entity.dart';
import '../repositories/shelf_repository.dart';

/// Use case لستريم الأرفف للتحديث الفوري
class GetShelvesStream
    implements StreamUseCase<List<ShelfEntity>, GetShelvesStreamParams> {
  GetShelvesStream(this.repository);
  final ShelfRepository repository;

  @override
  Stream<Either<Failure, List<ShelfEntity>>> call(
    GetShelvesStreamParams params,
  ) {
    return repository.getShelvesStream(
      organizationEmail: params.organizationEmail,
      zone: params.zone,
      isActive: params.isActive,
    );
  }
}

/// معاملات ستريم الأرفف
class GetShelvesStreamParams {
  const GetShelvesStreamParams({
    required this.organizationEmail,
    this.zone,
    this.isActive,
  });

  final String organizationEmail;
  final String? zone;
  final bool? isActive;
}
