# 德厚当 · 要建模或要买的道具和人物

> 由 `tools/blender/gen_asset_list.py` 从 `catalog.json` 生成。
> A 档 = 第 0 批（P0）要用、或很多图位都要用；B 档 = 常用；C 档 = 少数图位才用。
> “KayKit 替身”= 在正式模型到位之前可以先凑合的 KayKit 模型；空着的表示没有能凑合的。
> 找人建模或买模型时，要求写明：人工制作、不用 AI 生成网格或贴图、许可允许商用；交来的文件登记进 `MODELS.csv`。

## A 档（52 件）

| 道具 | 图位数 | 样子（给建模的人看） | 用在哪些场景 | KayKit 替身 | 别名 |
|---|---|---|---|---|---|
| 纸灯笼 | 26 | 竹骨纸灯笼，圆或椭圆约30–40厘米，红纸和白纸两种，可亮可灭，带挂钩或提杆 | `exterior:dock`、`exterior:lane`、`exterior:market`、`exterior:old_house`、`exterior:street`、`interior:counter`、`interior:home`、`interior:rice_shop`、`interior:storeroom`、`interior:teahouse`、`interior:temple`、`object:closeup`、`object:stage_prop` |  | 灯笼、红灯笼、白纸灯笼、红纸灯笼 |
| 布包袱 | 25 | 方布四角打结的包袱，蓝印花布或灰布，30–60厘米，可背可拎可堆在货架上 | `exterior:citygate`、`exterior:dock`、`exterior:lane`、`exterior:old_house`、`exterior:street`、`interior:counter`、`interior:office`、`interior:storeroom`、`object:item`、`object:stage_prop` |  | 包袱、小包袱、布包、小布包、蓝布包袱、包袱货物、邮包 |
| 米袋 | 24 | 粗麻或白布米袋，满袋约0.5×0.8米，扎口和敞口卷边露米两种，可堆垛；另做手掌大的米样小布袋；米粒换形状颜色区分四种米 | `exterior:dock`、`interior:counter`、`interior:home`、`interior:rice_shop`、`interior:storeroom`、`object:closeup`、`object:item`、`object:stage_prop` |  | 麻袋货包、米袋垛、麻袋米袋、麻袋、布米袋、敞口米袋、破角米袋、米样小布袋、布袋、碎米/粳米/糯米/籼米袋 |
| 当铺高柜台 | 19 | 德厚当专用高柜台：深色旧木实心台身，台面离地约1.5米（客人要仰头），厚台面外沿一道矮木栏/木栅留营业口，长约4米，内侧抽屉格；柜面墙面保持空，供代码贴工具 | `interior:counter`、`object:closeup` | Restaurant kitchencounter_straight_A 加箱体台面（counter.py 现做法，只作体块） | 高柜台、柜台、高柜台(带矮栏)、带木栅高柜台、柜台面 |
| 排门板 | 18 | 竖向旧木板（约0.3×2.4米、厚4厘米）逐块插进上下槽；每块单独可动，用于插上、靠墙、半开、坏板几种状态 | `exterior:lane`、`exterior:street`、`interior:counter` |  | 门板、铺门门板、铺面门板、当铺排门板、江南铺面门板、半开排门板、坏门板 |
| 白墙黑瓦民居 | 17 | 江南一二层民居拼接模块：白粉墙（可做旧剥落）、小青瓦双坡顶、阶梯马头墙、木窗、出挑屋檐；做3–4个模块并备积雪屋顶版 | `exterior:citygate`、`exterior:dock`、`exterior:lane`、`exterior:old_house`、`exterior:street`、`interior:counter` | City building_*_withoutBase（西式，只能远景体块占位） | 门外白墙黑瓦街景、白墙黑瓦、白墙黑瓦(马头墙)、黑瓦屋顶民居、瓦顶民居、黑瓦屋檐、屋檐、积雪黑瓦屋顶、对街亮灯窗 |
| 木板门 | 16 | 窄旧木板门（后门、库房门、民居门），铁钉门环，可半开 | `exterior:dock`、`exterior:lane`、`exterior:old_house`、`interior:storeroom`、`object:stage_prop` | Restaurant door_A（改色占位） | 木板后门、半开后门、后门木门、后门、门、库房木门、木门、住户门 |
| 木货架 | 16 | 深色木多层货架约2.4米高，可加长成后墙长架，放布包、木盒、坛罐 | `interior:counter`、`interior:office`、`interior:rice_shop`、`interior:storeroom`、`object:closeup`、`object:stage_prop` | Furniture shelf_A_big / shelf_B_large（换深木色） | 货架、高木架、长货架、当铺货架 |
| 线装账簿 | 16 | 线装账簿约20×28厘米，蓝布面或黄纸面，签条空白，合上和摊开两态（页面伪字贴图） | `exterior:dock`、`exterior:lane`、`exterior:street`、`interior:counter`、`interior:office`、`object:closeup`、`object:counter_tool`、`ui:icon` | Furniture book_single（仅占位） | 账本、账簿、蓝布面账簿、收租簿、名册、名单 |
| 告示和贴墙单据 | 14 | 贴在墙或门上的纸面平面，边角略卷，只用灰色伪字块和红印贴图；从小纸条到大告示多种尺寸，封条为两道交叉白纸条 | `exterior:citygate`、`exterior:street`、`exterior:yamen`、`interior:counter`、`interior:office`、`interior:rice_shop` |  | 告示、告示（红印）、大告示、大告示(红框)、摊派单、红印罚单、罚单纸条、封条、交叉封条、告示纸 |
| 散页文书 | 14 | 各种散页纸：平铺、对折、成叠、绳捆，纸面一律空白或伪字贴图 | `exterior:dock`、`exterior:old_house`、`exterior:street`、`exterior:yamen`、`interior:home`、`interior:office`、`object:closeup`、`object:fortune`、`object:item` |  | 文书、盖印文书、成捆旧文书、手稿纸页、空白电报纸、白纸、信纸、学费单、船票、船期单、汇票、货单纸叠、交代纸 |
| 木格窗 | 14 | 木框方格或冰裂纹窗棂，糊白窗纸，约0.8×1米，可开可关，冬天贴窗花 | `exterior:street`、`interior:counter`、`interior:home`、`interior:office`、`interior:pharmacy`、`interior:rice_shop`、`interior:storeroom`、`object:closeup` |  | 格窗、格子窗、木格纸窗、窗花格窗 |
| 铜煤油灯 | 13 | 铜座玻璃罩煤油灯约35厘米高，点灯和熄灯两态（火苗用自发光面片），配一只小油瓶 | `exterior:lane`、`interior:counter`、`interior:home`、`interior:storeroom`、`object:closeup`、`object:counter_tool`、`interior:office` |  | 油灯、煤油灯、铜煤油灯（玻璃灯罩）、油灯/蜡烛、油瓶 |
| 木匣 | 12 | 带铜锁片的小木匣约40×20×15厘米，开盖和合盖两态；缩放后兼作钱匣、戥子匣、存根匣、礼盒、货架上的木盒 | `exterior:yamen`、`interior:counter`、`interior:storeroom`、`object:closeup`、`object:counter_tool`、`object:relic`、`object:stage_prop` | Furniture cabinet_small（仅占位） | 木钱匣（铜锁片）、钱匣、钱箱、小木匣、存根木匣、礼盒、木盒 |
| 毛笔 | 12 | 竹杆毛笔约20厘米；电报柜台那支换成蘸水钢笔 | `exterior:street`、`interior:office`、`object:closeup`、`object:fortune`、`ui:icon` |  | 笔 |
| 青花碗碟 | 12 | 白底青花粗瓷碗、盖碗、碟，配筷子和简单菜肴；可做豁口版 | `exterior:street`、`interior:counter`、`interior:home`、`interior:storeroom`、`interior:teahouse`、`object:closeup`、`object:item`、`object:relic` | Restaurant bowl / bowl_small / plate（只作白瓷体块占位，不另加贴图） | 青花碗、缺口碗、空碗、药碗、茶碗、盖碗、碗筷、菜碟、饭菜碗碟、鱼盘、饺子、青花猫碗 |
| 乌篷船 | 11 | 江南小木船长约6米，中段竹编黑篷，船尾橹或竹篙；同一船体出空船、载货、带帆、加长货船几版 | `exterior:citygate`、`exterior:dock`、`object:stage_prop` |  | 江南货船(乌篷船)、乌篷货船、小木船、木船、木帆船、竹篙、橹 |
| 布巾 | 11 | 布料模拟的方布：铺底红布、盖货湿布、抹布、地摊蓝布 | `exterior:dock`、`exterior:street`、`interior:storeroom`、`object:closeup`、`object:item` |  | 湿布、盖布、红布、布、旧布、抹布、地摊蓝布 |
| 方桌 | 11 | 中式方桌约0.9米见方，束腰直腿，深木色；缩小即小方桌 | `exterior:street`、`interior:home`、`interior:prison`、`interior:teahouse`、`object:closeup` | Furniture table_medium（仅占位） | 八仙桌、饭桌、茶馆方桌、小方桌、木桌 |
| 银元 | 11 | 直径约4厘米银元，同一币坯换袁头、帆船、蟠龙浮雕（法线贴图，字只用小点），可堆摞 | `exterior:citygate`、`interior:counter`、`interior:rice_shop`、`object:closeup`、`object:item` |  | 银元摞、袁头银元、船洋银元、龙洋银元、银元/元宝、一把铜钱/银元 |
| 方孔铜钱 | 10 | 方孔圆铜钱约2.5厘米，可红绳串、可堆摞 | `exterior:dock`、`exterior:street`、`interior:counter`、`object:closeup`、`ui:icon` |  | 铜钱、红绳串铜钱、铜钱摞 |
| 石阶码头驳岸 | 10 | 条石驳岸和下水台阶（河埠头），带系船石孔，附一块河面平面 | `exterior:dock` |  | 石阶码头、码头石阶、石砌码头、石驳岸、码头、河道 |
| 空白匾额 | 10 | 横匾约2×0.6米，黑漆底金边，面空白；老匾“德厚”版只做金色刻痕不可读 | `exterior:old_house`、`exterior:yamen`、`interior:office`、`interior:pharmacy`、`interior:rice_shop`、`interior:teahouse`、`object:relic`、`object:stage_prop` | Furniture pictureframe_large_B（仅占位） | 匾额、空白新匾、空白门匾、德厚木匾、老匾 |
| 空白木招牌 | 10 | 长方形木招牌约0.4×1.2米，黑底或木色带边框，面上空白（字由代码写），吊绳或钉在门楣 | `exterior:market`、`exterior:street`、`exterior:yamen`、`interior:office`、`object:counter_tool` |  | 空白招牌、招牌匾额、招牌 |
| 手 | 9 | 写实比例的成人手和前臂（男女各一），袖口可换短褂、长衫，用于只拍手的构图 | `exterior:citygate`、`exterior:dock`、`interior:counter`、`interior:storeroom`、`object:closeup` |  | 递钱的手、掌柜的手 |
| 算盘 | 9 | 中式13档算盘，深色木框约40×15厘米，上二下五珠；紫檀版只换材质 | `interior:counter`、`interior:office`、`object:closeup`、`object:counter_tool`、`object:relic` |  | 紫檀算盘 |
| 红手印条子 | 9 | 约10×20厘米的小纸条，伪字加红手印贴图，可对折、用绳成捆、钉在木板上 | `interior:counter`、`object:closeup`、`object:counter_tool` |  | 条子(红手印)、对折条子、欠条、绳扎欠条捆、钉在板上的纸条 |
| 办事长柜台 | 8 | 普通高度（约1米）的木长柜台，可加一排铁栏杆窗口（保公所/邮电所版），同一模型换配件用于邮电所、保公所、米行、药铺、茶馆 | `interior:office`、`interior:pharmacy`、`interior:rice_shop`、`interior:teahouse` | Restaurant kitchencounter_straight_B（改深木色，只作体块） | 长柜台、柜台、带铁栏杆柜台、邮电柜台、邮局柜台、米行柜台 |
| 城门城墙 | 8 | 青砖城墙带垛口、拱形城门洞、上方木构城楼，可拼接城墙段，备雪顶版 | `exterior:citygate` |  | 城门城楼、城门洞、城墙(垛口)、城门洞(砖拱)、城门洞城墙、城墙 |
| 红纸对联和斗方 | 8 | 红纸长条对联约0.25×1.5米、菱形斗方约30厘米，可贴门贴缸或放篮里；字只做空白或不可读墨痕 | `exterior:street`、`interior:counter`、`interior:home`、`object:closeup`、`object:fortune` |  | 对联、红对联、红对联纸、空白春联、斗方福字、红纸斗方、红纸、红纸字帖 |
| 蜡烛与铜烛台 | 8 | 短红蜡烛插在铜烛台上约15厘米，火苗用自发光面片 | `exterior:lane`、`interior:prison`、`interior:storeroom`、`interior:temple`、`object:counter_tool`、`object:stage_prop` |  | 蜡烛、红蜡烛、铜烛台、烛台 |
| 证件和路条 | 8 | 小折叠证件或纸条，空白照片框、印框线和红印贴图，不出字；户口纸为带格子单页 | `exterior:citygate`、`exterior:street`、`object:closeup` |  | 良民证、路条、通行证、证件、旧证件、新证件、户口纸 |
| 书桌和公案 | 7 | 长条木书桌约1.5×0.7米带抽屉；公案版加桌围 | `interior:office`、`object:closeup` | Furniture table_medium_long（仅占位） | 书桌、警察所办公桌、办事桌、公案桌、会桌、登记桌 |
| 布幌子 | 7 | 竹竿或木杆挑出的长条布幡约0.4×1.5米，下端带穗，布面空白，可做风吹弯曲 | `exterior:street`、`interior:teahouse`、`object:fortune` |  | 空白布幌子、当铺幌子(布幡)、幌子、茶旗幌子、布幌子竿 |
| 木柱梁架 | 7 | 穿斗式木构：约0.25米粗的柱、横梁、檩条；店铺用深棕本色，庙和衙门用朱红漆 | `interior:counter`、`interior:temple` | Restaurant pillar_A / pillar_B（只作柱子） | 木柱横梁、屋梁、红柱 |
| 砚台 | 7 | 长方石砚约12×18厘米，带墨块 | `exterior:street`、`interior:office`、`object:closeup`、`object:fortune` |  |  |
| 德厚当门面 | 6 | 德厚当专属两层木门面：底层三开间排门板（可半开）、门边门旗位、门楣空白招牌、二楼木格窗挑檐、黑瓦顶，位于石拱桥头；不能出现“当”字 | `exterior:lane`、`exterior:street` |  | 当铺两层木门面、当铺木门面、当铺门脸、当铺木门、当铺门面、铺面门脸 |
| 方凳和小板凳 | 6 | 木方凳约45厘米高、矮板凳约25厘米 | `exterior:dock`、`interior:home`、`interior:storeroom`、`object:fortune` | Furniture chair_stool_wood（可作占位） | 凳子、方凳、小板凳 |
| 柳树 | 6 | 江南垂柳，冬秃、春芽、夏绿三态 | `exterior:dock`、`exterior:old_house`、`exterior:street`、`exterior:yamen` |  | 秃柳、发芽柳树 |
| 石拱桥 | 6 | 江南单孔青石拱桥，台阶桥面、石栏板，跨度约8米，桥头接石板街 | `exterior:dock`、`exterior:street` |  |  |
| 木拒马和木栅路障 | 5 | 交叉木拒马和横杆栏杆 | `exterior:citygate`、`exterior:street` |  | 木栅路障、岗哨木栅、拒马木栏、木栏杆路障、木拒马 |
| 木印章与印泥盒 | 4 | 方柱木印章约8厘米，配圆形瓷印泥盒（孙府那只是青花）；官印版做大号铜钮印 | `interior:office`、`object:closeup`、`object:counter_tool`、`object:relic` |  | 木印章、圆印泥盒、铺子木印(印章)、印章、印泥盒、青花印泥盒、官印 |
| 格扇门 | 4 | 江南木格扇门，每扇约0.6×2.6米，上部方格/步步锦棂格、下部裙板；铺面用4–6扇深棕木，庙殿用红漆版 | `interior:counter`、`interior:temple` | Restaurant door_A 改色（仅样稿占位，须换） | 对开格子门、格子门、殿门格扇 |
| 戥子 | 3 | 称银子的小戥子：细木杆约30厘米、小铜盘、小秤砣，可放进开盖木匣；做新旧两种材质 | `object:closeup`、`object:counter_tool`、`object:relic` |  | 戥子(小秤)、小秤、老戥子 |
| 撕页黄历 | 3 | 墙挂撕页黄历：红色木头板夹一叠纸页，钉子吊着，约15×25厘米；线装老黄历版是平放书册，红墨批注不可读 | `object:counter_tool`、`object:relic`、`ui:icon` |  | 黄历、撕页黄历（红头板）、线装老黄历 |
| 电报机和铜电键 | 3 | 带盖木箱电报机，开盖露出铜电键；另有单独铜电键放邮电柜台 | `interior:office`、`object:counter_tool` |  | 铜电键、电键、电报机（带盖木箱）、电报机（开盖） |
| 竹竿门旗 | 3 | 门边竹竿挑着的窄长布旗约0.25×1米，蓝/红/白三色同一模型逐像素对齐 | `object:counter_tool` |  | 蓝布门旗、红布门旗、白布门旗、门旗 |
| 信件分拣格 | 2 | 墙上木格分拣架，格内塞信 | `interior:office` |  | 信格 |
| 布面档案簿 | 1 | 棕布面硬壳簿约20×28厘米，系布绳 | `object:counter_tool` |  | 棕布面档案簿（系绳） |
| 沙袋 | 1 | 麻布沙袋堆 | `exterior:street` |  |  |
| 铜框放大镜 | 1 | 铜圆框放大镜，镜片约10厘米，短木柄 | `object:counter_tool` |  |  |
| 鸡毛掸子 | 1 | 竹柄鸡毛掸子约70厘米 | `interior:storeroom` |  |  |

