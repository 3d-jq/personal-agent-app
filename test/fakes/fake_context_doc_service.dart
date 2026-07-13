import 'package:personal_agent_app/services/context_doc_service.dart';

class FakeContextDocService extends ContextDocService {
  @override
  Future<void> ensureDefaults() async {}

  @override
  Future<void> loadAll() async {}

  @override
  String cached(ContextDoc doc) => '';

  @override
  bool hasUserProfile() => false;
}
