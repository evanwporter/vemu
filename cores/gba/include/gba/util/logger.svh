`ifndef GBA_UTIL_LOGGER_SVH
`define GBA_UTIL_LOGGER_SVH

// Runtime-configurable logging. The selected level and all more-severe levels
// are enabled. With no plusarg, logging is disabled.
`define __GBA_LOG_ENABLED_TRACE \
  ($test$plusargs("gba-log-trace"))
`define __GBA_LOG_ENABLED_INFO \
  (`__GBA_LOG_ENABLED_TRACE || $test$plusargs("gba-log-info"))
`define __GBA_LOG_ENABLED_WARN \
  (`__GBA_LOG_ENABLED_INFO || $test$plusargs("gba-log-warn"))
`define __GBA_LOG_ENABLED_ERROR \
  (`__GBA_LOG_ENABLED_WARN || $test$plusargs("gba-log-error"))

`define __GBA_LOG(level, msg) \
  $display("[%s] [%0t] %s", level, $time, $sformatf msg);

`define LOG_TRACE(msg) \
  if (`__GBA_LOG_ENABLED_TRACE) `__GBA_LOG("TRACE", msg)
`define LOG_INFO(msg) \
  if (`__GBA_LOG_ENABLED_INFO) `__GBA_LOG("INFO", msg)
`define LOG_WARN(msg) \
  if (`__GBA_LOG_ENABLED_WARN) `__GBA_LOG("WARN", msg)
`define LOG_ERROR(msg) \
  if (`__GBA_LOG_ENABLED_ERROR) `__GBA_LOG("ERROR", msg)

`endif
