// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ========================= OracleAllowlist ==========================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

// ====================================================================

abstract contract OracleAllowlist {
    /// @notice mapping from address to boolean to indicate whether an address
    ///         is to be allowed to push
    mapping(address => bool) public isAllowed;

    /// @notice virtual function to be overriden in child allows for the list to
    ///         to be modified
    function setAllowed(address, bool) public virtual;

    /// @notice Internal function to set the allowlist
    /// @param sender The address of the wallet who's status will be changed
    /// @param status The boolean indicating status: true -> allowed | false -> not
    function _setAllowed(address sender, bool status) internal virtual {
        isAllowed[sender] = status;
        emit AllowListUpdatated(sender, status);
    }

    /// @notice modifer to be used on external functions in child
    modifier onlyAllowed() {
        if (!isAllowed[msg.sender]) revert NotAllowed();
        _;
    }

    /// Errors
    error NotAllowed();

    /// Events
    event AllowListUpdatated(address sender, bool isAllowed);
}
