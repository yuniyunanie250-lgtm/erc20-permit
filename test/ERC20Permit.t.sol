// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20Permit} from "../src/ERC20Permit.sol";

contract ERC20PermitTest is Test {
    ERC20Permit internal token;
    uint256 internal ownerKey = 0xA11CE;
    address internal owner;
    address internal spender = address(0xB0B);

    bytes32 internal constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    function setUp() public {
        owner = vm.addr(ownerKey);
        token = new ERC20Permit("Permit Token", "PMT", 18);
        token.mint(owner, 1_000e18);
    }

    function _sign(uint256 value, uint256 deadline) internal view returns (uint8, bytes32, bytes32) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, token.nonces(owner), deadline))
            )
        );
        return vm.sign(ownerKey, digest);
    }

    function test_PermitSetsAllowance() public {
        (uint8 v, bytes32 r, bytes32 s) = _sign(500e18, block.timestamp + 1 hours);
        token.permit(owner, spender, 500e18, block.timestamp + 1 hours, v, r, s);
        assertEq(token.allowance(owner, spender), 500e18);
        assertEq(token.nonces(owner), 1);
    }

    function test_PermitThenTransferFromSpendsIt() public {
        (uint8 v, bytes32 r, bytes32 s) = _sign(100e18, block.timestamp + 1 hours);
        token.permit(owner, spender, 100e18, block.timestamp + 1 hours, v, r, s);
        vm.prank(spender);
        token.transferFrom(owner, spender, 100e18);
        assertEq(token.balanceOf(spender), 100e18);
        assertEq(token.allowance(owner, spender), 0);
    }

    function test_ExpiredPermitReverts() public {
        (uint8 v, bytes32 r, bytes32 s) = _sign(1e18, block.timestamp + 1);
        vm.warp(block.timestamp + 2);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Permit.PermitExpired.selector, block.timestamp - 1, block.timestamp)
        );
        token.permit(owner, spender, 1e18, block.timestamp - 1, v, r, s);
    }

    function test_ReplayOfTheSameSignatureReverts() public {
        (uint8 v, bytes32 r, bytes32 s) = _sign(10e18, block.timestamp + 1 hours);
        token.permit(owner, spender, 10e18, block.timestamp + 1 hours, v, r, s);
        vm.expectRevert(ERC20Permit.InvalidSignature.selector);
        token.permit(owner, spender, 10e18, block.timestamp + 1 hours, v, r, s);
    }

    function test_WrongSignerReverts() public {
        uint256 otherKey = 0xBAD;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, 1e18, token.nonces(owner), type(uint256).max))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(otherKey, digest);
        vm.expectRevert(ERC20Permit.InvalidSignature.selector);
        token.permit(owner, spender, 1e18, type(uint256).max, v, r, s);
    }

    function test_DomainSeparatorBindsChainAndAddress() public {
        assertTrue(token.DOMAIN_SEPARATOR() != bytes32(0));
        assertEq(
            token.DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    token.DOMAIN_TYPEHASH(),
                    keccak256(bytes("Permit Token")),
                    keccak256(bytes("1")),
                    block.chainid,
                    address(token)
                )
            )
        );
    }
}
