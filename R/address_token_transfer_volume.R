
#' Address Token Transfer Volume
#'
#' Total transfer volume of a token between two block heights. Ignores direction of transfer.
#' Alice traded/transferred a total of 2,000 UNI between blocks 10,000,000 and 15,000,000.
#'
#' @param token_address ERC20 token contract address to assess change in balance.
#' @param block_min Initial block to start scoring balances over time, default 0 (genesis block).
#' @param block_max The block height to assess balance at (for reproducibility).
#' @param min_tokens Minimum amount of tokens acknowledged. Already decimal adjusted, useful to
#' ignoring dust balances. Default 1.
#' @param api_key Flipside Crypto ShroomDK API Key to create and access SQL queries.
#'
#' @return A data frame of the form:
#' | |  |
#' | ------------- |:-------------:|
#' | ADDRESS | The EOA or contract with the volume |
#' | VOLUME | amount of tokens transferred/traded between block_min and block_max |
#' @md
#' @export
#' @import jsonlite httr
#' @examples
#' \dontrun{
#' address_transfer_volume(
#' token_address = tolower("0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"), #UNI token
#'  block_min = 10000000,
#'  block_max = 15000000,
#'  min_tokens = 10,
#'  api_key = readLines("api_key.txt")
#' )
#'}
address_transfer_volume <- function(token_address,
                                    block_min = 0,
                                    block_max,
                                    min_tokens = 1,
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
)

-- ignoring direction of change (absolute value) and summing is volume of change
SELECT HOLDER as user_address, SUM(ABS(CHANGE)) as VOLUME
FROM token_changes
 GROUP BY HOLDER
 HAVING VOLUME >= _MIN_TOKENS_
    "
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

  query <- gsub(pattern = "_MIN_TOKENS_",
                replacement = min_tokens,
                x = query,
                fixed = TRUE)


  volume <- shroomDK::auto_paginate_query(query, api_key)
  return(volume)
}
