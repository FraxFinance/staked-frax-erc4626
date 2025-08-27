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

<!-- sfrxUSD2 upgrade -->
<!-- ================================================================== -->
<!-- 00 -->
```source .env && forge script src/script/sfrxUSD2/00_DeploySfrxUSDImpl.s.sol:DeploySfrxUSDImpl --chain-id 1 --with-gas-price 2000000000 --priority-gas-price 200000000 --rpc-url $MAINNET_RPC_URL --optimize --optimizer-runs 1000000 --use "0.8.30" --evm-version "prague" --broadcast --slow --verify --verifier=etherscan --retries=3 --verifier-url=$ETHERSCAN_API_URL --verifier-api-key $ETHERSCAN_API_KEY```

## Verification
### Regular contracts
Try using forge verify-contract first
```source .env && forge verify-contract --chain-id 1 --watch --compiler-version "0.8.30" --evm-version "prague" --num-of-optimizations 1000000 --rpc-url $MAINNET_RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY 0x501921ab4320389A44A5B935ed05332F45Eb6452 src/contracts/StakedFrxUSD2.sol:StakedFrxUSD2```
CHECK THE PROXY OUT FOLDER TO SEE THE OPTS/RUNS/EVM/COMP STUFF BECAUSE SOMETIMES IT IS OLDER AND IS DIFFERENT FROM THE IMPLEMENTATION!!!


If this fails, try `forge flatten`
1) `forge flatten --output src/flattened.sol src/contracts/VestedFXS-and-Flox/VestedFXS/VeFXSYieldDistributor.sol`
2) `sed -i '/SPDX-License-Identifier/d' ./src/flattened.sol && sed -i '/pragma solidity/d' ./src/flattened.sol && sed -i '1s/^/\/\/ SPDX-License-Identifier: GPL-2.0-or-later\npragma solidity >=0.8.0;\n\n/' ./src/flattened.sol`
3) Take the contents of your new flattened.sol file and do the Etherscan verification manually