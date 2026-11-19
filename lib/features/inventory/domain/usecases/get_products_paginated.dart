import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/products_page.dart';
import '../repositories/product_repository.dart';

class GetProductsPaginated {
  GetProductsPaginated(this.repository);
  final ProductRepository repository;

  Future<Either<Failure, ProductsPage>> call({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
    String? searchQuery,
  }) {
    return repository.getProductsPaginated(
      organizationEmail: organizationEmail,
      limit: limit,
      lastDocument: lastDocument,
      searchQuery: searchQuery,
    );
  }
}
