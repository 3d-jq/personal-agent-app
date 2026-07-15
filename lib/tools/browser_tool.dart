// Browser tools barrel — re-exports from browser/ subdirectory.
// Split from original 1261-line single file into 4 domain files:
//   browser_core.dart          Base class + plugin
//   browser_nav_tools.dart     Goto, back, close, scroll, wait
//   browser_interact_tools.dart Click, type, select, hover, fill, evaluate, screenshot
//   browser_data_tools.dart    Snapshot, getText, findElements, search, cookies, config

export 'browser/browser_core.dart';
export 'browser/browser_nav_tools.dart';
export 'browser/browser_interact_tools.dart';
export 'browser/browser_data_tools.dart';
