import 'dart:async';

import 'package:get_it/get_it.dart';

import '../service_locator.dart';

final ServiceLocator sl = ServiceLocatorGetit();

class ServiceLocatorGetit implements ServiceLocator {
  late GetIt getit;

  ServiceLocatorGetit({GetIt? getit}) : getit = getit ?? GetIt.instance;

  @override
  T get<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
  }) =>
      getit.get<T>(
        instanceName: instanceName,
        param1: param1,
        param2: param2,
      );

  @override
  Future<T> getAsync<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
  }) =>
      getit.getAsync<T>(
        instanceName: instanceName,
        param1: param1,
        param2: param2,
      );

  @override
  void registerFactory<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  }) =>
      getit.registerFactory<T>(
        factoryFunc,
        instanceName: instanceName,
      );

  @override
  void registerLazySingleton<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
  }) =>
      getit.registerLazySingleton<T>(
        factoryFunc,
        instanceName: instanceName,
        dispose: dispose,
      );

  @override
  void registerSingleton<T extends Object>(
    T instance, {
    String? instanceName,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  }) =>
      getit.registerSingleton<T>(
        instance,
        instanceName: instanceName,
        signalsReady: signalsReady,
        dispose: dispose,
      );

  @override
  FutureOr<dynamic> unregister<T extends Object>({
    Object? instance,
    String? instanceName,
    FutureOr<dynamic> Function(T p1)? disposingFunction,
  }) =>
      getit.unregister<T>(
        instance: instance,
        instanceName: instanceName,
        disposingFunction: disposingFunction,
      );

  @override
  bool isRegistered<T extends Object>({
    String? instanceName,
    Object? instance,
  }) =>
      getit.isRegistered<T>(
        instanceName: instanceName,
      ) ||
      getit.isRegistered(instance: instance);

  @override
  void safeRegisterSingleton<T extends Object>(
    T instance, {
    String? instanceName,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  }) {
    if (!isRegistered<T>(instanceName: instanceName, instance: instance)) {
      registerSingleton<T>(
        instance,
        instanceName: instanceName,
        signalsReady: signalsReady,
        dispose: dispose,
      );
    }
  }
}
