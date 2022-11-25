# Decentralized Anonymous Voting

This is a simple implementation of a decentralized anonymous voting system, based on the main idea of zerocash, using zk-snarks.
The voting system requires voters to be predefined and makes the voting results publicly known at all times without revealing voter choices.

> **Note:**
> Zerocash implements a decentralized anonymous currency by making use of zk-snarks to transfer an unknown coin to an unknown recipients by nullifying the coin and making a new one that follows a correct format. Here we only nullify the unknown coin (called a ticket), which acts as casting a vote.

The implementation relies heavily on the poseidon hash function,
which has a circuit optimized for zk-snark construction.

## Voting flow

The voting flow follows the below description:
- a user [deploys the voting contract](#Deployment-of-the-voting-contract) by specifying the voter addresses, along with the voting duration;
- before the voting period, voters [register tickets](#Registering-tickets) to the smart contract;
- during the voting period, voters vote for an option by spending their tickets 
in a zero-knowledge way, which is done by [producing](#Constructing-zk-snark) and sending a zk-snark to the contract;
- after the voting period the winner is considered fixed.

### Deployment of the voting contract

There are two contracts that should be deployed to establish the voting system:
- `TicketSpender.sol` verifies zk-snarks,
- `AnonymousVoting.sol` implements the voting system and uses `TicketSpender.sol` to verify whether ticket spending is valid.

The second contract should be deployed with specified `TicketSpender` address, a list of voter addresses and the voting duration. The second sets of arguments are poseidon hash function constants, that are specified in the tests.

### Registering tickets

To register a spendable ticket, you should generate a secret 256-bit number and hash it as `poseidon(secret, secret)`. For later use, you should also produce its serial number `poseidon(secret, ticket)`.

### Constructing zk-snark

The construction of zk-snark is generated by circom and snarkjs
from the circuits defined in the circuits folder. To use those, you should generate a one-time trusted setup by downloading [this](https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_16.ptau) file into the root folder and then run `generate-plonk-setup.sh`. 

To construct the necessary zk-snark, follow the steps below:
- call the `AnonymousVoting` contract's `getTickets` view function
to obtain all tickets and from them construct the merkle tree. From that tree obtain the merkle root and construct the merkle proof of your ticket being inside. The following elements are then responsible for generating the zk-snark:
    - your ticket's serial number,
    - merkle root,
    - your ticket,
    - your secret,
    - merkle proof
    
    and should be pasted into `snark_data/input.json`. To auto-generate those values from the merkle tree and your secret number, use `generate_input.py`. 
- run `generate-proof.sh` to obtain the values, necessary to make the contract call.

Detailed `input.json` production is done below in Python:
```python
from random import getrandbits
from lib import MerkleTree, generateCircomInput
TREE_DEPTH = 21

# define secret value, ticket and serial
secret = getrandbits(256)
ticket = poseidon(secret, secret)
serial = poseidon(secret, ticket)

# define tickets merkle tree
tickets = [111, 222, 333, ticket, 444, 555]

# construct the merkle tree out of hashed_data
merkle_tree = MerkleTree(TREE_DEPTH)
for x in tickets: merkle_tree.addElement(x)

# proving ticket is inside tickets
ticket_idx = tickets.index(ticket)
merkle_proof = merkle_tree.proof(ticket_idx)

# verify the merkle proof
merkle_root = merkle_tree.root()
merkle_tree.verifyProof(ticket, merkle_proof, merkle_root)

# produce circom input
createCircomInput(
    serial, merkle_root, ticket, 
    secret, merkle_proof
)
```

## To-do
- [ ] Find a way to hardcode poseidon constants in the `AnonymousVoting` contract and use them to initialise `Poseidon`,
- [ ] Find a way for `AnonymousVoting` to inherit `TicketSpender` without `verifyProof` blocking the following code execution.