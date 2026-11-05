# 1939 腊月的公历起止

核对对象：`data/cards/rules/stages.json` 第二关（era `1939`，`_doc` 写着公历起点待 K13 核对）。K13 只读这个文件，不改它（归 G02，合同 §2.6）。

## 结论

农历己卯年十二月（1939 腊月）是大月，公历：

- **初一：1940-01-09**
- **三十 / 除夕：1940-02-07**
- 次日 **1940-02-08** 是庚辰年正月初一（春节）

`stages.json` 现在就是 `start: 1940-01-09`、`days: 30`。

- 第 1 天 = 1940-01-09（腊月初一）
- 第 30 天 = 1940-02-07（除夕）

30 天正好盖住整个腊月，不进入农历正月。起点和天数都不用改。

请 G02 只把那条 `_doc` 改成“K13 已核对：己卯腊月为 1940-01-09 至 1940-02-07”，不要改 `start` 和 `days`。

## 怎么数的

1940 年 1 月 9 日到 1 月 31 日是 23 天，2 月 1 日到 2 月 7 日是 7 天，合计 30 天。

## 依据

- 1940 年历：1 月 9 日腊月初一，1 月 16 日腊八，2 月 7 日除夕，2 月 8 日春节。
  - https://www.xingzuobaike.com/huangli/rilibiao/1940nian.html
  - https://www.yourchineseastrology.com/hk/rili/1940-02.htm （除夕 1940-02-07 标成农历 1939 年十二月三十）
  - 春节 1940-02-08：https://www.selfgazer.com/chinese-zodiac/year/1940

## 交给 G02

issue：https://github.com/misakamikotoghr-5205/dehoudang/issues/54

标题：`[shared] K13→G02: stages.json 1939 起点`

正文要点：日期已经对，不必改数字；请在 `stages.json` 第二关的 `_doc` 里记下上面的起止，删掉“待 K13 核对”。K13 不提交这个修改。
