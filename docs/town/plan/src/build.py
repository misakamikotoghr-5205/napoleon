# 德厚当 交付计划 PDF 的 HTML 源
import gantt

CSS = """
@page { size: A4 landscape; margin: 11mm 12mm 11mm 12mm; }
:root { --ink:#0b0b0b; --ink2:#52514e; --muted:#8a8984; --line:#e4e3df; --paper:#fcfcfb;
  --a:#2a78d6; --b:#eb6834; --out:#1baf7a; --steam:#eda100; --warn:#b54708; }
* { box-sizing: border-box; }
body { margin:0; background:var(--paper); color:var(--ink); font-family:"WenQuanYi Zen Hei", sans-serif; font-size:10.5px; line-height:1.5; }
.page { page-break-after: always; break-after: page; }
.page:last-child { page-break-after: auto; }
h1 { font-size:24px; margin:0 0 2px; letter-spacing:1px; }
h2 { font-size:15px; margin:0 0 8px; padding-bottom:4px; border-bottom:2px solid var(--ink); }
h3 { font-size:12px; margin:10px 0 4px; }
.sub { color:var(--ink2); font-size:11px; margin-bottom:10px; }
.grid2 { display:grid; grid-template-columns: 1fr 1fr; gap:14px; }
.grid3 { display:grid; grid-template-columns: 1fr 1fr 1fr; gap:12px; }
.card { border:1px solid var(--line); border-radius:6px; padding:8px 10px; background:#fff; }
.card h3 { margin-top:0; }
.tag { display:inline-block; padding:0 6px; border-radius:3px; font-size:9.5px; margin-right:4px; border:1px solid var(--line); }
.tA { border-left:4px solid var(--a); } .tB { border-left:4px solid var(--b); } .tO { border-left:4px solid var(--out); } .tS { border-left:4px solid var(--steam); }
table { width:100%; border-collapse:collapse; }
th, td { border-bottom:1px solid var(--line); padding:3px 5px; vertical-align:top; text-align:left; }
th { font-size:10px; color:var(--ink2); border-bottom:1.5px solid var(--ink); font-weight:bold; }
td.n { white-space:nowrap; }
ul { margin:2px 0 2px 16px; padding:0; } li { margin:1px 0; }
.big { font-size:13px; }
.kpi { display:flex; gap:10px; margin:8px 0 10px; }
.kpi div { flex:1; border:1px solid var(--line); border-radius:6px; padding:6px 8px; background:#fff; }
.kpi b { display:block; font-size:16px; }
.kpi span { color:var(--ink2); font-size:10px; }
.note { color:var(--ink2); font-size:9.5px; }
.warn { border:1.5px solid var(--warn); border-radius:6px; padding:6px 10px; background:#fff8f1; }
.legend span { margin-right:12px; font-size:10px; }
.sw { display:inline-block; width:14px; height:10px; border-radius:2px; vertical-align:middle; margin-right:4px; }
.wk td { font-size:9.6px; line-height:1.38; }
.wk td:first-child { white-space:nowrap; font-weight:bold; }
.tight td { padding:2px 4px; font-size:9.7px; line-height:1.36; } .tight li { margin:0; } .tight th { padding:2px 4px; }
.foot { position:fixed; bottom:-6mm; right:0; font-size:8.5px; color:var(--muted); }
"""


def page(inner: str) -> str:
    return f'<section class="page">{inner}</section>'


P1 = page("""
<h1>德厚当 · 交付时间线与里程碑</h1>
<div class="sub">2026-10-12 → 2027-01-31（16 周）　·　两人团队：<b style="color:var(--a)">A 剧情·美术</b>　<b style="color:var(--b)">B AI 编程·音乐</b>　·　基线：v0.4.2「只守铺子」（commit f8d8567）</div>
<div class="kpi">
  <div><b>1 月 28 日（周四）</b><span>建议 Steam 发售日（在 2/6 春节之前，落在 1/25–2/1「店主节」里）</span></div>
  <div><b>1 月 29 日（周五）</b><span>两个版本交付：完成版（独立版）＋ Steam 版</span></div>
  <div><b>8 个里程碑</b><span>M0 10/16 → M7 1/28，每个都有可以逐项打勾的验收条件</span></div>
  <div><b>约 ¥2.6 万</b><span>外包＋工具（区间 ¥1.6–5.4 万，另留 10% 机动）</span></div>
</div>
<div class="grid2">
 <div class="card">
  <h3>两个交付物怎么定义</h3>
  <ul>
   <li><b>完成版</b>：玩法、剧情、3 个结局都做完的完整游戏，不依赖 Steam 客户端也能玩（独立 zip）。<b>12/18（M4）</b>先出“功能与剧情完整”的版本；1/29 交付最终版。</li>
   <li><b>Steam 免 AI 声明版</b>：和完成版<b>同一套内容</b>，再接入 Steam（云存档、成就可选）。玩家能看到、听到、读到的东西——美术、音乐、音效、文字、商店页、预告片、宣传图——<b>全部由人制作或有授权</b>。</li>
   <li>建议两个版本共用一套全人工内容：做两套内容要测两遍，还容易把 AI 素材误带进 Steam 截图。</li>
  </ul>
  <h3>AI 声明：结论</h3>
  <ul>
   <li>Valve 在 <b>2026 年 1 月</b>改写了声明表：重点是“随游戏发出、被玩家消费的内容”（美术、声音、叙事、本地化等）；“AI 开发工具带来的效率”不是这部分的重点。多家媒体把它解读为<b>用 AI 写代码不需要声明</b>，但有一家律所博客持不同看法——<b>属于普遍解读，尚有争议</b>。</li>
   <li>本计划的做法：<b>代码继续用 AI 辅助</b>（B 的分工）；<b>由 AI 写的程序画出来的像素图、合成出来的音乐也当作 AI 内容，全部换掉</b>（Valve 对这一点没有表态，按最保守的理解处理）。</li>
   <li>现状：v0.4.2 的 160 张图、10 首音乐、9 个合成音效、约 4.3 万字守铺可见文字<b>全部是 AI 产出</b>，都要人工重做。</li>
  </ul>
 </div>
 <div class="card">
  <h3>需要你在 10/16（M0）前拍板的决定（括号里是默认）</h3>
  <table>
   <tr><td class="n">D1 范围</td><td>只守铺子，不加出门/小镇（出门版放到发售后）</td></tr>
   <tr><td class="n">D2 篇幅</td><td>14 天 + 终章；第 13–14 天重写成高潮，约 5–8 小时流程</td></tr>
   <tr><td class="n">D3 结局</td><td>3 个结局（钱与债、德字第一九六号、通敌/嫌疑），结束后放制作人员名单</td></tr>
   <tr><td class="n">D4 发售</td><td>1/28 在 Steam 发售；不参加 2 月新品节（新品节要求 3/1 之后发售）</td></tr>
   <tr><td class="n">D5 外包</td><td>4 份禁 AI 合同外包：C1 主视觉封面、C2 头像约 21 人、C3 行走图身体 16 个、C4 通用物品 11 + 陈设 15</td></tr>
   <tr><td class="n">D6 语言</td><td>只做简体中文；任何地方不用机器翻译（翻译也算 AI 内容）</td></tr>
   <tr><td class="n">D7 文字</td><td>按大纲<b>从头重写</b>，不在 AI 稿上改；发出的文字不用 AI 润色/纠错</td></tr>
   <tr><td class="n">D8 音乐</td><td>3 首循环（标题/当铺/夜）+ 3 个短乐句 + 结局曲，江南丝竹配器</td></tr>
   <tr><td class="n">D9 工时</td><td>按每人每周 5 天算（共 79 人日）；若每周 5.5 天需两人同意</td></tr>
   <tr><td class="n">D10 签约</td><td>Steamworks 用个人还是公司签（决定税表 W-8BEN / W-8BEN-E）</td></tr>
   <tr><td class="n">D11 定价</td><td>11/27 前定</td></tr>
  </table>
 </div>
</div>
<div class="warn" style="margin-top:10px"><b>必须先说明的不确定性：</b>研究时 partner.steamgames.com 被网络代理拦截，所有 Steamworks 规则（30 天等待、即将推出≥14 天、审核 3–5 个工作日、素材尺寸、AI 声明原文）都来自搜索摘要和媒体报道，<b>没有读到官方页面原文</b>。登录 Steamworks 后台后请逐条核对；费用与外包价格是估算。</div>
<div class="foot">德厚当 交付计划 · 2026-10-12</div>
""")

