# 德厚当·卡牌版 玩法设计文档（HTML → PDF）
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ERA = json.load(open(os.path.join(HERE, "era.json"), encoding="utf-8"))

CSS = """
@page { size: A4; margin: 14mm 14mm 14mm 14mm; }
:root { --ink:#1b1714; --ink2:#5a524a; --muted:#8c8378; --line:#e3ddd3; --paper:#fbf8f2; --card:#fffdf8;
  --seal:#a8322a; --jade:#2f6b5a; --gold:#a07a2c; --indigo:#2d4a7a; --soot:#3a3532; }
* { box-sizing:border-box; }
body { margin:0; background:var(--paper); color:var(--ink); font-family:"WenQuanYi Zen Hei", sans-serif; font-size:10.4px; line-height:1.62; }
.page { page-break-after:always; break-after:page; }
.page:last-child { page-break-after:auto; }
h1 { font-size:30px; margin:0; letter-spacing:2px; }
h2 { font-size:16px; margin:0 0 8px; padding-bottom:4px; border-bottom:2px solid var(--ink); }
h3 { font-size:12.2px; margin:12px 0 4px; color:var(--ink); }
h4 { font-size:11px; margin:8px 0 2px; color:var(--ink2); }
p { margin:3px 0 6px; }
ul, ol { margin:2px 0 6px 18px; padding:0; } li { margin:1px 0; }
table { width:100%; border-collapse:collapse; margin:4px 0 8px; }
th, td { border-bottom:1px solid var(--line); padding:3px 5px; vertical-align:top; text-align:left; }
th { font-size:10px; color:var(--ink2); border-bottom:1.5px solid var(--ink); }
td.n { white-space:nowrap; }
.sub { color:var(--ink2); font-size:11.5px; margin:4px 0 14px; }
.box { border:1px solid var(--line); background:var(--card); border-radius:6px; padding:8px 11px; margin:6px 0 10px; }
.seal { border-left:4px solid var(--seal); }
.jade { border-left:4px solid var(--jade); }
.gold { border-left:4px solid var(--gold); }
.grid2 { display:grid; grid-template-columns:1fr 1fr; gap:12px; }
.grid3 { display:grid; grid-template-columns:1fr 1fr 1fr; gap:10px; }
.note { color:var(--ink2); font-size:9.6px; }
.tune { color:var(--gold); font-size:9.6px; }
.tag { display:inline-block; border:1px solid var(--line); border-radius:3px; padding:0 5px; font-size:9.4px; margin-right:3px; background:#fff; }
.card { border:1.5px solid var(--soot); border-radius:7px; padding:6px 8px; background:var(--card); font-size:9.8px; }
.card b.t { display:block; font-size:11px; margin-bottom:2px; }
.card .k { color:var(--muted); font-size:9px; letter-spacing:1px; }
.foot { position:fixed; bottom:-8mm; right:0; font-size:8.5px; color:var(--muted); }
.cover-band { height:6px; background:linear-gradient(90deg,var(--seal) 0 25%,var(--gold) 25% 50%,var(--jade) 50% 75%,var(--indigo) 75% 100%); margin:8px 0 14px; border-radius:3px; }
.flow { display:flex; gap:6px; align-items:stretch; margin:6px 0 10px; }
.flow div { flex:1; border:1px solid var(--line); background:var(--card); border-radius:6px; padding:6px 8px; }
.flow div b { display:block; font-size:11px; }
.arrow { flex:0 0 12px !important; border:none !important; background:none !important; padding:0 !important; display:flex; align-items:center; justify-content:center; color:var(--muted); font-size:14px; }
"""


def page(inner: str) -> str:
    return f'<section class="page">{inner}</section>'


def era_rows() -> str:
    out = []
    for e in ERA["pawn"]:
        out.append(f"<tr><td class='n'><b>{e['stage']}</b></td><td class='n'>{e['year']}</td><td>{e['bg']}</td><td>{e['cards']}</td><td class='n'>{e['ship']}</td></tr>")
    return "".join(out)


def timeline_svg() -> str:
    # 1938 → 1949 → 分支 → 1956 的结构图
    W, H = 690, 156
    x0, x1 = 30, 470
    years = list(range(1938, 1950))
    step = (x1 - x0) / (len(years) - 1)
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="WenQuanYi Zen Hei, sans-serif">']
    s.append(f'<rect x="{x0-12}" y="48" width="{x0 + step*2.5 - (x0-12):.1f}" height="34" rx="6" fill="#a8322a" fill-opacity="0.12" stroke="#a8322a" stroke-dasharray="4 2"/>')
    s.append(f'<text x="{x0-8}" y="44" font-size="10" fill="#a8322a">首发（抢先体验）：三大关</text>')
    s.append(f'<line x1="{x0}" y1="65" x2="{x1}" y2="65" stroke="#3a3532" stroke-width="2"/>')
    for i, y in enumerate(years):
        x = x0 + i * step
        s.append(f'<circle cx="{x:.1f}" cy="65" r="6" fill="#fffdf8" stroke="#3a3532" stroke-width="1.6"/>')
        s.append(f'<text x="{x:.1f}" y="69" font-size="7.5" text-anchor="middle" fill="#1b1714">{i+1}</text>')
        s.append(f'<text x="{x:.1f}" y="{98 if i % 2 == 0 else 110}" font-size="9" text-anchor="middle" fill="#5a524a">{y}</text>')
    s.append(f'<text x="{(x0+x1)/2:.0f}" y="20" font-size="11" text-anchor="middle" fill="#1b1714" font-weight="bold">当铺年代：每关一个月，打完跳一年（12 关）</text>')
    # pivot
    px = x1 + 40
    s.append(f'<line x1="{x1+6}" y1="65" x2="{px-8}" y2="65" stroke="#3a3532" stroke-width="2"/>')
    s.append(f'<path d="M{px},55 l10,10 l-10,10 l-10,-10 z" fill="#2f6b5a"/>')
    s.append(f'<text x="{px}" y="96" font-size="9.5" text-anchor="middle" fill="#2f6b5a" font-weight="bold">解放·选新行当</text>')
    branches = ["信托商店/旧货店", "茶馆", "中药铺", "杂货铺", "修理铺", "教书/代写"]
    for i, b in enumerate(branches):
        by = 12 + i * 22
        s.append(f'<path d="M{px+10},65 C{px+40},65 {px+40},{by+6} {px+70},{by+6}" fill="none" stroke="#2f6b5a" stroke-width="1.3"/>')
        s.append(f'<rect x="{px+70}" y="{by-3}" width="104" height="18" rx="4" fill="#2f6b5a" fill-opacity="0.12" stroke="#2f6b5a"/>')
        s.append(f'<text x="{px+76}" y="{by+10}" font-size="9.5" fill="#1b1714">{b}</text>')
    s.append(f'<text x="{px+172}" y="{H-4}" font-size="9" text-anchor="end" fill="#5a524a">各分支到 1956 年公私合营收尾</text>')
    s.append("</svg>")
    return "".join(s)


