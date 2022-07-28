address_net_on_chain <- function(token_address = tolower("0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9"),
                                 block_min = 15001056,
                                 block_max = 15051056,
                                 decimal_reduction = 18,
                                 api_key){

  # Scientific notation is troublesome in R<>SQL
  block_min <- format(block_min, scientific = FALSE)
  block_max <- format(block_max, scientific = FALSE)

  query <- {
    "
  WITH cex_addresses AS (
    SELECT ADDRESS, LABEL_TYPE
    FROM FLIPSIDE_PROD_DB.ETHEREUM_CORE.DIM_LABELS
    WHERE LABEL_TYPE = 'cex'
),
from_cex AS (
  SELECT *, TO_ADDRESS as user_address, 'FROM_CEX' as txtype
  FROM FLIPSIDE_PROD_DB.ETHEREUM_CORE.FACT_TOKEN_TRANSFERS
  WHERE BLOCK_NUMBER >= _BLOCK_MIN_ AND
        BLOCK_NUMBER <= _BLOCK_MAX_ AND
        CONTRACT_ADDRESS = '_TOKEN_ADDRESS_' AND
        FROM_ADDRESS IN (SELECT ADDRESS FROM cex_addresses) AND
        TO_ADDRESS NOT IN (SELECT ADDRESS FROM cex_addresses)
),
to_cex AS (
  SELECT *,  FROM_ADDRESS as user_address, 'TO_CEX' as txtype
  FROM FLIPSIDE_PROD_DB.ETHEREUM_CORE.FACT_TOKEN_TRANSFERS
  WHERE BLOCK_NUMBER >= _BLOCK_MIN_ AND
        BLOCK_NUMBER <= _BLOCK_MAX_ AND
        CONTRACT_ADDRESS = '_TOKEN_ADDRESS_' AND
        FROM_ADDRESS NOT IN (SELECT ADDRESS FROM cex_addresses) AND
        TO_ADDRESS IN (SELECT ADDRESS FROM cex_addresses)
),

cex_ramp AS (
  SELECT * FROM from_cex UNION SELECT * FROM to_cex
),

-- NOTE 1e18 is standard decimal reduction, but some stablecoins are 1e6
cex_adjusted AS (
  SELECT *, ((RAW_AMOUNT/1e_DECIMAL_REDUCTION_) * IFF(txtype = 'FROM_CEX', 1, -1)) as adjusted_amount
  FROM cex_ramp
  )

  SELECT USER_ADDRESS, SUM(ADJUSTED_AMOUNT) as net_ramped
  FROM cex_adjusted
  GROUP BY USER_ADDRESS;
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
  query <- gsub(pattern = "_DECIMAL_REDUCTION_",
                replacement = decimal_reduction,
                x = query,
                fixed = TRUE)

  net_on_chain <- shroomDK::auto_paginate_query(query, api_key)
  return(net_on_chain)
}
