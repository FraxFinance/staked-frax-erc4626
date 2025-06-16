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
// ========================= BulkTransfer =============================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract BulkTransfer is Ownable2Step {
    // #### State Variables ####
    // @notice The token being transferred
    IERC20 public immutable token;

    // @notice The operator address that can call the bulkTransfer function
    address public operator;

    // @notice Mapping of nonces for each address to prevent replay attacks
    mapping(address => uint64) public nonces;

    // EIP-712 Domain
    // @notice The name of the domain, used for EIP-712 signing
    string public DOMAIN_NAME;

    // @notice The version of the domain, used for EIP-712 signing
    string public constant DOMAIN_VERSION = "1";

    // @notice The domain separator, used for EIP-712 signing
    bytes32 public immutable DOMAIN_SEPARATOR;

    // EIP-712 Type hashes
    // @notice The type hash for the EIP-712 domain, used for EIP-712 signing
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    // @notice The type hash for the transfer struct, used for EIP-712 signing
    // keccak256("Transfer(address from,address to,address token,uint256 amount,uint32 deadline,uint64 nonce)")
    bytes32 private constant TRANSFER_TYPEHASH = 0x732a7efcbc89ef5b114051e56e17473392a6868a68abe9d399a0ee488f76e402;

    // #### Events ####
    /// @notice Emitted when a transfer is executed successfully
    event TransferExecuted(address indexed from, address indexed to, uint256 amount, uint64 nonce);

    /// @notice Emitted when a transfer fails
    event TransferFailed(address indexed from, address indexed to, uint256 amount, uint64 nonce);

    /// @notice Emitted when the operator address is changed
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // #### Errors ####
    /// @notice Error thrown when the caller is not the operator
    /// @param caller The address of the caller
    error Forbidden(address caller);

    /// @notice Error thrown when the length of transfers and signatures do not match
    /// @param transfersLength The length of the transfers array
    /// @param signaturesLength The length of the signatures array
    error LengthMismatch(uint256 transfersLength, uint256 signaturesLength);

    /// @notice Error thrown when the signature for a transfer is invalid
    /// @param signer The address of the signer
    error InvalidSignature(address signer, address expectedSigner, bytes32 messageHash);

    // #### Structs ####
    /// @notice Struct representing a transfer
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to transfer
    /// @param deadline The deadline for the transfer
    /// @param nonce The nonce for the transfer
    struct Transfer {
        address from;
        address to;
        uint256 amount;
        uint32 deadline;
        uint64 nonce;
    }

    // #### Constructor ####
    /// @notice Constructor for the BulkTransfer contract
    /// @param _token The address of the token being transferred
    constructor(IERC20 _token) Ownable(msg.sender) {
        token = _token;
        operator = msg.sender;

        // Get token name if it's an ERC20 with name() function
        string memory tokenName;
        try IERC20Metadata(address(_token)).name() returns (string memory name) {
            tokenName = name;
        } catch {
            tokenName = "Unknown";
        }

        // Construct domain name with token name
        DOMAIN_NAME = string(abi.encodePacked("Frax BulkTransfer: ", tokenName));

        // Compute the EIP-712 domain separator
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(DOMAIN_NAME)),
                keccak256(bytes(DOMAIN_VERSION)),
                block.chainid,
                address(this)
            )
        );
    }

    // #### Functions ####
    /// @notice Function to perform bulk transfers of tokens
    /// @param _transfers An array of Transfer structs representing the transfers to be executed
    /// @param _signatures An array of signatures corresponding to each transfer, can contain both a permit signature and a transfer signature
    /// @dev The function can only be called by the operator address
    /// @dev Only unlimited permit signatures are allowed, as the contract will call permit with type(uint256).max
    function bulkTransfer(Transfer[] calldata _transfers, bytes[] calldata _signatures) external {
        if (msg.sender != operator) revert Forbidden(msg.sender);
        if (_transfers.length != _signatures.length) revert LengthMismatch(_transfers.length, _signatures.length);

        for (uint256 i = 0; i < _transfers.length; ++i) {
            Transfer calldata transfer = _transfers[i];
            if (transfer.deadline >= block.timestamp && transfer.nonce == nonces[transfer.from]) {
                // Verify signature
                bytes32 digest = getMessageHash(transfer);
                bytes calldata _signature = _signatures[i];
                if (_signature.length == 130) {
                    // extract permit signature and call permit function
                    bytes memory permitSignature = _signature[0:65];
                    bytes32 r;
                    bytes32 s;
                    uint8 v;
                    // ecrecover takes the signature parameters, and the only way to get them
                    // currently is to use assembly.
                    assembly ("memory-safe") {
                        r := mload(add(permitSignature, 0x20))
                        s := mload(add(permitSignature, 0x40))
                        v := byte(0, mload(add(permitSignature, 0x60)))
                    }
                    try
                        IERC20Permit(address(token)).permit(
                            transfer.from,
                            address(this),
                            type(uint256).max,
                            transfer.deadline,
                            v,
                            r,
                            s
                        )
                    {} catch {
                        // permit failed, let's continue with the transfer
                    }
                    _signature = _signature[65:130];
                }
                address signer = ECDSA.recover(digest, _signature);
                if (signer != transfer.from) revert InvalidSignature(signer, transfer.from, digest);

                // Transfer the tokens
                try token.transferFrom(transfer.from, transfer.to, transfer.amount) {
                    // Emit an event for the transfer
                    emit TransferExecuted(transfer.from, transfer.to, transfer.amount, transfer.nonce);
                    // Increment nonce for the next use
                    nonces[transfer.from]++;
                } catch {
                    // transfer failed, let's continue with the next transfer
                    emit TransferFailed(transfer.from, transfer.to, transfer.amount, transfer.nonce);
                }
            } else {
                // The deadline has passed, or wrong nonce
                emit TransferFailed(transfer.from, transfer.to, transfer.amount, transfer.nonce);
            }
        }
    }

    // #### View functions ####
    /// @notice Function to get the current nonce for a user
    /// @param user The address of the user
    /// @return The current nonce for the user
    function getNonce(address user) external view returns (uint64) {
        return nonces[user];
    }

    /// @notice function to get the EIP-712 message hash for a transfer
    /// @param transfer The transfer struct to hash
    function getMessageHash(Transfer calldata transfer) public view returns (bytes32) {
        // Create the struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                TRANSFER_TYPEHASH,
                transfer.from,
                transfer.to,
                token,
                transfer.amount,
                transfer.deadline,
                transfer.nonce
            )
        );

        // Create the digest
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        return digest;
    }

    // #### Admin Functions ####
    /// @notice Function to set the operator address
    /// @param _operator The new operator address
    /// @dev Only the owner of the contract can call this function
    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
        emit OperatorChanged(operator, _operator);
    }

    /// @notice Function to recover ERC20 tokens sent to the contract
    /// @param _token The address of the token to recover
    /// @param _to The address to send the recovered tokens to
    /// @param _amount The amount of tokens to recover
    /// @dev Only the owner of the contract can call this function
    function recoverERC20(IERC20 _token, address _to, uint256 _amount) external onlyOwner {
        _token.transfer(_to, _amount);
    }
}