P1 = page(f"""
<div style="margin-top:10mm"></div>
<h1>德厚当 · 卡牌版</h1>
<div class="sub">玩法设计 v1.3　·　2026-10-13　·　依据：主创在对话里定下的规则（v1.1：命运轮盘、算命、金色角色牌；v1.2：新手指引；v1.3：“下一天”按钮永远可用、九条做法已确认）</div>
<div class="cover-band"></div>
<div class="box seal"><b>一句话</b><br>
1938 年，江南小镇青溪镇，你接手了德厚当。每天进门的人、街上出的事、命运的转折都是随机抽来的；当不当、给不给、帮不帮，由你决定。一个月是一关，打完跳一年，时代变了牌也变了；1949 年解放后，你按这些年攒下的东西改行，走进新的分支。</div>

<h3>三条原则</h3>
<div class="grid3">
 <div class="box jade"><b>1　贴近生活，不分黑白</b><br>选项不标好坏，结果有得有失。日常开销（米、煤、看病、学费、人情、过年）都是牌。“本心”藏在后面，只影响你能走哪些路。</div>
 <div class="box gold"><b>2　参考大富翁</b><br>随机的命运牌和命运轮盘（还有算命、求签、黄历）；钱不够就一样样抵押家当，押光了流落街头碰运气；坐牢可以花钱打点、找人保；手头宽裕可以置产。</div>
 <div class="box seal"><b>3　参考《苏丹的游戏》</b><br>胡二每周送来一张限期七天的“条子”；大事件上有空格，把人物牌、东西、钱放进去，按属性掷铜钱定成败；一部分牌可以留在手里，想用的时候再打；主线人物是金色牌，当天必须处理。</div>
</div>

<h3>整体结构</h3>
{timeline_svg()}
<table>
 <tr><th style="width:90px">层级</th><th>是什么</th></tr>
 <tr><td class="n"><b>一天</b></td><td>发一手牌（人物、事件、消息、偶尔命运牌），一张张处理；晚上选一件事做，结算。</td></tr>
 <tr><td class="n"><b>一周</b></td><td>每周一胡二送来一张条子，七天内办完。生活牌每周一两张。</td></tr>
 <tr><td class="n"><b>一关（一个月）</b></td><td>开场看时局和本关目标；月底结账（抵押利息、当票、生活开销）；打完跳一年。</td></tr>
 <tr><td class="n"><b>当铺年代（12 关）</b></td><td>1938–1949，每年一关。时局推进，牌库整套更换，货币和物价跟着变。</td></tr>
 <tr><td class="n"><b>解放后</b></td><td>按攒下的人脉、钱、档案簿和本心，选一个新行当；进入该行当的新牌库，到 1956 年收尾。</td></tr>
 <tr><td class="n"><b>首发</b></td><td>1 月抢先体验：前三关（1938、1939、1940）。之后按年更新到 1949；解放后的分支作为大更新。</td></tr>
</table>
<div class="note">本文档的数字都是起始值，标着 <span class="tune">【待调】</span> 的要在原型里试玩后调。</div>
""")

