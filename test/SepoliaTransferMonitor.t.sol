// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {IReactive} from "@reactive/src/interfaces/IReactive.sol";
import {CampTestToken} from "../src/CampTestToken.sol";
import {SepoliaTransferMonitor} from "../src/SepoliaTransferMonitor.sol";

interface Vm {
    function deal(address account, uint256 balance) external;
    function etch(address account, bytes calldata code) external;
    function prank(address sender) external;
}

contract MockSystem {
    uint256 public subscriptionCount;
    uint256 public unsubscriptionCount;

    function subscribe(uint256, address, uint256, uint256, uint256, uint256) external {
        ++subscriptionCount;
    }

    function unsubscribe(uint256, address, uint256, uint256, uint256, uint256) external {
        ++unsubscriptionCount;
    }
}

contract SepoliaTransferMonitorTest {
    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private constant SYSTEM = 0x8888888888888888888888888888888888888888;
    address private constant RECIPIENT = address(0x1234);

    function testAcceptsQualifyingTransfersOnceAndUnsubscribesAtLimit() external {
        VM.etch(SYSTEM, address(new MockSystem()).code);
        VM.deal(address(this), 1 ether);
        CampTestToken token = new CampTestToken();
        SepoliaTransferMonitor monitor = new SepoliaTransferMonitor{value: 0.1 ether}(address(token), 1 ether, 2);
        require(MockSystem(SYSTEM).subscriptionCount() == 1, "missing subscription");

        IReactive.LogRecord memory record;
        record.chainId = 11155111;
        record.contractAddress = address(token);
        record.topic0 = uint256(keccak256("Transfer(address,address,uint256)"));
        record.topic1 = uint256(uint160(address(this)));
        record.topic2 = uint256(uint160(RECIPIENT));
        record.opCode = 3;
        record.txHash = 1;
        record.data = abi.encode(0.5 ether);

        VM.prank(SYSTEM);
        monitor.react(record);
        require(monitor.remaining() == 2, "small transfer counted");

        record.data = abi.encode(1 ether);
        (bool accepted,) = address(monitor).call(abi.encodeCall(IReactive.react, (record)));
        require(!accepted, "accepted non-system caller");

        require(token.transfer(RECIPIENT, 1 ether), "transfer failed");
        require(token.balanceOf(RECIPIENT) == 1 ether, "wrong recipient balance");
        VM.prank(SYSTEM);
        monitor.react(record);
        require(monitor.remaining() == 1, "threshold transfer missing");
        require(
            monitor.processed(keccak256(abi.encode(record.chainId, record.txHash, record.logIndex))), "event missing"
        );

        VM.prank(SYSTEM);
        monitor.react(record);
        require(monitor.remaining() == 1, "duplicate counted");

        record.logIndex = 1;
        VM.prank(SYSTEM);
        monitor.react(record);
        require(monitor.remaining() == 0, "limit not reached");
        require(MockSystem(SYSTEM).unsubscriptionCount() == 1, "missing unsubscribe");
    }
}
