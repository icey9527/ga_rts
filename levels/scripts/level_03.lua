return {
  objective={type="escort",label="护送侦察资料舰",destination={1800,-500}},
  intro={{id=25,text="资料舰要穿过侦察屏障。先让轻快型探路，主队掩护它抵达集结区。",kind="idle"},
         {id=22,text="晶体区会影响视野和弹道。不要把所有火力线压在同一条航道。",kind="idle"}},
  interludes={{time=34,id=22,text="侦察回波确认，敌方正在绕后。现在可以让一支小队回防。",kind="hit"}},
  victory={{id=22,text="屏障已穿过。你的侦察顺序比火力更重要，这次判断正确。",kind="praise"}},
  defeat={{id=25,text="看不见目标时不要盲冲。先停下来，让侦察机给你视野。",kind="failed"}}
}
