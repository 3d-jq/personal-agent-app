import 'package:personal_agent_app/widgets/ai_settings.dart';
import 'package:personal_agent_app/widgets/vendor_config.dart';

class FakeAISettings extends AISettings {
  FakeAISettings({
    String apiKey = 'sk-test',
    String baseUrl = 'https://fake.test/v1',
    String model = 'test-model',
    String thinkingEffort = 'medium',
    int contextWindowSize = 256000,
    String vendorId = 'v1',
    String vendorName = 'Test',
  }) {
    vendors = [
      VendorConfig(
        id: vendorId,
        name: vendorName,
        apiKey: apiKey,
        baseUrl: baseUrl,
        model: model,
      )
    ];
    selectedVendorId = vendorId;
    this.thinkingEffort = thinkingEffort;
    this.contextWindowSize = contextWindowSize;
  }

  @override
  Future<void> load() async {}
}
