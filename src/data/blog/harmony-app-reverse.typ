#import "/typ/templates/blog.typ": *

#show: main.with(
  title: "HarmonyOS Hap逆向小记",
  author: "Vink",
  description: "三个鸿蒙app的逆向",
  pubDatetime: "2026-03-26T00:00:00Z",
  tags: ("typst", "reverse", "harmonyos"),
  featured: true,
  draft: false,
)

= HarmonyOS app逆向

随着LLM代码能力的发展，基于AI的IDE编辑工具层出不穷，降低了开发者开发app的难度，也涌现了一批由LLM生成的程序，可以说某些地方运行效率远低于手写，某些地方安全做得非常不好。当然本篇文章并不会讨论下面三个app的代码质量如何，只考虑其在安全方面的问题。

== 目录

+ #link(<reverse-tools>)[逆向工具: abcd]
+ 分析的app
  + #link(<celesmark-v1>)[CelesmarkPro 第一版]
  + #link(<celesmark-v2>)[CelesmarkPro 第二版]
  + #link(<moonlight>)[Moonlight V+]
  + #link(<hokit>)[Hokit]
+ #link(<summary>)[总结]

=== 逆向工具: abcd <reverse-tools>

darknavy对鸿蒙的研究非常深入，但是他们并没有公开很多相关内容，他们基于jadx魔改开源了abcd，反编译了字节码到伪代码。

逆向工具其实也是有一定局限性的，首先并不像安卓，可以像apktool一样解析出smali代码并回编译，目前还没有。即abc字节码文件仍不能大规模地重新打包替换代码实现插桩操作。

群友都说，AI写的东西就要AI来分析。下面的几个都介入了各种AI配合分析。

=== CelesmarkPro 第一版 <celesmark-v1>

CelesmarkPro有两个版本，第一个版本的安装包删掉了，第二个版本加强了检测。

第一个版本中，经过abcd逆向后，可知其激活码生成机制为

- 1.machine_code 先 trim()
- 2.再转大写 toUpperCase()
- 3.拼接固定密钥 `xxx`, 已脱敏
- 4.做 SHA-256
- 5.转成十六进制大写
- 6.取前 12 位作为验证码 / 注册码

使用GPT-5.4还原的逻辑大致如下

```ts
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

const SECRET_KEY: string = 'xxx';

export class LicenseUtil {
  static generateMachineCode(length: number = 12): string {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    let result = '';
    for (let i = 0; i < length; i++) {
      const index = Math.floor(Math.random() * chars.length);
      result += chars[index];
    }
    return result;
  }
  static makeVerifyCode(machineCode: string): string {
    const normalizedMachineCode = machineCode.trim().toUpperCase();
    const raw = `${normalizedMachineCode}${SECRET_KEY}`;

    const md = cryptoFramework.createMd('SHA256');
    md.updateSync({
      data: this.stringToBytes(raw)
    });

    const digest = md.digestSync();
    return this.bytesToHex(digest.data).toUpperCase().slice(0, 12);
  }
  static verify(machineCode: string, inputCode: string): boolean {
    const realCode = this.makeVerifyCode(machineCode);
    return realCode === inputCode.trim().toUpperCase();
  }
  private static stringToBytes(str: string): Uint8Array {
    const bytes = new Uint8Array(str.length);
    for (let i = 0; i < str.length; i++) {
      bytes[i] = str.charCodeAt(i);
    }
    return bytes;
  }
  private static bytesToHex(bytes: Uint8Array): string {
    let hex = '';
    for (let i = 0; i < bytes.length; i++) {
      hex += bytes[i].toString(16).padStart(2, '0');
    }
    return hex;
  }
}
```

随后开发者更新了第二个版本，将验证挪到了二进制里，但算法依旧可被重新推导，因为涉及加解密的成本太高，我认为没必要强攻算法，直接改二进制即可。

=== CelesmarkPro 第二版 <celesmark-v2>

改成二进制了，我们直接深入二进制去探索

```asm
; Attributes: thunk

; __int64 napi_module_register()
.napi_module_register
ADRP            X16, #off_15100@PAGE
LDR             X17, [X16,#off_15100@PAGEOFF] ; napi_module_register
ADD             X16, X16, #off_15100@PAGEOFF
BR              X17 ; napi_module_register
; End of function .napi_module_register
```

已知鸿蒙的入口点为napi_module_register，我们不难找到napi注册点

```asm
; __int64 sub_9824()
sub_9824
; __unwind {
NOP
ADR             X0, unk_163B8
B               .napi_module_register
; } // starts at 9824
; End of function sub_9824
```

