return {
  objective={type="flagship",label="保护己方母舰并击败对方母舰"},
  reinforcements={{time=30,team=0,unit="light",count=2,offset={-200,650}},{time=30,team=1,unit="heavy",count=2,offset={3000,-500}}},
  intro={{id=25,text="最终演习。卡兹亚君，这次没有标准答案，只有你能不能把所有人带回来。",kind="idle"},
         {id=22,text="生产、研究和技能全部开放。资源有限，升级要服务于你的战术。",kind="idle"},
         {id=20,text="双方舰队就位。卡兹亚，让我们认真打完这一场。",kind="attack"}},
  interludes={{time=30,id=21,text="第一批预备队进入。敌我双方都还有余力。",kind="attack"},
              {when={type="losses",count=2},id=22,text="战损接近临界值。现在保存兵力，比交换击坠更重要。",kind="hit"},
              {time=95,id=25,text="最后阶段。技能准备好的单位已经在名单里闪烁。",kind="skill"}},
  victory={{id=25,text="演习结束。做得好，卡兹亚君。把大家完整带回来，比漂亮的数字更重要。",kind="praise"},
           {id=22,text="战报已保存。我承认，这次你的判断值得研究。",kind="praise"}},
  defeat={{id=20,text="胜负已定。别低头，下一次从部署阶段重新赢回来。",kind="failed"},
          {id=25,text="先休息，然后复盘。你还有机会把这支舰队带好。",kind="failed"}}
}
