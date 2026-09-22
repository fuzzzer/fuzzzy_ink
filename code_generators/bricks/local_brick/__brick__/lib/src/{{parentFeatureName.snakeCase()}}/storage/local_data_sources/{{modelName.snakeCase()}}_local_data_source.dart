import 'package:fuzzzy_ink/lib.dart';
import 'package:isar/isar.dart';

class {{modelName.pascalCase()}}LocalDataSource {
  final Isar isar;

  {{modelName.pascalCase()}}LocalDataSource({required this.isar});

  Future<List<Stored{{modelName.pascalCase()}}>> getAll() async {
    return await isar.stored{{modelName.pascalCase()}}s.where().findAll();
  }

  Future<Stored{{modelName.pascalCase()}}?> getByUid(String uid) async {
    return await isar.stored{{modelName.pascalCase()}}s.filter().uidEqualTo(uid).findFirst();
  }

  Future<void> addOrUpdate({{modelName.pascalCase()}} model) async {
    // TODO: Implement the mapping from your clean model to the stored model.
    final storedModel = Stored{{modelName.pascalCase()}}()
      ..uid = model.uid
      ..lastUpdated = DateTime.now();
      // ..name = model.name;

    await isar.writeTxn(() async {
      await isar.stored{{modelName.pascalCase()}}s.put(storedModel);
    });
  }

  Future<void> delete(String uid) async {
    await isar.writeTxn(() async {
      await isar.stored{{modelName.pascalCase()}}s.filter().uidEqualTo(uid).deleteAll();
    });
  }
}
