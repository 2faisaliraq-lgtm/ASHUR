import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/users_repository.dart';

class GetUsersStatsStreamParams extends Equatable {
  const GetUsersStatsStreamParams({required this.organizationEmail, this.limit});
  final String organizationEmail;
  final int? limit;

  @override
  List<Object?> get props => [organizationEmail, limit];
}

class GetUsersStatsStream implements StreamUseCase<Map<String, int>, GetUsersStatsStreamParams> {
  GetUsersStatsStream(this.repository);
  final UsersRepository repository;

  @override
  Stream<Either<Failure, Map<String, int>>> call(GetUsersStatsStreamParams params) {
    return repository.getUsersStatisticsStream(
      organizationEmail: params.organizationEmail,
      limit: params.limit,
    );
  }
}
