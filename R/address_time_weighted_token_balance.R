#' Time Weighted Address Token Balance
#'
#' Time weighted token balance of an address between 2 block heights.
#' Holding 20 UNI for 10,000 blocks might be more interesting to score than someone
#' buying 20 UNI right before a snapshot for an airdrop.
#'
#' @param token_address ERC20 token contract address to assess balance.
#' @param min_tokens Minimum amount of tokens acknowledged. Already decimal adjusted, useful for
#' ignoring dust balances.
#' @param block_min Initial block to start scoring balances over time, default 0 (genesis block).
#' @param block_max The block height to assess balance at (for reproducibility).
#' @param amount_weighting Weight by amounts held across time, default TRUE. If FALSE, it treats
#' all amounts as binary. Person had at least `min_tokens` at a block or they did not. To NOT
#' weight by time, use `address_token_balance()` instead of this function.
#' @param api_key Flipside Crypto ShroomDK API Key to create and access SQL queries.
#'
#' @return A data frame of the form:
#' | |  |
#' | ------------- |:-------------:|
#' | ADDRESS       | The EOA or contract that holds the balance |
#' | TOKEN_ADDRESS | ERC20 address provided |
#' | time_weighted_score | 1 point per 1 token held per 1,000 blocks (amount_weighting = FALSE is 1 point per 1000 blocks where balance was above min_tokens) |
#' | ADDRESS_TYPE  | If ADDRESS is known to be 'contract address' or 'gnosis safe address'.
#' If neither it is assumed to be an 'EOA'. Some EOAs may have a balance but have never initiated a transaction
#' These are noted as 'EOA-0tx' Note: contracts, including gnosis safes may not have consistent owners across different EVM chains.|
#' @md
#' @export
#' @import jsonlite httr
#' @examples
#' \dontrun{
#' address_time_weighted_token_balance(
#' token_address = tolower("0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"), #UNI token
#'  min_tokens = 0.01,
#'  block_min = 10000000,
#'  block_max = 15000000,
#'  amount_weighting = TRUE,
#'  api_key = readLines("api_key.txt")
#' )
#'}
address_time_weighted_token_balance <- function(token_address, min_tokens = 0.01,
                                                block_min = 0,
                                                block_max,
                                                amount_weighting = TRUE,
                                                api_key){

  # Scientific notation is troublesome in R<>SQL
  block_min <- format(block_min, scientific = FALSE)
  block_max <- format(block_max, scientific = FALSE)


   # see ?address_token_balance for info on NEW_VALUE
  weight = ifelse(amount_weighting, "NEW_VALUE", "1")

  query <- {
    "
WITH block_tracked AS (
   SELECT USER_ADDRESS as address,
           CONTRACT_ADDRESS as token_address,
           BLOCK_NUMBER as block,
           PREV_BAL as old_value,
           CURRENT_BAL as new_value,
           lag(block, 1, _BLOCK_MAX_) over (partition by address, token_address order by block DESC) as holder_next_block
      FROM ETHEREUM.CORE.EZ_BALANCE_DELTAS
    WHERE TOKEN_ADDRESS = '_QUERY_TOKENS_' AND
          BLOCK >= _BLOCK_MIN_ AND
          BLOCK <= _BLOCK_MAX_ AND
          new_value >= _MINVAL_
       ORDER BY address desc, BLOCK desc),

   time_points AS (
-- scale down time points by 1,000 to reduce integer overflow risk
                -- use 1 for any amount, otherwise use NEW_VALUE
       SELECT *, (_WEIGHT_ * (holder_next_block - block) )/1000 as time_points
    FROM block_tracked
    ),

  -- Aggregation here assumes no minimum required points.

 user_tp AS(SELECT address, token_address, sum(time_points) as time_weighted_score
FROM time_points
GROUP BY address, token_address
ORDER BY time_weighted_score DESC
)

SELECT address, token_address, time_weighted_score,
  CASE
    WHEN address IN (SELECT DISTINCT address FROM CROSSCHAIN.CORE.ADDRESS_TAGS WHERE BLOCKCHAIN = 'ethereum' AND TAG_NAME IN ('gnosis safe address')) THEN 'gnosis safe'
    WHEN address IN (SELECT DISTINCT address FROM CROSSCHAIN.CORE.ADDRESS_TAGS WHERE BLOCKCHAIN = 'ethereum' AND TAG_NAME IN ('contract address')) THEN 'contract'
    WHEN address IN (SELECT DISTINCT address FROM flipside_prod_db.crosschain.address_labels WHERE label_type = 'cex') THEN 'EOA-cex'
    WHEN address IN (SELECT DISTINCT address FROM CROSSCHAIN.CORE.ADDRESS_TAGS WHERE BLOCKCHAIN = 'ethereum' AND TAG_NAME IN ('active on ethereum last 7')) THEN 'EOA'
    ELSE 'EOA-0tx'
END as address_type
FROM user_tp
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
  query <- gsub(pattern = "_QUERY_TOKENS_",
                replacement = token_address,
                x = query,
                fixed = TRUE)
  query <- gsub(pattern = "_MINVAL_",
                replacement = min_tokens,
                x = query,
                fixed = TRUE)
  query <- gsub(pattern = "_WEIGHT_",
                replacement = weight,
                x = query,
                fixed = TRUE)

  weighted_holding <- shroomDK::auto_paginate_query(query, api_key)

  weighted_holding$ADDRESS_TYPE[is.na(weighted_holding$ADDRESS_TYPE)] <- "EOA-0tx"

  if(nrow(weighted_holding) == 1e6){
    warning("shroomDK returns a max of 1M rows. There may be data you missed. You can use multiple requests
            with different BLOCK parameters to stitch together data.")
  }

 return(weighted_holding)

}
