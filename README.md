# ETHSCORE

ETHSCORE is a framework for identifying addresses and scoring their behavior. With the vision of simplifying the development of web3 'reputation'. Initially started with 5 fully on-chain metrics, new metrics will be added over-time including off-chain metrics, e.g., Snapshot governance voting.

Use cases such as under-collateralized credit or 'social' scoring may fall under this framework, but that is not the direct intention. ethscore was originally developed to assist in airdrop design so new protocols could more easily identify users for their applications that have a history of using similar apps and bribe them with tokens/ownership in the protocol as a direct to customer: Customer Acquisition Cost.

## Installation

Currently installation of the R package is best done via devtools::install_github().

    require(devtools)
    devtools::install_github(repo = 'FlipsideCrypto/ethscore')

## Available Metrics

Note: all documentation available within the ethscore package: `?ethscore::address_token_balance`

All functions leverage Flipside Crypto's free [shroomDK API](https://sdk.flipsidecrypto.xyz/shroomdk) and require a shroomDK API Key and the [shroomDK R package](https://github.com/FlipsideCrypto/sdk/tree/main/r/shroomDK). ShroomDK returns a maximum of 1,000,000 rows of data. Vary your block_min and block_max accordingly to stitch together large data if desired, or use min_tokens to remove more dust accounts.

### address_token_balance()

Token balance of an address at a specific block height. Example: Alice held 20 UNI at block 15,000,000.

Arguments include:

-   token_address: ERC20 token contract address to assess balance
-   min_tokens: Minimum amount of tokens acknowledged. Already decimal adjusted, useful for ignoring dust balances.
-   block_max: The block height to assess balance at.
-   api_key: Flipside Crypto ShroomDK API Key to create and access SQL queries.

Example:

    UNI_atb <- address_token_balance(
      token_address = tolower("0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"), #UNI token
      min_tokens = 0.01,
      block_max = 15000000,
      api_key = readLines("api_key.txt") # always gitignore your API keys!
      )

Returns a data frame of the following:

-   BLOCK: Block where user last changed their balance (i.e., traded or transferred)
-   TOKEN_ADDRESS: ERC20 address provided
-   ADDRESS: The EOA or contract that holds the balance
-   OLD_VALUE: Amount of token before latest trade or transfer
-   NEW_VALUE Amount of token as of BLOCK, i.e. balance after their latest trade or transfer
-   ADDRESS_TYPE: If ADDRESS is known to be 'contract address' or 'gnosis safe address'. If neither it is assumed to be an 'EOA'. Some EOAs may have a balance but have never initiated a transaction. These are noted as 'EOA-0tx' Note: contracts, including gnosis safes may not have consistent owners across different EVM chains.

### address_time_weighted_token_balance()

Time weighted token balance of an address between 2 block heights. Holding 20 UNI for 10,000 blocks might be more interesting to score than someone buying 20 UNI right before a snapshot for an airdrop.

Arguments include:

-   token_address: ERC20 token contract address to assess balance
-   min_tokens: Minimum amount of tokens acknowledged. Already decimal adjusted, useful for ignoring dust balances.
-   block_min: Initial block to start scoring balances over time, default 0 (genesis block).
-   block_max: The block height to assess balance at.
-   amount_weighting: Weight by amounts held across time, default TRUE. If FALSE, it treats all amounts as binary. Person had at least min_tokens at a block or they did not. To NOT weight by time, use `address_token_balance()` instead of this function.
-   api_key: Flipside Crypto ShroomDK API Key to create and access SQL queries.

Example:

    address_time_weighted_token_balance(
    token_address = tolower("0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"), #UNI token
     min_tokens = 0.01,
     block_min = 10000000,
     block_max = 15000000,
     amount_weighting = TRUE,
     api_key = readLines("api_key.txt")
    )

Returns a data frame of the following:

-   ADDRESS: The EOA or contract that holds the balance
-   TOKEN_ADDRESS: ERC20 address provided
-   time_weighted_score: 1 point per 1 token held per 1,000 blocks. If amount_weighting = FALSE, 1 point per 1,000 blocks where balance was at least min_tokens.
-   ADDRESS_TYPE: If ADDRESS is known to be 'contract address' or 'gnosis safe address'. If neither it is assumed to be an 'EOA'. Some EOAs may have a balance but have never initiated a transaction. These are noted as 'EOA-0tx' Note: contracts, including gnosis safes may not have consistent owners across different EVM chains.

### address_transfer_volume()

Total transfer volume of a token between two block heights. Ignores direction of transfer. Alice traded and/or transferred a total of 2,000 UNI between blocks 10,000,000 and 15,000,000.

Arguments include:

-   token_address: ERC20 token contract address to assess balance
-   min_tokens: Minimum amount of tokens acknowledged. Already decimal adjusted, useful for ignoring dust balances.
-   block_min: Initial block to start scoring balances over time, default 0 (genesis block).
-   block_max: The block height to assess balance at.
-   api_key: Flipside Crypto ShroomDK API Key to create and access SQL queries.

Example:

    address_transfer_volume(
    token_address = tolower("0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"), #UNI token
     block_min = 10000000,
     block_max = 15000000,
     min_tokens = 10,
     api_key = readLines("api_key.txt")
    )

Returns a data frame of the following:

-   ADDRESS: The EOA or contract that holds the balance
-   TOKEN_ADDRESS: ERC20 address provided
-   VOLUME: amount of tokens transferred/traded between block_min and block_max.
-   ADDRESS_TYPE: If ADDRESS is known to be 'contract address' or 'gnosis safe address'. If neither it is assumed to be an 'EOA'. Some EOAs may have a balance but have never initiated a transaction. These are noted as 'EOA-0tx' Note: contracts, including gnosis safes may not have consistent owners across different EVM chains.

### address_token_accumulate()

Net accumulation of a token between two block heights. By default excludes net sellers. Alice net gained 200 UNI between blocks 10,000,000 and 15,000,000.

Arguments include:

-   token_address: ERC20 token contract address to assess balance
-   min_tokens: Minimum amount of tokens acknowledged. Already decimal adjusted, useful for ignoring dust balances. Default 0.01. Use -Inf to include net sellers (but note: API max is 1M rows).
-   block_min: Initial block to start scoring balances over time, default 0 (genesis block).
-   block_max: The block height to assess balance at.
-   api_key: Flipside Crypto ShroomDK API Key to create and access SQL queries.

Example:

    address_token_accumulate(
    token_address = tolower("0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"), #UNI token
     block_min = 10000000,
     block_max = 15000000,
     min_tokens = 1,
     api_key = readLines("api_key.txt")
    )

Returns a data frame of the following:

-   ADDRESS: The EOA or contract that holds the balance
-   TOKEN_ADDRESS: ERC20 address provided
-   NET_CHANGE: net amount of tokens accumulated between block_min and block_max
-   ADDRESS_TYPE: If ADDRESS is known to be 'contract address' or 'gnosis safe address'. If neither it is assumed to be an 'EOA'. Some EOAs may have a balance but have never initiated a transaction. These are noted as 'EOA-0tx' Note: contracts, including gnosis safes may not have consistent owners across different EVM chains.

### address_net_on_chain()

Net transfer amount of tokens from a central exchange between two block heights. By default excludes net sellers. Alice net received 200 UNI from central exchanges between blocks 10,000,000 and 15,000,000.

Arguments include:

-   token_address: ERC20 token contract address to assess balance
-   min_tokens: Minimum amount of tokens acknowledged. Already decimal adjusted, useful for ignoring dust balances. Default 0.01. Use -Inf to include net sellers (but note: API max is 1M rows).
-   block_min: Initial block to start scoring balances over time, default 0 (genesis block).
-   block_max: The block height to assess balance at.
-   decimal_reduction: Most ERC20 have 18 decimals, but stablecoins often have only 6. Default is 18.
-   api_key: Flipside Crypto ShroomDK API Key to create and access SQL queries.