P2 = page(f"""
<h2>时间线（甘特图）</h2>
<div class="legend"><span><i class="sw" style="background:var(--a)"></i>A 剧情·美术</span><span><i class="sw" style="background:var(--b)"></i>B 程序·音乐</span><span><i class="sw" style="background:var(--out)"></i>外包（禁 AI 合同）</span><span><i class="sw" style="background:var(--steam)"></i>Steam·行政</span><span>◆ 里程碑</span><span><i class="sw" style="border:1.2px dashed #0b0b0b;background:#fff"></i>关键路径（拖了就影响 1/28 发售）</span><span><i class="sw" style="background:repeating-linear-gradient(45deg,#f3f2ee 0 3px,#d9d7d0 3px 5px)"></i>不可用时段</span></div>
{gantt.svg()}
<div class="grid3" style="margin-top:6px">
 <div class="note"><b>关键路径</b>：入驻资料 → 10/23 付 $100 → 30 天等待（到 11/22）→ 12/2 商店素材齐 → 12/7 提交商店页 → 12/16 即将推出 → 1/13 提交构建与预告 → 1/14 发售日锁定 → 1/28 发售。</div>
 <div class="note"><b>Valve 假期 12/21–1/4</b> 不提交任何需要审核的东西（审核可能变慢，未核实）；1/18 美国 MLK 假日。</div>
 <div class="note"><b>春节</b>：2027-02-06（周六），放假约 2/5–2/11（官方安排约 11 月公布）。1/28–2/4 是热修窗口，2/5 起冻结。</div>
</div>
""")

