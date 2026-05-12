# lark-codex-bridge

用飞书/Lark 机器人在手机上远程控制本机 Codex CLI。每个飞书聊天就是一个手机终端窗口：普通消息会作为 terminal task 发送给 Codex，机器人先给原消息添加 `OK` 表情，再回复一张运行中卡片；后续进度、空闲状态和最终结果优先更新同一张卡片。

> 安全提醒：这个桥接会让指定飞书/Lark 用户远程触发你电脑上的 Codex。默认优先使用 Codex `app-server` 的审批模型，并通过飞书交互卡片按钮处理 approval；旧 `exec` 后端才会读取 `LARK_CODEX_DANGEROUS_BYPASS`。

## 功能

- 直接发消息给机器人，让 Codex 执行任务。
- 忙时自动排队。
- 每个飞书/Lark 聊天（DM/群）都是一个独立“终端窗口”：状态按 `chat_id` 隔离。
- 普通消息默认是可恢复 terminal task：长超时、job 记录、超时后可 `continue`。
- 每个任务优先使用同一张 running card：`QUEUED / RUNNING / PAUSED / DONE / FAILED`。
- 查看 Codex 会话目录，并用编号选择会话。
- `切换 1` 后常驻绑定本地 Codex 会话，普通消息会无缝进入当前会话（直到 `清除会话`）。
- 同步会话进度，像手机上的轻量终端流（默认只在有新事件时推送；无新内容时只更新同卡状态行）。
- 在同步期间直接给当前会话继续发消息。
- 输出默认使用 Card JSON 2.0：主内容清爽可读，元信息放在折叠区（默认收起）。
- 支持长任务：更长超时、任务记录、部分产物追踪，以及失败后 `继续任务`。
- 支持 Codex `app-server` 后端：远程消息进入同一个 Codex thread，审批、sandbox、用户输入请求通过飞书按钮或文本 fallback 处理。
- 支持 `screen` 后台运行。

## 依赖

macOS 上需要这些命令：

- `bash`
- `jq`
- `curl`
- `sqlite3`
- `lark-cli`
- `codex`
- `screen`
- `node`

Codex CLI 和 lark-cli 需要先能在终端里正常运行。

## 安装

```bash
git clone https://github.com/YOUR_NAME/lark-codex-bridge.git
cd lark-codex-bridge
./scripts/install.sh
```

安装脚本会创建：

```text
~/.lark-codex/.env
```

然后编辑这个文件，填入你的飞书/Lark App 信息和允许控制 Codex 的用户 open_id：

