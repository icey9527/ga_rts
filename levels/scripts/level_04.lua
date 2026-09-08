return {
  objective={type="survive",label="挺过轰炸窗口",duration=180},
  reinforcements={{time=26,team=1,unit="bomber",count=2,offset={2600,-400}}},
  intro={{id=25,text="轰炸线即将启动。重型单位负责吸收压力，其他人保护维修机。",kind="idle"},
         {id=22,text="远距离定点打击会提前显示落点。看到红圈就移动，不要硬吃。",kind="idle"}},
  interludes={{time=26,id=22,text="发现第二条轰炸轨迹。把队形拉开，随后集中火力处理投弹机。",kind="hit"}},
  victory={{id=25,text="轰炸线已突破。护送维修机的决定很稳。",kind="praise"}},
  defeat={{id=22,text="全队挤在一处，正好给了范围武器目标。重新规划间距。",kind="failed"}}
}