MS = [
 ("M0", "启动与决策", "周五 10/16", "A+B", ["D1–D11 写进 docs/DECISIONS.md", "Steamworks 账号建好，入驻（身份/税表/银行）已开始", "素材来源清单 ASSET_PROVENANCE.csv 列出 v0.4.2 每个发出的文件，全部标 ai_legacy", "Steam 导出用白名单预设：包里没有 tests/、tools/、模型、来源 JSON", "CI 拦截上线：带 AI 合写标记的提交改动文字/美术/音频路径即失败"]),
 ("M1", "预制作锁定", "周五 10/30", "A 风格/剧情；B 工具/行政", ["$100 已付（收据日期 ≤10/23）", "风格指南 + 3 个基准像素图提交（含分层源文件）", "<b>测速关</b>：A 的基准图耗时 ≤ 估算的 110%；B 的 60–90 秒标题曲小样 A 认可。任一不过 → 11/2 加外包（物品/陈设或音乐）", "大纲（每天的字数目标）+ 3 结局矩阵两人签字", "C1、C2 试稿、C3 试稿已下单（禁 AI 合同已签）", "结局系统合入，测试全绿"]),
 ("M2", "人工美术垂直切片（柜台）", "周五 11/27", "A 美术；B 接入", ["柜台背景 4 张、工具 25 个、≥12 件物品、瑕疵贴花库、室内地砖全部人工，清单有记录", "截图要用的角色在柜台特写里<b>零</b> AI 旧素材；另附一份“还剩哪些 AI 素材、哪天换掉”的清单", "第 1–8 天文字为人写（_provenance: human）", "标题/当铺/夜 3 首循环 + 3 个短乐句定稿", "存档迁移测试通过；30 天等待已过；入驻资料已通过；定价已定"]),
 ("M3", "商店页上线（即将推出）", "提交 12/7 → 上线 周三 12/16", "B 上传；A 文案/标志", ["胶囊图 920×430 / 462×174 / 1232×706 / 748×896；图书馆 600×900、3840×1240、标志 1280 宽、图书馆头图 920×430、社区/客户端图标", "≥5 张 1920×1080 截图（≥4 张标“全年龄”），只拍已人工化的柜台画面", "中文简介只写发售时真有的功能；价格、配置要求、内容调查（含成人主题）填好", "提交前<b>重读后台 AI 声明表原文</b>，A/B 签字后填“无”", "30–45 秒柜台预告短片；社媒公布带愿望单链接"]),
 ("M4", "Alpha：完成版功能与剧情完整", "周五 12/18", "B 程序；A 剧情", ["开始 → 任一结局 → 制作人员名单 → 回标题，完整可玩；每个结局有自动试玩测试", "全部剧情/会话/结局文字为人写；全部玩家可见汉字 ≥70% 为人写", "必需音乐与音效全部替换，合成哔哔声删除；A 认可音乐", "Steam 接入版上传到私有分支能启动", "经济平衡第 2 轮：5 个种子里 ≥3 个达标（第 14 天资金在开局 340 的 0.6–3 倍，保护费天天付得起）", "12/19 发出第 1 轮外部试玩（3–5 人）"]),
 ("M5", "Beta：素材齐全 + 文字锁定", "周五 1/8（1/11 定去留）", "A+B", ["审核脚本对 Steam 导出 <b>0 违规</b>：无 AI 旧哈希、无 ai_draft、无清单外文件、与旧素材像素相似度 &gt;20% 的为 0、与旧文本四字重合 ≥30% 的已人工复核", "所有外包交付（分层源文件、WIP、合同、收据归档）", "文字锁定、字形表冻结", "试玩 1 的 P0/P1 修完；经济 5 个种子里 ≥4 个达标", "新品节决定已记录（默认不参加）"]),
 ("M6", "提交构建审核", "周三 1/13（最迟周五 1/15）", "B", ["RC1 经 SteamPipe 上传并提交审核；预告片上传转码完成", "发售日 1/28 已设（1/14 起锁定）", "字体子集重做、字形测试绿；全部测试绿；3 台机器冒烟（含 Intel 核显）", "一位外部测试者在 RC 上通关、无阻断；≥3/5 试玩者通关，记录中位时长", "A、B 签 AUDIT_SIGNOFF.md；独立版不带 steam_api64.dll 也能运行"]),
 ("M7", "上线与交付", "周四 1/28 发售；周五 1/29 交付", "B 发布；A 宣传", ["审核通过，手动按“发布”；首发折扣 1/28–2/11 生效", "完成版独立 zip 交付（含许可声明、新写的玩家须知、SmartScreen 说明）", "来源证明包归档（清单、许可、源文件、MIDI/工程、草稿、延时录像）", "首日补丁流程测过：RC 的存档能被补丁版读取"]),
]


def ms_table() -> str:
    rows = []
    for mid, name, date, owner, ex in MS:
        lis = "".join(f"<li>{e}</li>" for e in ex)
        rows.append(f'<tr><td class="n"><b>{mid}</b></td><td class="n"><b>{name}</b><br><span class="note">{date}</span><br><span class="note">负责：{owner}</span></td><td><ul>{lis}</ul></td></tr>')
    return '<table class="tight"><tr><th style="width:34px">编号</th><th style="width:190px">里程碑 / 日期 / 负责</th><th>验收条件（全部打勾才算过）</th></tr>' + "".join(rows) + "</table>"


P3 = page(f"<h2>里程碑与验收条件</h2>{ms_table()}")

