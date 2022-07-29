
#' Address Token Balance
#'
#' Token balance of an address at a specific block height.
#' Alice held 20 UNI at block 15,000,000.
#'
#' @param token_address ERC20 token contract address to assess balance
#' @param min_tokens Minimum amount of tokens acknowledged. Already decimal adjusted, useful to
#' ignoring dust balances.
#' @param block_max The block height to assess balance at (for reproducibility)
#' @param api_key Flipside Crypto ShroomDK API Key to create and access SQL queries.
#'
#' @return Data frame of form:
#'
#' | |  |
#' | ------------- |:-------------:|
#' | BLOCK         | Block where user last changed their balance (traded or transferred) |
#' | HASH          | Tx hash where user last traded or transferred |
#' | TOKEN_ADDRESS | ERC20 address provided |
#' | ADDRESS       | The EOA or contract that holds the balance |
#' | SYMBOL        | ERC20 symbol, e.g., "UNI" |
#' | OLD_VALUE     | Amount of token before latest trade or transfer |
#' | NEW_VALUE     | Amount of token as of BLOCK, i.e. balance after their latest trade or transfer|
#'
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
address_token_balance <- function(token_address,
                                  min_tokens = 0.0001,
                                  block_max,
                                  api_key = api_key){

  # Scientific notation is troublesome in R<>SQL
  block_max <- format(block_max, scientific = FALSE)

  query <- {
    "
WITH block_tracked AS (
    SELECT TX_HASH AS hash,
           SYMBOL AS symbol,
           HOLDER as address,
           TOKEN_ADDRESS as token_address,
           BLOCK as block,
           PREV_VALUE as old_value,
           CURR_VALUE as new_value
    FROM flipside_prod_db.tokenflow_eth.tokens_balance_diffs
    WHERE BLOCK <= _BLOCK_MAX_ AND
          TOKEN_ADDRESS = '_QUERY_TOKENS_'
    ORDER BY BLOCK desc),

-- group by holder-token
-- order by block desc
-- pick most recent block
-- get holders w/ address type label in case it is a contract

token_holder AS (
SELECT *, ROW_NUMBER() over (partition by address, token_address order by block DESC) as rownum
FROM block_tracked
),

latest_holdings AS (
SELECT block, hash, token_address, symbol, address, old_value, new_value
FROM token_holder
    WHERE rownum = 1 AND
    -- NOTE this applies to all tokens; to differentiate minimum for each token
    -- you can pull this table with 0 and filter after.
          new_value >= _MIN_TOKENS_
    )

-- include ability to filter out contract addresses if desired

SELECT block, hash, token_address,
  symbol, latest_holdings.address,
  old_value, new_value,
  IFNULL(tag_name, 'eoa') as address_type
FROM latest_holdings LEFT JOIN
  crosschain.core.address_tags ON
  latest_holdings.address = crosschain.core.address_tags.address
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

  return(amount_holding)
}
