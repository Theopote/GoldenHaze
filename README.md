# GoldenHaze

Iris 光影包。风格方向是温暖治愈系手绘动画光感——不追求物理写实，追求
"看起来像一帧手绘动画背景"。

## 开发原则

> **GoldenHaze 不应该把 Minecraft 截图「滤镜化成动画」，而应该重新解释
> Minecraft 世界的光、颜色和形体，使它在进入后期处理之前，就已经像一幅
> 动画背景画。**

这条原则区分 Phase 1 与 Phase 2：

| | Phase 1（当前） | Phase 2（目标） |
|---|---|---|
| 核心问题 | 原版场景 + 后期氛围 | 风格化光照 + 形体塑造 |
| 光照来源 | Vanilla lightmap | Painterly Lighting Model |
| GBuffer | scene + bright-pass | albedo / normal / material / depth |
| Bloom / God Ray | 决定画面风格的主要手段 | 最后的 10% 气氛 accent |
| 评价 | 不错的 Post Processing Prototype | 真正的吉卜力式渲染体系 |

---

## 完成度评估

整体约 **30%–40%**。方向没有走偏，但决定「是否像吉卜力」的核心模块尚未建立。

| 模块 | 评分 | 说明 |
|------|------|------|
| 风格方向 | 8/10 | 暖光冷影、非写实 tonemap 思路正确 |
| 天空 | 7/10 | 昼夜渐变 + 程序云 + 云亮/暗面分组，领先其他模块 |
| 色彩 | 6.5/10 | split-toning 有效，但目前仅依据最终像素亮度 |
| Bloom | 7/10 | 实现成熟，但权重偏高，易走向梦幻滤镜 |
| 光束 | 6/10 | 径向散射可用，应降级为辅助效果 |
| 水 | 5/10 | 青绿分块光照 + 闪光，待 palette 水体 2.0 |
| 植被 | 5.5/10 | 树叶独立色板 + 逆光 rim，闪光已融入 |
| 地形 | 5.5/10 | Painterly 宽色阶光照，仍依赖 lightmap 做洞穴/火把可见性 |
| 形体塑造 | 5.5/10 | 法线分块 + 太阳投影构图，大块柔和阴影 |
| 空气透视 | 5/10 | depthtex0 驱动：蓝移、去饱和、远景柔化（final.fsh） |
| 阴影系统 | 5/10 | 2048 软阴影 + 冷色投影 tint，待 entities pass |
| 材质统一性 | 3/10 | 各 pass 风格断裂（世界 vs 生物/手/天气） |
| 完整渲染管线 | 4/10 | GBuffer 2.0 已落地（normal + material），待接光照与 depth |

---

## Phase 1 已实现

以下模块方向正确，**保留并在此基础上演进**，不推倒重来：

- **暖光冷影 split-toning**（`final.fsh`）— 阴影偏冷紫、高光偏暖金
- **柔和 Bloom** — composite 阶段 bright-pass extract + 可分离高斯模糊
- **丁达尔光束** — `composite3` 径向采样
- **程序化天空** — `gbuffers_skybasic`：昼夜渐变、FBM 云、云亮/暗面分组
- **植被 / 水面闪光** — 世界空间噪声亮斑
- **纸张颗粒 + 非写实 tonemap**

当前管线（GBuffer 2.0）：

```
GBUFFER
  colortex0  lit scene color
  colortex1  view-normal (RGB) + material ID (A)

COMPOSITE
  composite   bright-pass extract (colortex0 → colortex2)
  composite1  bloom blur horizontal
  composite2  bloom blur vertical
  composite3  god rays (sample colortex2 → colortex3)

FINAL
  tonemap + split-tone + vignette + grain
```

**局限：** Painterly 光照已在 gbuffers 生效，但尚无 shadow map；生物/手部等待 pass 补全。

---

## Phase 2 路线图

按依赖顺序推进，不零散加效果：

### 2.0 — GBuffer 重构 ✅（已完成）

```
GBUFFER
  colortex0  Scene Color
  colortex1  Normal + Material ID   ← lib/gbuffer.glsl
  colortex2  Bloom working buffer
  colortex3  God-ray accumulation

COMPOSITE
  composite   Bloom extract
  composite1  Bloom blur (H)
  composite2  Bloom blur (V)
  composite3  God rays

FINAL
  Color Grade → Paper Texture → Vignette
```

- Bright-pass 已移出 gbuffers，改在 `composite.fsh` extract
- `colortex1` 专用于 GBuffer，不再被 bloom 占用
- 材质 ID：`MAT_DEFAULT` / `MAT_FOLIAGE` / `MAT_WATER` / `MAT_SKY`
- 待办：接入 `depthtex0`、在 composite 读取 GBuffer 做光照

### 2.1 — 空气透视 ✅（已完成）

在 `final.fsh` 读取 `depthtex0` + `colortex1`（跳过天空材质）：

- 基于线性视空间深度的 haze（`ATMOSPHERE_START` / `ATMOSPHERE_END`）
- 向地平线色调混合（昼夜 / 日落 / 雨天联动 `sunPosition`）
- 降低饱和度与对比度
- 远景 4-tap 柔化，减弱方块纹理细节

实现：`lib/atmospheric.glsl`

### 2.2 — Painterly Lighting Model ✅（已完成）

`lib/painterly.glsl`，在 gbuffers 阶段替换 `albedo * lightmap`：

- 3 段宽色阶：冷阴影 → 中性中间 → 暖阳光（`NdotL` + `sunPosition`）
- `lmcoord` 控制户外/洞穴/火把可见性（非最终颜色来源）
- 材质分支：`MAT_FOLIAGE`（黄绿日光 + 蓝绿阴影 + 逆光 rim）、`MAT_WATER`（青绿调）
- `PAINTERLY_STRENGTH` 滑块可回混 vanilla lightmap

