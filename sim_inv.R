
library(tidyverse)
library(readxl)
library(quantmod)

#------------------------------------------------------------------------------#

sim_inv <- function(sim_id) {
  
  sim_db <- '../../data/sim_inv.xlsx'
  
  # Load simulations
  sims <- read_excel(sim_db, sheet = 'simulations')
  
  if (length(sim_name <- sims[sims$id == sim_id, 'name', drop = TRUE]) > 0) {
    cat(paste0(sim_name, '\n\n'))
  } else {
    stop("Unknown simulation.")
  }
  
  # Load simulation transactions
  txns <- read_excel(sim_db, sheet = 'transactions') %>%
    filter(simulation == sim_id)
  
  if (nrow(txns) > 1) {
    start_date <- as.Date(min(txns$date))
    end_date <- as.Date(max(txns$date))
  } else {
    stop("No transactions.")
  }

  # Load prices of transaction assets
  prices <- loadPrices(unique(txns$ticker), start_date, end_date)

  first_price_date <- index(first(prices)) 
  if (first_price_date != start_date) {
    txns[as.Date(txns$date) == start_date, 'date'] <- first_price_date
    start_date <- first_price_date
    cat("Start date changed to first price date.\n\n")
  }
  
  last_price_date <- index(last(prices)) 
  if (last_price_date != end_date) {
    txns[as.Date(txns$date) == end_date, 'date'] <- last_price_date
    end_date <- last_price_date
    cat("End date changed to last price date.\n\n")
  }

  # Loop through transaction dates
  cur_date <- start_date ; posns <- NULL
  while (cur_date <= end_date) {

    # TODO: This should be loop for complex simulations
    cur_date_txns <- txns[txns$date == cur_date, ]
    if (nrow(cur_date_txns) > 0) {
      posns <- doTransaction(cur_date_txns, posns)
    }
  
    posns <- buildPositions(posns)
    
    cur_date <- cur_date + 1
  }
  
  buildPortfolio(posns)
}

#------------------------------------------------------------------------------#

loadPrices <- function(tickers, start_date, end_date) {
  
  Ad(getSymbols(tickers, from = start_date, to = end_date, auto.assign = FALSE))
}

#------------------------------------------------------------------------------#

doTransaction <- function(transaction, positions) {
  
  print(transaction)
  
  positions
}
  
#------------------------------------------------------------------------------#

buildPositions <- function(positions) {
  
  #    cat("\nTODO: Positions calculation\n")
  #    cat("\nTODO: Portfolio calculation\n")
  
  positions
}

#------------------------------------------------------------------------------#

buildPortfolio <- function(positions) {
  
  cat("\nTODO: Portfolio value plotting\n")
  
  print(prices[c(1, nrow(prices)), ])
  
  # coredata(prices[nrow(prices), 1, drop = TRUE]) - coredata(prices[1, 1, drop = TRUE])
  
  return <- coredata(prices[nrow(prices), 1, drop = TRUE])/coredata(prices[1, 1, drop = TRUE])*100
  
  list(return = return, risk = 0.1)
}
