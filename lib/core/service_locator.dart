import 'package:get_it/get_it.dart';
import '../services/foreground_service.dart';
import '../services/agent_group_storage.dart';
import '../services/agent_storage.dart';
import '../services/chat_storage.dart';
import '../services/connectivity_service.dart';
import '../services/context_doc_service.dart';
import '../services/export_service.dart';
import '../services/mcp_manager.dart';
import '../services/media_storage.dart';
import '../services/notification_service.dart';
import '../services/note_storage.dart';
import '../services/reminder_storage.dart';
import '../services/storage/app_database.dart';
import '../services/theme_service.dart';
import '../services/virtual_fs.dart';
import '../tools/skill_registry.dart';
import '../widgets/ai_settings_sheet.dart';

/// 全局依赖注入容器。
///
/// 所有 Service / Storage 都在这里注册为单例，业务代码统一通过
/// [getIt] 获取实例，方便在测试中替换为 mock。
final GetIt getIt = GetIt.instance;

/// 初始化所有依赖。
///
/// 应在应用启动时调用一次。测试前可调用 [resetDependencies] 重新注册。
///
/// 注意：本方法不初始化 SQLite 数据库。main.dart 显式调用
/// [AppDatabase.instance.initialize] + [DbMigration.run]。
/// 测试中通常用 fake 替换全部 storage，无需真实数据库。
Future<void> configureDependencies() async {
  getIt
    ..registerSingleton<AgentStorage>(AgentStorage())
    ..registerSingleton<AgentGroupStorage>(AgentGroupStorage())
    ..registerSingleton<AISettings>(AISettings())
    ..registerSingleton<ChatStorage>(ChatStorage())
    ..registerSingleton<ConnectivityService>(ConnectivityService())
    ..registerSingleton<ContextDocService>(ContextDocService())
    ..registerSingleton<ExportService>(ExportService())
    ..registerSingleton<McpManager>(McpManager())
    ..registerSingleton<MediaStorage>(MediaStorage())
    ..registerSingleton<NotificationService>(NotificationService())
    ..registerSingleton<NoteStorage>(NoteStorage())
    ..registerSingleton<ReminderStorage>(ReminderStorage())
    ..registerSingleton<ThemeService>(ThemeService())
    ..registerSingleton<VirtualFileSystem>(VirtualFileSystem())
    ..registerSingleton<SkillRegistry>(SkillRegistry());
}

/// 重置所有已注册依赖，主要用于测试。
///
/// 除重建 getIt 单例外，还会清理非 DI 持有的全局可变状态
/// （如 ForegroundService 的静态运行标志、数据库连接），避免跨测试泄漏。
///
/// 注意：TaskPlanTool / ReminderTool 等工具的状态已改为实例字段，
/// 随各自 ToolRegistry 实例隔离，无需在此清理。
Future<void> resetDependencies() async {
  ForegroundService.reset();
  await AppDatabase.instance.close();
  await getIt.reset();
}
