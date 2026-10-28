# 第三方声明

本项目在实现过程中参考了下列开源项目。按各自许可证要求保留声明。

---

## lilToon

- **项目**：https://github.com/lilxyzw/lilToon
- **版本**：2.4.1（对照基准）
- **作者**：lilxyzw
- **许可证**：MIT

### 使用方式

本项目的 shader 并非 lilToon 源码的直接复制，但**大量实现逻辑、参数语义、默认值取自 lilToon**：

- 参数命名与语义对照（`docs/参数对齐矩阵.md` 记录 578 项属性的映射关系）
- 着色算法的移植（多层卡通阴影、`lilTooningScale` 的边界/柔化/抗锯齿处理、`lilGetAnisotropyNormalWS` 的各向异性法线、Kajiya-Kay 高光、MatCap 的 `lerp(matCapColor, matCapColor * albedo, mainStrength)`、Glitter 的程序化闪点等）
- 默认值（`tools/compare_defaults.py` 逐项对照 `lts.shader` 的 Properties）
- 预设色彩参考（`Cloth-*` / `Hair-*` 等官方预设）

按 MIT 的要求，下列原始许可证全文保留。

### 原始许可证

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

## Godot Engine

- **项目**：https://godotengine.org
- **许可证**：MIT
- **说明**：本项目是 Godot 插件，运行依赖 Godot 4。Godot 自身的许可证与本项目独立，无需在此重复。

---

## 关于本项目自身

本项目的许可证**尚未确定**（待维护者决定）。在确定之前，建议：

- 内部使用无碍
- 若公开发布，需先选定许可证并添加 `LICENSE` 文件
- 无论选何种许可证，**本文件中的 lilToon MIT 声明必须保留**
