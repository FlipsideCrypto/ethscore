#' Big Int to Hex
#'
#' Converts extremely large numbers into HEX to make them workable. Most specifically
#' used for NFTs with millions of millions of token IDs. see `get_ens()` as a main example.
#'
#' @param bigint vector of large integers as characters.
#'
#' @return vector of hex with leading 0x and leading 0s to ensure at least 66 length.
#' This 66 length is to best fit Flipside Crypto ENS data.
#' @export
#' @import gmp
#' @examples
#' \dontrun{
#' token_id = "41104824783848331047501863836715107956672917465157448818057950770477717896101"
#' bigint_to_hex(token_i)
#'}
bigint_to_hex <- function(bigint){

  fill_hex <- function(x){
    if(nchar(x) < 66){
      x <- gsub("0x",
                paste0("0x", paste0(rep(0, (66 - nchar(x))), collapse = '')),
                x)
      return(x)
    }
    return(x)
  }

  hx <- paste0("0x", as.character(gmp::as.bigz(bigint), b = 16))
  hx <- unlist(lapply(hx, fill_hex))

  return(hx)
}
