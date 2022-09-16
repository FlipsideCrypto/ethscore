
#' Get Address Activity
#'
#' Gets basic activity information from a set of addresses: number of transactions,
#' number of days active, and last transaction date.
#'
#' @param addresses a character vector of addresses
#' @param block_min Initial block to start scoring balances over time, default 0 (genesis block).
#' @param block_max The block height to assess balance at (for reproducibility).
#' @param api_key Flipside Crypto ShroomDK API Key to create and access SQL queries.
#'
#' @return A data frame of the form:
#' | |  |
#' | ------------- |:-------------:|
#' | ADDRESS       | The EOA or contract that holds the balance |
#' | NUM_TX        | Number of transactions initiated by ADDRESS between block heights. Note, EOA-0tx and contracts may return null. |
#' | NUM_DAYS | Number of unique days with a transaction between block heights |
#' | LAST_TX_DATE | YYYY-MM-DD date (UTC) of last transaction of ADDRESS between block heights  |
#' @export
#'
#' @examples
#' \dontrun{
#' alist <- c("0x39e856863e5f6f0654a0b87b12bc921da23d06bb",
#'  "0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
#' get_address_activity(
#'  addresses = alist,
#'  block_min = 10000000,
#'  block_max = 15000000,
#'  api_key = readLines("api_key.txt")
#'  )
#' }
get_address_activity <- function(addresses,
                                 block_min = 0,
                                 block_max,
                                 api_key){

  query <- {
    "
with select_tx AS (
SELECT BLOCK_TIMESTAMP, TX_HASH, FROM_ADDRESS as ADDRESS FROM ethereum.core.fact_transactions
WHERE FROM_ADDRESS IN ('ADDRESSLIST') AND
BLOCK_NUMBER >= _MIN_BLOCK_ AND
BLOCK_NUMBER <= _MAX_BLOCK_
ORDER BY BLOCK_NUMBER DESC
)

SELECT ADDRESS, COUNT(*) as num_tx,
count(DISTINCT(date_trunc('DAY', block_timestamp))) as num_days,
MAX(block_timestamp) as last_tx_date FROM
select_tx
GROUP BY ADDRESS
"
  }

  alist <- paste0(tolower(addresses), collapse = "','")
  query <- gsub('ADDRESSLIST', replacement = alist, x = query)
  query <- gsub('_MIN_BLOCK_', replacement = block_min, x = query)
  query <- gsub('_MAX_BLOCK_', replacement = block_max, x = query)

  tryCatch({
  select_stats <- auto_paginate_query(query, api_key)
  }, error = function(e){
    stop("No valid EOAs found. EOAs w/o transactions and contracts do not initiate transactions.
         Double check the type of addresses provided.")
  })

  select_stats$LAST_TX_DATE <- as.Date(select_stats$LAST_TX_DATE)

  if(nrow(select_stats) != length(addresses)){
    warning("Some provided addresses may not be available. EOAs w/o transactions
            and contracts do not initiate transactions. Double check the type of
            addresses provided.")
  }

  if(nrow(select_stats) == 1e6){
    warning("shroomDK returns a max of 1M rows. There may be data you missed. You can use multiple requests
            with different address subsets to stitch together data.")
  }

  return(select_stats)

}
