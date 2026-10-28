# Third-Party Notices

本项目（`liltoon_gd`）在实现过程中参考并使用了以下第三方软件。
依其许可证要求，在此保留原版权声明与许可证全文。

---

## lilToon

- **软件名**：lilToon（`jp.lilxyzw.liltoon`）
- **版本**：2.4.1
- **作者**：lilxyzw
- **项目地址**：<https://github.com/lilxyzw/lilToon>
- **文档**：<https://lilxyzw.github.io/lilToon/>
- **许可证**：MIT License
- **版权所有**：Copyright (c) 2020-2024 lilxyzw

### 使用方式

`liltoon_gd` 是把 lilToon 的卡通渲染行为移植到 Godot 4 的**非官方实现**，二者无隶属关系。
本项目对 lilToon 的使用分为两部分：

1. **行为与参数语义的对齐**：shader 的数学模型、参数命名与默认值以 lilToon 2.4.1 的
   HLSL 源码为唯一依据；`addons/liltoon_gd/` 下的 GDShader 为本项目重写的 Godot 实现，
   不包含 lilToon 的 HLSL 源码。
2. **随仓库分发的参考源码**：`lilToon-2.4.1/` 目录是 lilToon 2.4.1 的原始发行内容
   （Unity C# / HLSL），仅作为对齐校验与二次开发的参照，**不参与 Godot 插件运行**。
   该目录内自带上游的 `LICENSE` 文件。

本项目中所有以 `lil` / `liltoon` 命名的类、变量与文档表述，均指代上述参考来源。

### 原始许可证全文

```
MIT License

Copyright (c) 2020-2024 lilxyzw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 说明

- 本项目自身采用 MIT License，见仓库根目录 [`LICENSE`](../../LICENSE)。
- 对外分发本项目（含衍生作品）时，**必须一并保留本文件**。
- 若本项目随仓库分发的 `lilToon-2.4.1/` 目录被移除，本文件中关于该目录的说明即不再适用，
  但上述 lilToon 署名与许可证全文仍需保留。