P2 = page("""
<h2>一、一天怎么过</h2>
<div class="flow">
 <div><b>早上 · 发牌</b>看今天的告示（天气、集市日、时局），发今天的牌。</div><div class="arrow">→</div>
 <div><b>白天 · 处理</b>按任意顺序处理手里的牌；能留的牌可以先留着。节奏由你把握：没有倒计时，不自动跳天。</div><div class="arrow">→</div>
 <div><b>打烊 · 下一天</b>按钮永远能按；还有牌没处理就先问一句，列出会发生什么。然后三张夜牌里选一张。</div><div class="arrow">→</div>
 <div><b>结算</b>当票倒计时、留牌过期、条子剩几天、下一天的牌库按状态调整。</div>
</div>
<h3>“打烊 · 下一天”按钮（主创硬性要求：不能卡住，节奏由玩家把握）</h3>
<div class="box seal">
<ul style="margin:0 0 0 16px">
 <li>牌桌上永远有一个“打烊 · 下一天”按钮，<b>任何时候都能按</b>：流落街头、坐牢、轮盘转完、面板开着时都一样；每个面板和小游戏都有“算了/关闭”。</li>
 <li>还有牌没处理就按，先弹一行确认，列出会发生什么，比如“林嫂会走；查良民证按没理会处理”。确认后：没接的人走掉（个别人记仇）；没处理的事件、命运牌按“没理会”结算；金色牌按“没理他”走；条子没到期就继续计时；大命运牌作废（错过机会）。</li>
 <li>牢房没处理就在牢里多待一天（铺子关门、不发人物牌），连着三天【待调】没出来按打点失败结算。</li>
 <li>没有任何真实时间的倒计时，不会自动跳天；什么时候进下一天完全由玩家决定。</li>
</ul>
</div>
<h3>每天发什么牌 <span class="tune">【待调】</span></h3>
<table>
 <tr><th style="width:80px">牌</th><th style="width:90px">每天几张</th><th>说明</th></tr>
 <tr><td><b>人物牌</b></td><td>3–4 张</td><td>今天进门的人。可以拒绝；打烊时还没接的人自己走（个别人记仇）。集市日多一张，下雨少一张，口碑高好客人多。</td></tr>
 <tr><td><b>事件牌</b></td><td>1 张</td><td>街上的事、时局的事；没处理就在打烊时按“没理会”结算。</td></tr>
 <tr><td><b>消息牌</b></td><td>0–1 张</td><td>行情、线索、流言、信、电报；很多会变成档案簿里的碎片。</td></tr>
 <tr><td><b>命运牌</b></td><td>随机</td><td>大约每三四天一张；风声大、时局乱时更常见。好坏都有。</td></tr>
 <tr><td><b>生活牌</b></td><td>每周 1–2 张</td><td>米缸见底、煤、看病、孩子学费、婚丧人情、过年。</td></tr>
 <tr><td><b>条子</b></td><td>每周一 1 张</td><td>胡二送来，限期七天（见“条子”一节）。</td></tr>
 <tr><td><b>主线牌</b></td><td>固定日子</td><td>到某天、或口碑风声到某档才出现。</td></tr>
</table>
<h3>夜牌（三选一）<span class="tune">【待调】</span></h3>
<table>
 <tr><td class="n"><b>整理库房</b></td><td>货架上的东西擦洗归置，卖的时候稍好出手。</td></tr>
 <tr><td class="n"><b>对账</b></td><td>看清这个月是赚是赔；有时翻出账上的问题（消息牌）。</td></tr>
 <tr><td class="n"><b>后门收货</b></td><td>夜里有人敲后门，便宜，但来路不明，风声会动。</td></tr>
 <tr><td class="n"><b>发电报</b></td><td>主线专用（第三天起），给远方的哥哥或别的人。</td></tr>
 <tr><td class="n"><b>回家吃饭</b></td><td>一家人吃顿饭；抵掉一张生活牌的坏处，或者得到一张家人的消息。</td></tr>
 <tr><td class="n"><b>早点睡</b></td><td>明天多发一张人物牌。</td></tr>
</table>

<h3>示例：1938 年 3 月第 9 天</h3>
<div class="box">
<p><b>早上</b>：告示说今天下雨、不是集市日。发牌：人物 3 张（林嫂、孙福、一个外乡人），事件 1 张（“警察挨家查良民证”），消息 1 张（周妈说：王山昨晚在码头出现过）。手里还留着一张“马万利欠你一次”。条子剩 3 天：要 60 蚨。</p>
<p><b>林嫂来当金簪</b>：你点开金簪，这次随机出的小游戏是“称分量”——用戥子称，比她说的轻一点点。线索是“分量差了一钱，像是补过”。你出“公道价”，她接了，得到一张当票（15 天后到期）。</p>
<p><b>查良民证</b>：事件上有两个格子：放“良民证”这张留着的牌就直接过；你没有，只好放 10 蚨和小丁（胆量 2）进去，掷 3 枚铜钱，要 2 个正面——掷出 1 个。警察记下了你的名字，风声上一档。</p>
<p><b>孙福来买字画</b>：你从货架挑了一幅，报“厚道价”太低了，你改报“公道价”，他还价，成交，进账 45 蚨。条子的钱凑够了。</p>
<p><b>外乡人求当棉袄</b>：棉袄不值钱，他说孩子病了。你可以压价收、厚道价收、白给他几个钱、或不收。你白给了 5 蚨——本心不显示，但档案簿里多了一页“外乡人”。</p>
<p><b>晚上</b>：选“回家吃饭”，抵掉了周末那张“煤用完了”的坏处。结算：当票 14 天、条子 2 天、明天牌库里查铺的牌多了一张（风声上去了）。</p>
</div>
""")