## B 档（43 件）

| 道具 | 图位数 | 样子（给建模的人看） | 用在哪些场景 | KayKit 替身 | 别名 |
|---|---|---|---|---|---|
| 江南木铺面 | 7 | 一到三开间木结构店面，底层排门板槽口、上层木窗挑檐，换招牌和幌子即成米行、警察所、邻铺 | `exterior:street`、`exterior:yamen`、`interior:rice_shop` |  | 江南铺面、上门板的铺面、木铺面、米行门脸、米行门面、警察所门脸、铺面 |
| 银饰 | 7 | 刻细花旧银镯、小银戒指、红绳穿的长命银锁，刻纹用凹凸贴图 | `exterior:street`、`object:closeup`、`object:item` |  | 银镯、银戒指、长命银锁、小首饰、首饰 |
| 信封和礼封 | 6 | 竖式中式信封约9×20厘米，白底红边或全红，可做开封、鼓厚、成束绳捆 | `exterior:old_house`、`object:closeup`、`object:item` |  | 厚信封、红边信封、汇款信封、拆开的信封、信封一束、红礼封、红喜帖 |
| 叠好的衣物 | 6 | 叠好的中式衣物：蓝布夹棉旧棉袄（盘扣）、藏青长衫、灰色粗绒线围巾；布料模拟后定形 | `exterior:street`、`interior:counter`、`object:closeup`、`object:item` |  | 折叠衣物、叠好的棉袄、旧棉袄、长衫、羊毛围巾、旧衣 |
| 宅院门楼 | 6 | 江南砖雕门罩加双扇木院门；石库门框（石框黑漆门）作变体；学堂版挂空白匾 | `exterior:lane`、`exterior:old_house` |  | 老宅门楼、门楼、双扇木院门、门罩、石库门门框、学堂门楼 |
| 摊桌 | 6 | 街边小木桌或矮桌约0.7米，铺布，放笔砚或小转盘 | `exterior:dock`、`exterior:market`、`exterior:street`、`object:fortune` | Furniture table_small / table_low | 测字小桌、算命桌、矮桌、赌桌、小木桌、摊台 |
| 斗笠和草帽 | 6 | 竹编尖顶斗笠和宽边草帽，可单放也给人物戴 | `exterior:dock`、`exterior:market`、`exterior:street`、`object:closeup` |  | 草帽、斗笠 |
| 木箱 | 6 | 旧木板箱约60×40×40厘米，可加捆绳、铜锁、盖布 | `exterior:dock`、`exterior:yamen`、`interior:counter`、`interior:storeroom` | Restaurant crate + crate_lid | 盖布木箱、捆绳上锁木箱、捆绳木箱 |
| 箩筐 | 6 | 圆口竹编箩筐直径约45厘米，系绳可挑；装菜、茧、米、砖、旧货 | `exterior:lane`、`exterior:market`、`exterior:street`、`interior:office`、`object:closeup` |  | 竹筐、菜筐、茧筐、竹米筐、砖筐 |
| 量米木斗与木勺 | 6 | 口约30厘米的方口梯形木斗和长柄木勺 | `interior:rice_shop`、`object:closeup` |  | 木米斗、量米木斗、米勺、木米勺、米勺/米斗 |
| 长凳 | 6 | 无靠背木长凳约1.5米，茶馆、会场、保公所共用 | `interior:home`、`interior:office`、`interior:teahouse`、`object:stage_prop` |  | 木长凳 |
| 供桌香案 | 5 | 长条高供桌约1.8米，红漆或黑漆，可铺桌围 | `exterior:lane`、`interior:temple`、`object:closeup` |  | 供桌、香案、灵前供桌 |
| 布钱袋 | 5 | 抽绳小布钱袋约15厘米，另做绣花版 | `interior:counter`、`interior:home`、`interior:office`、`object:closeup` |  | 钱袋、绣花钱袋 |
| 彩绘轮盘 | 5 | 木架立式彩绘轮盘（大）和桌面小转盘（小），扇区贴图对齐游戏轮盘配色、无字，顶上有指针 | `exterior:street`、`interior:temple` |  | 彩绘大轮盘、小转盘、小轮盘、彩绘轮盘木架、指针 |
| 签筒和竹签 | 5 | 竹签筒约20厘米，红布箍，插满红头竹签；签文用不可读墨点 | `interior:temple`、`object:fortune` |  | 签筒、竹签 |
| 线装书和布面册 | 5 | 同一书体换封面贴图：布面药书、学生课本、警察笔记本、翻开的花鸟画册（画页手绘贴图） | `exterior:street`、`object:closeup`、`object:counter_tool`、`object:item` | Furniture book_set / book_single（仅占位） | 药书、小本子、课本、布面画册、笔记本 |
| 西药瓶盒 | 5 | 1930年代西药包装：纸盒、带塞棕玻璃小瓶、封纸玻璃药瓶、小圆铁盒，标签用不可读贴图 | `object:closeup`、`object:item` |  | 药片纸盒、棕色碘酒瓶、玻璃药瓶、圆铁药盒、药粉小盒、药瓶 |
| 陶坛罐 | 5 | 褐釉或黑釉陶坛、小罐，封口纸或木塞 | `exterior:dock`、`interior:pharmacy`、`interior:storeroom`、`interior:teahouse`、`object:closeup` | Restaurant jar_A~D_large（换陶色） | 坛罐、陶罐、药罐、茶叶罐、破瓶罐 |
| 中式铜挂锁和钥匙 | 4 | 横式长条铜挂锁、长柄旧铜钥匙，可系红穗 | `interior:counter`、`interior:storeroom`、`object:closeup` |  | 铜锁、中式铜挂锁、旧铜钥匙、钥匙、钥匙红穗 |
| 当票 | 4 | 竖长印刷当票，框线加铺号红印贴图，无可读字；做完整、撕成5–6片、成叠存根三种 | `interior:counter`、`object:closeup`、`object:relic` |  | 撕碎的当票碎片、当票存根、空白当票 |
| 扁担 | 4 | 竹扁担约1.6米，两头系绳 | `exterior:lane`、`exterior:market`、`exterior:street` |  |  |
| 摊棚布篷 | 4 | 竹竿撑的中式素土布篷（不要西式条纹） | `exterior:market`、`exterior:street` |  | 条纹遮阳棚、竹棚货摊、摊棚、布棚 |
| 木梯 | 4 | 竹或木直梯约3米 | `exterior:lane`、`exterior:yamen`、`interior:counter`、`interior:storeroom` |  |  |
| 杆秤 | 4 | 木秤杆约0.8–1米，铜秤盘或秤钩，铁秤砣，可挂柴捆 | `exterior:market`、`interior:rice_shop`、`object:closeup` |  | 秤砣 |
| 棉被和枕头 | 4 | 蓝印花布棉被、方枕，布料模拟 | `interior:home`、`object:stage_prop` | Furniture pillow_A / pillow_B（枕头占位） | 棉被、蓝花棉被、枕头 |
| 空白木价牌 | 4 | 米行插在米囤上的空白木价牌，面上不写字和数字（价钱由代码写） | `interior:rice_shop` |  | 空白价牌 |
| 竹篮 | 4 | 带提梁的竹或藤编篮约35厘米，可盖布 | `exterior:dock`、`interior:counter`、`object:closeup` |  | 挎篮、藤篮 |
| 衙门门楼 | 4 | 县衙式门楼：红柱、黑瓦顶、对开大门，匾额空白 | `exterior:yamen` |  | 衙门大门(红柱) |
| 金条 | 4 | 一两和十两两种尺寸，面上凹刻不可读方戳 | `object:closeup`、`object:item` |  | 小金条、大金条、小黄鱼、大黄鱼 |
| 青花瓷瓶 | 4 | 青花梅瓶约30厘米，可插梅枝 | `exterior:street`、`interior:counter`、`object:closeup`、`object:stage_prop` |  | 瓷瓶、花瓶梅枝、瓷器 |
| 布匹 | 3 | 卷起或叠放的布匹，花纹用贴图（含一匹浅色花纹旗袍料） | `exterior:market`、`interior:storeroom`、`object:item` |  | 旗袍衣料匹 |
| 座钟和挂钟 | 3 | 方木壳座钟、带钟摆的木挂钟，钟面只画刻度 | `interior:office`、`object:item` |  | 木壳座钟、挂钟 |
| 木床 | 3 | 中式木架子床带帐子，另做一张窄木板床 | `interior:home`、`object:stage_prop` | Furniture bed_single_A（仅远景占位） | 架子床、窄木床 |
| 木盆 | 3 | 箍桶木盆约50厘米，铜盆版换材质 | `exterior:lane`、`exterior:street`、`interior:counter` |  | 铜盆 |
| 柴捆 | 3 | 草绳捆的树枝柴约0.8米，可码成柴垛 | `exterior:lane`、`exterior:market`、`object:closeup` |  | 柴垛 |
| 漆木首饰柜 | 3 | 红褐漆小柜约40×30×50厘米，多个小抽屉配铜拉手，可挂中式铜锁 | `object:closeup` | Furniture cabinet_small_decorated（仅占位） | 首饰柜、首饰柜(漆柜铜拉手)、漆木首饰柜(多小抽屉) |
| 画轴 | 3 | 挂轴可展开、半展、卷起裹蓝布；画面和字用手绘不可读贴图 | `interior:home`、`object:item` | Furniture pictureframe_large_A（仅占位） | 山水挂轴、行书条幅挂轴 |
| 砖砌灶台 | 3 | 江南砖砌柴灶，白灰抹面，一两口铁锅、木锅盖、灶门 | `interior:home`、`interior:teahouse` | Restaurant pan_A / pot_A（只作铁锅） | 灶台、中式灶台、铁锅 |
| 茶壶 | 3 | 紫砂或锡制短嘴提梁茶壶约15厘米 | `interior:counter`、`interior:teahouse`、`object:item` |  | 锡茶壶、茶壶茶碗 |
| 草席 | 3 | 草席，铺开和卷起两种 | `interior:prison`、`interior:storeroom` |  | 卷草席 |
| 银器 | 3 | 錾花鸟小银盒、缠枝花银酒杯、中式银调羹 | `object:item` |  | 錾花银盒、银酒杯、银汤匙 |
| 香炉 | 3 | 铜或石三足香炉，插香 | `interior:temple` |  |  |
| 博古架 | 1 | 柜台右墙空博古架，两行三格，格子须对齐 curio_cell；老物件由代码摆进格子，所以也是老物件渲染机位的基准 | `object:counter_tool` |  |  |