WEEKS = [
 ("W1", "10/12–10/18", "M0 决策；剧情大纲 v1（14 天+终章+3 结局）；风格指南草案", "注册 Steamworks、开始入驻；来源清单与 AI 旧素材哈希黑名单；Steam 导出白名单；生成器移到归档分支；CI 拦截 AI 改文字/美术/音频；删 persona_residual 模型", "写禁 AI 约稿合同模板（参考、底稿也不许用 AI；分层源文件；≥2 个 WIP；分期付款）", "10/16 M0"),
 ("W2", "10/19–10/25", "风格指南定稿 + 3 个基准像素图（测速）；主角色设定（给外包当需求）；大纲 v2 + 结局矩阵", "审核脚本 v0 进 CI；把 .gd 里的玩家文字抽到 data/strings；作曲环境（REAPER + 民乐音源），标题曲草稿", "<b>10/21 下单</b> C1 主视觉；C2 试稿（胡二或陈叔叔头像）；C3 试稿（沈如花行走图）", "<b>10/23 付 $100</b>（30 天等待到 11/22）；同日问 Steam 支持：主题节邀请、节中发售、是否要英文商店文、发售时刻"),
 ("W3", "10/26–11/1", "柜台白天背景；序章 + 第 1–3 天重写（约 5 千字）", "结局/终章系统 + 制作人员名单 + 测试；标题曲", "跟进试稿", "10/30 M1（测速关）"),
 ("W4", "11/2–11/8", "柜台黄昏/夜/烛光背景；25 件柜台工具", "存档迁移、日初备份、英文存档目录、云存档预设；标题曲定稿，开始当铺主题", "<b>11/2 下单</b> C2 第 1 批（8 主角）、C3 全部身体、C4（物品 11 + 陈设 15）；测速不过则加音乐外包", "—"),
 ("W5", "11/9–11/15", "第 4–8 天 + 柜台会话重写（约 5 千字）；剧情物品第 1 批 ×6；标题背景", "鉴定：按种子挑观察句 + 禁判词校验；瑕疵改用 A 画的贴花；删掉程序化物品；当铺主题", "—", "11/13 入驻资料应通过（通常 10–15 个工作日）"),
 ("W6", "11/16–11/22", "物品第 2 批 ×6；瑕疵贴花库（约 24 个）；鉴定观察句第 1 批", "接入背景/工具、对热点；守铺一致性（关掉出门/旧玩法、藏体力）；夜曲", "—", "起草商店字段与标签（店主/经营/经济/剧情）；11/22 等待期结束"),
 ("W7", "11/23–11/29", "室内地砖（约 16 块）；审 C1/C2 交付", "平衡第 1 轮；3 个短乐句；手工重排当铺地图；日夜色调与 UI 配色由 A 重选、B 填入", "<b>11/25</b> C1 定稿 + ≥3 张截图要用的头像", "11/27 M2；定价"),
 ("W8", "11/30–12/6", "第 9–12 天重写（约 4 千字）；中文商店文案；UI 图（当票、印章、图标）", "商店图裁切、标志排版（A 审）；音效（自录 + Kenney 等）；系统/规矩/菜单文字人工重写 前半；≥6 张截图；30–45 秒短预告", "12/4 C2 第 1 批", "<b>12/2 商店资料齐</b>"),
 ("W9", "12/7–12/13", "终章第 13–14 天 + 3 个结局（约 6 千字）；物品第 3 批 ×6", "Godot 4.7.2 + GodotSteam、云存档、SteamPipe 私有分支；前端补全（名单/第三方声明页、全屏、版本号、新档覆盖确认）；系统文字后半", "—", "<b>12/7 提交商店页</b>（提交前重读 AI 声明原文）"),
 ("W10", "12/14–12/20", "数据文字第 1 部分（人物、物品、图鉴页、夜事）；物品第 4 批 ×4", "接入物品 + 约 108 个验货部位框；平衡第 2 轮（含终章）；许可文件（OFL×2、Godot、GodotSteam、JevLike/GameJev MIT）；结局曲", "—", "约 12/14 报名店主节；<b>12/16 即将推出上线</b>（冬促 12/17 前）；12/18 M4；12/19 试玩 1"),
 ("W11", "12/21–12/27", "数据文字第 2 部分（日结、引导、过路客人、保护费等叙事部分）；鉴定观察句第 2 批", "试玩 1 协调与修复；新手引导打磨；更新受改字影响的测试", "C4 交付（12/23）", "Valve 假期：不提交审核"),
 ("W12", "12/28–1/3", ".gd 里的叙事文字（约 5 千字）；审 C3/C4 交付（1/1 休）", "试玩 1 修复；平衡第 3 轮；导入 C3 行走图", "<b>12/30</b> C2 第 2 批 + C3 定稿（最迟 1/6）", "12/29 是付费最后期限（应早已付）；后备：页面若未上线，1/4 提交"),
 ("W13", "1/4–1/10", "审路人调色变体；全文一致性与校对 → <b>1/8 文字锁定</b>", "接入 C2/C3；审核清零（哈希/像素相似度/四字重合）；RC0 + 3 台机器冒烟", "—", "1/8 M5；1/8 试玩 2；1/10 新品节报名截止（默认不报）"),
 ("W14", "1/11–1/17", "试玩 2 文字修正；预告片标题卡；更新截图", "字体子集重做 + 字形覆盖测试；60–90 秒预告（实机画面 + 自作配乐，不用 AI 剪辑/超分）；RC1 回归", "—", "1/11 定去留；<b>1/13 提交构建+预告</b>（最迟 1/15）；1/14 发售日锁定；M6"),
 ("W15", "1/18–1/24", "修文字 bug；发售公告 +“全人工制作”开发日志（延时录像）", "beta 分支修 bug；首日补丁准备；完成版独立 zip（许可、玩家须知、SmartScreen 说明）", "—", "1/18 MLK；1/22 设首发折扣 10–15%（14 天）；1/25 10:00 太平洋时间（北京 1/26 02:00）店主节折扣截止"),
 ("W16", "1/25–1/31", "社区回复、文字热修；交来源证明包", "<b>1/28 发布</b>；监控与热修", "—", "店主节 1/25–2/1；1/28 发售；1/29 M7 两版交付；1/31 截止；热修到 2/4，2/5 起春节冻结"),
]


def wk_table() -> str:
    head = '<tr><th style="width:62px">周</th><th style="width:25%"><span class="sw" style="background:var(--a)"></span>A 剧情·美术</th><th style="width:30%"><span class="sw" style="background:var(--b)"></span>B 程序·音乐</th><th style="width:17%"><span class="sw" style="background:var(--out)"></span>外包</th><th><span class="sw" style="background:var(--steam)"></span>Steam·行政</th></tr>'
    rows = "".join(f"<tr><td>{w}<br><span class='note'>{d}</span></td><td>{a}</td><td>{b}</td><td>{o}</td><td>{s}</td></tr>" for w, d, a, b, o, s in WEEKS)
    return f'<table class="wk">{head}{rows}</table>'


P4 = page(f"<h2>逐周安排</h2>{wk_table()}")

