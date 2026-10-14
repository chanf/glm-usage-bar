# PRD — GLM Usage Bar

## 1. 背景与目标

智谱 GLM Coding Plan 采用「5 小时 Token 池 + 每周额度 + MCP 月度额度」的多级配额机制，官方只能登录网页查看，开发者在写代码时无法随时感知余量，容易在额度耗尽时中断工作。

**目标**：在 macOS 菜单栏常驻一个轻量工具，一眼看到当前最吃紧的额度，并可下钻查看各额度明细，做到"不打断编码、不打开网页"。

**成功标准**：

- 菜单栏常驻显示百分比，刷新及时（默认 ≤ 5 分钟）
- 单次查询耗时 < 2s，内存占用 < 50MB，CPU 近零
- 无 API Key 时零配置可启动，出错不崩溃、有可读提示

## 2. 目标用户

- 订阅了 GLM Coding Plan（Lite / Pro / Max）的个人开发者
- 同时使用智谱国内站（open.bigmodel.cn）或 z.ai 国际站的用户

## 3. 功能需求

### 3.1 菜单栏主显示（P0）

| 项 | 说明 |
| --- | --- |
| 形态 | SF Symbol 仪表盘图标 + 百分比数字，跟随系统深浅色 |
| 数值 | 所有额度中**使用率最高**的一项（最吃紧者） |
| 副作用 | 无数据时显示 `…`，查询失败显示 `!` + `—` |
| 悬停 | Tooltip 列出套餐等级与各额度使用率 |

### 3.2 下拉菜单（P0）

- 套餐等级（如 `套餐：lite`）
- 每个额度一行：`名称 + 百分比 + 进度条`，进度条按使用率变色：
  - < 80% 绿色；80% ~ 90% 红色；≥ 90% 深红
- 额度明细行：剩余量 / 已用与总量 / 重置时间
- 模型与工具分项消耗（按消耗降序）
- 上次更新时间
- 操作项：立即刷新、更换 API Key、开机自动启动、退出
- 所有文字使用正文色，禁用态灰字不可接受

### 3.3 数据获取（P0）

```
GET {endpoint}/api/monitor/usage/quota/limit
Authorization: <API Key>
Accept-Language: en-US,en
```

- 国内站默认 `https://open.bigmodel.cn`，国际站 `https://api.z.ai`
- 使用率优先用 `usage / (usage + remaining)` 现算，接口只给 `percentage` 时兜底
- 容忍 HTTP 200 + 业务错误码（`success:false`），错误信息原样展示
- 超时 15s；后台线程请求，主线程刷新 UI

### 3.4 刷新机制（P0）

- 默认每 300 秒自动刷新，可配置
- 支持手动「立即刷新」；重复请求自动取消上一次

### 3.5 API Key 管理（P0）

- 首次启动无 Key：菜单提示设置
- 弹窗输入，支持 `Cmd+V` 粘贴与「粘贴」按钮兜底；弹窗必须延迟到菜单关闭后出现
- 保存至 `~/.config/glm-usage-bar/config.json`，文件权限 600
- 支持环境变量 `ZHIPU_API_KEY` 覆盖
- 不写日志、不上报、不进 shell 历史

### 3.6 开机自动启动（P1）

- 基于 `SMAppService`，需安装为 `.app` 才可用，菜单项显示勾选状态

### 3.7 命令行调试（P1）

```bash
GlmUsageBar --print
```

一次性拉取并打印各额度原始数据，用于排查接口问题；退出码非 0 表示失败。

## 4. 非功能需求

- **兼容**：macOS 13+，Apple Silicon / Intel
- **体量**：纯 AppKit/SwiftPM 实现，零第三方依赖；DMG ≤ 3MB
- **形态**：菜单栏应用（`LSUIElement`），不出现在 Dock
- **健壮**：网络异常、Key 失效、响应字段缺失均降级为菜单内提示，不崩溃
- **国际化**：界面中文；接口 `Accept-Language: en-US`（智谱接口对该语言返回稳定字段）

## 5. 技术方案

| 模块 | 文件 | 职责 |
| --- | --- | --- |
| 入口 | `Sources/GlmUsageBar/main.swift` | accessory 模式启动；`--print` 调试分支 |
| 配置 | `Config.swift` | 读写 `~/.config/glm-usage-bar/config.json` |
| 接口 | `QuotaClient.swift` | 请求、业务错误识别、额度模型解析、进度条文本 |
| 界面 | `StatusItemController.swift` | 状态栏渲染、菜单构建、定时刷新、设置弹窗、开机自启 |
| 图标 | `scripts/make-icon.swift` | CoreGraphics 绘制仪表盘图标 → iconset → icns |
| 打包 | `scripts/build-app.sh` / `build-dmg.sh` | 生成 `.app` 与 `.dmg` |

数据流：`Timer / 手动触发 → QuotaClient.fetch（后台）→ QuotaSnapshot（主线程）→ 状态栏 + 菜单重建`。

## 6. 交付物

- `dist/GlmUsageBar.app` — 可直接运行
- `dist/GlmUsageBar.dmg` — 含 Applications 快捷方式的安装镜像
- `dist/GlmUsageBar.icns` — 应用图标源文件

## 7. 后续规划（Backlog）

- 额度接近上限时系统通知（5 小时池 > 90% 等）
- 分模型消耗趋势图（接入 `model-usage` 接口）
- 多账号切换（z.ai / bigmodel 同时监控）
- 自定义刷新间隔的菜单入口（当前需改配置文件）
- 正式签名与公证，消除 Gatekeeper 提示