```asm
sub_9830

...

; __unwind {
SUB             SP, SP, #0x140
STP             X29, X30, [SP,#0x130+var_20]
STR             X28, [SP,#0x130+var_10]
STP             X20, X19, [SP,#0x130+var_s0]
ADD             X29, SP, #0x110
ADRP            X8, #__stack_chk_guard_ptr@PAGE
MOV             X19, X1
MOV             X20, X0
ADRL            X3, aCleancheck ; "CleanCheck"
ADRL            X4, aNapiInit ; ">>> NAPI Init <<<"
LDR             X8, [X8,#__stack_chk_guard_ptr@PAGEOFF] ; __stack_chk_guard
MOV             W0, WZR
MOV             W1, #4
MOV             W2, #0xFF00
LDR             X8, [X8]
STUR            X8, [X29,#0x20+var_28]
BL              .OH_LOG_Print
NOP
ADR             X8, off_149B0 ; "runNativeBenchmark"
MOV             X3, SP
MOV             X0, X20
MOV             X1, X19
MOV             W2, #4
LDP             Q0, Q1, [X8,#(off_14A70 - 0x149B0)] ; "verify"
LDP             Q2, Q3, [X8,#(xmmword_14A90 - 0x149B0)]
STP             Q0, Q1, [SP,#0x130+var_70]
LDP             Q0, Q1, [X8,#(off_14A30 - 0x149B0)] ; "getGpuRendererName"
STP             Q2, Q3, [SP,#0x130+var_50]
LDP             Q2, Q3, [X8,#(xmmword_14A50 - 0x149B0)]
STP             Q0, Q1, [SP,#0x130+var_B0]
LDP             Q0, Q1, [X8,#(off_149F0 - 0x149B0)] ; "getGpuStatus"
STP             Q2, Q3, [SP,#0x130+var_90]
LDP             Q2, Q3, [X8,#(xmmword_14A10 - 0x149B0)]
STP             Q0, Q1, [SP,#0x130+var_F0]
LDP             Q0, Q1, [X8] ; "runNativeBenchmark"
STP             Q2, Q3, [SP,#0x130+var_D0]
LDP             Q2, Q3, [X8,#(xmmword_149D0 - 0x149B0)]
STP             Q0, Q1, [SP,#0x130+var_130]
STP             Q2, Q3, [SP,#0x130+var_110]
BL              .napi_define_properties
ADRP            X8, #__stack_chk_guard_ptr@PAGE
LDR             X8, [X8,#__stack_chk_guard_ptr@PAGEOFF] ; __stack_chk_guard
LDUR            X9, [X29,#0x20+var_28]
LDR             X8, [X8]
CMP             X8, X9
B.NE            loc_9908
```

可见暴露给napi的共有四个函数，我们主要围绕verify函数展开

```c
  v37 = (char *)v40;
napi_create_string_utf8(a1, v37, v36, &v41);
OH_LOG_Print(0, 4, 65280, "CelesSecurity", "Security Check: PASSED");
if ( (v38 & 1) != 0 )
  operator delete(v40);
```

看一下控制流

#image("/assets/image.png")

其实很明确了，我们只需要把指向`loc_120D0`的线去掉即可

#figure(
  image("/assets/image-1.png"),
  caption: [第一块 改成NOP],
)

#figure(
  image("/assets/image-2.png"),
  caption: [第二块 改成NOP],
)

#figure(
  image("/assets/image-3.png"),
  caption: [第三块 改成B 即直接跳转],
)

#figure(
  image("/assets/47463dd71f6cdda9fb2cfc7a646b5fac_720.jpg"),
  caption: [轻松秒杀],
)



=== Moonlight V+ <moonlight>

我们不难发现源代码开源在了#link("https://github.com/AlkaidLab/moonlight-harmony")[AlkaidLab/moonlight-harmony]


我们只需要找到密钥即可，详见#link("https://github.com/AlkaidLab/moonlight-harmony/blob/4834b42fd5c0694b51e03bf5080310f3022d3ad1/entry/src/main/ets/config/DevKeySecret.ets.example#L4")[DevKeySecret.ets.example]


在一些特殊手段下拿到了安装包，很轻松找到了secret位置，无任何字符串加密，只有sha256验证。

- 把机器码转小写
- 前面拼接固定密钥 `xxxx`
- 做 SHA-256
- 取前 8 位十六进制字符串
- 转大写
- 作为注册码

