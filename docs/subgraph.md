https://thegraph.com/explorer/subgraphs/Gqm2b5J85n1bhCyDMpGbtbVn4935EvvdyHdHrx3dibyj?view=Query&chain=arbitrum-one

{
  pool(
    id: "0x06249abc099011fec3a5550a7a6d1f12ba90ad9b9c59cd13b32a83b5c1fad7ee"
  ) {
    id
    tickSpacing
    token0 {
      id
      symbol
      decimals
    }
    token1 {
      id
      symbol
      decimals
    }
    totalValueLockedUSD
    volumeUSD
    createdAtTimestamp
    hooks
    tickSpacing
    feeTier
  }
}

// response

{
  "data": {
    "pool": {
      "createdAtTimestamp": "1750070011",
      "feeTier": "19900",
      "hooks": "0x0000000000000000000000000000000000000000",
      "id": "0x06249abc099011fec3a5550a7a6d1f12ba90ad9b9c59cd13b32a83b5c1fad7ee",
      "tickSpacing": "398",
      "token0": {
        "decimals": "18",
        "id": "0x0000000000000000000000000000000000000000",
        "symbol": "ETH"
      },
      "token1": {
        "decimals": "9",
        "id": "0xfca95aeb5bf44ae355806a5ad14659c940dc6bf7",
        "symbol": "SHIB"
      },
      "totalValueLockedUSD": "637638.6697109202473715188435430573",
      "volumeUSD": "8935382.947986625496481725205458364"
    }
  }
}