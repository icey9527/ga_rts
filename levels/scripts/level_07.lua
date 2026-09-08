return {
  objective={type="escort",label="护送资料舰通过小行星门",destination={2400,550}},
  reinforcements={{time=35,team=1,unit="light",count=2,offset={2000,-650}}},
  intro={{id=25,text="穿过小行星门，把指定护航单位送到远端集结区。主队可以交战，但护送目标不能失能。",kind="idle"},
         {id=22,text="狭窄航道会压缩队形。使用跟随命令，让护航队分批通过。",kind="idle"}},
  interludes={{time=35,id=22,text="护送目标已接近门区，敌方增援从上侧出现。先挡住入口。",kind="hit"},
              {when={type="escort_progress",value=0.7},id=25,text="最后一段航路。别在终点前为了击坠数离开护送目标。",kind="attack"}},
  victory={{id=25,text="护送完成。你终于知道什么时候不该追了，卡兹亚君。",kind="praise"}},
  defeat={{id=22,text="护送目标失能。消灭再多敌机也不能替代任务目标。",kind="failed"}}
}