#link("https://github.com/AlkaidLab/moonlight-harmony/blob/4834b42fd5c0694b51e03bf5080310f3022d3ad1/entry/src/main/ets/utils/DevKeyVerifier.ets#L53")[验证逻辑 DevKeyVerifier.ets]

```py
import hashlib; 
print((lambda d: hashlib.sha256(f"xxxx{d.lower()}".encode()).hexdigest()[:8].upper() if d else "")("code"))
```

=== Hokit <hokit>

Hokit作为闭源的、带有应用商店的侧载工具，校验一键安装是否可用属于打赏功能，经过abcd拆包后，我们不难找到和后端交互的逻辑

```java
public Object func_main_0(Object functionObject, Object newTarget, x2 this) {
    newlexenv(4);
    _lexenv_0_1_ = import { Logger } from "@normalized:N&&&entry/src/main/ets/a/l/m&"("AnnouncementService");
    _lexenv_0_0_ = "http://xxxxxxx/api/hokit-admin";
    _lexenv_0_2_ = "announcement_prefs";
    _lexenv_0_3_ = "dismiss_version";
    obj = hole.#~@0=#AnnouncementService(Object2, Object3, hole, ["getLatest", "&entry/src/main/ets/e/x2&.#~@0<#getLatest", 1, "isDismissedForVersion", "&entry/src/main/ets/e/x2&.#~@0<#isDismissedForVersion", 2, "setDismissedForVersion", "&entry/src/main/ets/e/x2&.#~@0<#setDismissedForVersion", 2, 0]);
    obj2 = obj.prototype;
    _module_0_ = obj;
    return obj;
}
```

执行 `POST /members/check/1`之后可以拿到`{"enabled":true,"permissions":["store"]}`，至于判断如何下载，参见

```java
ldlexvar4 = _lexenv_0_0_;
r152 = parse.enabled;
obj7 = r152;
if (isfalse(r152) == null) {
    obj8 = parse.permissions;
    obj7 = obj8.includes("download");
}
ldlexvar4.downloadEnabled = obj7;
ldlexvar5 = _lexenv_1_0_;
ldlexvar5.debug("Access check: appStore=%{public}s, download=%{public}s", isfalse(_lexenv_0_0_.appStoreEnabled) == null ? "true" : "false", isfalse(_lexenv_0_0_.downloadEnabled) == null ? "true" : "false");

```

加个 `download` 就好。我们改不了代码，但是可以通过修改二进制将远程后端改到同长度的链接，挂到CF Workers上就行

```js
export default {
  async fetch(request) {
    const url = new URL(request.url);
    const pathname = url.pathname;

    const headers = {
      "Content-Type": "application/json; charset=UTF-8",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "*",
      "Cache-Control": "no-store"
    };

    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers
      });
    }

    if (pathname.includes("members/check")) {
      return new Response(
        JSON.stringify({
          enabled: true,
          permissions: ["store", "download"]
        }),
        {
          status: 200,
          headers
        }
      );
    }

    if (pathname === "/announcements/public" && url.searchParams.has("version")) {
      return new Response(
        JSON.stringify({
          announcement: {
            title: "v1.4.5",
            date: "2026-03-22"
          },
          latestUpdate: {
            title: "v1.4.7",
            date: "2026-03-26",
            type: "update",
            version: "1.4.7"
          },
          latestNotice: {
            title: "重要通知",
            date: "2026-03-04",
            type: "notice",
            version: ""
          },
          upgradeAvailable: null
        }),
        {
          status: 200,
          headers
        }
      );
    }

    return new Response(
      JSON.stringify({
        error: "Not Found"
      }),
      {
        status: 404,
        headers
      }
    );
  }
}
```

使用WinHex等hex修改工具将`http://xxxxxxx/api/hokit-admin`等长改到自己的域名，挂到CF Workers上即可。


== 总结 <summary>

分析三个app之后，我发现
+ LLM对于用户身份核验、密码学等验证存在默认认知欠缺，应该使用公私钥校验等更安全的方法以增强安全性，而不是将*可推导的*加密验证部分塞进二进制中来提高难度，这种情况被爆破只是时间问题。

+ 应妥善保管hap包，通过AGC(华为应用商店)分发到设备。

+ 二进制敏感部位代码应使用控制流混淆来提高难度

+ 在abc文件不能被重打包的情况下，可在ets中增强验证二进制so代码是否合规，并且将敏感字符串通过分割为数组的形式或者数组转化成字符串的方式在ArkVM中拼接，来防止在abc文件中直接修改字符串