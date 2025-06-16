## ABI Layout (Undeployed contracts)
```forge inspect src/contracts/StakedFrxUSD2.sol:StakedFrxUSD2 abi```

## Generate Interfaces (undeployed contracts)
```cast interface src/contracts/LinearRewardsErc4626.sol:LinearRewardsErc4626```

## Show storage layout (undeployed contracts)
```forge inspect src/contracts/StakedFrxUSD.sol:StakedFrxUSD storageLayout```
```forge inspect src/contracts/StakedFrxUSD2.sol:StakedFrxUSD2 storageLayout```

## Show storage layout (live contracts)
```source .env && cast storage --chain-id 1 --rpc-url $MAINNET_URL --etherscan-api-key $ETHERSCAN_API_KEY 0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6```

## sfrxUSD2 Testing
```clear && source .env && forge test --fork-url $MAINNET_URL --match-path ./src/test/StakedFrxUSD2/TestDeployment2.t.sol --match-test test_Deploy -vvvvv```
```clear && source .env && forge test --fork-url $MAINNET_URL --match-path ./src/test/StakedFrxUSD2/TestMintDepositWithdrawRedeem.t.sol --match-test test_MDWR -vvvvv```
```clear && source .env && forge test --fork-url $MAINNET_URL --match-path ./src/test/StakedFrxUSD2/TestPPSManipulations.t.sol --match-test test_1YrTtl_Simple -vvvvv```

## Code Coverage
```clear && source .env && forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage```
OR, if you get "stack too deep" issues
```clear && source .env &&  forge coverage --ir-minimum --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage```