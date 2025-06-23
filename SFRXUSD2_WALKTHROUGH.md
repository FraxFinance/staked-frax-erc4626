# SFRXUSD2 WALKTHROUGH

## Conceptual idea
### Give us a high-level explanation of what the product achieves.
Please see the [docs](https://docs.frax.com/protocol/assets/frxusd/sfrxusd)

[sfrxUSD](https://docs.frax.com/protocol/assets/frxusd/sfrxusd) is our ERC-4626 yield/vault token for frxUSD, our stablecoin. Per current GENIUS Act draft stipulations, holding frxUSD itself cannot earn you yield directly, but staking it can. frxUSD itself can only be backed by cash and short-dated cash equivalents, but sfrxUSD is an entirely separate token with its own risk pool. sfrxUSD aims to earn at least the risk-free/T-Bill IORB rate, and optimally higher than this via carry-trades, algorithmic market operations (AMOs), and other DeFi activities. The current problem, however, is that the frxUSD deposited in the sfrxUSD [contract](https://etherscan.io/address/0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6) is "stuck" there, as would be expected with a traditional ERC-4626. It cannot be rehypothecated or temporarily unwound (to other tokens) and invested in higher-yielding avenues. Assuming we do nothing, it can therefore earn, at best, just the risk-free/T-Bill rate.

In addition to upgrading the sfrxUSD yield/vault token for frxUSD, the new price evolution function will require an upgrade to the sfrxUSD oracles on fraxtal [`0x1B680F4385f24420D264D78cab7C58365ED3F1FF`](https://fraxscan.com/address/0x1B680F4385f24420D264D78cab7C58365ED3F1FF) and [`0xF750636E1df115e3B334eD06E5b45c375107FC60`](https://fraxscan.com/address/0xf750636e1df115e3b334ed06e5b45c375107fc60). You can assume that these addresses will be proxies at the time of upgrade and that we propose to use the `SfrxUsd2OracleImplementation` contract as the implementation, for said proxies. The variables within the oracle will be set via a trusted relay/msig.

### Give us a high-level explanation of how it does that.
StakedFrxUSD2 is ERC4626-like, at least at the moment. After the upgrade, it will behave more like a placeholder vault/tracker and the source-of-truth for the sfrxUSD pricing (to be used by oracle(s)). Routine mint/redeems will happen on the FraxtalERC4626MintRedeemer. Most of the ERC4626 functions on the Eth StakedFrxUSD2 contract will then be disabled or return 0.
### Explain non-trivial financial logic, math, or similar.
src/contracts/LinearRewardsQuasiErc4626.sol's _previewPricePerShare has some exponential math. Same with calcPPSIPSForGivenAPY
### Feel free to elaborate on important system parameters.
See above
### Visualizations, examples and other supportive materials can help.


## Actors and trust model
### What are the different roles in your system?
StakedFrxUSD2.sol: After the upgrade, only designed addresses can mint / redeem directly. Also only the timelock address should be able to add/remove minters and set the pricing params on StakedFrxUSD2  
SfrxUsd2OracleImplementation.sol: Thomas can explain, but we control it.
FraxtalERC4626MintRedeemer.sol: Anybody should be able to mint/deposit/redeem/withdraw. Only the owner can set oracles, fees, etc
### What are the trust assumptions between them?
See above
### What assumptions do you make about external systems?
We control them (oracle, owner)
### If there are any admin roles, what are they allowed to do?
See above
### Are there off-chain components and what do they do?
The oracle for the Fraxtal sfrxUSD pricing for the FraxtalERC4626MintRedeemer


## Architectural overview
### What smart contracts will be deployed? Are there any proxies?
StakedFrxUSD2.sol: New impl for Eth 0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6 
SfrxUsd2OracleImplementation.sol: New impls for Fraxtal 0x1B680F4385f24420D264D78cab7C58365ED3F1FF and 0xF750636E1df115e3B334eD06E5b45c375107FC60
FraxtalERC4626MintRedeemer.sol: Existing & no new upgrade @ Fraxtal 0xBFc4D34Db83553725eC6c768da71D2D9c1456B55
### Where are the different users supposed to enter the system?
After the upgrade, on Eth, only designated addresses (minters) can mint/redeem. General users will have to either buy from a DEX, or use the FraxtalERC4626MintRedeemer on Fraxtal. The pricing for that MintRedeemer will use the aforementioned SfrxUsd2Oracle
### How are the system’s smart contracts supposed to interact with each other?
TODO
### How are third-party systems integrated into your system design (integrations) and what do these systems roughly do (if we are unfamiliar with them)?
TODO
### Please tell us your concerns and which parts of the system are the most complex.
- Make sure allowances, permits, etc were not disrupted
- Make sure no new bugs were introduced
- Make sure storage was not incorrectly manipulated / altered
- Make sure the oracle for the FraxtalERC4626MintRedeemer is set up properly
- Only designed addresses can mint / redeem on Eth directly with the StakedFrxUSD2.sol contract
- Only the timelock address can add/remove minters and set the pricing params on StakedFrxUSD2