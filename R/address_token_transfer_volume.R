
address_transfer_volume <- function(token_address,
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
)

-- ignoring direction of change (absolute value) and summing is volume of change
SELECT HOLDER as user_address, SUM(ABS(CHANGE)) as VOLUME
FROM token_changes
 GROUP BY HOLDER
 ORDER BY VOLUME DESC;
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

  volume <- shroomDK::auto_paginate_query(query, api_key)
  return(volume)
}