P5 = page("""
<h2>Steam 上架关键路径与发售日选项</h2>
<div class="grid2">
 <div>
  <table>
   <tr><th style="width:118px">日期</th><th>步骤</th></tr>
   <tr><td class="n">10/16（周五）</td><td>定签约主体；建 Steamworks 账号；开始入驻：法定名称、美元 SWIFT 收款账户、税务问卷（个人 W-8BEN 用身份证号作外国税号，按中美协定预扣 10%；公司 W-8BEN-E）、身份核验</td></tr>
   <tr><td class="n">10/23（周五）</td><td><b>付 $100 上架费</b>（只有管理员能付；收入满 $1,000 后退还）。之后要等 30 天才能发售第一款游戏（有资料写 21 天，按 30 天算）→ 11/22 结束。<b>最晚付费日：12/29</b></td></tr>
   <tr><td class="n">11/13</td><td>入驻资料通过（通常 10–15 个工作日；税号或银行被退回会多拖几周，缓冲到 12/4）</td></tr>
   <tr><td class="n">12/2</td><td>商店素材齐：全部人工制作的胶囊图、图书馆素材、≥5 张截图、文案、内容调查</td></tr>
   <tr><td class="n">12/7（周一）</td><td>提交商店页审核（3–5 个工作日，至少提前 7 个工作日提交）</td></tr>
   <tr><td class="n">12/16（周三）</td><td><b>即将推出</b>页公开：发售前必须公开 ≥14 天，这里给了 43 天攒愿望单</td></tr>
   <tr><td class="n">约 12/14</td><td>收到邀请就报名 1/25–2/1「店主节」（主题是经营店铺，当铺正合适；邀请一般提前约 6 周，未核实）</td></tr>
   <tr><td class="n">1/10</td><td>2 月新品节报名截止。新品节要求 3/1 以后才发售，和 1 月发售冲突 → 默认不报</td></tr>
   <tr><td class="n">1/11（周一）</td><td><b>定去留</b>：发售日在 1/14 锁定（发售前 14 天内不能改）</td></tr>
   <tr><td class="n">1/13（最迟 1/15）</td><td>提交构建审核 + 预告片（预告片是发售必需；审核 3–5 个工作日，按 7 天计，避开 1/18 MLK）</td></tr>
   <tr><td class="n">1/22（周五）</td><td>设首发折扣：最多 40%，7–14 天，建议 10–15%；必须发售前设好，且早于 1/25 的店主节折扣截止</td></tr>
   <tr><td class="n">1/28（周四）</td><td><b>手动按“发布”</b>。默认 10:00 太平洋时间 = 北京 1/29 02:00；能否提前到北京晚上，要问 Valve（未核实）</td></tr>
   <tr><td class="n">发售后</td><td>Steam Deck 兼容审核可选；首笔分成约 2 月底到账；每次电汇约 $15–30 手续费</td></tr>
  </table>
 </div>
 <div>
  <h3>发售日选项</h3>
  <table>
   <tr><th style="width:96px">选项</th><th>好处</th><th style="width:34%">代价</th></tr>
   <tr><td class="n"><b>A　1/28 周四（推荐）</b></td><td>在店主节里；构建提交避开 Valve 假期和 MLK；14 天首发折扣盖住春节（推测春节期间中文用户多，未核实）；春节前留一周热修；30 天折扣冷却 2/27 结束，赶得上 3/18–25 春促</td><td>节中发售在节日页面的位置没有核实</td></tr>
   <tr><td class="n">B　1/25 周一</td><td>整个店主节都以已发售的打折游戏出现</td><td>构建要 1/12 前提交，少 3 天开发</td></tr>
   <tr><td class="n">C　2/1–2/4</td><td>春节前最后的空档</td><td>错过大部分店主节；热修撞春节；即将推出页要 1/18 前公开</td></tr>
   <tr><td class="n">D　2/15 周一</td><td>春节之后；能参加春促</td><td>不是 1 月发售；夹在合家欢节与新品节之间，比较挤</td></tr>
   <tr><td class="n">E　走新品节</td><td>新品节曝光最大，愿望单最多</td><td>不满足“1 月底上 Steam”；要做公开试玩版、1/10 前报名；3 月初发售赶不上春促</td></tr>
  </table>
  <h3>商店页注意</h3>
  <ul>
   <li>商店页只能写发售时真有的功能；标了的系统（Windows）发售时必须能启动。</li>
   <li>只发 Windows、键鼠；不声称 Steam Deck 兼容（游戏里约 190 处直接读键码，无手柄）。</li>
   <li>德国区不填评级会被隐藏：内容调查要填完，1938 年沦陷、吗啡等主题如实填写。</li>
   <li>是否必须有英文商店文案未核实；如需，<b>必须由人写</b>（约 ¥300–1,000），不能机翻。</li>
   <li>Valve 2027 年没有春节特卖（2022 年后取消）。中国大陆版号情况未核实。</li>
  </ul>
 </div>
</div>
""")

ASSETS = [
 ("背景（柜台日/黄昏/夜/烛光 + 标题）", "5 张 320×180", "A 自画（变体也手画，不用程序调色）", "A", "11/8；标题 11/15"),
 ("柜台工具（含 6 枚棋子）", "25 个", "A 自画，B 对照 layout.json 热点", "A/B", "11/8"),
 ("人物头像", "约 21 人 48×64（守铺可见约 18）", "C2 外包（米画师，基础 + 2 表情，商用，禁 AI，分层源文件），A 美术指导", "A 指导 / B 合同", "≥3 人 11/25；8 人 12/4；其余 12/30"),
 ("行走图", "26 张（16×32 帧，4 向×4 帧）", "C3 外包 16 个身体；其余 10 个路人用 A 选的配色换色（B 做）", "C3 / B", "12/30；换色 1/8"),
 ("当物（剧情物品）", "22 件 64×64", "A 自画，必须和图鉴部位逐像素对得上；B 重标约 108 个验货部位框", "A/B", "分 4 批：11/13、11/20、12/11、12/18"),
 ("通用物品 + 当铺陈设", "11 件 + 15 件", "C4 外包（这些没有真假对照，外包风险低）", "C4", "12/23"),
 ("鉴定瑕疵", "21 种运行时画法 → 约 24 个贴花", "A 画贴花；B 把 flaw_render 改成贴图 + A 定的调色；纯程序生成的几种（模糊/错位/描边）去掉或换成 A 画的替换部件", "A/B", "代码 11/13；贴花 11/22"),
 ("室内地砖、当铺地图", "约 16 块；20×12 格", "A 画地砖；B 在编辑器里手工重排地图（原图是生成脚本排的）", "A/B", "11/29"),
 ("UI 图、色调参数", "当票、印章、图标、对话框、铜钱；日夜色调 8 个关键帧、UI 配色", "A/B 手画；色值由 A 重新挑（原来是 AI 选的）", "A/B", "12/6"),
 ("小镇专属美术", "35 个（建筑、店铺背景、小镇砖、道具）", "守铺版用不到：移到归档，导出白名单排除，不进包", "B", "10/16"),
 ("字体", "思源宋体（Noto Serif SC）、马善政", "保留（SIL OFL 1.1，可商用）；附许可；文字锁定后重做子集", "B", "许可 12/18；子集 1/11"),
 ("音乐", "10 首 AI 合成 → 3 循环 + 3 短乐句 + 结局曲", "B 作曲（REAPER + EastWest SILK 或 NI East Asia），不沿用旧旋律，保留 MIDI/工程；可编配公有领域的江南丝竹曲目（如《中花六板》，公有领域状态未核实）", "B", "标题 11/6、当铺 11/13、夜 11/20、短乐句 11/27、结局曲 12/18"),
 ("音效", "9 个程序合成 → 约 15 个", "自己录（算盘、铜钱、门板、纸、印章、电报键）+ Kenney CC0；Sonniss 等多供应商包要逐个记录来源（没有逐家的无 AI 证明时优先不用）", "B", "12/6"),
 ("剧情 + 柜台会话文字", "守铺可见约 1.4 万字", "A 按大纲从头写（写的时候不开 AI 稿）", "A", "1–3 天 10/30；4–8 天 11/13；9–12 天 12/4；终章 12/13"),
 ("数据里的叙事文字", "约 1 万字（人物、物品、图鉴、夜事、日结等）", "A 重写，_provenance 标 human:A:日期", "A", "12/27"),
 ("系统、规矩、菜单文字", "约 9.5 千字（规矩/引导/说明约 6.5 千 + 菜单/设置/帮助约 3 千）", "B 人工重写（不用 AI）", "B", "12/13"),
 ("鉴定观察句（新写）", "约 6 千字", "A 写；校验器拦住“真/假/仿”等判词", "A/B", "11/22 + 12/27"),
 ("商店页、预告、宣传图、社媒、玩家须知", "全部", "全人工；截图只用人工化后的画面；预告不用 AI 剪辑/字幕/超分", "A/B", "12/2；预告 1/13"),
 ("运行时模型 persona_residual.json", "1 个", "删除，改回规则打分后重新平衡", "B", "10/16"),
]


