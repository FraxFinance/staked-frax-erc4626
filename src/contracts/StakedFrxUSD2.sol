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
// ========================== StakedFrxUSD2 ===========================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance
// Tested for 18-decimal underlying assets only

import { Timelock2Step } from "frax-std/access-control/v2/Timelock2Step.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IfrxUSD } from "src/contracts/interfaces/IfrxUSD.sol";
import { SafeCastLib } from "solmate/utils/SafeCastLib.sol";
import { LinearRewardsQuasiErc4626, ERC20 } from "./LinearRewardsQuasiErc4626.sol";

/// @title Staked frxUSD
/// @notice A ERC4626-like Vault implementation with linear rewards, rewards can be capped
contract StakedFrxUSD2 is LinearRewardsQuasiErc4626, Timelock2Step {
    using SafeCastLib for *;

    /// @notice Used for initialization
    bool private _initialized;

    /// @notice Array of minters
    address[] public minters_array;

    /// @notice Mapping of the minters
    /// @dev Mapping is used for faster verification
    mapping(address => bool) public minters;

    /// @param _underlying The erc20 asset deposited
    /// @param _name The name of the vault
    /// @param _symbol The symbol of the vault
    /// @param _timelockAddress The address of the timelock/owner contract
    constructor(
        IERC20 _underlying,
        string memory _name,
        string memory _symbol,
        address _timelockAddress
    ) LinearRewardsQuasiErc4626(ERC20(address(_underlying)), _name, _symbol) Timelock2Step(_timelockAddress) {
        _initialized = true;
    }

    error AlreadyInitialized();

    /// @param _name The name of the vault
    /// @param _symbol The symbol of the vault
    /// @param _timelockAddress The address of the timelock/owner contract
    /// @param _ppsInfo [0] Initial PricePerShare [1] PricePerShare increase per sec
    function initialize(
        string memory _name,
        string memory _symbol,
        address _timelockAddress,
        uint256[2] memory _ppsInfo
    ) external {
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;
        name = _name;
        symbol = _symbol;
        timelockAddress = _timelockAddress;

        // Burn all the frxUSD currently in this contract
        IfrxUSD(address(asset)).burn(asset.balanceOf(address(this)));

        // Set PricePerShare info initially
        pricePerShareStored = _ppsInfo[0];
        pricePerShareIncPerSecond = _ppsInfo[1];

        // Set lastSync to now
        lastSync = block.timestamp;
    }

    /* ========== MODIFIERS ========== */

    /// @notice A modifier that only allows a minters to call
    modifier onlyMinters() {
        if (!minters[msg.sender]) revert OnlyMinters();
        _;
    }

    /* ========== UNRESTRICTED FUNCTIONS========== */

    /// @notice Burn tokens. You do NOT receive any underlying assets when doing so
    /// @param _amount Amount of tokens to burn
    function burn(uint256 _amount) public {
        // Do the burn
        super._burn(msg.sender, _amount);

        emit Burn(msg.sender, _amount);
    }

    /* ========== RESTRICTED FUNCTIONS [MINTERS] ========== */

    /// @notice Used by minters to burn tokens
    /// @param b_address Address of the account to burn from
    /// @param b_amount Amount of tokens to burn
    function minter_burn_from(address b_address, uint256 b_amount) public onlyMinters {
        super._burn(b_address, b_amount);
        emit TokenMinterBurned(b_address, msg.sender, b_amount);
    }

    /// @notice Used by minters to mint new tokens
    /// @param m_address Address of the account to mint to
    /// @param m_amount Amount of tokens to mint
    function minter_mint(address m_address, uint256 m_amount) public onlyMinters {
        super._mint(m_address, m_amount);
        emit TokenMinterMinted(msg.sender, m_address, m_amount);
    }

    /* ========== RESTRICTED FUNCTIONS [OWNER] ========== */
    /// @notice Adds a minter
    /// @param minter_address Address of minter to add
    function addMinter(address minter_address) public {
        _requireSenderIsTimelock();
        require(minter_address != address(0), "Zero address detected");

        require(minters[minter_address] == false, "Address already exists");
        minters[minter_address] = true;
        minters_array.push(minter_address);

        emit MinterAdded(minter_address);
    }

    /// @notice Removes a non-bridge minter
    /// @param minter_address Address of minter to remove
    function removeMinter(address minter_address) public {
        _requireSenderIsTimelock();
        require(minter_address != address(0), "Zero address detected");
        require(minters[minter_address] == true, "Address nonexistant");

        // Delete from the mapping
        delete minters[minter_address];

        // 'Delete' from the array by setting the address to 0x0
        for (uint256 i = 0; i < minters_array.length; i++) {
            if (minters_array[i] == minter_address) {
                minters_array[i] = address(0); // This will leave a null in the array and keep the indices the same
                break;
            }
        }

        emit MinterRemoved(minter_address);
    }

    /// @notice Set pricePerShareStored, pricePerShareIncPerSecond, and lastSync in one call
    /// @param _newPricePerShareStored New stored price per share, in E18 asset tokens
    /// @param _newPricePerShareIncPerSecond New stored price per share increase per second, in E18 asset tokens
    /// @param _newLastSync New lastSync
    /// @dev p(t) = p0*e^(r(t-t0))
    function setAllPricingParams(
        uint256 _newPricePerShareStored,
        uint256 _newPricePerShareIncPerSecond,
        uint256 _newLastSync
    ) external {
        _requireSenderIsTimelock();

        // Make sure lastSync is not in the future
        if (_newLastSync > block.timestamp) revert MustNotBeInTheFuture();

        // Set the 3 parameters
        pricePerShareStored = _newPricePerShareStored;
        pricePerShareIncPerSecond = _newPricePerShareIncPerSecond;
        lastSync = _newLastSync;

        emit SetPricePerShareStored(_newPricePerShareStored);
        emit SetPricePerShareIncPerSecond(_newPricePerShareIncPerSecond);
        emit SetLastSync(_newLastSync);
    }

    /// @notice Set pricePerShare increase rate, per second (pricePerShareIncPerSecond). Also sets lastSync to now and pricePerShareStored to the current pricePerShare
    /// @param _newPricePerShareIncPerSecond New stored price per share increase per second, in E18 asset tokens
    function setPricePerShareIncPerSecond(uint256 _newPricePerShareIncPerSecond) external {
        _requireSenderIsTimelock();

        // Sync first
        sync();

        // Set pricePerShareIncPerSecond
        pricePerShareIncPerSecond = _newPricePerShareIncPerSecond;

        emit SetPricePerShareIncPerSecond(_newPricePerShareIncPerSecond);
    }

    /// @notice Set pricePerShareStored
    /// @param _newPricePerShareStored New stored price per share, in E18 asset tokens
    function setPricePerShareStored(uint256 _newPricePerShareStored) external {
        _requireSenderIsTimelock();

        // Set lastSync to now
        lastSync = block.timestamp;

        // Set pricePerShareStored
        pricePerShareStored = _newPricePerShareStored;

        emit SetPricePerShareStored(_newPricePerShareStored);
    }

    //==============================================================================
    // Errors
    //==============================================================================

    /// @notice When lastSync is trying to be set to a future date
    error MustNotBeInTheFuture();

    /// @notice When a non-minter tries to call a restricted function
    error OnlyMinters();

    //==============================================================================
    // Events
    //==============================================================================

    /// @notice Emitted when a burn happens
    /// @param from The address whose tokens were burned
    /// @param amount Amount of tokens burned
    event Burn(address indexed from, uint256 amount);

    /// @notice Emitted when a mint happens
    /// @param to Recipient of the newly-minted tokens
    /// @param amount Amount of tokens minted
    event Mint(address indexed to, uint256 amount);

    /// @notice Emitted when a non-bridge minter is added
    /// @param minter_address Address of the new minter
    event MinterAdded(address minter_address);

    /// @notice Emitted when a non-bridge minter is removed
    /// @param minter_address Address of the removed minter
    event MinterRemoved(address minter_address);

    /// @notice When setLastSync is called
    /// @param newLastSync New lastSync
    event SetLastSync(uint256 newLastSync);

    /// @notice When setPricePerShareIncPerSecond is called
    /// @param newPricePerShareIncPerSecond New stored price per share increase per second, in E18 asset tokens
    event SetPricePerShareIncPerSecond(uint256 newPricePerShareIncPerSecond);

    /// @notice When setPricePerShareStored is called
    /// @param newPricePerShareStored New stored price per share, in E18 asset tokens
    event SetPricePerShareStored(uint256 newPricePerShareStored);

    /// @notice Emitted when a non-bridge minter burns tokens
    /// @param from The account whose tokens are burned
    /// @param to The minter doing the burning
    /// @param amount Amount of tokens burned
    event TokenMinterBurned(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when a non-bridge minter mints tokens
    /// @param from The minter doing the minting
    /// @param to The account that gets the newly minted tokens
    /// @param amount Amount of tokens minted
    event TokenMinterMinted(address indexed from, address indexed to, uint256 amount);
}
