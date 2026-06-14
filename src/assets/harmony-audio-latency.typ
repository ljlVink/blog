#import "/typ/templates/blog.typ": *

#show: main.with(
  title: "HarmonyOS Ultrafast Audio",
  author: "Vink",
  description: "HarmonyOS 系统级低延迟音频解析",
  pubDatetime: "2026-03-26T00:00:00Z",
  tags: ("typst", "reverse", "harmonyos"),
  featured: true,
  draft: false,
)

= HarmonyOS 系统级低延迟音频 解析

在华为发布MatePad Pro Max之后。我们不难发现华为上架了一个 音悦家 的APP。在进入店内体验时，不仅发现了启动会默认屏蔽指关节 (?)并且在输入-响应链路延迟上体感很低。

#strike[实际上我是为了去测试phira帧率的。打了一把发现音频延迟远高于我的平板，晚上和群友聊在coolapk上找到了一篇关于ultrafast的信息]

遂定位代码，拆固件分析。

== Part 1: 真的存在白名单吗

由于我并没有真正的MatePad Pro Max设备，于是我拿到我的平板，搭载`HarmonyOS 6.1(24)`的平板固件进行分析。

在分析的过程发现在四月份的固件中甚至找不到关于Ultrafast的内容。可知Ultrafast能力应该是6.1版本现加的。

已知固件system分区 可知 

```bash
==========================================
查找调用 com.huawei.hmos.musiccreate 的文件
==========================================

找到: ./base_images/system/system/lib64/ndk/libcolorpicker_ndk.z.so
找到: ./base_images/system/system/lib64/ndk/libudmf.so
找到: ./base_images/system/system/lib64/libaudio_policy_service.z.so
找到: ./base_images/system/system/lib64/platformsdk/libudmf_client.z.so
找到: ./base_images/system/system/lib64/libaudio_schedule.z.so
找到: ./base_images/system/system/lib64/libstylus_service.z.so
找到: ./base_images/system/system/lib64/libstylus_innerapi.z.so
找到: ./base_images/system/system/lib64/module/hms/officeservice/libimagefeaturepicker.z.so
找到: ./base_images/system/system/lib64/module/hms/officeservice/libstylusinteraction.z.so
找到: ./base_images/system/system/lib64/module/hms/officeservice/libstylusservice.z.so

==========================================
共找到 10 个文件
==========================================
  - ./base_images/system/system/lib64/ndk/libcolorpicker_ndk.z.so
  - ./base_images/system/system/lib64/ndk/libudmf.so
  - ./base_images/system/system/lib64/libaudio_policy_service.z.so
  - ./base_images/system/system/lib64/platformsdk/libudmf_client.z.so
  - ./base_images/system/system/lib64/libaudio_schedule.z.so
  - ./base_images/system/system/lib64/libstylus_service.z.so
  - ./base_images/system/system/lib64/libstylus_innerapi.z.so
  - ./base_images/system/system/lib64/module/hms/officeservice/libimagefeaturepicker.z.so
  - ./base_images/system/system/lib64/module/hms/officeservice/libstylusinteraction.z.so
  - ./base_images/system/system/lib64/module/hms/officeservice/libstylusservice.z.so


相关配置引用:
./base_images/system/system/etc/utd/conf/uniform_data_types.json:            "TypeId": "com.huawei.hmos.musiccreate.gofile",
./base_images/system/system/variant/tablet/base/etc/app/default_app.json:    "bundleName": "com.huawei.hmos.musiccreate",
./base_images/system/system/variant/tablet/base/etc/app/default_app.json:    "appType": "com.huawei.hmos.musiccreate.gofile",
./base_images/system/system/variant/tablet/base/etc/app/default_app.json:    "bundleName": "com.huawei.hmos.musiccreate",
./base_images/sys_prod/sys_prod/etc/aps_manager/aps_manager_config.xml:    <aps name="com.huawei.hmos.musiccreate" type ="993" rate="3" apptype="default" />
```

参考
#link("https://www.coolapk.com/feed/71726197?s=Y2RjYzU4NWQxNWEwZmI1ZzZhMmQ4OGJiega1603")["简单探下HarmonyOS 6 低延迟音频"]

可知我们可以查看`AudioPolicyService`.

使用
```sh
hidumper  -s AudioPolicyService
```

```
Stream 100114:
  - StreamStatus: 1 (STARTED)
  - CallerUid: 20020310 CallerPid: 62423 AppUid: 20020310 AppPid: 62423
  - SampleRate: 48000 ChannelCount: 2 ChannelLayout: 3 Format: 4 Encoding: 0
  - AudioFlag: 0x20 RouteFlag: 0x20 OldRouteFlag: 0x20
  - CreateTimestamp: 27008490941440
  - StartTimestamp: 27008594095033
  - StateStartTimestamp: 0
  - StreamUsage: 11
  - PlayerType: 100
  - OriginalFlag: 1 RendererFlags: 1
  - OffloadAllowed: 1
  - UltraFastFlag: 0
  - OldDevices:
    - device 1: role Output type 2 (SPEAKER) name:
  - NewDevices:
    - device 1: role Output type 2 (SPEAKER) name:
```