```bash
LARKSUITE_CLI_APP_ID=cli_xxxxxxxxxxxxxxxxx
LARKSUITE_CLI_APP_SECRET=replace_me
LARK_CODEX_ALLOWED_SENDER=ou_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## 飞书/Lark App 配置

1. 在飞书/Lark 开放平台创建自建应用。
2. 开启机器人能力。
3. 给应用添加收发消息所需权限。
4. 配置事件订阅，让应用能接收 `im.message.receive_v1`。
5. 如需飞书按钮审批，配置卡片回传交互 `card.action.trigger`。
6. 发布/启用应用，并把机器人添加到你要使用的会话里。
7. 获取你的用户 `open_id`，填入 `LARK_CODEX_ALLOWED_SENDER`。

权限建议：

- 基础体验：接收消息、以机器人身份回复消息。
- 完整体验：再添加 `im:message.reactions:write_only`，用于收到消息后添加 `OK` 表情。
- 完整 TUI：再添加 `im:message:update`，用于把进度和最终结果 patch 到同一张 running card（失败会自动降级，不影响核心功能）。
- 按钮审批：启用卡片回传交互 `card.action.trigger`。按钮回调失败时，可用 `approve <id>` / `deny <id>` 文本命令继续审批。

## 启动和停止

```bash
./scripts/start-screen.sh
```

查看日志：

```bash
tail -f ~/.lark-codex/bridge.log
```

停止：

```bash
./scripts/stop-screen.sh
```

## 开机自运行（LaunchAgent）

macOS 上可以用 `launchd` 把桥接设置成“登录后自动启动 + 常驻运行”（不需要 `screen`）。

安装：

```bash
./scripts/install-launchd.sh
```

卸载：

```bash
./scripts/uninstall-launchd.sh
```

说明：

- 这是用户级 `LaunchAgent`，会在你登录 macOS 后启动（通常就够用了）。
- 安装脚本会把运行副本复制到配置目录下的 `runtime/bin`，避免后台进程直接从 `Documents` 这类受 macOS 隐私保护的目录执行。
- 如需使用自定义配置目录，运行安装脚本前先设置 `LARK_CODEX_BASE_DIR`，例如：
  `LARK_CODEX_BASE_DIR="$HOME/.lark-codex" ./scripts/install-launchd.sh`

## 常用命令

在飞书/Lark 机器人里发送：

默认命令模式是 `slash`：系统级操作必须用 `/` 前缀（例如 `/目录`、`/切换 2`），保证普通对话不会被误判成命令而“拦截”；未加 `/` 的内容会直接作为输入发给当前 thread/session。

如需兼容旧用法（不加 `/` 也能触发命令），在 `.env` 里设置：`LARK_CODEX_COMMAND_MODE=both`。

```text
/status
```

查看桥接状态。

```text
/目录
```

用卡片列出当前会话、置顶会话和最近会话编号。也支持：

```text
/sessions
```

```text
/切换 1
```

把编号 `1` 设为当前“常驻会话”。之后普通消息会一直进入这个会话，直到再次切换或清除。

也支持别名：

```text
/常驻 1
/attach 1
```

```text
/当前会话
/current
```

查看当前绑定的本地 Codex 会话。

```text
/清除会话
/detach
```

取消当前会话绑定。之后普通消息会创建新任务。

```text
/新任务 帮我整理这个仓库
/new 帮我整理这个仓库
```

绕过当前会话，强制创建一个新的 terminal task，但不把它设为常驻会话。默认仍使用可恢复长任务模型。

```text
/新会话 帮我整理这个仓库
```

创建一个新的 Codex 会话，任务完成后自动把它设为当前常驻会话。

```text
/新会话
```

进入新会话待命状态。下一条普通消息会创建新的 Codex 会话，并自动常驻到这个新会话。

```text
/长任务 生成并写回这张表的前 3 行设计图
```

以长任务模式执行，默认超时 `LARK_CODEX_LONG_TASK_TIMEOUT_SECONDS=3600`。适合图片生成、批量写表、长时间代码迁移等任务。

```text
/任务
/tasks
```

`任务` 查看最近长任务状态、原始需求、尝试次数、已记录产物和下一步命令。`tasks` 列出最近任务。

```text
/继续任务
/continue
```

从最近失败或暂停的长任务继续。桥接会把原始需求、已记录产物和最近日志摘要一起发给 Codex，避免从头重做。若旧版本没有长任务记录，但当前窗口已有常驻会话，也会自动升级为长任务继续。

```text
/会话 1
```

查看编号 `1` 的最近进度。

```text
/同步会话 1 10分钟
```

同步编号 `1` 的输出 10 分钟。同步只在有新事件时推送，不会定期刷屏。

```text
/cd /path
/pwd
```

设置/查看本聊天窗口默认工作目录（新任务会用这个目录）。

```text
/debug on
/debug off
```

控制卡片折叠区的详细程度（默认 `off`）。

```text
/syncmode stream
/syncmode screen
/update on
/update off
```

同步输出模式。`screen` 会尽量更新同一张卡片（需要 `im:message:update` 权限；失败自动降级为逐条 `stream`）。

```text
切换 2
```

同步期间切换到编号 `2` 的会话。

```text
停止同步
```

结束当前同步。

```text
队列
```

查看等待执行的消息。

```text
logs
```

查看最近任务日志。

## 配置项

常用配置写在 `~/.lark-codex/.env`：

```bash
LARK_CODEX_BASE_DIR=$HOME/.lark-codex
LARK_CODEX_WORKDIR=$HOME
LARK_CODEX_MODEL=gpt-5.2
LARK_CODEX_ACK_EMOJI=👀
LARK_CODEX_ACK_MODE=reaction
LARK_CODEX_ACK_REACTION_EMOJI=OK
LARK_CODEX_RESULT_FORMAT=card
LARK_CODEX_DIRECTORY_FORMAT=card
LARK_CODEX_OUTPUT_STYLE=compact
LARK_CODEX_DIRECTORY_LIMIT=12
LARK_CODEX_CARD_SCHEMA=2
LARK_CODEX_CARD_MOBILE_LAYOUT=true
LARK_CODEX_CARD_BODY_LIMIT_CHARS=4000
LARK_CODEX_CARD_DETAIL_LIMIT_CHARS=2000
LARK_CODEX_CARD_MOBILE_LINE_CHARS=88
LARK_CODEX_BACKEND=auto
LARK_CODEX_APP_SERVER_LISTEN=stdio://
LARK_CODEX_APPROVAL_UI=buttons
LARK_CODEX_APPROVAL_TIMEOUT_SECONDS=600
LARK_CODEX_APPROVAL_ALLOW_SESSION=true
LARK_CODEX_APPROVAL_POLICY=on-request
LARK_CODEX_TASK_MODE=auto-long
LARK_CODEX_TERMINAL_RENDER=screen
LARK_CODEX_IDLE_STATUS_PATCH_SECONDS=60
LARK_CODEX_SYNC_RENDER=stream
LARK_CODEX_ENABLE_MESSAGE_UPDATE=false
LARK_CODEX_TASK_TIMEOUT_SECONDS=900
LARK_CODEX_LONG_TASK_TIMEOUT_SECONDS=3600
LARK_CODEX_DANGEROUS_BYPASS=false
```

`LARK_CODEX_WORKDIR` 是新建 Codex 任务时使用的默认工作目录。续接已有会话时，Codex 会使用会话自己的上下文。

`LARK_CODEX_TASK_MODE=auto-long` 表示普通消息默认按可恢复 terminal task 执行；如需旧行为可设为 `explicit-long`，只有 `长任务` / `long` 进入长任务模式。

`LARK_CODEX_TERMINAL_RENDER=screen` 表示任务进度优先更新同一张 running card；如果缺少 `im:message:update` 权限，会自动降级为逐条卡片或纯文本 fallback。

`LARK_CODEX_IDLE_STATUS_PATCH_SECONDS=60` 表示长时间无新输出时最多每 60 秒更新同一张卡片状态行；设为 `0` 可禁用空闲状态更新。

`LARK_CODEX_CARD_MOBILE_LAYOUT=true` 是默认值：卡片按手机阅读优先，关闭宽屏模式，主输出限长，长行会自动换行，状态/路径/thread 等元信息放进折叠详情。审批按钮在移动端每行最多 2 个。

`LARK_CODEX_BACKEND=auto` 会优先尝试 Codex `app-server`，不可用时回退旧 `exec` 后端。`app-server` 后端让飞书消息进入 Codex thread，并把 approval request 显示为飞书卡片按钮。

`LARK_CODEX_APPROVAL_UI=buttons` 表示审批优先用飞书按钮；也可设为 `text` 或 `both`。文本 fallback 命令是 `approve <id>`、`approve session <id>`、`deny <id>`、`cancel <id>`、`answer <id> <text>`。

## 高权限模式

默认：

```bash
LARK_CODEX_DANGEROUS_BYPASS=false
```

这表示公开版不会默认给远程消息开启 Codex 的危险 bypass 参数。`app-server` 后端不使用这个 bypass；它使用 Codex 自己的 approval request，并把审批映射到飞书按钮。

如果你确认只允许可信账号使用，并接受远程触发本机文件修改的风险，可以显式开启：

```bash
LARK_CODEX_DANGEROUS_BYPASS=true
```

开启后，续接会话会使用：

```text
--dangerously-bypass-approvals-and-sandbox
```

请只在个人机器和可信飞书/Lark 账号下使用。

---

# English

Control your local Codex CLI from a Feishu/Lark bot on your phone. Each Feishu/Lark chat behaves like a mobile terminal window: a normal message starts a terminal task, the bot adds an `OK` reaction, posts a running card, then patches progress, idle status, and final output into the same card whenever possible.

> Security note: this bridge lets one configured Feishu/Lark user remotely trigger Codex on your computer. The default backend prefers Codex `app-server` approvals and exposes approval requests as Feishu/Lark card buttons. The dangerous bypass flag only applies to the legacy `exec` backend.

## Features

- Send normal bot messages to run Codex tasks.
- Automatic queueing while Codex is busy.
- Treat each Feishu/Lark chat (DM/group) as an isolated terminal window (state is per `chat_id`).
- Normal messages default to recoverable terminal tasks (`auto-long`).
- Tasks prefer one running card with `QUEUED / RUNNING / PAUSED / DONE / FAILED` states.
- List Codex sessions and refer to them by number.
- Keep one local Codex session attached with `切换 1`, so normal messages flow into that session.
- Follow a session like a lightweight terminal stream (silent when nothing changes).
- Send follow-up messages into the attached session.
- Run long tasks with extended timeout, job records, artifact tracking, and `继续任务` resume.
- Default output uses Card JSON 2.0 (clean main content; extra metadata folded in a collapsed panel).
- Codex `app-server` backend: remote messages enter Codex threads, and approval/sandbox/user-input requests are handled through card buttons or text fallback commands.
- Run in the background with `screen`.

## Requirements

On macOS, the following commands must be available:

- `bash`
- `jq`
- `curl`
- `sqlite3`
- `lark-cli`
- `codex`
- `screen`
- `node`

Make sure both Codex CLI and lark-cli work in your terminal first.

## Install

```bash
git clone https://github.com/YOUR_NAME/lark-codex-bridge.git
cd lark-codex-bridge
./scripts/install.sh
```

The installer creates:

```text
~/.lark-codex/.env
```

Edit it and fill in your own Feishu/Lark app credentials and allowed sender open_id:

```bash
LARKSUITE_CLI_APP_ID=cli_xxxxxxxxxxxxxxxxx
LARKSUITE_CLI_APP_SECRET=replace_me
LARK_CODEX_ALLOWED_SENDER=ou_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Feishu/Lark App Setup