P3 = page("""
<h2>二、牌的种类</h2>
<div class="grid3">
 <div class="card"><span class="k">人物牌</span><b class="t">林嫂</b>船工的妻子，怀孕八个月。<br>来意：来当 · 金簪<br><span class="note">处理：鉴定小游戏 → 三档出价 → 当票</span></div>
 <div class="card"><span class="k">事件牌</span><b class="t">警察挨家查良民证</b>格子：［证件］［钱］［人］<br>要 2 个正面<br><span class="note">没过：风声上一档</span></div>
 <div class="card"><span class="k">命运牌</span><b class="t">邻铺失火</b>火势往这边蔓延。<br>①搬货（掷胆量）②报警 ③关门躲<br><span class="note">好坏都可能</span></div>
 <div class="card"><span class="k">条子 · 要钱 · 中</span><b class="t">维持会摊派</b>七天内交 60 蚨。<br>格子：［钱］［人情］［口才的人］<br><span class="note">办不成：查封三天</span></div>
 <div class="card"><span class="k">留着的牌</span><b class="t">马万利欠你一次</b>可放进任何“官面上”的格子，算 3 个正面。<br><span class="note">20 天后不灵了</span></div>
 <div class="card"><span class="k">大命运牌</span><b class="t">一箱来路不明的东西</b>陌生人出大价钱请你保管七天。<br>收下：钱够还清抵押；被查到：直接被抓。</div>
</div>
<table>
 <tr><th style="width:84px">牌</th><th>作用</th><th style="width:190px">举例</th></tr>
 <tr><td><b>人物牌</b></td><td>今天进门的人。来当、来卖、来买、来赎、求助、打听。每人跨年会变（老了、穷了、走了、换了身份）。</td><td>林嫂、孙福、王山、李敬之、外乡人、挑货的</td></tr>
 <tr><td><b>你（人物）</b></td><td>主角沈如花自己也是一张人物牌，有属性，可以放进格子；属性会随事件成长。</td><td>眼力 2 · 口才 1 · 门路 1 · 胆量 1【待调】</td></tr>
 <tr><td><b>人脉牌</b></td><td>帮过、结交过的人变成常驻牌：既能放进格子出力，也带被动效果。槽位从 3 个开始，铺面升级能加。</td><td>周妈（每天多一张消息牌）、陈文庭（书画药材线索更清楚）、马万利（条子降一档但风声每天涨）、小丁（提前看明天一张事件）</td></tr>
 <tr><td><b>物品牌</b></td><td>收来的东西。名字、类别、成色看得见；真假、来路、底价藏着。摆上货架等买家。</td><td>金簪、铜手炉、旧报纸、《辞源》、阿司匹林</td></tr>
 <tr><td><b>当票</b></td><td>收当后摆在桌上，带倒计时。到期有人赎就是利息；没人赎就满当，东西归你。</td><td>“德字第一九六号”（主线）</td></tr>
 <tr><td><b>事件牌</b></td><td>街上和时局的事；大的带格子；没处理就按“没理会”结算。</td><td>下雨、米价涨、集市日、宵禁提前、查良民证、维持会摊派</td></tr>
 <tr><td><b>命运牌</b></td><td>随机发；好坏都有（大富翁的“机会/命运”合一）。</td><td>拾到钱袋、远亲寄钱、罚款、查封三天、征用、空袭、失火、被诬告、币制改革</td></tr>
 <tr><td><b>大命运牌</b></td><td>快输的时候出现一次，给一个翻身的机会，代价也大（见“大命运牌”一节）。</td><td>一箱来路不明的东西、孙老爷要人作保、有人高价买老宅、一张船票</td></tr>
 <tr><td><b>条子</b></td><td>胡二每周一送来，限期七天。四类 × 四档（见“条子”一节）。</td><td>要钱、要货、要人、要消息</td></tr>
 <tr><td><b>生活牌</b></td><td>过日子的开销和家事，贴近生活的主要来源。</td><td>米缸见底、煤用完了、母亲咳嗽、学费、喜帖、过年</td></tr>
 <tr><td><b>消息牌</b></td><td>行情、线索、流言、信、报纸、电报；多半会变成档案簿碎片。</td><td>“王山昨晚在码头”“米行要涨价”</td></tr>
 <tr><td><b>留着的牌</b></td><td>能留在手里、想用时再打的牌：人情、证件、硬货、把柄、空白当票。手里最多留 5 张，有的会过期。<span class="tune">【待调】</span></td><td>马万利欠你一次、良民证、孙府介绍信、一根金条、某人的把柄</td></tr>
 <tr><td><b>家当牌</b></td><td>能抵押的东西。押出去换钱，但会少一样本事（见“抵押”一节）。</td><td>老宅、铺面、柜台、库房、首饰柜；置产买来的房</td></tr>
 <tr><td><b>主线牌</b></td><td>固定日子或条件出现，推动大故事。</td><td>哥哥沈如松告别、德字第一九六号、王山回来、赵老三借三百</td></tr>
 <tr><td><b>金色角色牌</b></td><td>主线人物在主线节点上以金色牌框出现，排在手牌最前面；<b>当天必须处理，不能留到第二天</b>。不处理他就走了，主线按“没理他”走另一条路，档案簿那一页留下缺口。</td><td>沈如松（离家那天）、王山（回来那夜）、林嫂（来赎金簪）、马万利（摊派）</td></tr>
 <tr><td><b>签与黄历</b></td><td>算命求来的签文（预示接下来几天的牌）、每天告示上的黄历宜忌。</td><td>“三日之内，东南有贵人携金而来”；宜收当、忌出行</td></tr>
</table>
""")

P4 = page("""
<h2>三、核心机制</h2>
<h3>1. 柜台：当、卖、买、赎</h3>
<ul>
 <li><b>来当 / 来卖</b>：客人拿来一件东西，说个价。你可以点开东西做<b>鉴定小游戏</b>（也可以不做），得到线索；然后出三档价之一：<b>压价 / 公道 / 厚道</b>。客人接受、还价或走人（他心里的底线藏着）。来当得到当票，来卖东西直接归你。</li>
 <li><b>来买</b>：买家要某一类东西。你从货架挑一件、报三档价，他还价或走人。<b>货架上的东西只能这样卖出去</b>，没有一键卖掉。</li>
 <li><b>来赎</b>：当票到期时，当户可能拿着钱来赎。照规矩还；或者刁难加价（钱多了，口碑和本心掉）。东西要是被你提前卖了，就得赔钱或者去买回来。</li>
 <li><b>求助 / 打听</b>：不为买卖，为借钱、托事、问消息。帮、不帮、告发，都有得有失。</li>
</ul>
<h3>2. 鉴定小游戏（随机出）</h3>
<table>
 <tr><th style="width:90px">小游戏</th><th>怎么玩</th><th style="width:150px">适用</th><th style="width:44px">首发</th></tr>
 <tr><td><b>找不同</b></td><td>对照图鉴，在东西上圈出和正品不一样的地方（现在已经做好）。</td><td>瓷器、首饰、书画、铜器</td><td>✓</td></tr>
 <tr><td><b>吹银元</b></td><td>捏住银元吹一下放到耳边，听声音的长短高低，和标准声比。</td><td>银元、银器</td><td>✓</td></tr>
 <tr><td><b>称分量</b></td><td>用戥子或秤配砝码，看分量和东西对不对得上。</td><td>金银、米、药材</td><td>✓</td></tr>
 <tr><td><b>拼碎片</b></td><td>撕破的当票、裂开的字画拼回去，看印章和落款。</td><td>文书、书画、当票</td><td>✓</td></tr>
 <tr><td><b>对印章</b></td><td>转动印章，和账上、图鉴里的旧印对齐比较。</td><td>文书、字号、书画</td><td></td></tr>
 <tr><td><b>闻、摸</b></td><td>几段描述对着挑（樟木味、霉味、新漆味……）。</td><td>衣物、木器、药材</td><td></td></tr>
 <tr><td><b>解密</b></td><td>电报码、暗信、账本暗语；主线专用。</td><td>主线</td><td>✓</td></tr>
</table>
<div class="box jade">规矩：小游戏做得好，线索清楚；做得差，线索含糊。<b>永远不直接告诉你真假</b>——只给观察（“分量差了一钱，像是补过”），由你自己判断。客人有耐心，拖久了他会改价或者走人。</div>

<h3>3. 条子（胡二，每周一张）</h3>
<table>
 <tr><th style="width:70px">类别</th><th>要什么</th><th style="width:240px">怎么办</th></tr>
 <tr><td><b>要钱</b></td><td>交一笔摊派、“孝敬”。</td><td>放钱；或放人情牌、口才高的人去讲价降档</td></tr>
 <tr><td><b>要货</b></td><td>指定一类东西（米、布、药、铜器）。</td><td>放货架上合适的物品牌；没有就得去收</td></tr>
 <tr><td><b>要人</b></td><td>出夫、修工事、凑壮丁名额。</td><td>放一张人物牌（这个人这周不能用，可能回不来）；或花钱顶替</td></tr>
 <tr><td><b>要消息</b></td><td>让你说出谁常来、谁可疑。</td><td>放消息牌（会伤到那个人，档案簿那页可能断掉）；或者编一个（掷胆量）</td></tr>
</table>
<p>每类分四档：<b>小 / 中 / 大 / 要命</b>。档位随时局和风声上升 <span class="tune">【待调】</span>。办不成按档位吃亏：罚钱 → 查封三天（不发人物牌）→ 拿走一件家当 → 被抓。可以“拖一拖”：期限加三天，但条子升一档。</p>

<h3>4. 放格子、掷铜钱</h3>
<ul>
 <li>条子、大事件、命运牌、牢房都有几个<b>空格</b>，每格标着要什么：钱、东西、人（某项属性）、证件、人情。</li>
 <li>人物有四项属性：<b>眼力</b>（看东西、看人）、<b>口才</b>（讲价、说情）、<b>门路</b>（关系、办事、消息）、<b>胆量</b>（冒险、硬顶）。</li>
 <li>放进去的人和东西加起来，<b>每点属性给一枚铜钱</b>；一起掷，正面数够了就成。铜钱数看得见，成功的机会自己估（不显示百分比）。</li>
 <li>放进格子的人当天不能再用；有的事件会让人受伤、被扣、离开。</li>
</ul>
""")

