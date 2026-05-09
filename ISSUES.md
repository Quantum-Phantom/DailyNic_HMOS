# ISSUES.md — 项目可优化点汇总

> 审查日期：2026-05-09 | 分支：openclaw

---

## 🔴 高优先级（性能 / 稳定性）

### 1. Index.ets ForEach 中读取 @State 变量 — 性能警告
- **位置**：`entry/src/main/ets/pages/Index.ets:269`
- **规则**：`@performance/hp-arkui-no-state-var-access-in-loop`（codelinter 已报）
- **问题**：在 ForEach 循环体内部直接访问 `this.currentTime.getTime()` 等 @State 变量，ArkUI 框架无法优化渲染追踪，每次状态变化都会重建整个 ForEach。
- **建议**：将循环依赖的 State 值提前缓存到局部变量中再传入 ForEach。

### 2. 多处 ForEach 缺少 keyGenerator（15+ 处）
- **位置**：
  - `Index.ets:551,653,753,937,939`
  - `Schedule.ets:450,612,918,981,1330,1718`
  - `Help.ets:33`
  - `MultiPageMenu.ets:15,31,43`
  - `CheckinCollection.ets:32`
  - `ExamDetail.ets:459`
  - `GetSchedule.ets:474`
  - `ThemeSetting.ets:329`
- **规则**：`@performance/foreach-args-check`（codelinter 已报）
- **问题**：缺少 keyGenerator 导致列表 diff 效率低下，增删项时可能渲染错误。
- **建议**：为所有 ForEach 添加唯一的 keyGenerator 函数。

### 3. ExamManager.ets 循环内重复创建 Date 对象
- **位置**：`entry/src/main/ets/utils/ExamManager.ets:46-47`
- **规则**：`@performance/reuse-date-instances-check`（codelinter 已报）
- **问题**：`storeExam()` 和 `addExam()` 中每次都 `new Date(...)` 解析同一格式字符串。
- **建议**：提取日期解析为独立函数，避免重复创建。

### 4. UnifyPreference.putSync() 每次写入都立即 flush
- **位置**：`entry/src/main/ets/utils/UnifyPreference.ets` → `putSync()`
- **问题**：每次 putSync 都调用 `this.flush()`（异步 IO）。而 ScheduleManager 的 `coverExistSemester`、`newSemester` 等方法在一次操作中可能连续调用 putSync 多次，每次都触发磁盘刷盘。
- **建议**：引入批量写入模式（beginBatch/endBatch），或至少将 flush 改为延迟/debounce。

---

## 🟡 中优先级（代码质量 / 维护性）

### 5. shrinkContArrayToString 存在逻辑缺陷
- **位置**：`entry/src/main/ets/utils/tools.ets` → `shrinkContArrayToString()`
- **问题**：
  - 数组只有一个元素时输出格式异常（如 `"---0"` 而非 `"1"`）
  - 非连续开头的数组（如 `[1,3,5]`）输出缺少起始数字（`"-1, 3-5"`）
- **影响**：课表"节数"展示文本可能显示不正确。
- **建议**：使用标准区间压缩算法重写。

### 6. deleteAIHelper JS 中条件恒真
- **位置**：`entry/src/main/ets/utils/tools.ets` → `deleteAIHelper` 常量
- **问题**：`if (!isRemoved || true)` 中 `|| true` 使条件永远为 true，`isRemoved` 变量无意义，MutationObserver 总会被创建。
- **建议**：如果是有意保留完整监听逻辑，删除无用变量和判断；如果原本意图是"首次没删掉才监听"，改为 `if (!isRemoved)`。

### 7. Webview.ets eachDownloadPercent 使用模块级全局 Map
- **位置**：`entry/src/main/ets/pages/Webview.ets` 顶部
- **问题**：`let eachDownloadPercent = new Map<string, number>()` 是模块级变量。Webview 页面多次创建销毁时旧数据不会被清理。
- **建议**：移入 struct 内部作为成员变量，在 aboutToAppear 中清理。

