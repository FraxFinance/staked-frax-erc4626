# Audit Scope for sfrxUSD (Staked FrxUSD), version 2 and FraxtalERC4626MintRedeemer
## Background
[sfrxUSD](https://docs.frax.com/protocol/assets/frxusd/sfrxusd) is our ERC-4626 yield/vault token for frxUSD, our stablecoin. Per current GENIUS Act draft stipulations, holding frxUSD itself cannot earn you yield directly, but staking it can. frxUSD itself can only be backed by cash and short-dated cash equivalents, but sfrxUSD is an entirely separate token with its own risk pool. sfrxUSD aims to earn at least the risk-free/T-Bill IORB rate, and optimally higher than this via carry-trades, algorithmic market operations (AMOs), and other DeFi activities. The current problem, however, is that the frxUSD deposited in the sfrxUSD [contract](https://etherscan.io/address/0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6) is "stuck" there, as would be expected with a traditional ERC-4626. It cannot be rehypothecated or temporarily unwound (to other tokens) and invested in higher-yielding avenues. Assuming we do nothing, it can therefore earn, at best, just the risk-free/T-Bill rate.

## Upgrade
To fix the aforementioned issues, we need to upgrade the sfrxUSD contract. Key points are:
- In the initialization, burn all the frxUSD currently in the contract
- Make the asset/share price manually settable. pricePerShare and setPricePerShareIncPerSecond
- Return 0 for previewDeposit, previewMint, previewWithdraw, previewRedeem
- Return 0 for maxDeposit, maxMint, maxWithdraw, maxRedeem
- Disable / error for deposit, mint, withdraw, redeem
- Only designed addresses can mint. We will have a mint/redeemer [contract](https://fraxscan.com/address/0xBFc4D34Db83553725eC6c768da71D2D9c1456B55#code) on Fraxtal that we will periodically balance (FraxtalERC4626MintRedeemer).
- Burning does not give back asset tokens.
- Make sure allowances, permits, etc were not disrupted
- Make sure no new bugs were introduced

For FraxtalERC4626MintRedeemer, it needs to be double checked that it will work as intended

## Audit Scope
**New sfrxUSD Implementation**  
src/contracts/StakedFrxUSD2.sol  
src/contracts/LinearRewardsQuasiErc4626.sol  

**sfrxUSD Tests**  
src/test/StakedFrxUSD2/BaseTestStakedFrxUSD2.sol
src/test/StakedFrxUSD2/TestDeployment2.t.sol
src/test/StakedFrxUSD2/TestMintDepositWithdrawRedeem.t.sol
src/test/StakedFrxUSD2/TestPPSManipulations.t.sol

**FraxtalERC4626MintRedeemer Implementation**  
src/contracts/FraxtalERC4626MintRedeemer.sol

**FraxtalERC4626MintRedeemer Tests**  
src/test/FraxtalERC4626MintRedeemer/unit/Unit_Test_sFRAXRedeemer.t.sol
