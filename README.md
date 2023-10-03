# Staked Frax

Staked Frax is an ERC-4626 Vault

Rewards are distributed linearly over a rewards cycle.

Any excess assets available in the vault are queued as rewards for the next cycle upon calling syncRewardsAndDistributions()


# Optional Setup
Add:
```
function profile() {
  FOUNDRY_PROFILE=$1 "${@:2}"}
```
To easily execute specific foundry profiles like `profile test forge test -w`

# Installation
`npm i && forge build`

# Compile
`forge build`

# Test
`profile test forge test`

`profile test forge test -w` watch for file changes

`profile test forge test -vvv` show stack traces for failed tests

# Update to latest version of frax-standard-solidity
`git submodule update --init --remote lib/frax-standard-solidity`

# Tooling
This repo uses the following tools:
- frax-standard-solidity for testing and scripting helpers
- forge fmt & prettier for code formatting
- lint-staged & husky for pre-commit formatting checks
- solhint for code quality and style hints
- foundry for compiling, testing, and deploying
