// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "./TicketSpender.sol";
import "./MerkleTree.sol";
import "./Poseidon.sol";

struct VotingPeriod {
    uint256 start;
    uint256 end;
}

struct Winner {
    uint256 option;
    uint256 votes;
}

contract AnonymousVoting is MerkleTree, Poseidon {
    address[] public voters;
    mapping(uint256 => bool) internal nullified;
    mapping(address => bool) internal claimedTicket;
    mapping(uint256 => uint256) internal votes;

    Winner public winner;
    VotingPeriod public votingPeriod;

    TicketSpender ticketSpender;

    constructor(
        TicketSpender _ticketSpender,
        address[] memory _voters,
        uint256 _startVotingTime,
        uint256 _endVotingTime,
        uint256 _p,
        uint256 _nRoundsF,
        uint256 _nRoundsP,
        uint256[] memory _C,
        uint256[] memory _S,
        uint256[][] memory _M,
        uint256[][] memory _P
    ) Poseidon(
        _p, 3, _nRoundsF, _nRoundsP, 
        _C, _S, _M, _P
    ) { 
        ticketSpender = _ticketSpender;
        voters = _voters;
        votingPeriod = VotingPeriod(
            _startVotingTime, _endVotingTime);
    }

    modifier beforeVotingPeriod() {
        require(block.timestamp < votingPeriod.start);
        _;
    }
    modifier duringVotingPeriod() {
        require(
            block.timestamp >= votingPeriod.start && 
            block.timestamp < votingPeriod.end
        );
        _;
    }

    modifier afterVotingPeriod() {
        require(block.timestamp > votingPeriod.end);
        _;
    }
    
    function registerTicket(
        uint256 ticket
    ) external beforeVotingPeriod returns (uint256) {
        require(
            !claimedTicket[msg.sender], 
            "ticket already registered"
        );
        addElement(ticket);
        claimedTicket[msg.sender] = true;
        return size-1;
    }

    function spendTicket(
        uint256 serial, uint256 option, bytes memory proof
    ) external duringVotingPeriod {
        require(!nullified[serial], "ticket already spent");
        bool result = ticketSpender.verifyTicketSpending(
            proof, serial, merkleRoot());
        require(result == true, "incorrect proof");
        nullified[serial] = true;
        votes[option] += 1;
        if (votes[option] > winner.votes) {
            winner.option = option;
            winner.votes = votes[option];
        }
    }

    function getWinner(
    ) external view afterVotingPeriod returns (uint256) {
        return winner.option;
    }

    // so users can build their own merkle tree locally
    function getTickets(
    ) external view returns (uint256[] memory) {
        uint256[] memory tickets = new uint256[](size);
        for (uint256 i = 0; i < size; i++)
            tickets[i] = tree[TREE_DEPTH-1][i];
        return tickets;
    }

    function hashFunction(
        uint256 a, uint256 b
    ) internal view override returns (uint256) {
        uint256[] memory inputs = new uint256[](2);
        inputs[0] = a;
        inputs[1] = b;
        return poseidon(inputs);
    }
}