P5 = page("""
<h3>5. 留着的牌</h3>
<ul>
 <li>一部分牌不用当天处理，可以<b>留在手里</b>，想用的时候再打：人情（马万利欠你一次）、证件（良民证、孙府介绍信）、硬货（一根金条）、把柄（某人的秘密）、空白当票、主线信物。</li>
 <li>手里最多留 5 张 <span class="tune">【待调】</span>；有的会过期（人情放久了不灵）；有的留着本身就有风险（把柄、来路不明的东西被查到会出事）。</li>
 <li>留牌是在牢房、条子、大命运牌这些关口保命的主要手段——和大富翁的“出狱卡”一个道理。</li>
</ul>

<h3>6. 命运牌和大命运牌</h3>
<ul>
 <li><b>命运牌</b>随机发，大约每三四天一张 <span class="tune">【待调】</span>；风声越大、时局越乱，坏的越多。好的：拾到钱袋、远亲寄钱、米价跌、老主顾介绍生意。坏的：罚款、查封三天、征用、空袭、失火、被诬告、币制改革。</li>
 <li><b>大命运牌</b>在你快输的时候出现，给一次翻身的机会：
  <ul>
   <li>触发：钱不够付条子且家当快押光；被抓进牢房；风声到了最高一档；流落街头超过几天。<span class="tune">【待调】</span></li>
   <li>它不一定救命，是一次<b>大赌</b>：成了能还清抵押、出狱、压下风声；败了直接坠底。比如“陌生人出大价钱请你保管一箱东西七天”“孙老爷要人作保”“有人高价买你的老宅”“一张去上海的船票”。</li>
   <li>每关最多出现两次，同一种危机只给一次。<span class="tune">【待调】</span></li>
  </ul></li>
</ul>

<h3>7. 抵押、流落街头（破产阶梯）</h3>
<table>
 <tr><th style="width:100px">一步步往下</th><th>怎么回事</th></tr>
 <tr><td><b>① 钱不够</b></td><td>先卖货、拿货抵。</td></tr>
 <tr><td><b>② 抵押家当</b></td><td>一样一样押出去换现钱，每月付利息，月底有钱就能赎回。押出去的东西会让你少一样本事：<br>
 首饰柜 → 不能收首饰；库房 → 货架变小；柜台 → 每天少一张人物牌；老宅 → 一家人搬进铺子，生活牌变多；铺面 → 押出去的那个月还能开，月底赎不回就没了。</td></tr>
 <tr><td><b>③ 流落街头</b></td><td>铺面没了，换成“街头”牌库，每天 3 张：乞讨、打零工、摆地摊、替人写信、跑腿、当掉随身东西、赌一把。熟人有的帮你，有的躲你。</td></tr>
 <tr><td><b>④ 爬回来</b></td><td>攒够钱赎回铺面，重新开张；之前押出去的家当按原价赎。</td></tr>
</table>

<h3>8. 被抓、打点、结局</h3>
<ul>
 <li>被抓的原因：风声到顶；“要命”档的条子没办成；某些命运牌（被诬告、窝藏）。</li>
 <li>被抓后进<b>牢房</b>事件：格子可以放钱（打点）、人脉（保人）、留着的牌（人情、介绍信、金条），再掷铜钱。成了就出来，代价是钱、人脉或家当；不成，这一局结束。</li>
 <li>结束后可以从这个月开头重来（存档按月）。</li>
</ul>

<h3>9. 口碑、风声、本心</h3>
<table>
 <tr><th style="width:60px"></th><th style="width:120px">怎么显示</th><th>影响什么</th></tr>
 <tr><td><b>钱</b></td><td>明着显示</td><td>一切买卖、条子、抵押。开局 340 蚨 <span class="tune">【待调】</span>。货币改了会换算（见年代表）。</td></tr>
 <tr><td><b>口碑</b></td><td>五档文字（“没人知道”→“老字号”）</td><td>来的是什么人、客人肯出多少、买家多不多。</td></tr>
 <tr><td><b>风声</b></td><td>五档文字（“平静”→“要抓人了”）</td><td>查铺、命运牌里坏牌的比例、条子的档位；到顶就被抓。</td></tr>
 <tr><td><b>本心</b></td><td>不显示</td><td>大命运牌出现哪几张、主线往哪走、解放后能选哪些行当、结局文字。</td></tr>
</table>
""")

