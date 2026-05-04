# lark-codex-bridge

用飞书/Lark 机器人在手机上远程控制本机 Codex CLI。普通消息会触发 Codex，机器人优先给原消息添加 `OK` 表情表示收到，任务完成后优先回复结构化交互卡片；如果权限或卡片发送失败，会自动退回纯文本。

> 安全提醒：这个桥接会让指定飞书/Lark 用户远程触发你电脑上的 Codex。公开版默认不开启高权限 bypass。只有你显式设置 `LARK_CODEX_DANGEROUS_BYPASS=true` 时，续接会话才会使用 `--dangerously-bypass-approvals-and-sandbox`。

## 功能

- 直接发消息给机器人，让 Codex 执行任务。
- 忙时自动排队。
- 每个飞书/Lark 聊天（DM/群）都是一个独立“终端窗口”：状态按 `chat_id` 隔离。
- 查看 Codex 会话目录，并用编号选择会话。
- `切换 1` 后常驻绑定本地 Codex 会话，普通消息会无缝进入当前会话（直到 `清除会话`）。
- 同步会话进度，像手机上的轻量终端流（默认只在有新事件时推送，完全静默等待）。
- 在同步期间直接给当前会话继续发消息。
- 输出默认使用 Card JSON 2.0：主内容清爽可读，元信息放在折叠区（默认收起）。
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
5. 发布/启用应用，并把机器人添加到你要使用的会话里。
6. 获取你的用户 `open_id`，填入 `LARK_CODEX_ALLOWED_SENDER`。

权限建议：

- 基础体验：接收消息、以机器人身份回复消息。
- 完整体验：再添加 `im:message.reactions:write_only`，用于收到消息后添加 `OK` 表情。
- 可选增强：`im:message:update`，用于 `syncmode screen + update on` 时更新同一张卡片（失败会自动降级，不影响核心功能）。
- 交互卡片通过消息回复发送；如果卡片发送失败，桥接会自动退回纯文本回复。

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

## 常用命令

在飞书/Lark 机器人里发送：

```text
status
```

查看桥接状态。

```text
目录
```

用卡片列出当前会话、置顶会话和最近会话编号。

```text
切换 1
```

把编号 `1` 设为当前“常驻会话”。之后普通消息会一直进入这个会话，直到再次切换或清除。

也支持别名：

```text
常驻 1
```

```text
当前会话
```

查看当前绑定的本地 Codex 会话。

```text
清除会话
```

取消当前会话绑定。之后普通消息会创建新任务。

```text
新任务 帮我整理这个仓库
```

绕过当前会话，强制创建一个新的 Codex 任务，但不把它设为常驻会话。

```text
新会话 帮我整理这个仓库
```

创建一个新的 Codex 会话，任务完成后自动把它设为当前常驻会话。

```text
新会话
```

进入新会话待命状态。下一条普通消息会创建新的 Codex 会话，并自动常驻到这个新会话。

```text
会话 1
```

查看编号 `1` 的最近进度。

```text
同步会话 1 10分钟
```

同步编号 `1` 的输出 10 分钟。同步只在有新事件时推送，不会定期刷屏。

```text
cd /path
pwd
```

设置/查看本聊天窗口默认工作目录（新任务会用这个目录）。

```text
debug on
debug off
```

控制卡片折叠区的详细程度（默认 `off`）。

```text
syncmode stream
syncmode screen
update on
update off
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
LARK_CODEX_SYNC_RENDER=stream
LARK_CODEX_ENABLE_MESSAGE_UPDATE=false
LARK_CODEX_TASK_TIMEOUT_SECONDS=900
LARK_CODEX_DANGEROUS_BYPASS=false
```

`LARK_CODEX_WORKDIR` 是新建 Codex 任务时使用的默认工作目录。续接已有会话时，Codex 会使用会话自己的上下文。

## 高权限模式

默认：

```bash
LARK_CODEX_DANGEROUS_BYPASS=false
```

这表示公开版不会默认给远程消息开启 Codex 的危险 bypass 参数。

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

Control your local Codex CLI from a Feishu/Lark bot on your phone. A normal message triggers Codex. The bot first tries to add an `OK` reaction to the original message, then sends a structured interactive card when the task completes. If reactions or cards are unavailable, it falls back to plain text.

> Security note: this bridge lets one configured Feishu/Lark user remotely trigger Codex on your computer. Dangerous bypass mode is off by default. It is only enabled when you explicitly set `LARK_CODEX_DANGEROUS_BYPASS=true`.

## Features

- Send normal bot messages to run Codex tasks.
- Automatic queueing while Codex is busy.
- Treat each Feishu/Lark chat (DM/group) as an isolated terminal window (state is per `chat_id`).
- List Codex sessions and refer to them by number.
- Keep one local Codex session attached with `切换 1`, so normal messages flow into that session.
- Follow a session like a lightweight terminal stream (silent when nothing changes).
- Send follow-up messages into the attached session.
- Default output uses Card JSON 2.0 (clean main content; extra metadata folded in a collapsed panel).
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
5. Publish/enable the app and add the bot to your chat.
6. Put your user `open_id` into `LARK_CODEX_ALLOWED_SENDER`.

Permission guide:

- Basic: receive messages and reply as the bot.
- Enhanced: also add `im:message.reactions:write_only` for the `OK` acknowledgement reaction.
- Optional: `im:message:update` for `syncmode screen + update on` (single-card updates; auto-degrades on failure).
- Interactive cards are sent as message replies. If card sending fails, the bridge falls back to plain text.

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

- `status`: show bridge status.
- `目录` or `sessions`: list Codex sessions.
- `切换 1` / `常驻 1`: set session `1` as the persistent current session.
- `当前会话` or `current`: show the current target session.
- `清除会话` or `detach`: clear the current target session.
- `新任务 <content>` or `new <content>`: force a new Codex task instead of using the current session.
- `新会话 <content>` / `new session <content>`: create a new Codex session and make it the persistent current session.
- `新会话` / `new session`: make the next normal message create and attach a new session.
- `会话 1`: show recent progress for session `1`.
- `同步会话 1 10分钟`: stream session `1` for 10 minutes (only pushes when new events; no periodic keepalive).
- `切换 2`: switch the attached stream to session `2`.
- `停止同步`: stop streaming.
- `cd /path` / `cwd /path`: set the default workdir for new tasks in this chat.
- `pwd`: show the default workdir for new tasks in this chat.
- `debug on|off`: control how verbose the folded details panel is.
- `syncmode stream|screen`: choose sync render mode.
- `update on|off`: enable/disable message update (required for `screen`).
- `队列`: show queued messages.
- `logs`: show recent task logs.

## Dangerous Mode

Default:

```bash
LARK_CODEX_DANGEROUS_BYPASS=false
```

To allow resumed sessions to run with Codex's dangerous bypass flag:

```bash
LARK_CODEX_DANGEROUS_BYPASS=true
```

This enables:

```text
--dangerously-bypass-approvals-and-sandbox
```

Only enable this on a personal machine with a trusted Feishu/Lark account.
