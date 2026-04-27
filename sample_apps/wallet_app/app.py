import sys
import logging
import traceback
from pycma import RollupCma, Ledger, decode_advance, decode_inspect, decode_ether_deposit, decode_erc20_deposit, \
    decode_erc721_deposit, decode_erc1155_single_deposit, decode_erc1155_batch_deposit

from config import ETHER_PORTAL_ADDRESS, ERC20_PORTAL_ADDRESS, ERC721_PORTAL_ADDRESS, \
    ERC1155_SINGLE_PORTAL_ADDRESS, ERC1155_BATCH_PORTAL_ADDRESS

logging.basicConfig(level="DEBUG")
logger = logging.getLogger(__name__)

LEDGER_OFFSET = 0
ASSETS_PER_ACCOUNT = 8          # Average of positions for an account.
MAX_ACCOUNTS = 16 * 1024        # Maximum number of accounts.
MAX_ASSETS = 8                  # Maximum number of assets.
MAX_BALANCES = ASSETS_PER_ACCOUNT * MAX_ACCOUNTS    # Maximum number of balances.
MEMORY_SIZE = 64 * 1024 * 1024 - LEDGER_OFFSET      # 33554432 # State file size

class EtherId:
    ether_id = None
    def __new__(cls):
        return cls
    @classmethod
    def set(cls,val):
        cls.ether_id = val
    @classmethod
    def get(cls):
        return cls.ether_id

