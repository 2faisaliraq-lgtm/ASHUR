import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/product_repository.dart';

class GetProductsStatsStream
    implements StreamUseCase<Map<String, dynamic>, String> {
  GetProductsStatsStream(this.repository);
  final ProductRepository repository;

  @override
  Stream<Either<Failure, Map<String, dynamic>>> call(String organizationEmail,
      {int? limit}) {
    return repository.getProductsStatsStream(
      organizationEmail: organizationEmail,
      limit: limit,
    );
  }
}
