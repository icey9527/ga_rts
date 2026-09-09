-- chara.tbl 的 type 数值 -> 机体类型名（与 config/units 同名）。
-- 0=母舰，-1=左手，-2=右手；不写 type 表示随机分配，1..N 见下表。
return {
    [0]="mothership",
    [1]="fighter",
    [2]="interceptor",
    [3]="sniper",
    [4]="artillery",
    [5]="heavy",
    [6]="repair",
    [7]="bomber",
    [13]="tiger",
    [8]="light",
    [9]="scout",
    [10]="missile_frigate",
    [11]="gunship",
    [12]="carrier",
}
