#' Address Token Net Onto-Chain
#'
#' Net transfer amount of tokens from a central exchange between two block heights.
#' By default excludes net sellers. Alice net received 200 UNI from central exchanges
#' between blocks 10,000,000 and 15,000,000.
#'
#' @param token_address ERC20 token contract address to assess change in balance.
#' @param block_min Initial block to start scoring balances over time, default 0 (genesis block).
#' @param block_max The block height to assess balance at (for reproducibility).
#' @param decimal_reduction Most ERC20 have 18 decimals, but stablecoins often have only 6.
#' @param min_tokens Minimum amount of tokens acknowledged. Already decimal adjusted, useful for
#' ignoring dust balances. Default 0.0001. Use -Inf to include net sellers (but note: API max is 1M rows.).
#' @param api_key Flipside Crypto ShroomDK API Key to create and access SQL queries.
#'
#' @return A data frame of the form:
#' | |  |
#' | ------------- |:-------------:|
#' | ADDRESS       | The EOA or contract that holds the balance |
#' | TOKEN_ADDRESS | ERC20 address provided |
#' | NET_ONTO_CHAIN | net amount of token taken from central exchanges between block_min and block_max |
#' | ADDRESS_TYPE  | If ADDRESS is known to be 'contract address' or 'gnosis safe address'.
#' If neither it is assumed to be an 'EOA'. Some EOAs may have a balance but have never initiated a transaction
#' These are noted as 'EOA-0tx' Note: contracts, including gnosis safes may not have consistent owners across different EVM chains.|
#' @md
#' @export
#' @import jsonlite httr
#' @examples
#' \dontrun{
#' address_net_on_chain(
#' token_address = tolower("0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"), #UNI token
#'  block_min = 10000000,
#'  block_max = 15000000,
#'  decimal_reduction = 18,
#'  min_tokens = 1,
#'  api_key = readLines("api_key.txt")
#' )
#'}
address_net_on_chain <- function(token_address,
                                 block_min = 0,
                                 block_max,
                                 decimal_reduction = 18,
                                 min_tokens = 1,
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
  ),

user_ontochain AS(SELECT USER_ADDRESS as ADDRESS, CONTRACT_ADDRESS as TOKEN_ADDRESS,
  SUM(ADJUSTED_AMOUNT) as NET_ONTO_CHAIN
  FROM cex_adjusted
  GROUP BY ADDRESS, TOKEN_ADDRESS
  HAVING NET_ONTO_CHAIN >= _MIN_TOKENS_
),

  address_type AS (
SELECT DISTINCT address,
IFF(TAG_NAME IN ('contract address', 'gnosis safe address'),
    TAG_NAME, 'EOA') as address_type
FROM CROSSCHAIN.CORE.ADDRESS_TAGS
WHERE BLOCKCHAIN = 'ethereum'
)

SELECT   user_ontochain.address, token_address, NET_ONTO_CHAIN,
 address_type
FROM user_ontochain LEFT JOIN
  address_type ON
  user_ontochain.address = address_type.address
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
  query <- gsub(pattern = "_MIN_TOKENS_",
                replacement = min_tokens,
                x = query,
                fixed = TRUE)

  net_on_chain <- shroomDK::auto_paginate_query(query, api_key)

  net_on_chain$ADDRESS_TYPE[is.na(net_on_chain$ADDRESS_TYPE)] <- "EOA-0tx"

  if(nrow(net_on_chain) == 1e6){
    warning("shroomDK returns a max of 1M rows. There may be data you missed. You can use multiple requests
            with different BLOCK parameters to stitch together data.")
  }


  return(net_on_chain)
}
