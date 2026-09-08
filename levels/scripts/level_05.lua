return {
  objective={type="eliminate",label="拦截敌方编队"},
  reinforcements={{time=30,team=0,unit="interceptor",count=2,id=26,offset={-250,550}}},
  intro={{id=25,text="拦截作战开始。轻快型先压制敌方拦截机，重型随后推进。",kind="idle"},
         {id=22,text="此关会有中途支援。保留一支机动队，不要把所有单位一次投入。",kind="idle"}},
  interludes={{time=30,id=21,text="友方支援已进入边缘空域。给他们留出航线，别把敌人引过去。",kind="praise"}},
  victory={{id=25,text="拦截成功。支援与主队衔接得不错。",kind="praise"}},
  defeat={{id=21,text="支援没有接上。下一次请把跟随目标设给机动队。",kind="failed"}}
}
