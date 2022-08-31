
#' Address Token Balance
#'
#' Token balance of an address at a specific block height.
#' Alice held 20 UNI at block 15,000,000.
#'
#' @param token_address ERC20 token contract address to assess balance
#' @param min_tokens Minimum amount of tokens acknowledged. Already decimal adjusted, useful for
#' ignoring dust balances.
#' @param block_max The block height to assess balance at (for reproducibility)
#' @param api_key Flipside Crypto ShroomDK API Key to create and access SQL queries.
#'
#' @return Data frame of form:
#'
#' | |  |
#' | ------------- |:-------------:|
#' | BLOCK         | Block where user last changed their balance (traded or transferred) |
#' | TOKEN_ADDRESS | ERC20 address provided |
#' | ADDRESS       | The EOA or contract that holds the balance |
#' | OLD_VALUE     | Amount of token before latest trade or transfer |
#' | NEW_VALUE     | Amount of token as of BLOCK, i.e. balance after their latest trade or transfer|
#' | ADDRESS_TYPE  | If ADDRESS is known to be 'contract address' or 'gnosis safe address'.
#' If neither it is assumed to be an 'EOA'. Some EOAs may have a balance but have never initiated a transaction
#' These are noted as 'EOA-0tx' Note: contracts, including gnosis safes may not have consistent owners across different EVM chains.|
#' @md
#' @export
#' @import jsonlite httr
#' @examples
#' \dontrun{
#' address_token_balance(
#' token_address = tolower("0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"), #UNI token
#'  min_tokens = 0.01,
#'  block_max = 15000000,
#'  api_key = readLines("api_key.txt")
#' )
#'}
#'
address_token_balance <- function(token_address,
                                  min_tokens = 0.01,
                                  block_max,
                                  api_key = api_key){

  # Scientific notation is troublesome in R<>SQL
  block_max <- format(block_max, scientific = FALSE)

  query <- {
    "
WITH block_tracked AS (
    SELECT USER_ADDRESS as address,
           CONTRACT_ADDRESS as token_address,
           BLOCK_NUMBER as block,
           PREV_BAL as old_value,
           CURRENT_BAL as new_value
    FROM ETHEREUM.CORE.EZ_BALANCE_DELTAS
    WHERE BLOCK_NUMBER <= _BLOCK_MAX_ AND
          TOKEN_ADDRESS = '_QUERY_TOKENS_'
    ORDER BY BLOCK_NUMBER desc),

-- group by holder-token
-- order by block desc
-- pick most recent block
-- get holders w/ address type label in case it is a contract

token_holder AS (
SELECT *, ROW_NUMBER() over (partition by address, token_address order by block DESC) as rownum
FROM block_tracked
),

latest_holdings AS (
SELECT block, token_address, address, old_value, new_value
FROM token_holder
    WHERE rownum = 1 AND
    -- NOTE this applies to all tokens; to differentiate minimum for each token
    -- you can pull this table with 0 and filter after.
          new_value >= _MIN_TOKENS_
    ),

address_type AS (
SELECT DISTINCT address,
IFF(TAG_NAME IN ('contract address', 'gnosis safe address'),
    TAG_NAME,
    IFF(address NOT IN (SELECT address FROM CROSSCHAIN.CORE.ADDRESS_TAGS
WHERE BLOCKCHAIN = 'ethereum' AND TAG_NAME IN ('contract address', 'gnosis safe address')), 'EOA', TAG_NAME))
    as address_type
FROM CROSSCHAIN.CORE.ADDRESS_TAGS
WHERE BLOCKCHAIN = 'ethereum'
)

-- include ability to filter out contract addresses if desired

SELECT block, token_address,
   latest_holdings.address,
  old_value, new_value, address_type
FROM latest_holdings LEFT JOIN address_type ON
  latest_holdings.address = address_type.address
"
  }

  query <- gsub(pattern = "_BLOCK_MAX_",
                replacement = block_max,
                x = query,
                fixed = TRUE)
  query <- gsub(pattern = "_QUERY_TOKENS_",
                replacement = token_address,
                x = query,
                fixed = TRUE)
  query <- gsub(pattern = "_MIN_TOKENS_",
                replacement = min_tokens,
                x = query,
                fixed = TRUE)

  amount_holding <- shroomDK::auto_paginate_query(query, api_key)

  amount_holding$ADDRESS_TYPE[is.na(amount_holding$ADDRESS_TYPE)] <- "EOA-0tx"

  if(nrow(amount_holding) == 1e6){
    warning("shroomDK returns a max of 1M rows. There may be data you missed. You can use multiple requests
            with different BLOCK parameters to stitch together data.")
  }

  return(amount_holding)
}