P6 = page("""
<h3>10. 人脉</h3>
<ul>
 <li>帮过、结交过的人会变成<b>人脉牌</b>，常驻在桌边：能放进格子出力，也带被动效果。</li>
 <li>人脉不是只有好处：马万利让条子降一档，但风声每天涨；王山胆量很高，但跟他走得近，查铺的牌会变多。</li>
 <li>人脉会离开：被抓壮丁、搬走、死于空袭、和你翻脸。跨年时可能变了身份。</li>
</ul>

<h3>11. 档案簿：碎片化叙事</h3>
<ul>
 <li>每个人一页。每次遇到他，就补一块碎片：他当了什么、说了什么、别人提起他的话、报纸剪报、当票上的字、一封信。</li>
 <li>跨年时补“一年后”：林嫂当的金簪一直没人来赎，一年后的消息告诉你为什么。</li>
 <li>有的碎片只有你当时做了某个选择才拿得到；把人交出去，那一页可能就此断掉。</li>
 <li>一页补齐，解锁这个人的结局牌或人脉牌；整本档案簿的进度影响解放后的选择。</li>
</ul>

<h3>12. 牌库怎么变（随机从哪里来）</h3>
<ul>
 <li>每天的牌从几个牌库里抽：人物牌库、事件牌库、命运牌库、消息牌库、生活牌库。每个牌库里每张牌有权重。</li>
 <li>权重随状态变：口碑高好客人多；风声大查铺和坏命运多；集市日买家多；下雨人少；时局（年份）决定哪些牌在库里。</li>
 <li>整套用现有的 GameJev 生成器和确定性随机（同一个存档、同样的选择，抽到的牌一样），方便测试和平衡。</li>
 <li>主线牌、条子、生活牌按日程插入，不完全靠抽。</li>
</ul>

<h3>13. 命运轮盘</h3>
<ul>
 <li><b>每关开头转一次</b>，定这个月的“运势”：比如“财星高照”（买家多一些）、“流年不利”（命运牌坏的多）、“口舌是非”（流言多）。</li>
 <li><b>快输的时候</b>，大命运牌改成转一次<b>大轮盘</b>：扇区更极端，有翻身、平安、坠底。</li>
 <li><b>庙会、赌摊</b>之类事件，可以自己选择去转，花钱或押一张留着的牌。</li>
 <li><b>香案</b>：转之前可以往轮盘边的香案格里放东西（香火钱、留着的牌、某个人脉），让好的扇区变宽——和放格子是同一套机制。<b>不显示百分比，只看扇区大小。</b></li>
 <li>扇区内容随年代变；同一个存档、同样的选择，转出来的结果一样（确定性随机）。</li>
</ul>
<h3>14. 算命</h3>
<ul>
 <li><b>黄历</b>：每天告示上有当天的宜忌（宜收当、忌出行、宜祭祀……）。照着做有一点小好处，不照做也没事。</li>
 <li><b>求签</b>：算命先生、测字摊是随机来的人物牌，也可以在城隍庙事件里主动去抽。花几个钱求一支签，签文用含糊的话<b>预示接下来几天真的会抽到的牌</b>——牌由种子决定，所以签是“准”的，只是话说得含糊：“三日之内，东南有贵人携金而来”。</li>
 <li><b>测字</b>：让你挑一个字，按字给一条提示。</li>
 <li>本心低的时候，求到的签更凶。</li>
</ul>
<h3>15. 新手指引（每个机制都要有）</h3>
<ul>
 <li><b>讲在戏里</b>：由人物开口说，不弹系统说明书；锚点发光，旁边一句气泡说清“现在可以做什么”。</li>
 <li><b>第一次遇到才教</b>，按天逐步解锁，不一次灌给玩家；一次只亮一步，不挡操作、不暂停游戏。</li>
 <li><b>能回看、能关</b>：教过的都进档案簿“规矩”页和 F1；设置里可以关掉指引；开不开指引都不影响游戏结果。</li>
 <li>教学文字最后由 A 写，AI 只写占位。</li>
</ul>
<table>
 <tr><th style="width:120px">什么时候</th><th style="width:150px">谁教</th><th>教什么</th></tr>
 <tr><td>开局</td><td>哥哥沈如松</td><td>命运轮盘与香案（第一关的运势在第 1 天之前就要转）</td></tr>
 <tr><td>第 1 天</td><td>哥哥（在柜台）</td><td>发牌与手牌、人物牌、柜台三档出价、找不同鉴定、当票、货架只能等买家；晚上的夜牌</td></tr>
 <tr><td>第 2 天</td><td>哥哥（离家前）</td><td>金色角色牌当天必须处理、留着的牌</td></tr>
 <tr><td>胡二第一次送条子</td><td>胡二</td><td>条子与七天期限、拖一拖</td></tr>
 <tr><td>第一次带格子的事件</td><td>哥哥留下的账簿批注</td><td>放格子与掷铜钱</td></tr>
 <tr><td>第一次命运牌</td><td>账簿批注</td><td>命运牌</td></tr>
 <tr><td>第 4–7 天依次</td><td>告示、算命先生、周妈</td><td>黄历宜忌 → 求签/测字 → 消息牌与档案簿碎片 → 人脉牌 → 口碑与风声档位</td></tr>
 <tr><td>第一次钱不够 / 快输 / 街头 / 牢房</td><td>待定</td><td>抵押与家当、大轮盘、街头牌、打点</td></tr>
 <tr><td>月底、跳一年</td><td>账簿批注</td><td>结账；满当与“一年后”</td></tr>
</table>
<h3>16. 置产（可选，第二个更新再做）</h3>
<p>手头宽裕可以盘下隔壁铺面、买一间房收租，像大富翁买地。房子每月有租金，也能在破产时抵押；空袭、征用可能让它没了。</p>

<h2 style="margin-top:14px">四、一关（一个月）</h2>
<ul>
 <li><b>开场</b>：时局过场（这一年发生了什么），本关牌库换上，本关目标：1 个主线目标 + 2 个可选目标（比如“月底前赎回首饰柜”“补齐周妈那一页”）。</li>
 <li><b>每周一</b>：胡二送条子。<b>每周</b>：一两张生活牌。</li>
 <li><b>月底结账</b>：付抵押利息、清点当票、生活开销、结算本关目标；给一个评语（不是分数，是街坊怎么说你）。</li>
 <li><b>跳一年</b>：没人来赎的当票全部满当，东西归你；档案簿补“一年后”；物价、货币按新一年换算；部分人脉离开或变了身份；新面孔进入牌库。</li>
 <li>存档：每关开头自动存一份，失败可以从这个月开头重来。</li>
</ul>
""")

