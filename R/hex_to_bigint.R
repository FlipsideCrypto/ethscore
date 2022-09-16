#' Hex to Big Int
#'
#' Converts HEX to extremely large numbers to make them workable. Most specifically
#' used for NFTs with millions of millions of token IDs. see `get_ens()` as a main example.
#'
#' @param hex Hex to convert to big integer. Leading 0s are appropriately ignored.
#'
#' @return vector of big integer in character format.
#' @export
#' @import gmp
#'
#' @examples
#' \dontrun{
#' hex = "0x2aea5a3e13081115c6fcc5503f7ce0d950a8dfc5eaf871"
#' bigint_to_hex(token_i)
#'}
hex_to_bigint <- function(hex){
    as.character(gmp::as.bigz(hex))
}
