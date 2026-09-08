return {
  objective={type="eliminate",label="清理晨曦航道与后续波次"},
  intro={{id=25,text="晨曦航道有异常回波。卡兹亚君，先护住母舰，再判断敌人数量。",kind="idle"},
         {id=22,text="右侧数据里有一条低强度支援航线。不要为了追击离开补给范围。",kind="idle"}},
  interludes={{time=30,id=22,text="新的敌方波次从远端进入。队形不要散，维修机留在后方。",kind="hit"},
              {when={type="losses",count=1},id=25,text="有机体退出演习了。卡兹亚君，按优先级处理，不要同时追所有目标。",kind="hit"}},
  victory={{id=22,text="航道稳定。资源损耗在可接受范围内，接下来可以扩大采集。",kind="praise"}},
  defeat={{id=25,text="母舰失去掩护了。下次先布置跟随，再下集中攻击。",kind="failed"}}
}
