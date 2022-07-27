
#' Address Token Balance
#'
#' @param token_address ERC20 token contract address to assess balance
#' @param min_tokens the minimum amount of token needed to qualify (assumes 1e18 decimals)
#' @param block_max The block height to assess balance at (for reproducibility)
#' @param api_key Flipside ShroomDK API Key to access queries.
#'
#' @return
#' @export
#' @import jsonlite httr
#' @examples
#' #' \dontrun{
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

  query <- {
    "-- Get desired tokens
-- at a certain blockheight

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
-- get holders

token_holder AS (
SELECT *, ROW_NUMBER() over (partition by address, token_address order by block DESC) as rownum
FROM block_tracked
)

SELECT block, hash, token_address, symbol, address, old_value, new_value
FROM token_holder
    WHERE rownum = 1 AND
    -- NOTE this applies to all tokens; to differentiate minimum for each token
    -- you can pull this table with 0 and filter after.
          new_value >= _MIN_TOKENS_ -- <-- Place Minimum here.
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
