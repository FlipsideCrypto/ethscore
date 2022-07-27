#' Title
#'
#' @param token_address
#' @param min_tokens
#' @param block_min
#' @param block_max
#' @param amount_weighting
#' @param api_key
#'
#' @return
#' @export
#'
#' @examples
address_time_weighted_token_balance <- function(token_address, min_tokens = 0.0001,
                                                block_min = 0,
                                                block_max,
                                                amount_weighting = TRUE,
                                                api_key){

  weight = ifelse(amount_weighting, "NEW_VALUE", "1")

  query <- {
    "
WITH block_tracked AS (
    SELECT  BLOCK as block,
            TX_HASH AS hash,
            TOKEN_ADDRESS as token_address,
            SYMBOL AS symbol,
            HOLDER as address,
            PREV_VALUE as old_value,
            CURR_VALUE as new_value,
           -- max block is the cutoff block number for airdrop eligibility; do not use default 0
           -- lag(block, 1, block max)
           lag(block, 1, _BLOCK_MAX_) over (partition by address, token_address order by block DESC) as holder_next_block
    FROM flipside_prod_db.tokenflow_eth.tokens_balance_diffs
    WHERE TOKEN_ADDRESS = '_QUERY_TOKENS_' AND
          BLOCK >= _BLOCK_MIN_ AND
          BLOCK <= _BLOCK_MAX_ AND
          new_value >= _MINVAL_
       ORDER BY address desc, BLOCK desc),

   time_points AS (
-- scale down time points by 10K to reduce integer overflow risk
                -- use 1 for any amount, otherwise use NEW_VALUE
       SELECT *, (_WEIGHT_ * (holder_next_block - block) )/10000 as time_points
    FROM block_tracked
    )

  -- Aggregation here assumes no minimum required points.

    SELECT address, token_address, sum(time_points) as _timepoints
FROM time_points
GROUP BY address, token_address
ORDER BY _timepoints DESC;
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

  amount_holding <- shroomDK::auto_paginate_query(query, api_key)

 return(amount_holding)

}