待办：迁移到 composite deferred 路径、结合 shadow map

### 2.3 — Stylized Shadow Map ✅（已完成）

- `shadow.vsh/fsh` + `shadow_water` — 地形/水面投射阴影
- `lib/shadow.glsl` — 透视畸变 + 5×5 软 PCF + 坡度 bias
- 接入 `shadePainterly()`：仅户外太阳光受阴影影响，火把/洞穴 ambient 不受影响
- 投影区冷紫蓝 tint（`stylizedShadowTint`），最低亮度保留 ~32% 避免死黑
- `shaders.properties`：`shadowMapResolution=2048`，`shadowDistance=128`
- 滑块：`SHADOW_STRENGTH`、`SHADOW_SOFTNESS`

待办：`shadow_entities`、树叶半透明投影

### 2.4 — Foliage Rendering 2.0（最大视觉杠杆）

树是玩家最常看到的东西，应成为最重要的视觉模块：

- 树冠大块亮暗（world-space 大尺度噪声）
- 垂直色阶：顶暖黄绿 → 中自然绿 → 底蓝绿/深绿
- 向阳暖 tint / 背光青绿
- 树冠内部阴影（canopy shadow）
- 逆光边缘透光（rim translucency）
- 现有 sparkle 融入 foliage shading，而非「原版树叶 + 闪光」

### 2.5 — Water Rendering 2.0

- 水体统一 palette（天空蓝 / 青绿 / 深蓝 / 夕阳橙）
- 基于 depth 与视角的距离着色
- 动画式高光：细长横向、断续高光带，替代随机噪声亮点

### 2.6 — Cloud 2.0

从 FBM 主导转向 **Stylized Cloud Shape Model**：

- Macro blob + secondary blobs + bottom clipping + sun-side expansion
- 有限内部噪声（如 `macro 70% + medium 25% + detail 5%`）
- 强调 silhouette、mass、hard/soft edge hierarchy

### 2.7 — 统一材质 palette

grass / leaves / wood / stone / soil / water / snow 各有一套
动画背景式的色板，而非仅靠后期调色统一。

### 2.8 — 补全缺失 pass

消除风格断裂（以 Iris 当前 pipeline 支持为准）：

- `gbuffers_entities`
- `gbuffers_hand`
- `gbuffers_textured` / `gbuffers_textured_lit`
- `gbuffers_weather`
- `gbuffers_particles`

### 2.9 — 后期参数重调（最后 10%）

部分已在 Phase 1 末期预先收敛（`final.fsh` 默认值）：

- God Ray 默认 `0.45`（原 `0.9`），降级为辅助气氛
- Chroma Aberration 默认 `0.0`（原 `0.6`），可选 cinematic 效果
- Paper grain 默认 `0.35`（原 `1.0`），固定 screen-space、不 drift

Phase 2 主体完成后，再连同 Bloom 等一并重调。

---

## 目录结构

```
GoldenHaze/
└─ shaders/
   ├─ shaders.properties           # 缓冲区配置 + 可调选项
   ├─ lib/gbuffer.glsl            # GBuffer 编码：法线 + 材质 ID
   ├─ lib/painterly.glsl          # 宽色阶手绘光照模型
   ├─ lib/atmospheric.glsl        # 空气透视
   ├─ lib/shadow.glsl             # 风格化阴影采样
   ├─ shadow.vsh/.fsh             # 阴影贴图 pass
   ├─ shadow_water.vsh/.fsh       # 水面阴影
   ├─ gbuffers_terrain.vsh/.fsh # 方块几何体：scene + GBuffer
   ├─ gbuffers_water.vsh/.fsh     # 水面
   ├─ gbuffers_basic.vsh/.fsh     # 兜底 pass
   ├─ gbuffers_skybasic.vsh/.fsh  # 天空穹顶：昼夜渐变 + 程序云
   ├─ gbuffers_skytextured.vsh/.fsh # 太阳/月亮
   ├─ composite.vsh/.fsh           # Bloom bright-pass extract
   ├─ composite1.vsh/.fsh          # Bloom 模糊（水平）
   ├─ composite2.vsh/.fsh          # Bloom 模糊（垂直）
   ├─ composite3.vsh/.fsh          # 丁达尔光束
   └─ final.vsh/.fsh              # 合成 + tonemap + 调色 + 颗粒
   └─ textures/canvas.png         # 纸张颗粒纹理
```

Phase 2 将新增 `lib/`（共享 GLSL）、扩展 GBuffer 输出、补全 entities 等 pass。

## 如何测试

1. 安装 Fabric Loader + Fabric API + [Iris](https://irisshaders.dev/)。
2. 把 `GoldenHaze` 文件夹放进 `.minecraft/shaderpacks/`。
3. 游戏内 **视频设置 → 光影包** → 选择 GoldenHaze。
4. 找一个阳光充足、有树荫的场景——辉光与光束在亮部区域最明显；
   阴天或洞穴里效果会弱很多。

## 已知限制

- 生物 / 手部 / 天气 / 粒子等 pass 未实现（走原版 fallback，风格断裂）。
- Stylized shadow map 已在 terrain/water/basic 生效；entities 仍走 vanilla。
- 所有已实现效果的参数已接入光影设置界面，可在游戏内实时调节。

## 工具

`tools/make_canvas_texture_stdlib.py` 用纯 Python 标准库程序化生成
画布纹理（编织纹 + 纸浆斑块 + 细颗粒，无缝平铺），输出到
`shaders/textures/canvas.png`。想换一张纹理直接改随机种子重新生成即可。
