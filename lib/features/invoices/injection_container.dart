import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import '../../../features/customers/domain/repositories/customer_repository.dart';
import '../../../core/permissions/permission_checker.dart';
import '../inventory/data/repositories/product_repository_impl.dart';
import '../inventory/domain/repositories/product_repository.dart';
import 'data/repositories/invoice_repository_impl.dart';
import 'domain/repositories/invoice_repository.dart';
import 'domain/usecases/add_invoice.dart';
import 'domain/usecases/archive_customer_invoices.dart';
import 'domain/usecases/clear_customer_account.dart';
import 'domain/usecases/delete_invoice.dart';
import 'domain/usecases/get_invoice_logs.dart';
import 'domain/usecases/get_invoice_logs_stream.dart';
import 'domain/usecases/get_invoice_stats.dart';
import 'domain/usecases/get_invoice_stats_stream.dart';
import 'domain/usecases/get_invoices.dart';
import 'domain/usecases/get_archived_invoices.dart';
import 'domain/usecases/get_invoices_paginated.dart';
import 'domain/usecases/get_invoices_stream.dart';
import 'domain/usecases/update_invoice.dart';
import 'presentation/bloc/invoice_bloc.dart';

final getIt = GetIt.instance;

Future<void> initInvoices() async {
  // تسجيل ProductRepository أولاً (مطلوب لـ InvoiceBloc)
  if (!getIt.isRegistered<ProductRepository>()) {
    getIt.registerLazySingleton<ProductRepository>(
      () => ProductRepositoryImpl(firestore: getIt<FirebaseFirestore>()),
    );
  }

  // Repository
  if (!getIt.isRegistered<InvoiceRepository>()) {
    getIt.registerLazySingleton<InvoiceRepository>(
      // ✅ ملاحظة للمبرمجين المستقبليين:
      // productRepository مطلوب هنا ولا يُحذف أبداً.
      // السبب: InvoiceRepositoryImpl يجلب به المنتجات
      // داخل runTransaction لتحديث/عكس المخزون وسجلات
      // حركة المنتجات في معاملات الفواتير. بدونه يكون
      // productRepository null فلا يُحدَّث المخزون أبداً.
      () => InvoiceRepositoryImpl(
        firestore: getIt<FirebaseFirestore>(),
        productRepository: getIt<ProductRepository>(),
      ),
    );
  }

  // Use Cases
  if (!getIt.isRegistered<GetInvoices>()) {
    getIt.registerLazySingleton(() => GetInvoices(getIt()));
  }
  if (!getIt.isRegistered<GetArchivedInvoices>()) {
    getIt.registerLazySingleton(() => GetArchivedInvoices(getIt()));
  }
  if (!getIt.isRegistered<GetInvoicesPaginated>()) {
    getIt.registerLazySingleton(() => GetInvoicesPaginated(getIt()));
  }
  if (!getIt.isRegistered<GetInvoicesStream>()) {
    getIt.registerLazySingleton(() => GetInvoicesStream(getIt()));
  }
  if (!getIt.isRegistered<GetInvoiceStatsStream>()) {
    getIt.registerLazySingleton(() => GetInvoiceStatsStream(getIt()));
  }
  if (!getIt.isRegistered<AddInvoice>()) {
    getIt.registerLazySingleton(() => AddInvoice(getIt()));
  }
  if (!getIt.isRegistered<UpdateInvoice>()) {
    getIt.registerLazySingleton(() => UpdateInvoice(getIt()));
  }
  if (!getIt.isRegistered<DeleteInvoice>()) {
    getIt.registerLazySingleton(() => DeleteInvoice(getIt()));
  }
  if (!getIt.isRegistered<GetInvoiceStats>()) {
    getIt.registerLazySingleton(() => GetInvoiceStats(getIt()));
  }
  if (!getIt.isRegistered<GetInvoiceLogs>()) {
    getIt.registerLazySingleton(() => GetInvoiceLogs(getIt()));
  }
  if (!getIt.isRegistered<GetInvoiceLogsStream>()) {
    getIt.registerLazySingleton(() => GetInvoiceLogsStream(getIt()));
  }
  if (!getIt.isRegistered<ArchiveCustomerInvoices>()) {
    getIt.registerLazySingleton(() => ArchiveCustomerInvoices(getIt()));
  }
  if (!getIt.isRegistered<ClearCustomerAccount>()) {
    getIt.registerLazySingleton(() => ClearCustomerAccount(getIt()));
  }

  // BLoC
  if (!getIt.isRegistered<InvoiceBloc>()) {
    getIt.registerFactory(
      () => InvoiceBloc(
      getInvoices: getIt(),
      getInvoicesPaginated: getIt(),
      getInvoicesStream: getIt(),
      getInvoiceStatsStream: getIt(),
      addInvoice: getIt(),
      updateInvoice: getIt(),
      deleteInvoice: getIt(),
      getInvoiceStats: getIt(),
      getInvoiceLogs: getIt(),
      getInvoiceLogsStream: getIt(),
      getArchivedInvoices: getIt(),
      repository: getIt(),
      customerRepository: getIt<CustomerRepository>(),
      permissionChecker: PermissionChecker(),
      ),
    );
  }
}
