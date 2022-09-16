

#' Get Ethereum Name Service
#' Identifies ENS NFT names of addresses. Note, currently does not subset to current
#' holder. All historical owners will have the NFT. It is possible non-EOAs have an ENS,
#' e.g., gnosis safe holders and contracts.
#'
#' @param addresses a character vector of addresses
#' @param api_key Flipside Crypto ShroomDK API Key to create and access SQL queries
#'
#' @return Data frame of the form:
#' | |  |
#' | ------------- |:-------------:|
#' | ADDRESS  | EOA Address that held the ENS at least once. |
#' | ENS_NAME | Ethereum Name Service name, traders of ENS NFTs will each show as a historic recipient |
#' | TOKENID  |  ENS NFT Token ID Number (be aware of BIGINT issue) |
#' | HEX_TOKENID | ENS NFT Token ID in HEX form (to mitigate BIGINT issue) |
#' @export
#'
#' @examples
#' \dontrun{
#' get_ens(addresses = "0x39E856863e5F6f0654a0b87B12bc921DA23D06BB",
#'        api_key = readLines("api_key.txt"))
#' }

get_ens <- function(addresses, api_key){

  ens_nfts_query <- {
    "
SELECT BLOCK_NUMBER, NFT_TO_ADDRESS as ADDRESS,
TOKENID FROM ethereum.core.ez_nft_transfers
WHERE NFT_ADDRESS = '0x57f1887a8bf19b14fc0df6fd9b2acc9af147ea85' AND
NFT_TO_ADDRESS IN ('ADDRESSLIST')
"
  }

  addresslist <- tolower(paste0(addresses, collapse = "','"))
  ens_nfts_query <- gsub("ADDRESSLIST", addresslist, ens_nfts_query)
  ens <- auto_paginate_query(ens_nfts_query, api_key)

  ens$HEX_TOKENID <- bigint_to_hex(ens$TOKENID)

  ens_query <- {
    "
SELECT DISTINCT
  event_inputs:name :: STRING as ens_name,
  event_inputs:label :: STRING as hex_tokenid
  from ethereum.core.fact_event_logs
where
hex_tokenid IN ('HEXLIST')
"
  }

  hexlist <- paste0(ens$HEX_TOKENID, collapse = "','")
  ens_query <- gsub("HEXLIST", hexlist, ens_query)

  ens_label <- auto_paginate_query(ens_query, api_key)
  ens_label_full <- ens_label[!is.na(ens_label$ENS_NAME), ]
  eoa_nfts <- merge(ens, ens_label_full, by = 'HEX_TOKENID', all.x = TRUE)
  eoa_label <- unique(eoa_nfts[, c("ADDRESS", "ENS_NAME", "TOKENID", "HEX_TOKENID")])

  return(eoa_label)
}