P7 = page(f"""
<h2>五、年代表：当铺年代（1938–1949）</h2>
<p class="note">每一关挑这一年里最有事的一个月。史实已逐条核对（来源见附录）；写剧情时按附录里的措辞要求。</p>
<table>
 <tr><th style="width:36px">关</th><th style="width:44px">年份</th><th>时局（背景）</th><th style="width:220px">牌库的变化</th><th style="width:44px">首发</th></tr>
 {era_rows()}
</table>
<h3>首发三关的主线（沿用现有剧情，改成牌）</h3>
<table>
 <tr><th style="width:70px">关</th><th>主线</th></tr>
 {"".join(f"<tr><td class='n'><b>{s['stage']}</b></td><td>{s['story']}</td></tr>" for s in ERA['launch'])}
</table>
""")

P8 = page(f"""
<h2>六、解放后：选新行当</h2>
<div class="box jade">1949 年那一关以解放收尾。{ERA['pivot_intro']}</div>
<h3>能选哪些，看前面攒下的</h3>
<ul>
 <li><b>人脉</b>：周妈那条线开得出茶馆，陈文庭那条线开得出中药铺，李敬之那条线能去教书。</li>
 <li><b>钱和家当</b>：赎回来的铺面、置下的房，决定新行当的开局本钱。</li>
 <li><b>档案簿</b>：补齐的人越多，新行当里认识的人越多。</li>
 <li><b>本心和风声</b>：前面为维持会办事太多，有些行当选不了，或者开局带一张“历史问题”牌（留着的牌，会在某些时候被翻出来）。</li>
</ul>
<h3>分支</h3>
<table>
 <tr><th style="width:110px">新行当</th><th>和前面的关系</th><th style="width:170px">新牌、小游戏</th></tr>
 <tr><td><b>信托商店 / 旧货店</b></td><td>离当铺最近，鉴定估价都用得上；收的是寄卖、旧货。</td><td>沿用鉴定类小游戏；寄卖牌</td></tr>
 <tr><td><b>茶馆</b></td><td>周妈线。人物牌变成茶客，消息牌最多，最适合碎片叙事。</td><td>泡茶、记茶钱、听书</td></tr>
 <tr><td><b>中药铺</b></td><td>陈文庭线。验药材、抓方子。</td><td>验药材、称分量</td></tr>
 <tr><td><b>杂货铺</b></td><td>凭票、配给的日子。</td><td>记账、算账</td></tr>
 <tr><td><b>修理铺</b></td><td>修表、修钟、修收音机。</td><td>拆装、修理</td></tr>
 <tr><td><b>教书 / 代写书信</b></td><td>李敬之线。牌以人物和消息为主，替人写信读信。</td><td>识字、代写</td></tr>
</table>
<ul>
 <li>档案簿接着记：老面孔在新行当里重新出现，换了身份。</li>
 <li>条子不再是胡二，换成新时代自己的“任务”和“通知”；风险牌、生活牌换成新年代的内容。</li>
 <li><b>收尾</b>：{ERA['branch_end']}</li>
</ul>
<h3>结局</h3>
<ul>
 <li><b>中途</b>：被抓且没能打点出来——这一局结束（可从本月开头重来）。</li>
 <li><b>当铺年代结局</b>（1949）：按钱、家当、口碑、本心、档案簿，给“德厚当这些年”的结局文字。</li>
 <li><b>分支结局</b>（1956）：每个行当各自几种结局。</li>
</ul>
""")

P9 = page("""
<h2>七、首发要做的内容 <span class="tune">【待调】</span></h2>
<table>
 <tr><th style="width:110px">内容</th><th style="width:120px">数量（三关）</th><th>说明</th></tr>
 <tr><td><b>人物牌</b></td><td>约 30 人</td><td>现有主要角色 16 人 + 过路的 6–8 种 + 每年新面孔 3–4 人；每人每年 2–4 种来意</td></tr>
 <tr><td><b>事件牌</b></td><td>约 40 张</td><td>通用 10 + 每关专属 10</td></tr>
 <tr><td><b>命运牌</b></td><td>约 30 张</td><td>通用 18 + 每关 4</td></tr>
 <tr><td><b>大命运牌</b></td><td>8–10 张</td><td>对应几种危机</td></tr>
 <tr><td><b>条子</b></td><td>16 种</td><td>四类 × 四档，每年换说法</td></tr>
 <tr><td><b>生活牌</b></td><td>约 12 张</td><td></td></tr>
 <tr><td><b>消息牌</b></td><td>约 40 张</td><td>多数是档案簿碎片</td></tr>
 <tr><td><b>留着的牌</b></td><td>约 15 张</td><td>人情、证件、硬货、把柄、信物</td></tr>
 <tr><td><b>家当牌</b></td><td>5 张</td><td>老宅、铺面、柜台、库房、首饰柜</td></tr>
 <tr><td><b>物品</b></td><td>约 40 件</td><td>沿用现有物品模板和物品图</td></tr>
 <tr><td><b>小游戏</b></td><td>4 + 解密</td><td>找不同（已有）、吹银元、称分量、拼碎片；主线解密</td></tr>
 <tr><td><b>命运轮盘</b></td><td>每年 2 个</td><td>月初运势轮盘、快输时的大轮盘，每个 8–10 个扇区；庙会/赌摊复用</td></tr>
 <tr><td><b>签与黄历</b></td><td>签文约 40 支、黄历宜忌约 20 条</td><td>签文按“预示哪类牌”分组，话要含糊</td></tr>
 <tr><td><b>金色角色牌</b></td><td>约 15 张</td><td>三关主线节点上的人物</td></tr>
 <tr><td><b>街头牌库</b></td><td>约 12 张</td><td>流落街头时用</td></tr>
</table>
<h3>美术</h3>
<ul>
 <li>牌框：按牌种 8–10 种。</li>
 <li>头像：约 30 人（人物牌、人脉牌共用；原来计划外包的头像照用）。</li>
 <li>物品图：约 40 件（沿用）。事件、命运、条子的小插图：约 60 张，可以做成统一的水墨小图。</li>
 <li>场景：柜台桌面 1 张（牌桌就是柜台）、街头 1 张、牢房 1 张、每关开场过场图 3 张。</li>
 <li>不再需要：行走图（416 帧）、室内地砖、陈设、地图。</li>
</ul>
<h3>和现在的代码</h3>
<table>
 <tr><th style="width:90px">留下</th><td>账本（钱、物品、当票）、GameJev 生成器和确定性随机（改成牌库权重）、物品生成、找不同鉴定、保护费逻辑（改成条子）、存档、Steam 接入、免 AI 声明那套审核</td></tr>
 <tr><th>不要了</th><td>走路、地图、客人身体、门口吆喝、宵禁走动、“去哪儿”地图</td></tr>
 <tr><th>新做</th><td>牌桌界面、牌库与发牌、格子与掷铜钱、留牌、金色角色牌、条子、命运/大命运、命运轮盘（含香案）、算命/签/测字/黄历、抵押与街头、档案簿碎片、三个新小游戏、按月存档</td></tr>
</table>

<h2 style="margin-top:12px">八、还要在原型里试的</h2>
<ul>
 <li>每天手牌的张数、命运牌频率、条子的金额和档位曲线。</li>
 <li>四项属性够不够用；铜钱掷多少枚、要几个正面才合适。</li>
 <li>留牌上限、过期时间。</li>
 <li>大命运牌触发得太勤会让失败没分量，太少又救不了人：要试。</li>
 <li>一关（一个月）玩下来多长；太长就把平淡的日子合并。</li>
 <li>下一步：按这份文档重做交付计划（PDF），再做一个可以在游戏里玩的第一关原型。</li>
</ul>
""")


