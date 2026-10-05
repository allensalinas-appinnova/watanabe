import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/finance/data/datasources/finance_remote_data_source.dart';
import '../../features/finance/data/datasources/receipt_image_picker.dart';
import '../../features/finance/data/repositories/finance_repository_impl.dart';
import '../../features/finance/domain/repositories/finance_repository.dart';

final getIt = GetIt.instance;

@injectableInit
Future<void> configureDependencies() async {
  final preferences = await SharedPreferences.getInstance();

  if (!getIt.isRegistered<SharedPreferences>()) {
    getIt.registerSingleton<SharedPreferences>(preferences);
  }
  if (!getIt.isRegistered<FirebaseAuth>()) {
    getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  }
  if (!getIt.isRegistered<FirebaseFirestore>()) {
    getIt.registerLazySingleton<FirebaseFirestore>(
      () => FirebaseFirestore.instance,
    );
  }
  if (!getIt.isRegistered<FirebaseStorage>()) {
    getIt.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);
  }
  if (!getIt.isRegistered<AuthRemoteDataSource>()) {
    getIt.registerLazySingleton<AuthRemoteDataSource>(
      () => FirebaseAuthRemoteDataSource(firebaseAuth: getIt()),
    );
  }
  if (!getIt.isRegistered<AuthLocalDataSource>()) {
    getIt.registerLazySingleton<AuthLocalDataSource>(
      () => SharedPreferencesAuthLocalDataSource(preferences: getIt()),
    );
  }
  if (!getIt.isRegistered<AuthRepository>()) {
    getIt.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remoteDataSource: getIt(),
        localDataSource: getIt(),
      ),
    );
  }
  if (!getIt.isRegistered<FinanceRemoteDataSource>()) {
    getIt.registerLazySingleton<FinanceRemoteDataSource>(
      () => FirestoreFinanceRemoteDataSource(
        firestore: getIt(),
        storage: getIt(),
      ),
    );
  }
  if (!getIt.isRegistered<ReceiptImagePicker>()) {
    getIt.registerLazySingleton<ReceiptImagePicker>(
      NativeReceiptImagePicker.new,
    );
  }
  if (!getIt.isRegistered<FinanceRepository>()) {
    getIt.registerLazySingleton<FinanceRepository>(
      () => FinanceRepositoryImpl(remoteDataSource: getIt()),
    );
  }
}
