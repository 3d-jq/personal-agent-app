/// 本地持久化数据源接口。
///
/// 只负责“读/写原始对象列表”，不持有内存缓存或通知逻辑。
abstract interface class LocalDataSource<T> {
  Future<List<T>> readAll();
  Future<void> writeAll(List<T> items);
}