### 8. ScheduleManager 大量使用 JSON 序列化/反序列化做深拷贝
- **位置**：`entry/src/main/ets/utils/ScheduleManager.ets` 全文
- **问题**：几乎每个方法都 `JSON.parse(UnifyPreferences.getSync(...))` 从 Preferences 读原始字符串再解析。`coverExistSemester` 一次操作中可能 parse 同一数据 2-3 次。JSON.parse 对于大数据量课表是 CPU 密集操作。
- **建议**：在 ScheduleManager 内增加内存缓存层（读一次后缓存解析结果），仅在数据变更后重新 parse。

### 9. Index.ets aboutToAppear 包含大量混合职责
- **位置**：`entry/src/main/ets/pages/Index.ets` → `aboutToAppear()`
- **问题**：约 40 行代码，混合了事件注册、签到加载、课表刷新、日历初始化、背景图初始化、版本检测、旧版数据迁移等完全不同的职责。迁移逻辑是一次性操作，不应每次启动都走判断路径。
- **建议**：拆分为独立方法；迁移逻辑用独立的 migration 版本号标记完成状态。

### 10. 通配符 import（11 处）
- **位置**：
  - `Index.ets:8,13,15`
  - `Schedule.ets:3,6`
  - `GridComponent.ets:4,5`
  - `ExamDetail.ets:3`
  - `WriteCalendar.ets:6,9`
  - `EntryFormAbility.ets:6`
  - `Exam_infoCard.ets:4`
- **规则**：`@performance/no-use-any-import`（codelinter 已报）
- **问题**：通配符导入会增加编译产物体积，且不利于 tree-shaking。
- **建议**：按需导入实际使用的符号。

---

## 🟢 低优先级（体验 / 健壮性）

### 11. ThemeSetting.ets 颜色选择器手势可能冲突
- **位置**：`entry/src/main/ets/pages/ThemeSetting.ets` 环形颜色选择器 Stack
- **问题**：使用 TapGesture + PanGesture 组合的 GestureGroup(Exclusive) 实现选色。在部分设备上可能与子组件（Progress）触摸产生冲突，导致偶尔选不中。
- **建议**：考虑改用 `.onClick()` + `.onTouch()` 或在 Progress 上直接绑定点击事件。

### 12. GetSchedule.ets 新建学期名称不够智能
- **位置**：`entry/src/main/ets/pages/GetSchedule.ets` → `selectTerm()` Builder
- **问题**：新建学期名称硬编码为 `'自定义名称'`，不会根据当前季节/学年自动生成。
- **建议**：根据当前月份自动生成默认名称（如 "2025-2026 春季学期"）。

### 13. 硬编码中文字符串未走国际化
- **位置**：多处 .ets 文件
- **示例**：
  - `GetSchedule.ets`：`'嘿咻——拿到啦！'`、`'名称'`、`'新建或选择已有学期以保存课表'`
  - `Index.ets`：`'计算中…'`
  - `ThemeSetting.ets`：`'名称'`、`'学期开始日期'`
- **建议**：统一迁入 `string.json`，为未来可能的国际化预留。

### 14. .bak 占位文件 gitignore 风险
- **位置**：`entry/src/main/ets/utils/Encryption.ets.bak`
- **问题**：`.gitignore` 未明确忽略 `*.bak`，敏感占位文件可能被误提交。
- **建议**：确认 `.gitignore` 覆盖 `*.bak`。

### 15. EntryAbility setColorMode 连续调两次且有 try-catch 吞错误
- **位置**：`entry/src/main/ets/entryability/EntryAbility.ets` → `onCreate` + `onWindowStageCreate`
- **问题**：onCreate 先设 COLOR_MODE_NOT_SET，onWindowStageCreate 又从 Preferences 读取设置一次，冗余。catch 块只 console.error 不做降级。
- **建议**：合并为一次设置；对失败增加 fallback（如默认浅色）。

---

## 📊 汇总

| 优先级 | 数量 | 关键词 |
|--------|------|--------|
| 🔴 高 | 4 | ForEach 渲染性能、Date 重复创建、Preferences 频繁 flush |
| 🟡 中 | 6 | 字符串处理 bug、死代码、全局变量污染、JSON 反序列化冗余、aboutToAppear 臃肿、通配符导入 |
| 🟢 低 | 5 | 手势冲突风险、自动命名、国际化、gitignore、setColorMode 冗余 |
