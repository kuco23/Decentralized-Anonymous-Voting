circuit_name=ticket_spender
contract_name=TicketSpenderVerifier

snarkjs zkey export solidityverifier \
    snark_data/${circuit_name}_final.zkey \
    contracts/implementation/${contract_name}.sol