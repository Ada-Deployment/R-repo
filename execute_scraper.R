
library(dplyr)
library(stringr)
library(htmltools)
library(rvest)
library(purrr)
library(aws.s3)

tryCatch({
aws.s3::s3load("find-tenderservice.RData", bucket = "tender-bot")
aws.s3::s3load("contractsfinderservice.RData", bucket = "tender-bot")
    aws.s3::s3load("digitalmarketplace.RData", bucket = "tender-bot")
  },
  error = function(e) {
    source("initialise_master_findtender.R")
    source("initialise_master_contractfinder.R")
    source("initialise_digitalmarketplace.R")
  }
)
source("gov desc web scraping.R")
source("gov desc web scraping findtender.R")
source("gov desc web scraping digitalmarketplace.R")
source("email_format.R")
