// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// =================== sfrxUsd2OracleImplementation ===================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

import { StakedFrxUSD2, IERC20 } from "src/contracts/StakedFrxUSD2.sol";
import { ln, mul, div, pow, exp, wrap } from "@prb/math/src/ud60x18/Math.sol";
import { convert } from "@prb/math/src/ud60x18/Conversions.sol";
import { UD60x18 } from "@prb/math/src/ud60x18/ValueType.sol";
import { OracleAllowlist } from "src/contracts/misc/OracleAllowlist.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { GapFirst11 } from "src/contracts/misc/StorageGap.sol";

contract SfrxUsd2OracleImplementation is GapFirst11, OracleAllowlist, Ownable2Step {
    /// @notice Slot bumping handled in `GapFirst11` contract

    struct RewardsCycleData {
        uint40 cycleEnd; // Timestamp of the end of the current rewards cycle
        uint40 lastSync; // Timestamp of the last time the rewards cycle was synced
        uint216 rewardCycleAmount; // Amount of rewards to be distributed in the current cycle
    }

    /// @notice Variables needed for price evolution
    uint256 public pricePerShareStored;
    uint256 public pricePerShareIncPerSecond;
    uint256 public lastSync;
    uint256 public constant UNDERLYING_PRECISION = 1e18;
    bool public wasInitialized;

    constructor(address initialOwner) Ownable(initialOwner) {
        _setAllowed(initialOwner, true);
        wasInitialized = true;
    }

    /// @notice The ```initialize``` function set the ownable2step owner w/n a proxy context
    /// @param owner The owner of the contract
    /// @dev Only callable when not initialized
    function initialize(
        address owner,
        uint256 _newPricePerShareStored,
        uint256 _newPricePerShareIncPerSecond,
        uint256 _newLastSync
    ) external {
        if (wasInitialized) revert AlreadyInit();
        _transferOwnership(owner);
        _setAllowed(owner, true);
        _setAllowed(msg.sender, true);
        wasInitialized = true;
        setAllPricingParams(_newPricePerShareStored, _newPricePerShareIncPerSecond, _newLastSync);
        _setAllowed(msg.sender, false);
    }

    /* ========== Core ========== */

    /// @dev Adheres to chainlink's AggregatorV3Interface
    /// @return _roundId The l1Block corresponding to the last time the oracle was proofed
    /// @return _answer The price of SfrxUSD in frxUSD
    /// @return _startedAt The current timestamp
    /// @return _updatedAt The current timestamp
    /// @return _answeredInRound The l1Block corresponding to the last time the oracle was proofed
    function latestRoundData()
        external
        view
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        _answeredInRound = _roundId = uint80(block.number);
        /// @notice if rewards cycle data is stale treat, return a stale oracle response
        _startedAt = _updatedAt = block.timestamp;
        _answer = int256(previewPricePerShare());
        if (_answer < 0) revert CastError();
        if (_roundId < 0) revert CastError();
    }

    /// @dev Adheres to chainlink's AggregatorV3Interface
    /// @return The decimals intended to be used via this oracle
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /// @notice Calculate current pricePerShare as of now, accounting for any elapsed time since the last sync. Same as pricePerShare().
    /// @return _newPricePerShare Current pricePerShare, in UNDERLYING_PRECISION
    function previewPricePerShare() public view returns (uint256 _newPricePerShare) {
        // Do the calculation
        return _previewPricePerShare(block.timestamp);
    }

    /// @notice Calculate pricePerShare at a future time
    /// @param _futureTime The future time at which to calculate
    /// @return _newPricePerShare Expected pricePerShare at _asOfTime, in UNDERLYING_PRECISION
    function previewPricePerShareFuture(uint256 _futureTime) public view returns (uint256 _newPricePerShare) {
        // Do the calculation
        return _previewPricePerShare(_futureTime);
    }

    /// @notice The current price per share token, in asset tokens. Same as previewPricePerShare().
    /// @return _pricePerShare Current pricePerShare, in UNDERLYING_PRECISION
    function pricePerShare() external view returns (uint256 _pricePerShare) {
        return previewPricePerShare();
    }

    /// @notice Calculate current pricePerShare as of the given time, accounting for any elapsed time since the last sync.
    /// @param _asOfTime The time at which to calculate. Must be now or in the future
    /// @return _newPricePerShare Expected pricePerShare at _asOfTime, in UNDERLYING_PRECISION
    function _previewPricePerShare(uint256 _asOfTime) internal view returns (uint256 _newPricePerShare) {
        // CHECK THIS MATH!!!
        // CHECK THIS MATH!!!
        // CHECK THIS MATH!!!
        // CHECK THIS MATH!!!
        // CHECK THIS MATH!!!
        // CHECK THIS MATH!!!

        // Calculate the elapsed time
        uint256 _elapsedTime = _asOfTime - lastSync;

        // Continuously compounding interest. Done here instead of in _previewTotalAssets
        // p(t) = p₀ * e^((dr)*t)
        // Also might be able to use e^(xy) = (e^x)^y (to avoid overflows)
        // ---------------------------------------
        // Calculate e^x and convert back to uint256

        // Get the UD60x18 exponent first and scale down by UNDERLYING_PRECISION
        // UD60x18 _exponentUD608 = div(convert(pricePerShareIncPerSecond * _elapsedTime), convert(UNDERLYING_PRECISION));
        UD60x18 _exponentUD608 = wrap(pricePerShareIncPerSecond * _elapsedTime);
        // console2.log("=============");
        // console2.log("pricePerShareIncPerSecond: ", pricePerShareIncPerSecond);
        // console2.log("_elapsedTime: ", _elapsedTime);
        // console2.log("convert(_exponentUD608): ", convert(_exponentUD608));
        // console2.log(
        //     "convert(_exponentUD608 * UNDERLYING_PRECISION): ",
        //     convert(mul(_exponentUD608, convert(UNDERLYING_PRECISION)))
        // );

        // Get the raw e^exponent in UD60x18
        UD60x18 _ePowUD608 = exp(_exponentUD608);

        // Old
        // {
        //     // Scale the UD60x18 up by UNDERLYING_PRECISION and convert to uint256
        //     uint256 _ePowU256 = convert(mul(_ePowUD608, convert(UNDERLYING_PRECISION)));

        //     // console2.log(
        //     //     "convert(_ePowUD608 * UNDERLYING_PRECISION): ",
        //     //     convert(mul(_ePowUD608, convert(UNDERLYING_PRECISION)))
        //     // );
        //     // console2.log("_ePowU256: ", _ePowU256);

        //     // Calculate _newPricePerShare
        //     _newPricePerShare = (pricePerShareStored * _ePowU256) / UNDERLYING_PRECISION;
        //     // console2.log("_newPricePerShare: ", _newPricePerShare);
        // }

        // New
        {
            _newPricePerShare = mul(wrap(pricePerShareStored), _ePowUD608).unwrap();
        }
    }

    /* ========== Admin Gated Setters ========== */

    /// @notice The ```setAllowed``` function allows for the timelock to set the status of addresses
    ///         if allowed, an address is able to submit a proof
    /// @param _sender The msg.sender to allow
    /// @param _status The status of the msg.sender | false -> not allowed, true -> allowed
    /// @dev Requires the caller to be the timelock address
    function setAllowed(address _sender, bool _status) public override onlyOwner {
        _setAllowed(_sender, _status);
    }

    /// @notice Set pricePerShareStored, pricePerShareIncPerSecond, and lastSync in one call
    /// @param _newPricePerShareStored New stored price per share, in E18 asset tokens
    /// @param _newPricePerShareIncPerSecond New stored price per share increase per second, in E18 asset tokens
    /// @param _newLastSync New lastSync, must not be gt `block.timestamp`
    /// @dev p(t) = p0*e^(r(t-t0))
    function setAllPricingParams(
        uint256 _newPricePerShareStored,
        uint256 _newPricePerShareIncPerSecond,
        uint256 _newLastSync
    ) public onlyAllowed {
        if (_newLastSync > block.timestamp) revert LastSyncMustNotBeInTheFuture();
        pricePerShareStored = _newPricePerShareStored;
        pricePerShareIncPerSecond = _newPricePerShareIncPerSecond;
        lastSync = _newLastSync;

        emit SetPricePerShareStored(_newPricePerShareStored);
        emit SetPricePerShareIncPerSecond(_newPricePerShareIncPerSecond);
        emit SetLastSync(_newLastSync);
    }

    /// @notice Set pricePerShare increase rate, per second (pricePerShareIncPerSecond). Also sets lastSync to now and pricePerShareStored to the current pricePerShare
    /// @param _newPricePerShareIncPerSecond New stored price per share increase per second, in E18 asset tokens
    function setPricePerShareIncPerSecond(uint256 _newPricePerShareIncPerSecond) external onlyAllowed {
        pricePerShareStored = _previewPricePerShare(block.timestamp);
        lastSync = block.timestamp;
        pricePerShareIncPerSecond = _newPricePerShareIncPerSecond;
        emit SetPricePerShareIncPerSecond(_newPricePerShareIncPerSecond);
    }

    /// @notice Set pricePerShareStored
    /// @param _newPricePerShareStored New stored price per share, in E18 asset tokens
    function setPricePerShareStored(uint256 _newPricePerShareStored) public onlyAllowed {
        lastSync = block.timestamp;
        pricePerShareStored = _newPricePerShareStored;
        emit SetPricePerShareStored(_newPricePerShareStored);
    }

    function rewardsCycleData() external view returns (RewardsCycleData memory) {
        // Return the rewards cycle data as the max possible rate, rate is curbed by maxDistributionPerSecondPerAsset
        return
            RewardsCycleData({
                cycleEnd: uint40(604_800 + block.timestamp),
                lastSync: uint40(block.timestamp),
                rewardCycleAmount: uint216(type(uint216).max / 1e18) // max value
            });
    }

    function maxDistributionPerSecondPerAsset() external view returns (uint256) {
        return pricePerShareIncPerSecond;
    }

    function storedTotalAssets() external view returns (uint256) {
        return previewPricePerShare();
    }

    function totalAssets() external view returns (uint256) {
        return previewPricePerShare();
    }

    function totalSupply() external pure returns (uint256) {
        return 1e18;
    }

    function lastRewardsDistribution() external view returns (uint256) {
        return block.timestamp;
    }

    /* ========== Events ========== */

    /// @notice When setPricePerShareStored is called
    /// @param newPricePerShareStored New stored price per share, in E18 asset tokens
    event SetPricePerShareStored(uint256 newPricePerShareStored);

    /// @notice When setPricePerShareIncPerSecond is called
    /// @param newPricePerShareIncPerSecond New stored price per share increase per second, in E18 asset tokens
    event SetPricePerShareIncPerSecond(uint256 newPricePerShareIncPerSecond);

    /// @notice When setLastSync is called
    /// @param newLastSync New lastSync
    event SetLastSync(uint256 newLastSync);

    /* ========== Errors ========== */

    /// @notice If the contract was already initialized
    error AlreadyInit();

    /// @notice If latestRoundData casting is problematic
    error CastError();

    /// @notice If the supplied lastSync time is in the future
    error LastSyncMustNotBeInTheFuture();
}
