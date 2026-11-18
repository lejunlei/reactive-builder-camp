// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {AbstractReactive} from "@reactive/src/base/AbstractReactive.sol";

/// @notice Records qualifying transfers from one Ethereum Sepolia ERC-20.
contract SepoliaTransferMonitor is AbstractReactive {
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 private constant TRANSFER_TOPIC = uint256(keccak256("Transfer(address,address,uint256)"));

    address public immutable token;
    uint256 public immutable minimumAmount;
    uint256 public remaining;
    mapping(bytes32 eventId => bool) public processed;

    error InvalidConfiguration();

    event TransferObserved(bytes32 indexed eventId, address indexed sender, address indexed recipient, uint256 amount);

    constructor(address token_, uint256 minimumAmount_, uint256 limit_) payable {
        if (token_ == address(0) || minimumAmount_ == 0 || limit_ == 0 || msg.value == 0) {
            revert InvalidConfiguration();
        }
        token = token_;
        minimumAmount = minimumAmount_;
        remaining = limit_;
        SYSTEM.subscribe(SEPOLIA_CHAIN_ID, token_, TRANSFER_TOPIC, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
    }

    function react(LogRecord calldata record) external override onlySystem {
        if (
            remaining == 0 || record.opCode != 3 || record.chainId != SEPOLIA_CHAIN_ID
                || record.contractAddress != token || record.topic0 != TRANSFER_TOPIC || record.data.length != 32
        ) return;

        address sender = address(uint160(record.topic1));
        address recipient = address(uint160(record.topic2));
        uint256 amount = abi.decode(record.data, (uint256));
        if (sender == address(0) || recipient == address(0) || amount < minimumAmount) return;

        bytes32 eventId = keccak256(abi.encode(record.chainId, record.txHash, record.logIndex));
        if (processed[eventId]) return;

        processed[eventId] = true;
        emit TransferObserved(eventId, sender, recipient, amount);
        if (--remaining == 0) {
            SYSTEM.unsubscribe(
                SEPOLIA_CHAIN_ID, token, TRANSFER_TOPIC, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
            );
        }
    }
}
