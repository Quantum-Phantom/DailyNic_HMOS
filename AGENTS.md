
# AGENTS.md — DailyNic-openclaw (妮可之记 · 龙虾版)

> HarmonyOS NEXT 校园导航应用 · AI 开发指南

## 项目概述

**妮可之记 (DailyNic)** 是一个面向中国科大（USTC）的 HarmonyOS NEXT 校园一站式导航应用。
- **定位**：课表/考试管理 + 校园功能链接聚合 + 内置浏览器
- **开源协议**：GPLv3
- **目标设备**：phone / tablet / 2in1（多端适配）
- **API 版本**：compatibleSdkVersion 5.1.0(18)，targetSdkVersion 6.0.0(20)
- **构建工具**：Hvigor（hvigorfile.ts），ohpm 包管理
- **主入口**：`EntryAbility.ets` → `pages/Index`

---

## 目录结构与职责

```
AppScope/                     # 应用基本信息、全局资源

entry/src/main/
├── module.json5              # 模块配置：权限、Ability、卡片声明、启动图标
├── resources/
│   ├── base/                 # 浅色模式资源（element/color/string, media, profile）
│   ├── dark/                 # 深色模式资源（必须与 base 同名对称）
│   └── rawfile/              # HTML 原始文件（用户协议、功能页内嵌网页等）
│
└── ets/
    │
    ├── entryability/
    │   └── EntryAbility.ets          # [核心] UIAbility 入口，初始化偏好设置、恢复模式判断、路由跳转
    ├── entrybackupability/
    │   └── EntryBackupAbility.ets    # 备份扩展能力
    ├── entryformability/
    │   └── EntryFormAbility.ets      # 服务卡片生命周期管理
    │
    ├── pages/                         # 📄 页面层（@Entry + @Component struct）
    │   ├── Index.ets                  # [核心] 主页面：Tabs 底部导航 + 今日课程/考试 + 功能入口
    │   ├── Webview.ets                # 内置浏览器页面
    │   ├── Schedule.ets               # 本地课表展示（周视图）
    │   ├── ExamDetail.ets             # 考试信息详情/管理
    │   ├── GetSchedule.ets            # 在线课表 & 考试同步（教务系统爬取）
    │   ├── ThemeSetting.ets           # 主题/背景图/颜色设置
    │   ├── CheckinCollection.ets      # 签到集合页
    │   ├── AddCard.ets                # 手动添加课程/考试
    │   ├── GetClassByName.ets         # 按名称查课
    │   ├── Help.ets / About.ets       # 帮助 & 关于
    │   ├── Declaration.ets            # 用户协议
    │   ├── UpdateLog.ets              # 更新日志
    │   └── FaultOccurred.ets          # 恢复模式页面
    │
    ├── constants/                     # 📦 纯数据/常量定义
    │   ├── ScheduleSources.ets        # 课表数据模型（classAttribute, semesterAttribute 等）
    │   ├── GridListDataSources.ets    # 功能页 GridData 数据源
    │   ├── GridListIcons.ets          # 功能页图标映射
    │   ├── Links.ets                  # 功能页 URL 链接表
    │   ├── ListDataConstants.ets      # 功能页分区标题
    │   ├── SettingsSources.ets        # 设置选项数据
    │   ├── UserAgent.ets              # WebView UA 字符串
    │   └── BasicConstants.ets         # 版本号、设备类型等基础常量
    │
    ├── utils/                         # 🔧 业务逻辑 / 工具类
    │   ├── ScheduleManager.ets        # [核心] 多学期课表管理（CRUD、持久化、默认学期）
    │   ├── ExamManager.ets            # 考试信息管理类
    │   ├── CheckIn.ets                # 签到逻辑
    │   ├── FunctionOrder.ets          # 最常访问功能排序统计
    │   ├── tools.ets                  # 公共工具函数（颜色、数组操作等）
    │   ├── UnifyPreference.ets        # [核心] 统一偏好设置封装（Preferences 持久化）
    │   ├── WriteCalendar.ets          # 系统日历读写
    │   ├── BgImageManager.ets         # 背景图片管理
    │   ├── Encryption.ets             # RSA 加密接口（⚠️ 有 .bak 占位文件）
    │   ├── WantAbility.ets            # Want 跳转工具
    │   └── jsencrypt/                 # 第三方 JSEncrypt 库
    │
    ├── view/                          # 🎨 可复用 UI 组件（@Component struct，非 @Entry）
    │   ├── GridComponent.ets          # 功能网格组件（带排序、弹窗）
    │   ├── SettingsComponent.ets      # 设置项列表组件
    │   ├── PasswordDialog.ets         # 密码输入对话框
    │   ├── CustomClickDialog.ets      # 自定义点击对话框
    │   ├── RenameDialog.ets           # 重命名对话框
    │   ├── MultiPageMenu.ets          # 多页菜单组件
    │   └── UpdateInfo.ets             # 更新信息组件
    │
    └── class_schedule_daily/                    # 📋 今日课表服务卡片（Form）
        ├── pages/Class_schedule_dailyCard.ets   # 卡片入口 @EntryForm
        ├── view/CardListComponent.ets           # 卡片 UI 框架
        └── viewmodel/CardListParameter.ets      # 卡片数据构造
```

