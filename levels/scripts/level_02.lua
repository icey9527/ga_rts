return {
  objective={type="survive",label="保持母舰，完成接触演习",duration=160},
  intro={{id=20,text="两支演习舰队即将接触。今天的目标是保持阵型并完成换位。",kind="idle"},
         {id=21,text="雷达标记为模拟敌我。请把追击距离控制在火控范围内。",kind="idle"}},
  interludes={{time=28,id=20,text="中场换阵开始。后排单位先转移，前排不要单独冲锋。",kind="attack"}},
  victory={{id=20,text="接触战结束。阵型转换合格，战报稍后交给诺阿。",kind="praise"}},
  defeat={{id=21,text="队形断开得太早。模拟战输了也没关系，复盘会留下答案。",kind="failed"}}
}