## C 档（52 件）

| 道具 | 图位数 | 样子（给建模的人看） | 用在哪些场景 | KayKit 替身 | 别名 |
|---|---|---|---|---|---|
| 岗亭 | 2 | 木板小岗亭约1×1×2.2米 | `exterior:citygate` |  |  |
| 挂着的衣服 | 2 | 木衣架或横杆上挂着的长衫、短褂、红旗袍，不要人体 | `exterior:market`、`object:stage_prop` |  | 挂起的长衫、挂起的短褂、长衫（挂着）、旗袍（挂着）、木衣架 |
| 敞口米囤 | 2 | 米行店堂里的木制或竹编敞口米囤，约1米宽，米面隆起，插空白价牌 | `interior:rice_shop` |  | 米箱 |
| 晾衣竹竿 | 2 | 跨巷竹竿晾晒衣物 | `exterior:lane` |  | 竹竿晾衣、晾衣竹竿和衣物 |
| 木栅牢门 | 2 | 粗木栅牢门 | `interior:prison` |  | 木栅栏 |
| 木梆子 | 2 | 打更用木梆子 | `exterior:dock`、`exterior:street` |  | 梆子 |
| 木灯杆 | 2 | 街边木灯杆约2.5米，石底座，顶上挂灯笼 | `exterior:street`、`object:stage_prop` |  | 街灯 |
| 枯树 | 2 | 冬天枯树 | `exterior:citygate` |  |  |
| 狸花猫 | 2 | 坐姿狸花猫小模型（需另找或购买） | `interior:rice_shop`、`object:stage_prop` |  | 猫 |
| 神龛 | 2 | 小木神龛挂红布帘，不建神像 | `interior:temple`、`object:stage_prop` |  | 神龛供桌、红布神龛 |
| 腊鱼腊肉 | 2 | 挂杆上的腊鱼腊肉等年货 | `exterior:market`、`object:closeup` |  | 腊鱼、腊肉、年货、挂杆 |
| 芦苇 | 2 | 芦苇丛，用卡片面片即可 | `exterior:citygate`、`exterior:dock` |  | 芦苇河滩 |
| 蓝布门帘 | 2 | 蓝布棉门帘，可挂可叠 | `object:relic`、`object:stage_prop` |  | 蓝布棉门帘 |
| 金簪 | 2 | 细长金簪约15厘米，顶端一朵小花 | `object:closeup`、`object:item` |  |  |
| 长烟袋 | 2 | 竹杆铜锅长烟袋约1米，挂布烟荷包 | `object:closeup`、`object:relic` |  | 旱烟袋、竹烟杆、烟荷包 |
| 陶米缸 | 2 | 家用深褐釉陶缸约0.6米高，木盖，内放木勺，可贴一张空白红纸斗方（不写字） | `object:closeup` | Restaurant jar_A_large（换陶色占位） | 米缸、缸盖 |
| 青菜 | 2 | 一把青菜 | `exterior:market`、`object:closeup` |  | 菜 |
| 高处小铁窗 | 2 | 牢房墙上高处的小铁栅窗 | `interior:prison` |  | 小铁窗 |
| 丧事白布幔 | 1 | 门口挂的白布幔 | `exterior:lane` |  | 白布幔 |
| 告示栏 | 1 | 木框告示栏，贴空白告示 | `interior:office` |  |  |
| 圆顶礼帽 | 1 | 黑呢圆顶礼帽（马保长那顶），可放在桌上 | `object:closeup` |  | 圆礼帽 |
| 城隍庙山门 | 1 | 城隍庙山门，红墙黑瓦，可挂灯笼 | `interior:temple` |  |  |
| 天平 | 1 | 药铺铜天平 | `interior:pharmacy` |  |  |
| 小火轮 | 1 | 1930年代内河小火轮，长约15米，木壳带烟囱和顶篷，只做远景低模 | `exterior:dock` |  | 蒸汽船、小火轮(蒸汽船) |
| 小藤箱 | 1 | 藤编小提箱（哥哥离家提的那只） | `object:stage_prop` |  |  |
| 拴船桩 | 1 | 码头石或木系船桩，约0.5米高 | `exterior:dock` |  |  |
| 月洞门 | 1 | 白墙上的圆形门洞，直径约2米 | `exterior:old_house` |  |  |
| 木水桶 | 1 | 箍木水桶带提梁 | `exterior:street` |  |  |
| 朱漆大门 | 1 | 大户人家朱漆双扇大门，铜门环 | `exterior:old_house` |  |  |
| 樟木箱 | 1 | 老宅樟木箱，铜包角铜锁 | `object:relic` |  |  |
| 油纸伞 | 1 | 收拢的竹骨油纸伞 | `object:relic` |  | 油纸伞（收拢） |
| 炭火盆 | 1 | 铜或铁炭火盆约40厘米，炭块发光 | `interior:home` |  |  |
| 煤筐 | 1 | 竹编浅煤筐 | `interior:home` |  | 空煤筐 |
| 玉镯 | 1 | 翠玉手镯约直径7厘米 | `object:closeup` |  | 玉镯金饰 |
| 玻璃柜 | 1 | 木框玻璃小柜 | `interior:office` |  |  |
| 白玉坠 | 1 | 白玉坠穿一根旧绳 | `object:item` |  |  |
| 百子柜 | 1 | 中药铺满墙小抽屉药柜 | `interior:pharmacy` |  |  |
| 碎银 | 1 | 大小不一的碎银块 | `object:item` |  | 碎银块 |
| 票插 | 1 | 木座铁签票插，串满条子 | `interior:counter` |  | 票插(铁签) |
| 空白横幅 | 1 | 会场空白布横幅 | `interior:office` |  |  |
| 竹扫帚 | 1 | 立着的竹扫帚 | `object:stage_prop` |  |  |
| 竹编纸篓 | 1 | 竹编纸篓 | `object:counter_tool` |  |  |
| 竹脚手架和砖堆 | 1 | 竹竿绑扎脚手架、砖堆 | `exterior:lane` |  | 竹脚手架、青砖墙、红砖堆 |
| 药箱 | 1 | 中医出诊木药箱 | `interior:home` |  |  |
| 药葫芦 | 1 | 挂饰药葫芦 | `interior:pharmacy` |  |  |
| 蒲团 | 1 | 草编蒲团 | `interior:temple` |  |  |
| 货栈大门 | 1 | 码头货栈的木大门 | `exterior:dock` |  |  |
| 轿子 | 1 | 两人或四人抬的蓝呢轿子 | `exterior:yamen` |  |  |
| 铁锹 | 1 | 旧铁锹配木柄，靠墙放 | `object:closeup` |  |  |
| 铜手炉 | 1 | 铜圆手炉带提梁，炉盖镂花孔 | `object:item` |  |  |
| 铜药碾 | 1 | 济生堂铜药碾，碾槽加碾轮 | `object:relic` |  |  |
| 锡箔纸锭和线香 | 1 | 清明用锡箔纸锭和线香 | `object:closeup` |  | 锡箔纸锭、线香 |

