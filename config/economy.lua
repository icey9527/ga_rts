return {
    -- 目标节奏：无击杀时约 90 秒攒够一台普通机体；击杀奖励只提供适度加速。
    starting_credits=650,income=9,bounty=250,max_queue=4,
    actions={
        {id="random",label="随机增援",cost=1000,time=14,unit="random"},
        {id="fighter",label="生产战机",cost=1500,time=16,unit="fighter"},
        {id="repair",label="生产维修机",cost=1500,time=20,unit="repair"},
        {id="collector",label="建造采集站",cost=400,time=24,unit="collector"},
        {id="armor",label="研究装甲",cost=300,time=28,tech=true,max=3},
        {id="weapons",label="研究火控",cost=320,time=30,tech=true,max=3},
    }
}
