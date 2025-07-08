// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.21;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ===================== LinearRewardsQuasiErc4626 ====================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

import { ERC20, ERC4626 } from "solmate/mixins/ERC4626.sol";
import { SafeCastLib } from "solmate/utils/SafeCastLib.sol";
import { ln, mul, div, pow, exp, wrap } from "@prb/math/src/ud60x18/Math.sol";
import { convert } from "@prb/math/src/ud60x18/Conversions.sol";
import { UD60x18 } from "@prb/math/src/ud60x18/ValueType.sol";
import "forge-std/console2.sol";

/// @title LinearRewardsErc4626
/// @notice An ERC4626 Vault implementation with linear rewards
abstract contract LinearRewardsQuasiErc4626 is ERC4626 {
    using SafeCastLib for *;

    /// @notice The precision of all integer calculations
    uint256 public constant PRECISION = 1e18;

    /// @notice One year, in seconds
    uint256 public constant ONE_YEAR = 31_536_000;

    /// @notice The rewards cycle length in seconds
    uint256 public immutable DEPRECATED__REWARDS_CYCLE_LENGTH;

    /// @notice Precomputed year
    UD60x18 public immutable ONE_YEAR_UD60X18;

    /// @notice Information about the current rewards cycle
    struct RewardsCycleData {
        uint40 cycleEnd; // Timestamp of the end of the current rewards cycle
        uint40 lastSync; // Timestamp of the last time the rewards cycle was synced
        uint216 rewardCycleAmount; // Amount of rewards to be distributed in the current cycle
    }

    /// @notice The rewards cycle data, stored in a single word to save gas
    RewardsCycleData public DEPRECATED__rewardsCycleData;

    /// @notice The timestamp of the last time rewards were distributed
    uint256 public DEPRECATED__lastRewardsDistribution;

    /// @notice The total amount of assets that have been distributed and deposited
    uint256 public DEPRECATED__storedTotalAssets;

    /// @notice The precision of the underlying asset
    uint256 public immutable UNDERLYING_PRECISION;

    // ---------------------------------------------
    // DEPRECATED STORAGE SLOTS (for storage order preservation)
    // ---------------------------------------------
    /// @notice The pending timelock address
    address public DEPRECATED__pendingTimelockAddress;

    /// @notice The current timelock address
    address public DEPRECATED__timelockAddress;

    /// @notice The maximum amount of rewards that can be distributed per second per 1e18 asset
    uint256 public DEPRECATED__maxDistributionPerSecondPerAsset;

    uint256 private DEPRECATED__initializeStage;

    // ---------------------------------------------
    // NEW STATE VARIABLES
    // ---------------------------------------------

    /// @notice Last stored pricePerShare. Current rate is stored + (rate * pricePerShareIncPerSecond)
    uint256 public pricePerShareStored;

    /// @notice Manually set increase in pricePerShare, per second
    uint256 public pricePerShareIncPerSecond;

    /// @notice The last time the contract was synced
    uint256 public lastSync;

    // ---------------------------------------------
    // CONSTRUCTOR
    // ---------------------------------------------

    /// @param _underlying The erc20 asset deposited
    /// @param _name The name of the vault
    /// @param _symbol The symbol of the vault
    constructor(ERC20 _underlying, string memory _name, string memory _symbol) ERC4626(_underlying, _name, _symbol) {
        UNDERLYING_PRECISION = 10 ** _underlying.decimals();
        ONE_YEAR_UD60X18 = convert(ONE_YEAR);
    }

    // ---------------------------------------------
    // VIEW FUNCTIONS
    // ---------------------------------------------

    /// @notice Calculate pricePerShare increase per second needed for a given APY.
    /// @param _apyE18 APY in 1.%%E18 (e.g. 5% APY = input 1.05e18). Must be >= 1e18
    /// @return _newPPSIPS The needed pricePerShare increase, per second, in UNDERLYING_PRECISION
    function calcPPSIPSForGivenAPY(uint256 _apyE18) public view returns (uint256 _newPPSIPS) {
        if (_apyE18 < 1e18) revert InvalidAPY();
        // Old
        // UD60x18 _numerator = mul(ln(convert(_apyE18)), convert(1e18)) - mul(ln(convert(1e18)), convert(1e18));
        // UD60x18 _denominator = convert(ONE_YEAR);
        // _newPPSIPS = convert(div(_numerator, _denominator));
        // New
        UD60x18 _numerator = ln(wrap(_apyE18));
        UD60x18 _denominator = ONE_YEAR_UD60X18;
        _newPPSIPS = (div(_numerator, _denominator)).unwrap();
    }

    /// @notice Calculate the total assets as of a given time.
    /// @param _asOfTime The time at which to calculate. Must be now or in the future.
    /// @return _newTotalAssets Expected total assets at _asOfTime, in UNDERLYING_PRECISION
    function _previewTotalAssets(uint256 _asOfTime) internal view returns (uint256 _newTotalAssets) {
        _newTotalAssets = (_previewPricePerShare(_asOfTime) * totalSupply) / 1e18;
    }

    /// @notice Calculate current totalAssets as of now, accounting for elapsed time
    /// @return _newTotalAssets Total assets as of right now, in UNDERLYING_PRECISION
    function previewTotalAssets() public view returns (uint256 _newTotalAssets) {
        // Do the calculation
        return _previewTotalAssets(block.timestamp);
    }

    /// @notice Calculate current totalAssets as of now, accounting for elapsed time
    /// @return _newTotalAssets Total assets as of right now, in UNDERLYING_PRECISION
    function storedTotalAssets() public view returns (uint256 _newTotalAssets) {
        return previewTotalAssets();
    }

    /// @notice Calculate totalAssets at a future time
    /// @param _futureTime The future time at which to calculate
    /// @return _newTotalAssets Expected total assets at _futureTime, in UNDERLYING_PRECISION
    function previewTotalAssetsFuture(uint256 _futureTime) public view returns (uint256 _newTotalAssets) {
        // Do the calculation
        return _previewTotalAssets(_futureTime);
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
        // OLD: UD60x18 _exponentUD60_18 = div(
        //     convert(pricePerShareIncPerSecond * _elapsedTime),
        //     convert(UNDERLYING_PRECISION)
        // );
        // Get the UD60x18 exponent first and scale down by UNDERLYING_PRECISION
        // UD60x18 _exponentUD60_18 = convert(pricePerShareIncPerSecond * _elapsedTime);
        UD60x18 _exponentUD60_18 = div(
            convert(pricePerShareIncPerSecond * _elapsedTime),
            convert(UNDERLYING_PRECISION)
        );

        // console2.log("=============");
        // console2.log("pricePerShareIncPerSecond: ", pricePerShareIncPerSecond);
        // console2.log("_elapsedTime: ", _elapsedTime);
        // console2.log("convert(_exponentUD60_18): ", convert(_exponentUD60_18));
        // console2.log(
        //     "convert(_exponentUD60_18 * UNDERLYING_PRECISION): ",
        //     convert(mul(_exponentUD60_18, convert(UNDERLYING_PRECISION)))
        // );

        // Get the raw e^exponent in UD60x18
        UD60x18 _ePowUD60_18 = exp(_exponentUD60_18);

        // Old
        // {
        //     // Scale the UD60x18 up by UNDERLYING_PRECISION and convert to uint256
        //     uint256 _ePowU256 = convert(mul(_ePowUD60_18, convert(UNDERLYING_PRECISION)));

        //     // console2.log(
        //     //     "convert(_ePowUD60_18 * UNDERLYING_PRECISION): ",
        //     //     convert(mul(_ePowUD60_18, convert(UNDERLYING_PRECISION)))
        //     // );
        //     // console2.log("_ePowU256: ", _ePowU256);

        //     // Calculate _newPricePerShare
        //     _newPricePerShare = (pricePerShareStored * _ePowU256) / UNDERLYING_PRECISION;
        //     // console2.log("_newPricePerShare: ", _newPricePerShare);
        // }

        // New
        {
            _newPricePerShare = mul(wrap(pricePerShareStored), _ePowUD60_18).unwrap();
        }
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

    /// @notice Calculate pricePerShare and totalAssets at a given time
    /// @param _asOfTime The time at which to calculate. Must be now or in the future.
    /// @return _pricePerShare Expected pricePerShare at _asOfTime, in UNDERLYING_PRECISION
    /// @return _totalAssets Expected totalAssets at _asOfTime, in UNDERLYING_PRECISION
    function _previewPPSAndTotalAssets(
        uint256 _asOfTime
    ) internal view returns (uint256 _pricePerShare, uint256 _totalAssets) {
        _pricePerShare = _previewPricePerShare(_asOfTime);
        _totalAssets = _previewTotalAssets(_asOfTime);
    }

    /// @notice Calculate pricePerShare and totalAssets as of right now
    /// @return _pricePerShare Current pricePerShare, in UNDERLYING_PRECISION
    /// @return _totalAssets Current totalAssets, in UNDERLYING_PRECISION
    function previewPPSAndTotalAssets() public view returns (uint256 _pricePerShare, uint256 _totalAssets) {
        return _previewPPSAndTotalAssets(block.timestamp);
    }

    /// @notice The current price per share token, in asset tokens. Same as previewPricePerShare().
    /// @return _pricePerShare Current pricePerShare, in UNDERLYING_PRECISION
    function pricePerShare() external view returns (uint256 _pricePerShare) {
        return previewPricePerShare();
    }

    /// @notice The current totalAssets, accounting for any elapsed time since the last sync
    /// @dev This function simulates the rewards that will be distributed at the top of the block
    /// @return _totalAssets The total assets available in the vault
    function totalAssets() public view virtual override returns (uint256 _totalAssets) {
        _totalAssets = _previewTotalAssets(block.timestamp);
    }

    // ---------------------------------------------
    // WRITE FUNCTIONS
    // ---------------------------------------------

    /// @notice Update pricePerShareStored and storedTotalAssets
    /// @return _pricePerShare Current pricePerShare, in UNDERLYING_PRECISION
    function sync() public returns (uint256 _pricePerShare) {
        // Calculate the current values
        _pricePerShare = _previewPricePerShare(block.timestamp);

        // Update the state variables
        pricePerShareStored = _pricePerShare;
        lastSync = block.timestamp;
    }

    /// @notice DEPRECATED: The ```deposit``` function allows a user to mint shares by depositing underlying
    /// @param _assets The amount of underlying to deposit
    /// @param _receiver The address to send the shares to
    /// @return _shares The amount of shares minted
    function deposit(uint256 _assets, address _receiver) public override returns (uint256 _shares) {
        revert MintRedeemsDisabled();
    }

    /// @notice DEPRECATED: The ```mint``` function allows a user to mint a given number of shares
    /// @param _shares The amount of shares to mint
    /// @param _receiver The address to send the shares to
    /// @return _assets The amount of underlying deposited
    function mint(uint256 _shares, address _receiver) public override returns (uint256 _assets) {
        revert MintRedeemsDisabled();
    }

    /// @notice DEPRECATED: The ```withdraw``` function allows a user to withdraw a given amount of underlying
    /// @param _assets The amount of underlying to withdraw
    /// @param _receiver The address to send the underlying to
    /// @param _owner The address of the owner of the shares
    /// @return _shares The amount of shares burned
    function withdraw(uint256 _assets, address _receiver, address _owner) public override returns (uint256 _shares) {
        revert MintRedeemsDisabled();
    }

    /// @notice DEPRECATED: The ```redeem``` function allows a user to redeem their shares for underlying
    /// @param _shares The amount of shares to redeem
    /// @param _receiver The address to send the underlying to
    /// @param _owner The address of the owner of the shares
    /// @return _assets The amount of underlying redeemed
    function redeem(uint256 _shares, address _receiver, address _owner) public override returns (uint256 _assets) {
        revert MintRedeemsDisabled();
    }

    /// @notice DEPRECATED: The ```depositWithSignature``` function allows a user to use signed approvals to deposit
    /// @param _assets The amount of underlying to deposit
    /// @param _receiver The address to send the shares to
    /// @param _deadline The deadline for the signature
    /// @param _approveMax Whether or not to approve the maximum amount
    /// @param _v The v value of the signature
    /// @param _r The r value of the signature
    /// @param _s The s value of the signature
    /// @return _shares The amount of shares minted
    function depositWithSignature(
        uint256 _assets,
        address _receiver,
        uint256 _deadline,
        bool _approveMax,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (uint256 _shares) {
        revert MintRedeemsDisabled();
    }

    /*//////////////////////////////////////////////////////////////
    //////          ERC4626 ACCOUNTING LOGIC OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @notice DEPRECATED: Will always return 0.
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        return 0;
    }

    /// @notice DEPRECATED: Will always return 0.
    function previewMint(uint256 shares) public view override returns (uint256) {
        return 0;
    }

    /// @notice DEPRECATED: Will always return 0.
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        return 0;
    }

    /// @notice DEPRECATED: Will always return 0.
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        return 0;
    }

    /*//////////////////////////////////////////////////////////////
    //////    ERC4626 DEPOSIT/WITHDRAWAL LIMIT LOGIC OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @notice DEPRECATED: Will always return 0.
    function maxDeposit(address) public view override returns (uint256) {
        return 0;
    }

    /// @notice DEPRECATED: Will always return 0.
    function maxMint(address) public view override returns (uint256) {
        return 0;
    }

    /// @notice DEPRECATED: Will always return 0.
    function maxWithdraw(address owner) public view override returns (uint256) {
        return 0;
    }

    /// @notice DEPRECATED: Will always return 0.
    function maxRedeem(address owner) public view override returns (uint256) {
        return 0;
    }

    //==============================================================================
    // Errors
    //==============================================================================

    /// @notice When the provided APY is invalid
    error InvalidAPY();

    /// @notice When a user attempts to Mint/Redeem
    error MintRedeemsDisabled();

    //==============================================================================
    // Events
    //==============================================================================
}
