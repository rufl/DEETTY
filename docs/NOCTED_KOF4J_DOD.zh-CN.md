# NoctEd KOF4J 兼容性完成定义

状态：**开放验收门槛**。NoctEd 当前已有通用语言导入、语法发现、本地
linter/LSP 传输、诊断、补全、悬停、定义、引用、重命名、符号和格式化界面。
本文件新增 KOF4J 项目专项要求；这些通用能力本身不代表 KOF4J 兼容。

必须在保留收据中锁定 KOF4J 项目基准、仓库 revision、构建/语言清单、linter
配置和版本、LSP 配置和 server 版本，以及所有需要的本地工具。NoctEd 不得
静默下载工具，也不得替换项目配置。

## 当前实现基线（不代表验收关闭）

当前源码树已同时保留官方 `source.kof` TextMate 输入和生成的 GtkSourceView
`kof.lang` 定义，其中包含语法声明的嵌套字符串、函数和类上下文。NoctEd 将
`.kf`、`.kof` 映射到 `kof lsp`，并在 Kof 工具项目中调用本地发行版的
`check`、`build`、`test`。脚本
`scripts/nocted_kof4j_qualification.sh` 会对指定的真实发行版执行资格检查，
但收据仍为 `status=partial`：尚未提交规范 fixture manifest、完整的已声明能力
矩阵、生命周期收据，或隔离的 native Debug/`ReleaseSafe` 证据。

## 固定 DoD

只有在每个发布声明支持的 NoctEd 目标上，KOF4J 基准项目通过以下全部条件后，
该门槛才可关闭：

1. **100% 语言覆盖。** 清单中的每一种 KOF4J 源文件、会被打开的生成文件、配置、
   模板和文档文件类型，都必须以正确的 NoctEd language identity 打开，并提供
   完整声明的语法/高亮行为。未支持或误识别文件必须为零；跳过的文件类别必须
   在 fixture manifest 中明确批准。
2. **100% linter 兼容。** NoctEd 必须从项目根目录发现并调用确切的 KOF4J
   linter 和项目配置，保留工作目录及参数，并正确显示每条 fixture 诊断的文件、
   范围、严重级别、消息和版本。干净输出、警告、错误、非零退出、格式错误输出、
   取消、超时和可执行文件缺失都必须有明确可观察结果；不得静默丢弃或伪造诊断。
3. **100% 必需 LSP 兼容。** NoctEd 必须通过有界 stdio JSON-RPC 路径启动确切的
   KOF4J language server 和配置。每项 KOF4J 要求的能力——初始化、workspace
   root、打开/变更版本、诊断、补全、悬停、定义、引用、重命名、文档符号、格式化、
   取消、重启和关闭——在 server 宣布支持时都必须通过项目 fixture。未支持的
   server 能力必须明确报告，不能当作成功。
4. **项目生命周期兼容。** 打开、重新加载、重命名、嵌套模块、生成物/vendor
   忽略、未保存缓冲区、多文件、server 重启、linter 失败和 NoctEd 干净退出，都
   必须保留项目根、语言、linter 和 LSP 状态，且不能残留旧诊断或跨项目泄漏。
5. **证据完整性。** 收据必须标识 KOF4J revision、确切工具/server 版本、配置摘要、
   NoctEd commit 和包摘要、实际覆盖的语言/linter/LSP 案例、批准的未支持案例、
   失败、跳过和主机/backend。Debug、`ReleaseSafe` 以及原生 NoctEd smoke 都必须
   通过；源代码检查、只打开一个文件或 mock server 都不能关闭门槛。

验收收据必须包含
`nocted_kof4j_compatibility languages=100% linter=100% lsp=100% lifecycle=true`，
且在每个 fixture manifest 行通过前不得使用 `100%`。
