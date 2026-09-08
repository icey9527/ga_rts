return {
    starting_credits=650,income=3,bounty=65,max_queue=4,
    actions={
        {id="random",label="随机增援",cost=120,time=14,unit="random"},
        {id="fighter",label="生产战机",cost=180,time=16,unit="fighter"},
        {id="repair",label="生产维修机",cost=220,time=20,unit="repair"},
        {id="collector",label="建造采集站",cost=260,time=24,unit="collector"},
        {id="armor",label="研究装甲",cost=300,time=28,tech=true,max=3},
        {id="weapons",label="研究火控",cost=320,time=30,tech=true,max=3},
    }
}
