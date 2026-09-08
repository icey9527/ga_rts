return {
  objective={type="escort",label="护送撤离舰突破包围",destination={2200,-650}},
  intro={{id=21,text="我方被包围。建立一条撤离走廊，保护撤离舰抵达集结区。",kind="idle"},
         {id=22,text="屏障之间有安全间隔。范围轰炸适合清理出口，定点火力留给母舰。",kind="idle"}},
  interludes={{time=24,id=25,text="出口已经打开一半。受损单位先撤，别让它们停在火线上。",kind="hit"}},
  victory={{id=21,text="包围解除。全舰重新编队，准备下一轮演习。",kind="praise"}},
  defeat={{id=25,text="突围不是各跑各的。跟随、掩护和维修必须连在一起。",kind="failed"}}
}
