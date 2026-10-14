# ChmViewerRe — CHM Viewer 重建版

基于对 macOS App Store 应用 **CHM Viewer Star 6.3.7**（`com.Ababe.chmviewer5`）的
逆向分析（REA + Ghidra），以全新代码重建的 CHM 阅读器核心 + UI。
不含原应用的任何二进制代码或资源；解析层使用开源 CHMLIB（LGPL，即原应用内嵌的同源库）。

## 与原版对齐的架构

```
CHM 文件 → chmlib 解析 (ITSF/ITSP + LZX) → itss:// 自定义协议 → WKWebView 渲染
                    ↓
          ABCHMContent 解析 .hhc/.hhk → TOC 大纲 / 索引
```

对逆向结论逐条对齐：
- 原版嵌入式 chmlib（校验 ITSF/ITSP 魔数、0x4d8 句柄、块缓存 LZX）→ 本项目 vendor/chmlib
- `itss://chm/%@` 自定义协议（composeURL:）→ ItssSchemeHandler（WKURLSchemeHandler）
- `ABCHMContent initWithData:encodingName:`（libxml2 解析 hhc/hhk）→ 同名类，同依赖
- NSDocument 式文档模型 / `readFromFile:` 打开即 loadMetadata + setupTOCSource → CHMDocument
- 左侧 TOC 大纲 + 右侧 WebView + 右上角文本编码下拉 → CHMWindowController
- 侧栏顶部目录搜索框（实时过滤 9000+ 节点，平铺结果列表）
- 原版 chmlib 的 UTF-16 目录名 / PMGI collation 两处缺陷已修复（见下）

## 对原版 chmlib 的三处必要修复（逆向发现）

1. **UTF-16LE 目录名**：上游把条目名按字节拷贝，中文/长名乱码 → 补 UTF-16→UTF-8 转换
2. **PMGI 索引误定向**：上游用 strcasecmp（ASCII 序）走索引，但 CHM 实际 collation
   不同，大档案（>1 块）会 resolve 失败 → PMGI 失败后回退 PMGL 链线性扫描
3. **GBK 标题**：hhc 常为 GBK 编码 → UTF-8 探测失败回退 GB18030

页面文本编码支持 UTF-8 自动探测 + GB18030 回退，工具栏可手动切换（同原版"右上角编码"）。

## 构建

```bash
make          # 产出 build/ChmViewerRe.app 和 CLI 验证工具 build/chmtest
open build/ChmViewerRe.app 你的文件.chm
```

CLI 冒烟测试：

```bash
./build/chmtest 文件.chm                      # 枚举 + TOC 树 + 首页内容
./build/chmtest 文件.chm 内部/路径.html [偏移 长度]  # 按路径取内容
python3 tools/make_test_chm.py build/test.chm  # 生成无压缩测试 CHM
```

## 已验证

- UBM 2.0.RC2 二次开发指南（9240 条目、1.87MB hhc、LZX 多块、GBK 中文）：
  目录树/正文/页面内跳转/资源加载全部正常
- chmcmd（Free Pascal）生成的 LZX 压缩 CHM：解析与解压正常
- 自造无压缩 CHM：全链路 PASS

## 已知差异（vs 原版 6.3.7）

- 无多标签（原版用开源 PSMTabBarControl）、无书签/搜索/打印、无 #SYSTEM 标题解析
- 无内购/试用/VIP 逻辑（刻意未重建）
- DotZLib.chm（grpc third_party 内）文件本身截断 2 字节（72726 vs ITSF 声明 72728），
  最后一个 LZX 块无法解压属文件损坏，非阅读器问题

## 目录

- `src/` 应用源码（ObjC/AppKit，~1000 行）
- `vendor/chmlib/` CHMLIB 0.40（LGPL）+ 修复补丁
- `tools/` chmtest.m（CLI 验证）、make_test_chm.py（测试 CHM 生成器）
- `resources/Info.plist`
