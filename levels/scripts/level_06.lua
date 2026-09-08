return {
  objective={type="flagship",label="使敌方母舰退出演习"},
  intro={{id=20,text="目标是敌方母舰。先拆掉外围护航，再让重火力进入射程。",kind="idle"},
         {id=22,text="母舰周围火力密集。先削弱护航，再集中你的定点火力。",kind="idle"}},
  interludes={{when={type="enemy_remaining",count=4},id=20,text="护航阵型出现缺口。机动队切入，维修机保持原位。",kind="attack"}},
  victory={{id=21,text="敌方母舰退出演习，目标完成。各舰按序返航。",kind="praise"}},
  defeat={{id=20,text="攻击母舰之前丢掉了自己的核心，这个交换不成立。",kind="failed"}}
}
