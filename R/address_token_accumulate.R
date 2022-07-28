
#' Address Token Accumulate
#'
#' Net accumulation of a token between two block heights. Throws out net sellers.
#' Alice net gained 200 UNI between blocks 10,000,000 and 15,000,000.
#'
#' @param token_address ERC20 token contract address to assess change in balance.
#' @param block_min Initial block to start scoring balances over time, default 0 (genesis block).
#' @param block_max The block height to assess balance at (for reproducibility).
#' @param api_key Flipside Crypto ShroomDK API Key to create and access SQL queries.
#'
#' @return A data frame of the form:
#' | |  |
#' | ------------- |:-------------:|
#' | ADDRESS       | The EOA or contract that holds the balance |
#' | TOKEN_ADDRESS | ERC20 address provided |
#' | time_weighted_score | 1 point per 1 token held for 1,000 blocks (amount_weighting = FALSE is
#' 1 point per 1000 blocks where balance was above min_token) |
#' @md
#' @export
#' @import jsonlite httr
#' @examples
#' \dontrun{
#' address_token_accumulate(
#' token_address = tolower("0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"), #UNI token
#'  block_min = 10000000,
#'  block_max = 15000000,
#'  api_key = readLines("api_key.txt")
#' )
#'}
address_token_accumulate <- function(token_address,
                               block_min = 0,
                               block_max,
                               api_key){

  # Scientific notation is troublesome in R<>SQL
  block_min <- format(block_min, scientific = FALSE)
  block_max <- format(block_max, scientific = FALSE)

  query <-  {
    "
    -- change in token balance between block heights
with token_changes AS (
  SELECT *, (CURR_VALUE - PREV_VALUE) as CHANGE
  FROM flipside_prod_db.tokenflow_eth.tokens_balance_diffs
  WHERE BLOCK >= _BLOCK_MIN_ AND
        BLOCK <= _BLOCK_MAX_ AND
        TOKEN_ADDRESS = '_TOKEN_ADDRESS_'
        ORDER BY BLOCK DESC
)

-- net change can be negative between blocks, 0 (often bots/aggregators), or positive (accumulation)

  SELECT HOLDER as user_address, SUM(CHANGE) as net_change
  FROM token_changes
   GROUP BY HOLDER, token_address
   HAVING net_change > 0"
  }

  query <- gsub(pattern = "_BLOCK_MIN_",
                replacement = block_min,
                x = query,
                fixed = TRUE)
  query <- gsub(pattern = "_BLOCK_MAX_",
                replacement = block_max,
                x = query,
                fixed = TRUE)
  query <- gsub(pattern = "_TOKEN_ADDRESS_",
                replacement = token_address,
                x = query,
                fixed = TRUE)

  accumulate <- shroomDK::auto_paginate_query(query, api_key)
  return(accumulate)
}
