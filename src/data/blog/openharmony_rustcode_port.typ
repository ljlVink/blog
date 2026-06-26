#import "/typ/templates/blog.typ": *

#show: main.with(
  title: "OpenHarmony Rust 移植",
  author: "Vink",
  description: "OpenHarmony Rust 移植",
  pubDatetime: "2026-06-26T00:00:00Z",
  tags: ("typst", "rust", "harmonyos"),
  featured: true,
  draft: false,
)

= Rust on OpenHarmony

== 目录

+ #link(<intro>)[简介]
+ #link(<compile>)[Rust -> LLVM -> Native Code]
+ #link(<ohos-rs>)[ohos-rs]
+ #link(<porting>)[移植要点]
  + #link(<entry-point>)[入口点]
  + #link(<cfg-target>)[cfg target on code & cargo.toml]
  + #link(<work-path>)[work path]
  + #link(<debug>)[debug]
+ #link(<porting-tauri>)[移植 Tauri]
+ #link(<summary>)[总结]

== 简介 <intro>

Rust 是由 Mozilla 主导开发的高性能编译型编程语言，遵循"安全、并发、实用"的设计原则，具备性能极高、无 GC、可在嵌入式环境运行等特性。

总的来看，Rust 的类型系统抽象让我们更容易写出安全可预测的代码，并且代码风格可以被强大的编译器统一检查和约束。

== Rust -> LLVM -> Native Code <compile>

要理解 Rust 如何在 OpenHarmony 中运行，首先需要理解其编译原理。Rust 实际上是 LLVM 的一个前端语言，编译器将 Rust 代码编译为 LLVM IR 中间代码，然后通过 LLVM 后端将其编译为目标平台的 Native Code。

前端负责词法分析、语法分析、语义分析，生成抽象语法树 AST，然后将 AST 转换为中间表示 IR。中端负责生成 LLVM IR 中间代码，进行优化。后端负责将 IR 编译为目标机器码，使用对应平台的指令生成目标文件。那么如果后端支持 OpenHarmony 的目标平台，Rust 代码就可以在 OpenHarmony 上运行。

OpenHarmony 的分支系统主要为 `linux-musl-aarch64`，不需要依赖 libc。

== ohos-rs <ohos-rs>

考虑 Android 调用 native code 时为 JNI 调用，Android 侧传入 Java 胶水层，随后进入 native 层实现相关内容。

OHOS 使用 N-API 调用 native code，OHOS 侧传入参数到 JS 胶水层，随后转换参数到 native 层实现相关内容。

ohos-rs is a framework for building compiled OpenHarmony SDK in Rust via Node-API (Forked from napi-rs)

可以参考 #link("https://ohos.rs/")[ohos.rs] 进行配置。

== 移植要点 <porting>

Rust 层移植最需要注意的位置为：入口点、cfg target、work path，以及 debug 相关内容。

=== 入口点 <entry-point>

入口点通过 napi 宏属性调用相关代码。

```rust
use napi_derive_ohos::napi;
#[napi]
pub fn add(left: u32, right: u32) -> u32 {
  left + right
}
```

这是最简单的形式，我们在实际生产环境中可能会套入很多层逻辑处理，比如 miniquad。

miniquad 是一个跨平台的游戏引擎，支持多种平台。在移植过程中我会先让 XComponent 加载起来，然后将 XComponent 的指针函数存到全局变量中，引擎层调用游戏层的 C exported `quad_main()` 函数再获取回 XComponent 的指针，给到引擎层进行渲染，这个链路的时间复杂度为 O(1)，实际用户感知不到短暂黑屏。

```ts
XComponent(this.xComponentAttrs)
        .onLoad((xComponentContext) => {
          // onLoad 时已经到引擎层带有 module_exports 宏属性的 init 函数了
          // rust code ↓
          // #[cfg(target_env = "ohos")]
          // #[napi(module_exports)] // 保存 exports 和 env
          // pub fn init(exports: Object, env: Env) -> Result<()> {
          // }
          this.xComponentContext = xComponentContext;
          ...
          }
```

实际上这样的实现较为粗糙，在 2026 年 2 月附近我看到了更加优雅的处理方式，使用 winit 等窗口处理库，在 OHOS 前端项目中引入 `@ohos-rs/ability` 等库，使用

```rust
#[openharmony_ability_derive::ability]
pub fn openharmony_app(app: OpenHarmonyApp) {
  ...
}
```

等宏属性处理，这里不过多提及。

=== cfg target on code & cargo.toml <cfg-target>

cfg target 是 Rust 中用于条件编译的属性，通过它我们可以根据不同的目标平台来编译不同的代码。在 OpenHarmony 中，最大的坑在于：不存在 `target_os = "ohos"` 的 cfg target，只有 `target_env = "ohos"`（即 `target_os = "linux" && target_env = "ohos"`），我们在对项目移植时要将带有 linux 的宏也做特殊判断，保证 x11/wayland/dbus 等 linux 平台的特殊代码不被 OHOS 编译进去。

`Cargo.toml` 中也需要进行修改，将 iOS/Android/Linux 相关库移除，进行特判，防止编译失败。

```toml
[target.'cfg(any(target_os = "macos", target_os = "ios"))'.dependencies]
objc = "0.2"

[target.'cfg(target_env = "ohos")'.dependencies]
napi-ohos = { version = "1.1.3", default-features = false, features = [
    "napi8",
    "async",
] }
napi-derive-ohos = { version = "1.1.3" }
...
```

=== work path <work-path>

运行目录也是需要注意的一点，可以参考华为开发者文档：

