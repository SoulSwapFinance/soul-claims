// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./libs/MerkleProof.sol";
import "./interfaces/ISoulDistributor.sol";

contract SoulDistributor is ISoulDistributor, Ownable {

    // SOUL TOKEN && (VERIFIABLE) MERKLE ROOT
    IERC20 public immutable soul = IERC20(0xe2fb177009FF39F52C0134E8007FA0e4BaAcBd07);
    bytes32 public merkleRoot = 0x2ac1f9a51bb253aac91d25ade4dd66036b817a7345064bba8b1fe3571ee33ce9;

    // PACKED ARRAY OF BOOLEANS
    mapping(uint => uint) private claimedBitMap;

    // TIME VARIABLES
    uint public immutable startTime = block.timestamp;
    uint public immutable endTime = block.timestamp + 180 days;

    function initialize(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    // CLAIM VIEW
    function isClaimed(uint index) public view override returns (bool) {
        uint claimedWordIndex = index / 256;
        uint claimedBitIndex = index % 256;
        uint claimedWord = claimedBitMap[claimedWordIndex];
        uint mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint index) private {
        uint claimedWordIndex = index / 256;
        uint claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(uint index, address account, uint amount, bytes32[] calldata merkleProof) external override {
        require(!isClaimed(index), 'claim: already claimed.');

        // VERIFY MERKLE ROOT
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'claim: invalid proof.');

        // CLAIM AND SEND
        _setClaimed(index); // sets claimed
        require(block.timestamp >= startTime, '_setClaimed: too soon'); // blocks early claims
        require(block.timestamp <= endTime, '_setClaimed: too late'); // blocks late claims
        require(IERC20(soul).transfer(account, amount), '_setClaimed: transfer failed'); // transfers tokens

        emit Claimed(index, account, amount);
    }

    // COLLECT UNCLAIMED TOKENS
    function collectUnclaimed(uint amount) public onlyOwner {
        require(block.timestamp >= endTime, 'collectUnclaimed: too soon');
        require(IERC20(soul).transfer(owner(), amount), 'collectUnclaimed: transfer failed');
    }

}