1. Create a custom app in the Feishu/Lark developer console.
2. Enable bot capability.
3. Grant the app message permissions.
4. Enable event subscription for `im.message.receive_v1`.
5. For button approvals, enable card callback interaction `card.action.trigger`.
6. Publish/enable the app and add the bot to your chat.
7. Put your user `open_id` into `LARK_CODEX_ALLOWED_SENDER`.

Permission guide:

- Basic: receive messages and reply as the bot.
- Enhanced: also add `im:message.reactions:write_only` for the `OK` acknowledgement reaction.
- Full TUI: also add `im:message:update` for single-card progress/final updates; auto-degrades on failure.
- Button approvals: enable card callback interaction `card.action.trigger`. If callbacks are unavailable, use `approve <id>` / `deny <id>` text commands.

## Start and Stop

```bash
./scripts/start-screen.sh
```

View logs:

```bash
tail -f ~/.lark-codex/bridge.log
```

Stop:

```bash
./scripts/stop-screen.sh
```

## Bot Commands

Send these to your Feishu/Lark bot:

Default command mode is `slash`: system commands must start with `/`; plain messages go to the current Codex thread/session.

- `/status`: show bridge status.
- `/目录` or `/sessions`: list Codex sessions.
- `/attach 1` / `/切换 1` / `/常驻 1`: set session `1` as the persistent current session.
- `/当前会话` or `/current`: show the current target session.
- `/清除会话` or `/detach`: clear the current target session.
- `/新任务 <content>` or `/new <content>`: force a new Codex task instead of using the current session.
- `/新会话 <content>` / `/new session <content>`: create a new Codex session and make it the persistent current session.
- `/新会话` / `/new session`: make the next normal message create and attach a new session.
- `/长任务 <content>` / `/long <content>`: run an extended-timeout job.
- `/任务` / `/task`: show the latest long job.
- `/tasks` / `/jobs`: list recent jobs.
- `/继续任务` / `/continue` / `/continue task`: resume the latest failed or paused job.
- `/会话 1`: show recent progress for session `1`.
- `/同步会话 1 10分钟`: stream session `1` for 10 minutes.
- `/切换 2`: switch the attached stream to session `2`.
- `/停止同步`: stop streaming.
- `/cd /path` / `/cwd /path`: set the default workdir for new tasks in this chat.
- `/pwd`: show the default workdir for new tasks in this chat.
- `/debug on|off`: control folded details verbosity.
- `/syncmode stream|screen`: choose sync render mode.
- `/update on|off`: enable/disable message update.
- `/队列`: show queued messages.
- `/logs`: show recent task logs.
- `/approve <id>` / `/approve session <id>` / `/deny <id>` / `/cancel <id>`: text fallback for Codex approval requests.
- `/answer <id> <text>`: text fallback for Codex user-input requests.

Cards are mobile-first by default (`LARK_CODEX_CARD_MOBILE_LAYOUT=true`): wide-screen mode is disabled, main output is capped, long lines wrap, metadata stays folded, and approval buttons are grouped in small rows.

## Dangerous Mode

Default:

```bash
LARK_CODEX_DANGEROUS_BYPASS=false
```

To allow resumed sessions in the legacy `exec` backend to run with Codex's dangerous bypass flag:

```bash
LARK_CODEX_DANGEROUS_BYPASS=true
```

This enables:

```text
--dangerously-bypass-approvals-and-sandbox
```

Only enable this on a personal machine with a trusted Feishu/Lark account. The `app-server` backend does not use this flag; it routes approval requests back to Feishu/Lark.
