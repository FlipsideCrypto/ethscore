
#' Address Token Transfer Volume
#'
#' Total transfer volume of a token between two block heights. Ignores direction of transfer.
#' Alice traded/transferred a total of 2,000 UNI between blocks 10,000,000 and 15,000,000.
#'
#' @param token_address ERC20 token contract address to assess change in balance.
#' @param block_min Initial block to start scoring balances over time, default 0 (genesis block).
#' @param block_max The block height to assess balance at (for reproducibility).
#' @param min_tokens Minimum amount of tokens acknowledged. Already decimal adjusted, useful for
#' ignoring dust balances. Default 1.
#' @param api_key Flipside Crypto ShroomDK API Key to create and access SQL queries.
#'
#' @return A data frame of the form:
#' | |  |
#' | ------------- |:-------------:|
#' | ADDRESS | The EOA or contract with the volume |
#' | TOKEN_ADDRESS | ERC20 address provided |
#' | VOLUME | amount of tokens transferred/traded between block_min and block_max |
#' | ADDRESS_TYPE  | If ADDRESS is known to be 'contract address' or 'gnosis safe address'.
#' If neither it is assumed to be an 'EOA'. Some EOAs may have a balance but have never initiated a transaction
#' These are noted as 'EOA-0tx' Note: contracts, including gnosis safes may not have consistent owners across different EVM chains.|
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
      SELECT
      BLOCK_NUMBER as block,
      CONTRACT_ADDRESS as token_address,
      USER_ADDRESS as address,
      (CURRENT_BAL - PREV_BAL) as CHANGE
      FROM ETHEREUM.CORE.EZ_BALANCE_DELTAS
      WHERE BLOCK >= _BLOCK_MIN_ AND
      BLOCK <= _BLOCK_MAX_ AND
      TOKEN_ADDRESS = '_TOKEN_ADDRESS_'
      ORDER BY BLOCK DESC
    ),

    -- net change can be negative between blocks, 0 (often bots/aggregators), or positive (accumulation)

    address_volume AS (
      SELECT address, token_address, SUM(ABS(CHANGE)) as VOLUME
      FROM token_changes
      GROUP BY address, token_address
      HAVING VOLUME > _MIN_TOKENS_
    )


    -- include ability to filter out contract addresses if desired

    SELECT address_volume.address,
    token_address,
    VOLUME,
     CASE
    WHEN address IN (SELECT DISTINCT address FROM CROSSCHAIN.CORE.ADDRESS_TAGS WHERE BLOCKCHAIN = 'ethereum' AND TAG_NAME IN ('gnosis safe address')) THEN 'gnosis safe'
    WHEN address IN (SELECT DISTINCT address FROM CROSSCHAIN.CORE.ADDRESS_TAGS WHERE BLOCKCHAIN = 'ethereum' AND TAG_NAME IN ('contract address')) THEN 'contract'
    WHEN address IN (SELECT DISTINCT address FROM CROSSCHAIN.CORE.ADDRESS_TAGS WHERE BLOCKCHAIN = 'ethereum' AND TAG_NAME IN ('active on ethereum last 7')) THEN 'EOA'
    ELSE 'EOA-0tx'
END as address_type
    FROM address_volume

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

  volume$ADDRESS_TYPE[is.na(volume$ADDRESS_TYPE)] <- "EOA-0tx"

  if(nrow(volume) == 1e6){
    warning("shroomDK returns a max of 1M rows. There may be data you missed. You can use multiple requests
            with different BLOCK parameters to stitch together data.")
  }


  return(volume)
}
