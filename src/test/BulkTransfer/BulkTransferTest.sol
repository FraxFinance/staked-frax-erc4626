// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { BulkTransfer } from "../../contracts/BulkTransfer.sol";

contract BulkTransferTest is FraxTest {
    IERC20 public constant frxUSD = IERC20(0xFc00000000000000000000000000000000000001);
    BulkTransfer public bulkTransfer;

    // Keys for testing - each has a private key and address
    uint256 private constant PRIVATE_KEY_1 = 0x1234;
    uint256 private constant PRIVATE_KEY_2 = 0x5678;
    uint256 private constant PRIVATE_KEY_3 = 0x9abc;
    uint256 private constant PRIVATE_KEY_4 = 0xdef0;
    uint256 private constant PRIVATE_KEY_5 = 0x1111;
    uint256 private constant PRIVATE_KEY_6 = 0x2222;

    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public user5;
    address public user6;

    function setUp() public {
        vm.createSelectFork(vm.envString("FRAXTAL_RPC_URL"), 18_354_035);
        bulkTransfer = new BulkTransfer(frxUSD);

        // Create addresses from private keys
        user1 = vm.addr(PRIVATE_KEY_1);
        user2 = vm.addr(PRIVATE_KEY_2);
        user3 = vm.addr(PRIVATE_KEY_3);
        user4 = vm.addr(PRIVATE_KEY_4);
        user5 = vm.addr(PRIVATE_KEY_5);
        user6 = vm.addr(PRIVATE_KEY_6);
    }

    function test_BulkTransfer() public {
        deal(address(frxUSD), user1, 1000 ether);
        deal(address(frxUSD), user2, 1000 ether);
        deal(address(frxUSD), user3, 1000 ether);

        BulkTransfer.Transfer[] memory transfers = new BulkTransfer.Transfer[](4);
        transfers[0] = BulkTransfer.Transfer({
            from: user1,
            to: user4,
            amount: 100e18,
            deadline: uint32(block.timestamp + 1 days),
            nonce: 0
        });
        transfers[1] = BulkTransfer.Transfer({
            from: user2,
            to: user5,
            amount: 200e18,
            deadline: uint32(block.timestamp + 1 days),
            nonce: 0
        });
        transfers[2] = BulkTransfer.Transfer({
            from: user3,
            to: user6,
            amount: 150e18,
            deadline: uint32(block.timestamp + 1 days),
            nonce: 0
        });
        transfers[3] = BulkTransfer.Transfer({
            from: user3,
            to: user6,
            amount: 150e18,
            deadline: uint32(block.timestamp + 1 days),
            nonce: 1
        });

        bytes[] memory sigatures = new bytes[](4);
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY_1, bulkTransfer.getMessageHash(transfers[0]));
            (uint8 pv, bytes32 pr, bytes32 ps) = vm.sign(PRIVATE_KEY_1, getPermitHash(user1));
            sigatures[0] = abi.encodePacked(pr, ps, pv, r, s, v);
        }
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY_2, bulkTransfer.getMessageHash(transfers[1]));
            (uint8 pv, bytes32 pr, bytes32 ps) = vm.sign(PRIVATE_KEY_2, getPermitHash(user2));
            sigatures[1] = abi.encodePacked(pr, ps, pv, r, s, v);
        }
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY_3, bulkTransfer.getMessageHash(transfers[2]));
            (uint8 pv, bytes32 pr, bytes32 ps) = vm.sign(PRIVATE_KEY_3, getPermitHash(user3));
            sigatures[2] = abi.encodePacked(pr, ps, pv, r, s, v);
        }
        {
            (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(PRIVATE_KEY_3, bulkTransfer.getMessageHash(transfers[3]));
            sigatures[3] = abi.encodePacked(r3, s3, v3);
        }

        bulkTransfer.bulkTransfer(transfers, sigatures);

        assertEq(frxUSD.balanceOf(user1), 1000e18 - 100e18);
        assertEq(frxUSD.balanceOf(user2), 1000e18 - 200e18);
        assertEq(frxUSD.balanceOf(user3), 1000e18 - 300e18);
        assertEq(frxUSD.balanceOf(user4), 100e18);
        assertEq(frxUSD.balanceOf(user5), 200e18);
        assertEq(frxUSD.balanceOf(user6), 300e18);
    }

    function getPermitHash(address owner) public view returns (bytes32) {
        // Create the permit digest for the given owner
        bytes32 permitDigest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                IERC20Permit(address(frxUSD)).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner, // owner
                        address(bulkTransfer), // spender
                        type(uint256).max, // value
                        uint256(0), // nonce
                        uint32(block.timestamp + 1 days) // deadline
                    )
                )
            )
        );
        return permitDigest;
    }
}
