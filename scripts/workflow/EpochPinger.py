import web3
from web3 import Web3, HTTPProvider
import json
import time


### DECODE PRIVATE KEY FOR STORAGE

w3 = Web3(Web3.HTTPProvider("https://staging-v2.skalenodes.com/v1/rapping-zuben-elakrab"))

EXDT_token_address = "0x013121200dfcb362a55561d84A193c990c42706f"
Private_key = "deaddead071899995fb92d83ed54dead1eb74e72a84ef980d42953caaa6db074"
pinger_address = w3.eth.account.from_key(Private_key).address

print("EXDT Testnet token Address =",EXDT_token_address)
print("Pinger address =", pinger_address)

spot_contract = '0xf7b2f1fB641151e8369a0d91E6B634B6527F18BD'
format_contract = '0x2a6b5715bB02934fCe0e1FA41976F59f334B3c6E'

print("\nSpot_contract  =",spot_contract)
print("Format_contract  =",format_contract)


##### 0 - CHECK VALIDITY

is_valid = w3.isAddress(spot_contract)
if is_valid == False:
    print("INVALID SPOT CONTRACT ADDRESS, ABORT")
    exit(1)
spot_contract_address = w3.toChecksumAddress(spot_contract)

is_valid = w3.isAddress(format_contract)
if is_valid == False:
    print("INVALID FORMAT CONTRACT ADDRESS, ABORT")
    exit(1)
format_contract_address = w3.toChecksumAddress(format_contract)


#### 1 - INTERFACE WITH CONTRACTS WITH ABIs
with open(r"DataSpotting.json") as file:
    spot_abi = json.load(file)["abi"]
spot_contract = w3.eth.contract(spot_contract_address, abi=spot_abi)

with open(r"DataFormatting.json") as file:
    format_abi = json.load(file)["abi"]
format_contract = w3.eth.contract(format_contract_address, abi=format_abi)

while(True):

    #### 2 - PING SPOT CONTRACT
    increment_tx = spot_contract.functions.TriggerNextEpoch().buildTransaction({
            'from': pinger_address,
            'nonce': w3.eth.get_transaction_count(pinger_address),
            'value': 0,
            'gas': 100000000,
            'gasPrice': w3.eth.gas_price,
    })

    tx_create = w3.eth.account.sign_transaction(increment_tx, Private_key)
    tx_hash = w3.eth.send_raw_transaction(tx_create.rawTransaction)
    tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f'Spot Pinging Tx successful with hash: { tx_receipt.transactionHash.hex() }')

    #### 3 - PING FORMAT CONTRACT
    increment_tx = format_contract.functions.TriggerNextEpoch().buildTransaction({
            'from': pinger_address,
            'nonce': w3.eth.get_transaction_count(pinger_address),
            'value': 0,
            'gas': 100000000,
            'gasPrice': w3.eth.gas_price,
    })

    tx_create = w3.eth.account.sign_transaction(increment_tx, Private_key)
    tx_hash = w3.eth.send_raw_transaction(tx_create.rawTransaction)
    tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f'Format Pinging Tx successful with hash: { tx_receipt.transactionHash.hex() }')

    time.sleep(30)