可看到如下内容 (以下是Phira的) 可发现当前`StreamUsage`为11, 即游戏，#link("https://github.com/Mivik/sasa/blob/4470cd7867f2fd4e0ef4800b27dfa993fc97afca/src/backend/ohos.rs#L96","这里是sasa源代码")，但是 `UltraFastFlag: 0`。

继续分析。

我们转头查看OHOS 6.1的源码，整理下`UltraFastFlag`的线索。

我们考虑`OHAudio`配置`AUDIOSTREAM_LATENCY_MODE_FAST`获得的普通低延迟，UltraFast 更像系统的特权路径。

#set quote(block: true)
#quote()[
  1. 普通 `OHAudio` 主要是在公开 API 层请求低延迟，系统在设备支持时把流放到 `fast/mmap` 路由。

  2. `UltraFast` 仍然复用 `fast/mmap` 这条基础低延迟通道，但额外要求产品配置、bundle 白名单、设备类型、并发状态都满足。

  3. `UltraFast` 将 endpoint 的 period 从普通 fast 的 5 ms 级进一步压到 2.5 ms 级，并让播放 callback 线程使用更激进的 CPU 绑核与线程优先级策略。

  4. 代价是更高功耗、更高 CPU 唤醒频率、更小的 underrun 容错、更弱的并发公平性，所以它被系统限制给特定内置/自家音频软件是合理的。
]


#let flow-fill(tone) = if tone == "entry" {
  rgb("#fff8c5")
} else if tone == "gate" {
  rgb("#ffebe9")
} else if tone == "route" {
  rgb("#ddf4ff")
} else if tone == "result" {
  rgb("#e6ffec")
} else {
  rgb("#f6f8fa")
}

#let flow-stroke(tone) = if tone == "entry" {
  rgb("#d4a72c")
} else if tone == "gate" {
  rgb("#cf222e")
} else if tone == "route" {
  rgb("#0969da")
} else if tone == "result" {
  rgb("#1a7f37")
} else {
  rgb("#d0d7de")
}

#let flow-node(num, title, note: none, tone: "normal") = {
  rect(
    width: 100%,
    inset: (x: 0.8em, y: 0.62em),
    radius: 5pt,
    fill: flow-fill(tone),
    stroke: (paint: flow-stroke(tone), thickness: 0.7pt),
  )[
    #strong[#num. #title]
    #if note != none [
      #linebreak()
      #text(size: 8.5pt, fill: rgb("#57606a"))[#note]
    ]
  ]
}

#let flow-arrow() = align(center)[
  #text(size: 14pt, fill: rgb("#8c959f"))[↓]
]

#figure(
  block(width: 100%)[
    #set text(size: 9.4pt)

    #flow-node("1", [系统/白名单应用], note: [设置 `latency mode = 11`], tone: "entry")
    #flow-arrow()
    #flow-node("2", [`OHAudioStreamBuilder`], note: [保存 `latencyMode_`])
    #flow-arrow()
    #flow-node("3", [Generate Renderer], note: [写入 `AudioRendererInfo.rendererFlags`])
    #flow-arrow()
    #flow-node("4", [`AudioRenderer` 创建], note: [把 `rendererFlags` 复制到 `originalFlag`])
    #flow-arrow()
    #flow-node(
      "5",
      [`AudioPolicy::UpdatePlaybackStreamFlag`],
      note: [识别 `AUDIO_FLAG_ULTRA_FAST`],
      tone: "gate",
    )
    #flow-arrow()
    #flow-node("6", [`IsSupportUltraFast`], note: [做产品、bundle、设备检查], tone: "gate")
    #flow-arrow()
    #flow-node(
      "7",
      [通过检查后],
      note: [`SetUltraFastRequested(true)`，并仍映射到 `mmap/fast` 路由],
      tone: "route",
    )
    #flow-arrow()
    #flow-node(
      "8",
      [`AudioPipeSelector`],
      note: [创建/匹配 fast pipe，必要时 `SetUltraFastFlag(true)`],
      tone: "route",
    )
    #flow-arrow()
    #flow-node("9", [`streamDesc`], note: [得到 `ULTRA_IMPLEMENTED`], tone: "route")
    #flow-arrow()
    #flow-node("10", [`AudioRenderer`], note: [将 `ultraFastFlag` 传给 `AudioStreamParams`])
    #flow-arrow()
    #flow-node("11", [`FastAudioStream`], note: [将 `ultraFastFlag` 写入 `AudioProcessConfig`])
    #flow-arrow()
    #flow-node("12", [`AudioService`], note: [根据 session 查询 `isUltraFast`])
    #flow-arrow()
    #flow-node(
      "13",
      [`AudioEndpoint`],
      note: [用 2.5 ms period 初始化 fast sink],
      tone: "result",
    )
    #flow-arrow()
    #flow-node(
      "14",
      [客户端播放 callback 线程],
      note: [在双 bit 成立时绑中/大核并申请更高优先级],
      tone: "result",
    )
  ],
  caption: [UltraFast 音频链路流程],
)