Example:

    address_net_on_chain(
    token_address = tolower("0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"), #UNI token
     block_min = 10000000,
     block_max = 15000000,
     decimal_reduction = 18,
     min_tokens = 1,
     api_key = readLines("api_key.txt")
    )

Returns a data frame of the following:

-   ADDRESS: The EOA or contract that holds the balance
-   TOKEN_ADDRESS: ERC20 address provided
-   NET_ONTO_CHAIN: net amount of token taken from central exchanges between block_min and block_max. Double check `decimal_reduction` if amounts seem off.
-   ADDRESS_TYPE: If ADDRESS is known to be 'contract address' or 'gnosis safe address'. If neither it is assumed to be an 'EOA'. Some EOAs may have a balance but have never initiated a transaction. These are noted as 'EOA-0tx' Note: contracts, including gnosis safes may not have consistent owners across different EVM chains.

### get_address_activity()

Gets basic activity information from a set of addresses: number of transactions, number of days active, and last transaction date.

Arguments include:

-   addresses: a character vector of addresses
-   block_min: Initial block to start scoring balances over time, default 0 (genesis block).
-   block_max: The block height to assess balance at (for reproducibility).
-   api_key: Flipside Crypto ShroomDK API Key to create and access SQL queries.

Returns a data frame of the form:

-   ADDRESS: The EOA or contract that holds the balance
-   NUM_TX: Number of transactions initiated by ADDRESS between block heights. Note, EOA-0tx and contracts may return null.
-   NUM_DAYS: Number of unique days with a transaction between block heights
-   LAST_TX_DATE: YYYY-MM-DD date (UTC) of last transaction of ADDRESS between block heights

Example:

    alist <- c("0x39e856863e5f6f0654a0b87b12bc921da23d06bb",
     "0xd8da6bf26964af9d7eed9e03e53415d37aa96045")

    get_address_activity(
     addresses = alist,
     block_min = 10000000,
     block_max = 15000000,
     api_key = readLines("api_key.txt")
     )

### get_ens()

Identifies ENS NFT names of addresses. Note, currently does not subset to current holder (will update this soon). All historical owners will have the NFT. It is possible non-EOAs have an ENS, e.g., gnosis safe holders and contracts.

Arguments Include:

-   addresses: a character vector of addresses
-   api_key: Flipside Crypto ShroomDK API Key to create and access SQL queries

Example:

    get_ens(addresses = "0x39E856863e5F6f0654a0b87B12bc921DA23D06BB",
           api_key = readLines("api_key.txt"))

Returns a data frame of the form:

-   ADDRESS: EOA Address that held the ENS at least once.
-   ENS_NAME: Ethereum Name Service name, traders of ENS NFTs will each show as a historic recipient
-   TOKENID: ENS NFT Token ID Number (be aware of BIGINT issue)
-   HEX_TOKENID: ENS NFT Token ID in HEX form (to mitigate BIGINT issue)

## Support Functions

## big_int_to_hex()

Converts extremely large numbers into HEX to make them workable. Most specifically used for NFTs with millions of millions of token IDs. see `get_ens()` as a main example.

Arguments include:

-   bigint: vector of large integers as characters.

Example:

    token_id = "41104824783848331047501863836715107956672917465157448818057950770477717896101"
    bigint_to_hex(token_i)

Returns vector of hex with leading 0x and leading 0s to ensure at least 66 length. This 66 length is to best fit Flipside Crypto ENS data.

## hex_to_big_int()

Converts HEX to extremely large numbers to make them workable. Most specifically used for NFTs with millions of millions of token IDs. see `get_ens()` as a main example.

Arguments include:

-   hex: vector of hex with leading 0x, as characters to convert to big integer. Leading 0s are appropriately ignored.

Example:

     hex = "0x2aea5a3e13081115c6fcc5503f7ce0d950a8dfc5eaf871"
     bigint_to_hex(token_i)

Returns a vector of big integer in character format.