def asset_table() -> str:
    rows = "".join(f"<tr><td><b>{a}</b></td><td>{b}</td><td>{c}</td><td class='n'>{d}</td><td>{e}</td></tr>" for a, b, c, d, e in ASSETS)
    return '<table class="tight"><tr><th style="width:150px">类别</th><th style="width:150px">数量</th><th>怎么换</th><th style="width:70px">负责</th><th style="width:150px">期限</th></tr>' + rows + "</table>"


P6 = page(f"""
<h2>免 AI 声明：替换清单</h2>
<div class="note" style="margin-bottom:6px">原则：玩家在游戏里、商店页、预告片、社区素材里看到、听到、读到的，要么是 A/B/签约画师做的，要么是有书面“无 AI”证明的授权素材。AI 只用来写代码、测试和工具；不许用 AI 写玩家文字、旋律、像素排布、配色、贴花或地图布局；不许用 AI 润色或翻译。</div>
{asset_table()}
""")

P7 = page("""
<h2>审核流程（防止 AI 素材漏进发售包）</h2>
<div class="grid2">
 <div>
  <ol style="margin:0 0 0 16px;padding:0">
   <li><b>来源清单</b> legal/ASSET_PROVENANCE.csv：每个发出的文件一行——路径、sha256、作者（A / B / 外包画师 / 授权卖家）、做法、源文件路径、许可与许可文件、订单号、无 AI 证明、日期、复核人。</li>
   <li><b>黑名单</b>：v0.4.2 所有图片/音频的哈希 + 旧文本语料。</li>
   <li><b>审核脚本</b>（不进包）在每次导出时检查：没有清单行的文件；哈希在黑名单里；ai_draft 标记；不该进包的目录；与旧图同路径的像素相似度 &gt;20%；旧旋律相似；与旧文本四字重合 ≥30% 的字符串（交人工复核）；缺许可文件；文字里有字体子集缺的字。</li>
   <li><b>CI 拦截</b>：带 AI 合写标记的提交，只要改到玩家文字、art/、audio/、data/strings 就失败。</li>
   <li><b>白名单导出</b>：Steam 预设只打包清单里列出的文件（吸取《光与影：33号远征》带出 AI 占位贴图、被撤奖的教训）。</li>
   <li><b>节点签字</b>：每周五构建跑一次；12/7 提交商店页、1/13 提交构建之前必须 0 违规。A、B 在 M3、M5、M6 签 AUDIT_SIGNOFF.md，之后再填后台 AI 声明“无”。</li>
   <li><b>外包闸门</b>：合同禁止生成式 AI（含参考图、底稿），要分层源文件 + ≥2 个 WIP，分期付款；授权素材要有“无 AI”证明，许可也要允许用在 AI 写代码的游戏里（如 Mana Seed 禁止，就不用）。</li>
   <li><b>证据包</b>放在仓库外：分层源文件、DAW/MIDI 工程、带 git 历史的草稿、3–5 段延时录像、合同。被误指控用 AI 时可以拿出来。</li>
   <li>发售后每个补丁重跑审核；Valve 改表格时重新核对。</li>
  </ol>
 </div>
 <div>
  <h3>完成定义（Definition of Done）</h3>
  <table>
   <tr><td class="n"><b>美术</b></td><td>人画、分层源文件进 art_src/、尺寸对、清单行齐、游戏里看过、锚点和部位框更新、哈希不在黑名单</td></tr>
   <tr><td class="n"><b>音乐</b></td><td>MIDI 与工程归档、OGG 渲染、循环点写进 music.json、响度达标（循环 −18~−20 LUFS，短乐句 −16 LUFS，峰值 &lt; −1.9 dBFS）、游戏里听过</td></tr>
   <tr><td class="n"><b>音效</b></td><td>许可 + 无 AI 证明或录音记录、清单行、游戏里触发正确</td></tr>
   <tr><td class="n"><b>文字</b></td><td>人按大纲写、标 human、判词校验与字形检查通过、另一人校对、没有沿用 AI 句子</td></tr>
   <tr><td class="n"><b>代码</b></td><td>加测试、全部测试与自动试玩绿、.gd 里不写玩家文字、在 Steam 导出包里能跑</td></tr>
   <tr><td class="n"><b>发售构建</b></td><td>审核 0 违规、A+B 签字、3 台机器冒烟、外部测试者通关、上一版存档能读</td></tr>
  </table>
  <h3>每周节奏</h3>
  <ul>
   <li>周一 30 分钟：定本周任务，更新燃尽（剩余人日 / 可用人日）。</li>
   <li>每天异步三行：做完了什么 / 接下来做什么 / 卡在哪里。</li>
   <li>周三：B 合入 A 的素材，A 在游戏里按 ×4、×6 看。</li>
   <li>周五：Steam 导出 + 审核报告 + 20 分钟试玩 + 风险复盘；里程碑周逐项打勾。</li>
   <li>每周指标：各类素材人工化比例、已重写字数、审核违规数、P0/P1 bug、经济区间、Steam 行政清单、已花预算。</li>
  </ul>
 </div>
</div>
""")

