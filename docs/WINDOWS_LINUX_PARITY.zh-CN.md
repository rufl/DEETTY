# Linux / Windows 原生功能对照矩阵

最后更新：2026-10-02。

这是 [BACKLOG.md](../BACKLOG.md#nct-127-fixed-definition-of-done) 中 NCT-127
固定 DoD 要求的源代码树对照清单。它记录实现和辅助证据，但不会把交叉编译、
Wine、回环连接或隔离运行器结果误记为真实 Windows 验收。

状态含义：

- **implemented** — 原生代码路径已经实现该能力。
- **supporting** — 专项策略测试、原生 smoke、交叉编译或 Wine 已覆盖部分能力。
- **physical-open** — 支持的 Windows 10/11、真实 ConPTY、Win32/GDI、DPI、高对比度、
  IME、辅助功能、生命周期和干净退出证据仍未完成。
- **external-open** — 真实 Linux↔Windows 主机、路由 VPN、身份切换和收据一致性仍未完成。

| ID | 能力 | Linux 实现 / 证据 | Windows 实现 / 证据 | 当前状态 | 剩余门槛 |
|---|---|---|---|---|---|
| `terminal-io` | 终端输入输出、VT、调整大小、回滚 | Zig VT + POSIX PTY；原生主机与运行时 smoke | Zig VT + ConPTY + GDI；交叉编译与主机 harness | implemented / supporting | physical-open |
| `tabs` | 新建、选择、重命名、排序、关闭标签 | GTK notebook、持久身份、原生 smoke | Win32 标签控件、受限 Unicode 重命名、拖拽/排序模型、Wine 控件测试 | implemented / supporting | physical-open |
| `recursive-splits` | 递归分屏树和 pane 生命周期 | GTK 分屏树、比例策略、原生 smoke | 有界 workspace 树、比例策略、每 pane 一个 ConPTY、Wine 控件测试 | implemented / supporting | physical-open |
| `focus` | 键盘、指针、活动 pane/tab 切换 | GTK 焦点桥接与快捷键 lane | Win32 消息路由、标签焦点、pane 选择策略 | implemented / supporting | physical-open |
| `selection-scrolling` | 选区、剪贴板、鼠标上报、滚动 | GTK 选区/剪贴板运行时 smoke | Win32 Unicode 选区、剪贴板、鼠标策略与 policy 测试 | implemented / supporting | physical-open |
| `profiles` | 内置/自定义启动配置和环境 | Zig 配置模型与 PTY 启动 | 原生配置对话框、NWS5 持久化、launch-plan 与 Wine 证据 | implemented / supporting | physical-open |
| `themes` | 主题选择、导入导出、持久化 | GTK 主题库与源格式导入 smoke | 原生选择器、事务式源格式导入、文件与 Wine 证据 | implemented / supporting | physical-open |
| `persistence` | workspace 保存/恢复与身份恢复 | autosave/workspace 快照与运行时 smoke | 版本化 NWS5 标签/分屏/配置 envelope 与 policy 测试 | implemented / supporting | physical-open |
| `smart-tabs` | 标签、过滤器、空状态恢复 | GTK 标签/过滤器桥接与维护 smoke | Win32 标签过滤器与 Ctrl+Alt+Space 入口 | implemented / supporting | physical-open |
| `dropdown-hotkey` | 下拉展示与全局快捷键 | Plasma/Noctalia 展示与快捷键证据 | Win32 可见性切换与菜单状态 | implemented / supporting | physical-open |
| `nocted` | 原生编辑器交接、标签、搜索、持久化 | Zig NoctEd 主机与项目 smoke | 独立 `nocted.exe`、Win32 主机与 qualification harness | implemented / supporting | physical-open |
| `sharing` | 配对、发现、远程视图、权限 | 原生 sharing 与 Linux 运行时 lane | 原生配对对话框、GDI 远程视图、主机批准的输入 | implemented / supporting | external-open + physical-open |
| `status-strip` | 模式/标签/pane/配置的紧凑上下文栏 | 现有原生 workspace 信息条 | 新增 DPI 感知 GDI 页脚，预留终端高度并显示模式、标签、pane、配置 | implemented | physical-open |

## 收据约定

源代码树检查保持有界。运行：

```sh
./scripts/check_windows_linux_parity.sh
```

它输出锁定 commit、行数以及开放的物理/外部门槛。未来的物理收据还必须标识
相同 commit、精确的包/归档摘要、支持的主机版本、实际覆盖的能力以及明确的跳过/失败。
本地 ztash 打包流程仅用于 build，报告 `remote_deployment=not_performed`；它不是
Windows 主机或跨机器收据。

矩阵本身不会关闭 NCT-127。剩余验收工作是：在真实支持的 Windows 10/11 上使用
ConPTY 和物理输入执行，然后在目标网络边界上执行真实 Linux↔Windows sharing。
发布签名、发布、依赖包再分发审查、合成器验收和经同意的 HID 仍属于独立的
Release Operations 门槛。
