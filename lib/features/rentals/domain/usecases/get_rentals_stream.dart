import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/rental_entity.dart';
import '../repositories/rental_repository.dart';

class GetRentalsStreamParams {
  const GetRentalsStreamParams({
    this.limit,
    this.searchQuery,
    this.statusFilter,
    this.customerFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
  });

  final int? limit;
  final String? searchQuery;
  final String? statusFilter;
  final String? customerFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
}

class GetRentalsStream
    implements StreamUseCase<List<RentalEntity>, GetRentalsStreamParams> {
  GetRentalsStream(this.repository);
  final RentalRepository repository;

  @override
  Stream<Either<Failure, List<RentalEntity>>> call(
    GetRentalsStreamParams params,
  ) {
    return repository.getRentalsStream(
      limit: params.limit,
      searchQuery: params.searchQuery,
      statusFilter: params.statusFilter,
      customerFilter: params.customerFilter,
      dateFilter: params.dateFilter,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}