def handle_advance(rollup, ledger):
    advance = rollup.read_advance_state()
    msg_sender = advance['msg_sender'].hex().lower()
    logger.info(f"Received advance request from {msg_sender=}")

    if msg_sender == ETHER_PORTAL_ADDRESS:
        deposit = decode_ether_deposit(advance)

        account_info = ledger.retrieve_account(account=deposit['sender'])

        ledger.deposit(EtherId.get(), account_info['account_id'], deposit['amount'])
        logger.info(f"[app] {deposit['sender']} deposited {deposit['amount']} ether")
        return True

    if msg_sender == ERC20_PORTAL_ADDRESS:
        deposit = decode_erc20_deposit(advance)

        asset_info = ledger.retrieve_asset(token=deposit['token'])
        account_info = ledger.retrieve_account(account=deposit['sender'])

        ledger.deposit(asset_info['asset_id'], account_info['account_id'], deposit['amount'])
        logger.info(f"[app] {deposit['sender']} deposited {deposit['amount']} of token {asset_info['token']}")
        return True

    if msg_sender == ERC721_PORTAL_ADDRESS:
        deposit = decode_erc721_deposit(advance)

        asset_info = ledger.retrieve_asset(token=deposit['token'],token_id=deposit['token_id'])
        account_info = ledger.retrieve_account(account=deposit['sender'])

        ledger.deposit(asset_info['asset_id'], account_info['account_id'], 1)
        logger.info(f"[app] {deposit['sender']} deposited id {deposit['token_id']} from token {asset_info['token']}")
        return True

    if msg_sender == ERC1155_SINGLE_PORTAL_ADDRESS:
        deposit = decode_erc1155_single_deposit(advance)

        asset_info = ledger.retrieve_asset(token=deposit['token'],token_id=deposit['token_id'],token_id_with_amount=True)
        account_info = ledger.retrieve_account(account=deposit['sender'])

        ledger.deposit(asset_info['asset_id'], account_info['account_id'], deposit['amount'])
        logger.info(f"[app] {deposit['sender']} deposited {deposit['amount']} of id {deposit['token_id']} from token {asset_info['token']}")
        return True

    if msg_sender == ERC1155_BATCH_PORTAL_ADDRESS:
        deposit = decode_erc1155_batch_deposit(advance)

        account_info = ledger.retrieve_account(account=deposit['sender'])
        for i in range(len(deposit['token_ids'])):
            asset_info = ledger.retrieve_asset(token=deposit['token'],token_id=deposit['token_ids'][i],token_id_with_amount=True)

            ledger.deposit(asset_info['asset_id'], account_info['account_id'], deposit['amounts'][i])
            logger.info(f"[app] {deposit['sender']} deposited {deposit['amounts'][i]} of id {deposit['token_ids'][i]} from token {asset_info['token']}")
        return True

    try:
        decoded_advance = decode_advance(advance)
        logger.info(f"[app] Advance is {decoded_advance['type']}")
        if decoded_advance['type'] == 'ETHER_WITHDRAWAL':
            account_info = ledger.retrieve_account(account=msg_sender)

            ledger.withdraw(EtherId.get(), account_info['account_id'], decoded_advance['amount'])
            logger.info(f"[app] {msg_sender} withdrew {decoded_advance['amount']} ethers")

            rollup.emit_ether_voucher(msg_sender, decoded_advance['amount'])
            logger.info("[app] Ether voucher emitted")
            return True

        if decoded_advance['type'] == 'ERC20_WITHDRAWAL':
            asset_info = ledger.retrieve_asset(token=decoded_advance['token'])
            account_info = ledger.retrieve_account(account=msg_sender)

            ledger.withdraw(asset_info['asset_id'], account_info['account_id'], decoded_advance['amount'])
            logger.info(f"[app] {msg_sender} withdrew {decoded_advance['amount']} of token {asset_info['token']}")

            rollup.emit_erc20_voucher(asset_info['token'], msg_sender, decoded_advance['amount'])
            logger.info("[app] Erc20 voucher emitted")
            return True

        if decoded_advance['type'] == 'ERC721_WITHDRAWAL':
            asset_info = ledger.retrieve_asset(token=decoded_advance['token'],token_id=decoded_advance['token_id'])
            account_info = ledger.retrieve_account(account=msg_sender)

            ledger.withdraw(asset_info['asset_id'], account_info['account_id'], 1)
            logger.info(f"[app] {msg_sender} withdrew id {decoded_advance['token_id']} from token {asset_info['token']}")

            rollup.emit_erc721_voucher(asset_info['token'], msg_sender, decoded_advance['token_id'])
            logger.info("[app] Erc721 voucher emitted")
            return True

        if decoded_advance['type'] == 'ERC1155_SINGLE_WITHDRAWAL':
            asset_info = ledger.retrieve_asset(token=decoded_advance['token'],token_id=decoded_advance['token_id'],token_id_with_amount=True)
            account_info = ledger.retrieve_account(account=msg_sender)

            ledger.withdraw(asset_info['asset_id'], account_info['account_id'], decoded_advance['amount'])
            logger.info(f"[app] {msg_sender} withdrew {decoded_advance['amount']} of id {decoded_advance['token_id']} from token {asset_info['token']}")

            logger.info(f"[app] {asset_info=}")
            logger.info(f"[app] {msg_sender=}")
            logger.info(f"[app] {decoded_advance=}")
            rollup.emit_erc1155_single_voucher(asset_info['token'], msg_sender, decoded_advance['token_id'], decoded_advance['amount'])
            logger.info("[app] Erc1155_single voucher emitted")
            return True

        if decoded_advance['type'] == 'ERC1155_BATCH_WITHDRAWAL':
            account_info = ledger.retrieve_account(account=msg_sender)

            for i in range(len(decoded_advance['token_ids'])):
                asset_info = ledger.retrieve_asset(token=decoded_advance['token'],token_id=decoded_advance['token_ids'][i],token_id_with_amount=True)
                ledger.withdraw(asset_info['asset_id'], account_info['account_id'], decoded_advance['amounts'][i])
                logger.info(f"[app] {msg_sender} withdrew {decoded_advance['amounts'][i]} of id {decoded_advance['token_ids'][i]} from token {asset_info['token']}")

            rollup.emit_erc1155_batch_voucher(decoded_advance['token'], msg_sender, decoded_advance['token_ids'], decoded_advance['amounts'])
            logger.info("[app] Erc1155_batch voucher emitted")
            return True

        if decoded_advance['type'] == 'ETHER_TRANSFER':
            account_info_from = ledger.retrieve_account(account=msg_sender)
            account_info_to = ledger.retrieve_account(account=decoded_advance['receiver'])

            ledger.transfer(EtherId.get(), account_info_from['account_id'], account_info_to['account_id'], decoded_advance['amount'])
            logger.info(f"[app] {msg_sender} transfered to {account_info_to['account']} {decoded_advance['amount']} ethers")
            return True

        if decoded_advance['type'] == 'ERC20_TRANSFER':
            asset_info = ledger.retrieve_asset(token=decoded_advance['token'])
            account_info_from = ledger.retrieve_account(account=msg_sender)
            account_info_to = ledger.retrieve_account(account=decoded_advance['receiver'])

            ledger.transfer(asset_info['asset_id'], account_info_from['account_id'], account_info_to['account_id'], decoded_advance['amount'])
            logger.info(f"[app] {msg_sender} transfered to {account_info_to['account']} {decoded_advance['amount']} of token {asset_info['token']}")
            return True

        if decoded_advance['type'] == 'ERC721_TRANSFER':
            asset_info = ledger.retrieve_asset(token=decoded_advance['token'],token_id=decoded_advance['token_id'])
            account_info_from = ledger.retrieve_account(account=msg_sender)
            account_info_to = ledger.retrieve_account(account=decoded_advance['receiver'])

            ledger.transfer(asset_info['asset_id'], account_info_from['account_id'], account_info_to['account_id'], 1)
            logger.info(f"[app] {msg_sender} transfered to {account_info_to['account']} id {decoded_advance['token_id']} from token {asset_info['token']}")
            return True

        if decoded_advance['type'] == 'ERC1155_SINGLE_TRANSFER':
            asset_info = ledger.retrieve_asset(token=decoded_advance['token'],token_id=decoded_advance['token_id'],token_id_with_amount=True)
            account_info_from = ledger.retrieve_account(account=msg_sender)
            account_info_to = ledger.retrieve_account(account=decoded_advance['receiver'])

            ledger.transfer(asset_info['asset_id'], account_info_from['account_id'], account_info_to['account_id'], decoded_advance['amount'])
            logger.info(f"[app] {msg_sender} transfered to {account_info_to['account']} {decoded_advance['amount']} of id {decoded_advance['token_id']} from token {asset_info['token']}")
            return True

        if decoded_advance['type'] == 'ERC1155_BATCH_TRANSFER':
            account_info_from = ledger.retrieve_account(account=msg_sender)
            account_info_to = ledger.retrieve_account(account=decoded_advance['receiver'])

            for i in range(len(decoded_advance['token_ids'])):
                asset_info = ledger.retrieve_asset(token=decoded_advance['token'],token_id=decoded_advance['token_ids'][i],token_id_with_amount=True)

                ledger.transfer(asset_info['asset_id'], account_info_from['account_id'], account_info_to['account_id'], decoded_advance['amounts'][i])
                logger.info(f"[app] {msg_sender} transfered to {account_info_to['account']} {decoded_advance['amounts'][i]} of id {decoded_advance['token_ids'][i]} from token {asset_info['token']}")
            return True

        logger.info("[app] unidentified wallet input")
        return False
    except Exception as e:
        logger.error(f"[app] Failed to process advance: {e}")
        logger.error(traceback.format_exc())
        return False

    logger.info("[app] non valid wallet input")
    return False