#link("https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-sandbox-directory")[应用沙箱目录]

按照沙箱特性，写死即可。

1. ro-el1 安装包目录在 `/data/storage/el1/bundle`，通常用来处理资源。

比如说部分 read-only 的资源：

#link("https://github.com/Mivik/prpr-miniquad/blob/0c525a3e0e38a8ab3d6d41bd2749eb8b6f676e4c/src/native/ohos.rs#L655-L668")[prpr-miniquad ohos.rs]

```rust
fn load_file_sync(path: &str) -> crate::fs::Response {
    let full_path = format!("/data/storage/el1/bundle/entry/resources/resfile/{}", path);
    match std::fs::read(&full_path) {
        Ok(data) => Ok(data),
        Err(e) => {
            hilog_error!(format!(
                "load_file_sync: failed to load file: {} - error: {:?}",
                full_path, e
            ));
            Err(e.into())
        }
    }
}
```

需要提前在 OHOS 前端存到 resfile：

#link("https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/resource-categories-and-access#resfile")[资源分类与访问 - resfile]

2. rw-el2 目录在 `/data/storage/el2/base`

```rust
let current_dir = std::path::PathBuf::from("/data/storage/el2/base");
let app_data_dir = std::path::PathBuf::from("/data/storage/el2/base");
```

=== debug <debug>

编译失败的情况：请查看 `Cargo.lock` 中是否存在 Linux 平台的内容，或者是 patch 没有生效。

我推荐尽早在一个可控的入口点加入转发 stdio 到 hilog 的 debug 以便调试。

导入：

```toml
ohos-hilog-binding = { version = "0.1.2", features = [
    "redirect"
] }
```

在较早的入口点中：

```rust
#[cfg(target_env = "ohos")]
use ohos_hilog_binding::forward_stdio_to_hilog;
let _handle = forward_stdio_to_hilog();
```

== 移植 Tauri <porting-tauri>

tauri 是一个跨平台的桌面应用框架，使用 Rust 作为后端语言，前端使用 Web 技术。tauri 的核心是通过 Rust 编写的后端逻辑与前端的 Web 界面进行交互，实现桌面应用的功能。

很好的一点是 Rust 社区非常开放，开发组会积极合并开发者提交的代码，而不需要另起东山（点名 electron/flutter/go）。这样开发者在维护一个项目时可以同时编译多平台的版本。我很讨厌在一个代码中另外 fork 出来然后花费时间或 token 手工适配。

tauri 的适配工作暂不完全，很多 plugin 可能需要临时屏蔽掉。

在 `Cargo.toml` 为 OHOS 平台处理不支持的插件：

```toml
[target.'cfg(not(target_env = "ohos"))'.dependencies]
tauri-plugin-dialog = "2.7.1"
tauri-plugin-shell = "2"

[target.'cfg(target_env = "ohos")'.dependencies]
napi-ohos = { version = "1.1" }
napi-derive-ohos = "1.1"
ohos-bundle-binding = { version = "0.1.0" }
ohos-hilog-binding = { version = "0.2.0", features = [
    "redirect"
] }
```

为 OHOS 平台添加 tauri patch：

```toml
[target.'cfg(target_env = "ohos")'.patch.crates-io]
openharmony-ability = { git = "https://github.com/harmony-contrib/openharmony-ability.git" }
openharmony-ability-derive = { git = "https://github.com/harmony-contrib/openharmony-ability.git" }
tauri = { git = "https://github.com/tauri-apps/tauri", branch = "feat/open-harmony" }
```

安装支持 OHOS 平台的 tauri：

```sh
cargo install tauri-cli --git https://github.com/tauri-apps/tauri --branch feat/open-harmony
cargo tauri ohos init
```

#strong[重要！] 需要设置环境变量 `OHOS_HOME` 为 SDK 目录。如果你是 Windows，可能会因为路径存在空格导致部分 C 代码编译失败。如果不设置，tauri 会去寻找系统自带的 DevEco，此时你需要保证路径中不包含空格。

编译：

```sh
cargo tauri ohos build
```

在 build 过程中可能会遇到扫盘 `System Volume Information` 问题，删除掉再跑。我暂时还不清楚这个问题怎么解决。

如果实在遇到渲染失败的问题，可参考修改 ohos-rs/ability 的 webview 代码输出 console 信息来解决。

闪退 debug 请参考 #link(<debug>)[debug 章节]。


== 总结 <summary>

(↓以下由ai生成)

本文从 Rust 的编译原理出发，介绍了 Rust 代码如何在 OpenHarmony 平台上运行。核心要点如下：

+ 编译链路：Rust 通过 LLVM 后端支持 OpenHarmony 的 `linux-musl-aarch64` 目标平台，无需依赖 libc。
+ ohos-rs 框架：基于 napi-rs fork，通过 Node-API 实现 Rust 与 OHOS 前端的互通。
+ 移植关键点：
  + 入口点使用 `#[napi]` 或 `#[openharmony_ability_derive::ability]` 宏属性；
  + 注意 cfg target 只有 `target_env = "ohos"` 而非 `target_os = "ohos"`；
  + 沙箱目录 `ro-el1` 和 `rw-el2` 需写死路径；
  + 尽早接入 hilog 转发 stdio 以方便调试。
+ Tauri 移植：社区积极合入 OHOS 支持，通过 patch 和条件依赖即可适配，但部分 plugin 仍需临时屏蔽。

Rust 在 OpenHarmony 上的生态正在快速发展，期待未来能有更完善的开箱即用体验。