P8 = page("""
<h2>工作量、预算、风险与后备方案</h2>
<div class="grid2">
 <div>
  <h3 style="margin:6px 0 3px">工作量（每人 79 人日，W1–W13 文字锁定前 64 人日）</h3>
  <table class="tight">
   <tr><th></th><th>主要内容</th><th class="n">估计</th></tr>
   <tr><td class="n"><b style="color:var(--a)">A</b></td><td>写作约 3.5 万字（剧情、会话、叙事数据、鉴定观察句、.gd 叙事文字）+ 大纲与校对；自画背景 5、工具 25、剧情物品 22、贴花约 24、地砖约 16、UI 图；风格指南、角色设定与外包指导；试玩观察</td><td class="n">锁定前约 56–58 / 64</td></tr>
   <tr><td class="n"><b style="color:var(--b)">B</b></td><td>来源清单与审核、结局/存档/鉴定/一致性/前端代码、Steam 接入、3 轮平衡、素材接入、作曲与音效、系统/规矩/菜单文字约 9.5 千字、商店图排版、截图与预告、测试更新、试玩协调与修复、外包合同与付款</td><td class="n">约 80 / 79（只剩 QA 缓冲）</td></tr>
  </table>
  <div class="note">原计划 A 在锁定前要 70+ 人日，超出 64；所以把系统文字、商店图排版、路人换色、外包事务挪给 B，并加 C4 外包。B 因此吃紧：所有“可选”项默认挪到发售后。估算来自研究者判断，未经实测；10/30 的测速关就是用来校准的。</div>
  <h3 style="margin:6px 0 3px">预算（人民币，美元按 6.75 折算；外包价格为估算）</h3>
  <table class="tight">
   <tr><th>项目</th><th class="n">低</th><th class="n">计划</th><th class="n">高</th></tr>
   <tr><td>Steam 上架费 $100（收入满 $1,000 退还）</td><td class="n">675</td><td class="n">675</td><td class="n">675</td></tr>
   <tr><td>C1 主视觉 + 封面一套</td><td class="n">2,100</td><td class="n">3,675</td><td class="n">10,500</td></tr>
   <tr><td>C2 头像 约 21 人（基础 + 2 表情，商用，含试稿与平台费）</td><td class="n">4,500</td><td class="n">8,700</td><td class="n">20,650</td></tr>
   <tr><td>C3 行走图身体 16 个</td><td class="n">3,360</td><td class="n">5,040</td><td class="n">10,080</td></tr>
   <tr><td>C4 通用物品 11 + 陈设 15</td><td class="n">4,000</td><td class="n">6,000</td><td class="n">8,000</td></tr>
   <tr><td>REAPER 授权（年收入 &lt;$2 万）</td><td class="n">405</td><td class="n">405</td><td class="n">405</td></tr>
   <tr><td>民乐音源（NI East Asia / EastWest SILK）</td><td class="n">668</td><td class="n">1,006</td><td class="n">2,018</td></tr>
   <tr><td>音效（自录 + 免费为主）、Aseprite、试玩谢礼</td><td class="n">0</td><td class="n">758</td><td class="n">1,450</td></tr>
   <tr><td>字体（OFL 免费；方正/汉仪/Zpix 不用）</td><td class="n">0</td><td class="n">0</td><td class="n">0</td></tr>
   <tr><td><b>合计</b>（另留 10% 机动 ≈ ¥2.9 万；如需英文商店文案再加 ¥300–1,000）</td><td class="n"><b>≈1.6 万</b></td><td class="n"><b>≈2.6 万</b></td><td class="n"><b>≈5.4 万</b></td></tr>
  </table>
  <div class="note">预算为 0 的话排不下：A 会超出约 25–30 人日。</div>
 </div>
 <div>
  <h3 style="margin:6px 0 3px">主要风险</h3>
  <table class="tight">
   <tr><th>风险</th><th style="width:44%">应对</th></tr>
   <tr><td>A 画得比估算慢（高估算 105 人日）</td><td>早下外包；10/30 测速；11/13 若 A 进度 &lt;70%，再加外包 ¥3–5 千并按砍单顺序砍</td></tr>
   <tr><td>外包晚交、风格不对、偷偷用 AI</td><td>付费试稿、禁 AI 条款、WIP、分期付款；交期都在春节前；备选画师；配角 A 可画单姿势兜底</td></tr>
   <tr><td>入驻资料（税号、银行）被退回</td><td>W1 就开始、W2 付费；缓冲到 12/4；最晚付费日 12/29</td></tr>
   <tr><td>12/2 前拿不出人工画面</td><td>截图只拍柜台；后备：1/4 提交、1/14 上线（愿望单会少）</td></tr>
   <tr><td>审核变慢或临近发售被打回</td><td>Valve 假期内不提交；1/13 提交留余量；文案保守；只发 Windows</td></tr>
   <tr><td>AI 残留进包（没用到的图、旧音频、冷门分支的旧句子）</td><td>白名单导出、哈希黑名单、相似度与四字重合检查、生成器隔离</td></tr>
   <tr><td>经济不达标，后期太难；没结局影响口碑</td><td>3 轮平衡 + 2 轮试玩；结局系统 M1 就合入；兜底：调低保护费或用接近“太平年”的数值</td></tr>
   <tr><td>补丁弄坏存档</td><td>存档迁移在 M2 完成；M7 测 RC → 补丁读档</td></tr>
   <tr><td>被误指控用 AI（像素图和合成器味的音乐容易招）</td><td>发售时发“全人工制作”开发日志 + 延时录像</td></tr>
   <tr><td>1938 年沦陷题材的审查与舆论风险</td><td>内容调查如实填写；宣传文案谨慎</td></tr>
  </table>
  <h3 style="margin:6px 0 3px">落后了先砍什么（按顺序）</h3>
  <ol style="margin:0 0 0 16px;padding:0;font-size:9.7px;line-height:1.36">
   <li>所有“可选”项：表情切换、成就、无障碍、黄昏曲、多存档、马保长客串、请人看货、Deck 审核</li>
   <li>6 个配错图的物品模板直接删掉，不补画</li>
   <li>通用物品只上已画好的</li>
   <li>路人换色 6 → 3</li>
   <li>结局 3 → 2；鉴定观察句每部位 2 → 1 句</li>
   <li>缩短或删掉序章下棋场景（省一张背景、6 枚棋子、约 1,164 字）</li>
   <li>标题背景改用柜台背景 + 标志</li>
   <li>再不行就改发售日（见下）</li>
  </ol>
  <h3 style="margin:6px 0 3px">检查点</h3>
  <ul style="font-size:9.7px;line-height:1.36">
   <li><b>11/13</b> A 进度 ≥70% 且试稿通过，否则加外包、砍可选项。</li>
   <li><b>11/27</b> 切片没完成 → 即将推出改走后备（1/4 提交、1/14 上线），砍单第 1–3 步。</li>
   <li><b>12/18</b> Alpha 没过 → 砍单第 4–7 步。</li>
   <li><b>1/11</b>（1/14 锁定前）审核没清零、有 P0、外包未齐 → 发售改到 2/1–2/4 或 2/15；完成版独立版仍在 1/29–1/31 交付。</li>
  </ul>
  <div class="note">不建议的退路：先带 AI 声明上 Steam、换完再删声明——技术上可行，但有人专门追踪这类删除，名声受损，也不符合你的要求；只有你明确同意才用。</div>
 </div>
</div>
""")