**另外还有 `exam_info/` 目录结构同 `class_schedule_daily/`**，是考试信息卡片。

---

## 开发范式与约定

### 架构模式：MVVM 变体

| 层 | 职责 | 约束 |
|---|------|------|
| **pages/** | 页面容器（@Entry）+ Tabs/Nav 路由编排 | 只做布局组装和事件分发，不写业务逻辑 |
| **view/** | 可复用 UI 组件（@Component） | 通过 @Prop/@Link/@BuilderParam 接收数据 |
| **utils/** | 业务逻辑、状态管理、网络/加密 | 纯逻辑，不导入任何 ArkUI 组件 |
| **constants/** | 数据模型接口、常量、资源索引 | 纯数据，零副作用 |

### 页面路由机制

项目使用 **两种路由方式并存**：

1. **main_pages.json（全局路由）**：首页、恢复模式、声明、更新日志等基础页面
2. **router_map.json（动态路由）**：大部分功能页面通过 `router.pushNamedRoute()` 导航

添加新页面时：
- 如果是独立完整页面 → 在 `router_map.json` 注册，导出 `@Builder function XxxBuilder()`
- 如果是启动时就需要的基础页面 → 加入 `main_pages.json` 的 `src` 数组

### 状态管理

- **本地持久化**：统一通过 `UnifyPreference`（基于 Preferences API），键值对存储
- **UI 状态**：`@State` / `@Prop` / `@Link` / `@Provide` / `@Consume` / `@StorageLink`
- **全局状态**：通过 `AppStorage` 或 `UnifyPreference` 读写
- **跨页面通信**：`eventHub`（如 EntryAbility → Index 的路由跳转）

### 关键生命周期

```
EntryAbility.onCreate()
  → UnifyPreference.init(context)
  → 判断恢复模式（FaultOccurred/RecoveryMode）

EntryAbility.onWindowStageCreate()
  → 恢复模式？→ loadContent('pages/FaultOccurred')
  → 正常？     → loadContent('pages/Index') + eventHub 发射 navigation 事件

EntryAbility.onForeground()  → 标记 FaultOccurred=true
EntryAbility.onBackground()  → 标记 FaultOccurred=false
```

### 组件装饰器规范

```typescript
// 页面入口（可独立导航到的页面）
@Entry
@Component
struct PageName {
  // ...
}

// 可复用 UI 组件
@Component
export default struct ComponentName {
  @Prop xxx: Type
  @Link yyy: Type
  // ...
}

// 服务卡片入口
@EntryForm
@Component
struct FormName {
  // ...
}

// 页面路由 Builder 函数（动态路由页面必须导出）
export function PageNameBuilder() {
  // ...
}
```

### 资源管理

- **字符串/颜色**：使用 `$string:xxx` / `$color:xxx` 引用，定义在 `resources/base/element/`
- **媒体资源**：`$media:xxx`，放在 `resources/base/media/`
- **深色适配**：`resources/dark/` 下必须存在同名资源（尤其是 color.json 和图标 SVG）
- **分层图像**：使用 `layered_image.json` 配置（启动图标等场景）

### 导入风格

```typescript
// 系统 Kit 导入（按 Kit 分组）
import { UIAbility, Want } from '@kit.AbilityKit';
import { router, window } from '@kit.ArkUI';

// 项目内部导入（相对路径）
import ScheduleManager from '../utils/ScheduleManager';
import { classAttribute } from '../constants/ScheduleSources';
import GridComponent from '../view/GridComponent';
```

---

## 编码规范

### 代码检查

项目配置了 `code-linter.json5`，运行：
```bash
codelinter -f json --fix .
```
- 必须修复所有 `"severity":"error"` 级别问题
- 安全规则：禁止不安全的 AES/RSA/ECDSA 等加密实现（`@security/*` 规则集）
- 同时启用 TypeScript ESLint 推荐规则和性能推荐规则

### 注释语言

- **代码注释**：中文为主（面向中文开发者团队）
- **JSDoc**：函数使用 `@param` / `@returns` 标注，支持中英混合
- **特殊标记**：`⚠️` 标注注意事项（如 Encryption.ets.bak 占位文件）

### 文件命名

- 页面：`PascalCase.ets`（如 `GetSchedule.ets`）
- 组件：`PascalCase.ets`（如 `GridComponent.ets`）
- 工具类：`PascalCase.ets`（如 `ScheduleManager.ets`）
- 常量：`PascalCase.ets`（如 `ScheduleSources.ets`）
- 卡片目录：`snake_case`（如 `class_schedule_daily/`）

---

## 敏感文件（⚠️ 请勿提交密钥）

| 文件 | 说明 |
|------|------|
| `build-profile.json5` | 包含签名证书路径和密码 |
| `utils/Encryption.ets` | RSA 密钥硬编码（有 `.bak` 占位版本供公开） |
| `.hvigor/` | 构建缓存，不需要版本控制 |

对应占位/模板文件：
- `build-profile.json5.bak` → 公开模板
- `utils/Encryption.ets.bak` → 加密接口存根

---

## 常见开发任务指引

### 添加新功能页面

1. 在 `ets/pages/` 创建 `NewPage.ets`，使用 `@Entry @Component struct NewPage { }` + 导出 `NewPageBuilder`
2. 在 `router_map.json` 注册路由条目
3. 如需新资源，在 `base/element/` 和 `dark/element/` 同步添加
4. 从某页面调用 `router.pushByName({ name: 'NewPage', param: {} })`

### 添加新的校园链接

1. 编辑 `constants/Links.ets` 添加 LINK 枚举值和 URL
2. 在 `constants/GridListDataSources.ets` 对应分组添加 GridData 条目
3. 在 `constants/GridListIcons.ets` 添加图标映射
4. 在 `constants/ListDataConstants.ets` 添加分区标题（如需新分组）
5. 在 `base/media/` 和 `dark/media/` 添加图标 SVG/PNG

### 修改课表数据模型

1. **先改** `constants/ScheduleSources.ets` 的接口/类型定义
2. **再改** `utils/ScheduleManager.ets` 的 CRUD 逻辑
3. **最后改** `pages/Index.ets` / `pages/Schedule.ets` 的展示层
4. 运行 `codelinter -f json --fix .` 检查

### 修改服务卡片

1. 卡片代码在 `class_schedule_daily/` 或 `exam_info/` 目录下
2. 注意卡片环境限制：不可用 router、部分 API 受限
3. 通过 `formBindingData` 更新卡片数据
4. 修改后需重新添加卡片到桌面预览

---

## 技能约束（来自 harmonyos-dev 技能）

1. **不确定就查文档**：API 签名、入参、返回值以 `references/` 内离线文档为准，不凭经验补全
2. **ArkUI 优先声明式**：使用 `@Entry` / `@Component` / `build()` 模式（除非文档明确是 NDK 或系统服务）
3. **每次子任务完成后**运行 `codelinter -f json --fix .` 并修复 error 级别问题
4. **Git 操作前询问用户**
