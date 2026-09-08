return {
  objective={type="survive",label="守住交叉航道",duration=200},
  reinforcements={{time=58,team=0,unit="heavy",count=2,id=21,offset={-250,500}}},
  intro={{id=20,text="这里有两条交叉火力线。不要停在中央，选择一侧先打穿。",kind="idle"},
         {id=22,text="我会标记高威胁弹道。你的任务是让慢速重型单位提前转向。",kind="idle"}},
  interludes={{time=28,id=22,text="敌方火力重心改变，另一侧出现空隙。现在换边。",kind="attack"},
              {time=58,id=20,text="我方预备队抵达。让新单位跟随现有小队，不要单独投入。",kind="praise"}},
  victory={{id=20,text="交叉火力被分割处理，判断合格。",kind="praise"}},
  defeat={{id=22,text="停留在交叉点太久。弹道再慢，累积命中也会摧毁装甲。",kind="failed"}}
}