## 人物（56 个）

Blender 做人物需要专门的民国人物模型、绑定和姿势，成本比约稿画头像高得多；这里列出来是为了估算，不是建议走 Blender。

| 谁 | 涉及图位 | 样子 |
|---|---|---|
| 乡嫂 | `portrait.nf1939c`、`illus.ev.1939.countryside_word` | 进城过年的乡下妇人，蓝花包头巾、棉袄，挎竹篮 |
| 伪军/城门守卫 | `portrait.ex_soldier`、`walk.ex_soldier`、`bg.stage.1939`、`illus.ev.1939.gate_check`、`illus.ev.1940.gate_tight`、`illus.fa.1939.gate_wink`、`illus.gl.1939.gate_passed`、`illus.ev.1938.road_pass` | 深色军服、军帽、绑腿，不拿枪、无徽章，不画日本兵样式；城门和路口守卫多做背影 |
| 何启明（邮差） | `portrait.postman`、`walk.postman` | 邮电代办邮差，绿色邮差制服配大檐帽，斜挎皮邮包 |
| 区抄（伪区公所小职员） | `portrait.nf1939d`、`illus.ev.1939.district_levy`、`illus.fa.1939.district_fine`、`illus.ev.1940.household_count` | 青年抄写员，圆框眼镜，深色中山装或长衫，不画徽章；几张插图里的长衫或深色制服小职员都用他 |
| 吴长发（吴掌柜） | `portrait.wu`、`walk.wu`、`illus.ev.1939.wu_price`、`illus.fa.1938.rice_ease` | 裕丰米行掌柜，约45–50岁，胖圆脸爱笑、发际线高、不戴帽，褐色布褂或长衫，拎米样小布袋 |
| 周妈 | `portrait.zhouma`、`walk.zhouma`、`illus.nw.rumor`、`illus.gl.1938.zhouma_page` | 45岁桥头茶馆厨娘，胖，白头巾、白围裙、褐布褂、卷袖 |
| 周阿绣 | `portrait.nf1938b` | 前茧行女工，低发髻、褪色绿褂，领口别针线 |
| 外乡人 | `portrait.stranger_waixiang`、`illus.ky.traveling_buyers` | 旧毡帽、灰布褂，扛布包袱；traveling_buyers 的毡帽外地客借此模型 |
| 大户小厮 | `illus.ky.big_households` | 少年小厮，短褂，拎包袱跟在管事身后 |
| 孙富贵（孙少爷） | `portrait.sunyoung`、`walk.sunyoung` | 22岁，油头、西装外套、奶白长围巾、金怀表和表链 |
| 孙德昌（孙老爷） | `portrait.sunlaoye`、`illus.bf.any.sun_guarantee` | 55岁孙府当家、商会会长，黑缎瓜皮帽、黑缎马褂罩深蓝长衫，灰山羊胡；只用于牌面 |
| 孙福（孙府管家） | `portrait.guanjia`、`walk.guanjia`、`illus.ky.big_households` | 52岁，瓜皮帽顶红结、灰长衫、褐色马甲，手捻木念珠；big_households 的长衫管事可借此模型 |
| 学堂先生 | `illus.lf.1940.school_rename`、`illus.lf.any.school_fee` | 长衫先生，可戴眼镜，手拿学费单 |
| 孩子 | `illus.ev.1938.refugee_door`、`illus.ev.1939.refugee_cold`、`illus.lf.any.school_fee`、`illus.ev.1940.household_count` | 小孩，旧布褂或破棉袄，学童背布书包 |
| 守寡妇人 | `portrait.stranger_widow` | 年轻女子，素发髻戴小白花，素色深衣 |
| 官员与随从 | `illus.ev.1940.new_official`、`illus.fa.any.false_charge`、`illus.fa.1940.whisper` | 新到任官员（深色制服或长衫马褂，无徽章）加两三个随从轿夫；坐公案后、下轿等姿势 |
| 对门的姑娘 | `portrait.ex_girl`、`walk.ex_girl` | 少女群演，红色大襟袄、长辫；胸像从行走图正面第一帧派生 |
| 小丁 | `portrait.xiaoding`、`walk.xiaoding` | 17岁孙府伙夫，瘦高、胆小缩肩，灰布短褂、油渍围裙、颈上搭毛巾 |
| 崔老奎（更夫） | `portrait.nf1938d`、`illus.ev.1940.curfew` | 五十出头更夫，深色棉袄、毡帽，胸前挂木梆子；ev.1940.curfew 的打更人用他 |
| 巡警 | `portrait.ex_patrol`、`walk.ex_patrol`、`bg.stage.1938`、`illus.ev.1938.night_patrol`、`illus.ev.1938.police_check`、`illus.ev.1938.police_open`、`illus.ev.1939.patrol`、`illus.ev.1940.household_count`、`illus.ev.1940.shop_search`、`illus.ev.1940.wang_regime`、`illus.fa.any.requisition` | 深色警服、大檐警帽、皮腰带，不带任何徽章袖标旗；与伪军制服要区分 |
| 张慧娟（张护士） | `portrait.zhang`、`walk.zhang` | 26岁，短发不戴护士帽，灰白护士外衣罩藏蓝旗袍，挎竹篮 |
| 报童 | `portrait.ex_newsboy`、`walk.ex_newsboy` | 少年，鸭舌帽、浅色短褂，腋下夹报纸（不超出16px窄格） |
| 收货人（黑礼帽长衫） | `portrait.stranger_collector`、`walk.stranger_collector`、`illus.fa.any.stranger_deal` | 中年男子，黑色宽檐礼帽、深色长衫，拎小布包；stranger_deal 帽檐压低的生人可借此模型 |
| 方小安 | `portrait.nf1938c` | 济生堂学徒少年，蓝布褂、白袖套，拿纸药包（不是白褂十字） |
| 方晚晴 | `portrait.nf1940d` | 二十八上下寻人妇人，大襟褂，手持半张旧当票（无可认字） |
| 李敬之 | `portrait.li`、`walk.li` | 18岁中学生，深灰立领学生装、学生帽，袖子略短；不画报纸稿件等暗示身份之物 |
| 林嫂 | `portrait.linsao`、`walk.linsao` | 24岁船工妻子，发髻，蓝布/素色大襟褂（1938 有孕，1939 起孩子已生；头像和行走图跨三年共用，不做孕肚体型） |
| 柴佬 | `portrait.nf1939a`、`illus.ev.1939.charcoal_spike` | 城外卖柴人，冬装棉袄毡帽，背柴捆；charcoal_spike 的卖柴人用他 |
| 沈如松（哥哥） | `portrait.brother`、`walk.brother` | 19岁青年，藏青高领长衫、布鞋，左眉一道旧疤（16px行走图可省） |
| 沈如花（主角） | `portrait.ruhua`、`walk.ruhua`、`illus.ev.1938.police_check`、`illus.ev.1939.year_debt`、`illus.ev.1940.curfew`、`illus.ev.1940.shop_search`、`illus.fa.1938.kin_money`、`illus.fa.any.found_claim`、`illus.fa.any.illness`、`illus.lf.1939.pawn_coat`、`illus.st.ask_kin`、`illus.st.beg`、`illus.st.copy`、`illus.st.errand`、`illus.st.pawn_own`、`illus.st.scavenge`、`illus.st.stall`、`illus.st.watch`、`illus.st.write_letters`、`illus.gl.1938.keep_shop`、`illus.gl.1939.debt_paid`、`illus.gl.1939.gate_passed`、`illus.gl.1940.ruhua_well`、`illus.gl.1940.stand_rules`、`illus.bf.any.street_bed`、`illus.nt.family_dinner` | 16岁少女，写实比例（不是Q版）；长辫系红头绳，靛蓝大襟布褂、黑布裤、布鞋，斜挎小布包；冬天换短棉袄。要站、走、跑、坐、蹲、执笔、卧床几种姿势；多张插图可只露手或背影 |
| 王山 | `portrait.wangshan`、`walk.wangshan` | 22岁过路青年，旧草蓑衣罩灰布短褂，左手缠干净白布（不渗血），站姿笔直；不画枪和标志 |
| 码头脚夫 | `portrait.ex_porter`、`walk.ex_porter`、`illus.ev.1938.dock_night`、`illus.st.carry`、`illus.ky.dockhands`、`illus.bf.1938.night_cargo` | 粗布短褂、汗巾，肩扛一只麻袋，不要扁担；码头搬货、扛包的小人都用他 |
| 礼帽长衫中年男（债主/房东/买主） | `illus.ev.1939.year_debt`、`illus.gl.1939.debt_paid`、`illus.lf.any.debt_due`、`illus.lf.any.rent`、`illus.bf.any.house_offer` | 体面中年男子，礼帽、长衫，夹账本或收租簿、递厚信封；可从“收货人”底模改 |
| 算命先生 | `portrait.suanming`、`walk.suanming` | 老年男子，圆墨镜、白须、瓜皮帽、灰蓝长衫，手持签筒；与 ex_oldman 区分开 |
| 维持会长衫男（念名单、收捐、记账） | `illus.ev.1938.police_check`、`illus.ev.1938.puppet_roll`、`illus.ev.1938.wharf_due`、`illus.fa.1938.requisition`、`illus.ev.1938.night_patrol` | 中年长衫男子拿名单、账簿或笔记本，无臂章字、无徽章；可与区抄、茧账共用底模 |
| 胡二 | `portrait.hu2`、`walk.hu2` | 替保长跑腿的瘦男人，约三十岁，锅盖头不戴帽、黑布立领短褂，指间夹折好的空白纸条；cast.json 写灰布短褂、臂缠白布、帽檐压低，与出图单有出入，约稿前需主创定稿 |
| 胡二的人（剪影） | `portrait.ex_hu2_man`、`walk.ex_hu2_man`、`illus.fa.any.night_knock`、`illus.fa.any.theft`、`illus.bf.any.quiet_fee`、`illus.fa.any.street_fine` | 黑布短褂、宽檐呢帽的男子，游戏里压成纯剪影，只要轮廓对；可与胡二共用底模。夜里敲门、溜出门的黑影和柜台前伸手要钱的深色短褂男子都可用它 |
| 茧账（茧行账房） | `portrait.nf1939b`、`illus.ev.1939.cocoon_desk` | 青年账房伙计，冬装长衫，抱账本；只画账房，不画日本人 |
| 蔡布成（布贩） | `portrait.nf1940c` | 三十五上下布贩，瓜皮帽、短褂，抱布匹 |
| 街上的老先生（老主顾） | `portrait.ex_oldman`、`walk.ex_oldman`、`illus.ky.old_customers`、`illus.fa.1940.old_buyer`、`illus.fa.any.regular_intro`、`illus.st.ask_kin` | 灰发老人，圆框眼镜、长衫，可加瓜皮帽当老主顾；要与算命先生区分。亲戚家门缝探头的老人也可借用 |
| 街坊妇人（中年/老年） | `illus.fa.any.found_claim`、`illus.fa.any.neighbor_row`、`illus.st.write_letters`、`illus.lf.any.mother_cough`、`illus.ev.1940.household_count`、`illus.bf.any.street_bed` | 布褂大襟衣的中年和老年妇女，发髻；争吵、指认、请人写信、开门、咳嗽等姿势 |
| 货郎 | `portrait.stranger_peddler`、`walk.stranger_peddler` | 中年货郎，宽边草帽/斗笠、灰色补丁褂，背木货箱 |
| 赵老三 | `portrait.zhao`、`walk.zhao` | 40岁佃户，黑瘦，补丁蓝灰短褂，长竹烟杆贴身拿 |
| 赶路学生 | `portrait.stranger_student` | 青年学生，学生帽、深色学生装、白围巾、布挎包 |
| 过路船工 | `portrait.stranger_boatman`、`prop.boat`、`illus.gl.1940.heat_quiet`、`illus.bf.1939.gate_passage`、`illus.ky.dockhands`、`illus.ev.1938.wharf_due` | 竹斗笠、靛蓝短褂，肩挂绳圈；船上撑篙摇橹的船夫、船家都用他，远景做剪影 |
| 逃难者 | `portrait.stranger_refugee`、`walk.stranger_refugee`、`illus.ev.1938.refugee_door`、`illus.ev.1939.refugee_cold` | 瘦男子，补丁旧衣，背布包袱和卷草席；后门讨饭和城墙根挤着的难民都用他（冬天加破棉袄） |
| 通用短褂劳力男 | `illus.ev.any.gamble_stall`、`illus.ev.any.alley_row`、`illus.fa.any.false_charge`、`illus.lf.any.repair_house`、`illus.st.odd_job`、`illus.ky.junk_runners`、`illus.ev.any.market_haggle`、`illus.ev.any.demand_return`、`illus.fa.1938.kin_money` | 成年男子，粗布短褂、布裤、草帽或光头，要蹲、挑担、爬梯、指认、争吵等姿势；收旧货人、农夫、工匠、赌客、信差、回镇青年共用底模换衣色 |
| 通用镇民群众（背影剪影） | `bg.stage.1938`、`bg.stage.1939`、`bg.stage.1940`、`illus.ev.1938.police_open`、`illus.ev.1938.puppet_roll`、`illus.ev.1938.rice_line`、`illus.ev.1940.rice_notice`、`illus.fa.1940.rice_spike`、`illus.ev.1939.night_market`、`illus.ev.any.fair`、`illus.ky.needy_neighbors`、`illus.ev.1940.wang_regime`、`illus.fa.1938.requisition`、`illus.fa.any.clear_road`、`illus.fa.any.fire_next_door`、`illus.ev.1939.gate_check`、`illus.ev.1940.gate_tight`、`illus.ev.1939.patrol`、`illus.st.gamble`、`illus.ev.1939.charcoal_spike`、`illus.lf.any.funeral`、`illus.ev.any.temple_lot`、`illus.ev.1940.signboard` | 男女各两三个低细节体型，短褂、长衫、大襟袄、冬棉袄（背年货）、孝服几套换色；排队、围观、跪拜、提桶多为背影或剪影，远景复用 |
| 邻铺伙计（兼1939学徒） | `portrait.ex_shopboy`、`walk.ex_shopboy`、`illus.ev.1938.rice_line`、`illus.ev.1940.rice_notice` | 少年伙计，布短褂、布裤、白围裙，剃短头；米行伙计、贴告示伙计借此模型 |
| 钱阿根 | `portrait.nf1938a` | 四十出头米行脚夫，本色粗布短褂、汗巾，肩扛米袋 |
| 销赃人 | `portrait.stranger_fence`、`walk.stranger_fence` | 年轻男子，鸭舌帽帽檐压低、竖领外衣，双手揣袖（走路姿势也揣袖） |
| 镇上的学生 | `portrait.ex_student`、`walk.ex_student` | 米白学生装群演，性别由主创定（订单未定） |
| 陈文庭 | `portrait.chen`、`walk.chen`、`illus.lf.any.see_doctor` | 50岁济生堂老板，灰白头发、圆框金属眼镜、深褐长衫，不戴帽；不能带电台等暗示秘密身份之物。see_doctor 的老中医可借这个模型（长衫加药箱） |
| 顾承年（书记） | `portrait.nf1940a` | 二十出头的伪政权书记，礼帽、深色中山装或长衫，抱当铺名册；春装，无徽章 |
| 马万利（马保长） | `portrait.ma`、`walk.ma` | 38岁，黑色圆顶礼帽、小胡子、深色西装，左臂无字白布臂章，手拿账本；臂章不能有字或徽记 |
| 齐路生（报贩） | `portrait.nf1940b` | 四十上下从南京来的报贩，鸭舌帽、布褂，夹一叠旧报纸 |