P9 = page("""
<h2>假设与来源</h2>
<div class="grid2">
 <div>
  <h3>假设</h3>
  <ul>
   <li>“1 月末交付”理解为：两版都在 1/31 前做好，Steam 1/28 发售。若只要求做好不发售，发售日可以往后挪（见发售日选项）。</li>
   <li>两人全职，每周 5 天；1/1 休；春节安排以 11 月官方公布为准。</li>
   <li>B 会用 DAW + 音源作曲、A 会画像素图（10/30 测速关核实，不过就加外包）。</li>
   <li>Godot 从 4.7 升到 4.7.2（GodotSteam 需要），风险低。</li>
   <li>首次审核通过后，往默认分支推的新构建不需要再审（未核实）。</li>
   <li>仓库保持私有（里面有 AI 历史、生成器和来源记录）。</li>
   <li>独立版直接下载会遇到 Windows SmartScreen“未知发布者”提示：要么买代码签名证书（价格与周期未核实），要么在玩家须知里说明。</li>
  </ul>
  <h3>现状数据（来自仓库盘点，2026-10-12）</h3>
  <ul>
   <li>发出的图片 160 张：背景 5、物品 22、头像 21、工具 25、UI 2、小镇 85（行走图 26 张 = 416 帧）。</li>
   <li>音乐 10 首共 11.9 分钟（守铺可听到约 5.4 分钟 + 16 秒短乐句）；音效 0 个文件，9 个运行时合成。</li>
   <li>玩家可见文字约 4.99 万字（数据约 4.17 万 + 代码约 8.2 千），守铺可见约 4.28 万；32 个数据文件标着 ai_draft。</li>
   <li>字体 2 个，都是 SIL OFL 1.1；导出包 714 个条目，其中 104 个是测试脚本（要排除）。</li>
   <li>目前没有真正的结局；故事卡 42 张覆盖第 1–14 天（外加第 32 天一张）。</li>
   <li>经济：自动试玩 10 天后钱 31–119（开局 340）；保护费每天 18–51。</li>
  </ul>
 </div>
 <div>
  <h3>主要来源（访问日期 2026-10-12；Steamworks 页面经搜索摘要，未直接打开）</h3>
  <ul class="note" style="font-size:9px">
   <li>AI 声明改写（2026-01）：pcgamer.com “Steam updates AI disclosure form…”（2026-01-16）；gamedeveloper.com “Valve tweaks and clarifies AI disclosure rules for Steam”；videogameschronicle.com（2026-01-19）；pcgamesn.com（2026-01-17）；techpowerup.com/345302</li>
   <li>不同看法：legalmoveslawfirm.com/steam-ai-policy/；首版政策：theregister.com（2024-01-10）</li>
   <li>《光与影：33号远征》AI 占位贴图与撤奖：malaymail.com（2025-12-21）</li>
   <li>上架费与等待期：partner.steamgames.com/doc/gettingstarted/appfee、/onboarding、steamdirect</li>
   <li>即将推出与审核：partner.steamgames.com/doc/store/coming_soon、/review_process、/releasing</li>
   <li>素材尺寸与预告：partner.steamgames.com/doc/store/assets/standard、/libraryassets、/trailer</li>
   <li>折扣规则：partner.steamgames.com/doc/marketing/discounts</li>
   <li>2027 上半年活动：pcgamer.com “Steam reveals all the sale dates… first half of 2027”（2026-07）；店主节 /doc/marketing/upcoming_events/themed_sales/shop_keep_2027；新品节 /nextfest/feb_2027</li>
   <li>春节 2027：timeanddate.com；中文用户占比：gamingonlinux.com（2026-03）</li>
   <li>价格：米画师项目页、Fiverr、Native Instruments、EastWest、REAPER、Sonniss、Kenney、itch.io AI 披露规则（gamingonlinux.com 2024-11）；字体 OFL 文本</li>
   <li>GodotSteam 4.11 / Godot 4.7.2：godotsteam.com（2026-08-22）</li>
  </ul>
  <div class="warn" style="margin-top:10px">登录 Steamworks 后台后，请先核对这几条再执行计划：① AI 声明表原文；② 付费后等待 21 天还是 30 天；③ 即将推出最少天数与审核时长；④ 是否必须有英文商店文案；⑤ 店主节邀请与节中发售的位置；⑥ 能否选择北京时间晚上发布。</div>
 </div>
</div>
""")

HTML = f"""<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>德厚当 交付时间线与里程碑</title><style>{CSS}</style></head><body>
{P1}{P2}{P3}{P4}{P5}{P6}{P7}{P8}{P9}
</body></html>"""

if __name__ == "__main__":
    open("plan.html", "w", encoding="utf-8").write(HTML)
    print("ok")