P_CONFIRM = page("""
<h2>九、落地做法（主创 10-13 已确认）</h2>
<table>
 <tr><th style="width:24px">#</th><th style="width:150px">问题</th><th>编排先定的做法</th></tr>
 <tr><td>1</td><td><b>金色牌“不能留到明天”怎么落地</b></td><td>（v1.3 起）“打烊 · 下一天”永远能按。还有牌没处理时先问一句，列出后果：没接的人走掉，事件和命运按“没理会”结算；金色牌就是他走掉，主线按“没理他”走，档案簿留缺口。</td></tr>
 <tr><td>2</td><td><b>大命运牌和大轮盘</b></td><td>快输时出现一张“大命运”牌，处理它就是转大轮盘（翻身／平安／坠底三类扇区）。原来那几个“大赌”（来路不明的箱子、孙老爷要人作保、高价买老宅、去上海的船票）放进翻身或坠底扇区，转到才发到手上。</td></tr>
 <tr><td>3</td><td><b>存档</b></td><td>每关开头自动存一份；另外每天早上存一个“续玩点”，方便退出后接着玩。随机是确定的，读档重来抽到的牌、掷出的铜钱都一样，刷不了结果。</td></tr>
 <tr><td>4</td><td><b>第一关头三天</b></td><td>第 1–3 天不随机，只发安排好的牌，用来教学：第 1 天一定有来当（一定出找不同）、来卖、来买；第 2 天哥哥告别；第 3 天一张带格子的事件。第 4 天起照常随机。</td></tr>
 <tr><td>5</td><td><b>手牌先后</b></td><td>金色角色牌 → 牢房 → 大命运 → 事件 → 命运 → 人物 → 生活 → 消息。</td></tr>
 <tr><td>6</td><td><b>流落街头时</b></td><td>主线和金色牌、胡二的条子、命运牌照发；来赎当的人不来（当票照样倒计时）；每天三张街头牌代替人物、事件、消息。</td></tr>
 <tr><td>7</td><td><b>押牌和香案</b></td><td>庙会、赌摊押一张留着的牌：转到坏扇区这张牌没了，转到平常或好的扇区还给你。香案上的人脉当天不能再用，但不会消耗；香火钱花掉；留着的牌用掉。</td></tr>
 <tr><td>8</td><td><b>谁来教的空缺</b></td><td>哥哥第 2 天走后，没点名的规矩由“哥哥留下的账簿批注”来讲；抵押、街头、牢房的教学人待定。</td></tr>
 <tr><td>9</td><td><b>求签为什么准</b></td><td>求签时先按种子算出接下来几天的牌，挑一两张写进签里并“钉”在那一天；签文只说征兆（“官面”“水边”“远方来信”），不说是哪张。本心越低越挑坏的写进签里。测字读出“没有”时，接下来几天就不会随机抽到带那个征兆的牌。</td></tr>
</table>
<p class="note">完整的实现细节见仓库里的 docs/cards/DESIGN_cards.md（Markdown 版，含以上各条）和 docs/cards/CARDS_INTERFACES.md（38 条线的接口合同）。网页试玩版只做 1938 年三月的前 14 天，用来先试手感。</p>
""")


def appendix() -> str:
    rows = "".join(f"<li>{s}</li>" for s in ERA.get("sources", []))
    notes = "".join(f"<li>{s}</li>" for s in ERA.get("notes", []))
    return page(f"""
<h2>附录：史实核对与来源</h2>
<ul class="note">{notes}</ul>
<h3>来源</h3>
<ul class="note" style="font-size:9px">{rows}</ul>
<h3>参考游戏（来源：B 站 wiki、机核、TapTap、Boss Rush 等评测）</h3>
<ul class="note">
 <li>《苏丹的游戏》（2025）：苏丹每周抽一张卡（征服、杀戮、奢靡、纵欲，各分石、铜、银、金四档），七天内办不成就被处死；用人物、装备、道具卡去完成，属性越高掷的骰越多。</li>
 <li>大富翁：机会/命运卡、抵押、坐牢与出狱卡、置产收租。</li>
</ul>
""")


HTML = f"""<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>德厚当 卡牌版 玩法设计 v1.3</title><style>{CSS}</style></head><body>
{P1}{P2}{P3}{P4}{P5}{P6}{P7}{P8}{P9}{P_CONFIRM}{appendix()}
</body></html>"""

if __name__ == "__main__":
    open(os.path.join(HERE, "design.html"), "w", encoding="utf-8").write(HTML)
    print("ok")