def handle_inspect(rollup, ledger):
    inspect = rollup.read_inspect_state()
    logger.info(f"Received inspect request length {len(inspect['payload']['data'])}")
    try:
        decoded_inspect = decode_inspect(inspect)
        logger.info(f"[app] Inspect decoded {decoded_inspect}")
        if decoded_inspect['type'] == 'BALANCE':
            account_info = ledger.retrieve_account(account=decoded_inspect['account'])
            asset_id = EtherId.get()
            if decoded_inspect['token'] is not None:
                asset_info = ledger.retrieve_asset(token=decoded_inspect['token'], token_id=decoded_inspect['token_id'])
                asset_id = asset_info['asset_id']

            current_balance = ledger.balance(asset_id, account_info['account_id'])
            logger.info(f"[app] {decoded_inspect['account']} balance is {current_balance}")

            rollup.emit_report(current_balance.to_bytes(32, 'big'))
            logger.info("[app] report emitted")
            return True
        if decoded_inspect['type'] == 'SUPPLY':
            asset_id = EtherId.get()
            if decoded_inspect['token'] is not None:
                asset_info = ledger.retrieve_asset(token=decoded_inspect['token'], token_id=decoded_inspect['token_id'])
                asset_id = asset_info['asset_id']

            current_supply = ledger.supply(asset_id)
            logger.info(f"[app] Asset supply is {current_supply}")

            rollup.emit_report(current_supply.to_bytes(32, 'big'))
            logger.info("[app] report emitted")
            return True

        logger.info("[app] unidentified wallet input")
        return False
    except Exception as e:
        logger.error(f"[app] Failed to process inspect: {e}")

    logger.info("[app] non valid wallet input")
    return False

handlers = {
    "advance": handle_advance,
    "inspect": handle_inspect,
}

###
# Main
if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise Exception("Missing memory filename")
    create_file = False
    if len(sys.argv) > 2:
        create_file = True

    rollup = RollupCma()
    ledger = Ledger(
        memory_filename = sys.argv[1],
        offset = LEDGER_OFFSET,
        mem_length = MEMORY_SIZE,
        n_accounts = MAX_ACCOUNTS,
        n_assets = MAX_ASSETS,
        n_balances = MAX_BALANCES,
        initialize_memory = create_file
    )
    if create_file:
        asset_info = ledger.retrieve_asset(base_token = True)
        exit(0)

    asset_info = ledger.retrieve_asset(base_token = True, force_find = True)
    EtherId.set(asset_info['asset_id'])

    accept_previous_request = True

    # Main loop
    while True:
        logger.info("[app] Sending finish")

        next_request_type = rollup.finish(accept_previous_request)

        logger.info(f"[app] Received input of type {next_request_type}")

        accept_previous_request = handlers[next_request_type](rollup, ledger)

    exit(-1)
