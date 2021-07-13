library(dplyr)
library(stringr)
library(htmlTable)
library(emayili)
library(ini)
library(tableHTML)
config <- read.ini("config.ini")

smtp <- emayili::server(
  host = "email-smtp.eu-west-1.amazonaws.com",
  port = 587,
  username = config$DEFAULT$email_user,
  password = config$DEFAULT$email_password
)
portal <- c("find-tenderservice.RData", "contractsfinderservice.RData", "digitalmarketplace.RData")
class(portal)
service <- c("find-tenderservice", "contractsfinderservice", "digitalmarketplace")
class(portal)
table <- map_dfr(portal, function(page) { print(page)
  aws.s3::s3load(object = page, bucket = "tender-bot")
  index <- match(page, portal)
  service_portal <- service[index]
  relevant_contracts <- master_descriptions %>% filter(interesting == TRUE)
  print(nrow(relevant_contracts))
  relevant_contracts <- master_descriptions %>% filter(interesting == TRUE, sent == FALSE)
  print(nrow(relevant_contracts))
  list2 <- rep(service_portal, nrow(relevant_contracts))
  cont_table <- as.data.frame(relevant_contracts %>% select(title, link, Rating, description, Closing))
  cont_table <- cbind(cont_table, Portal = list2)})

scotland <- aws.s3::s3read_using(read.csv, object = "s3://tender-bot/scotlandcontracts.csv")
scotland_relevant <- scotland %>% filter(interesting == "True", sent == "False")
scotland_portal <- rep("publiccontractssotland", nrow(scotland_relevant))
scotland_contracts <- as.data.frame(scotland_relevant %>% select(title, link, Rating, description, Closing)) %>% cbind(Portal = scotland_portal)

for (file in portal) {
  aws.s3::s3load(object = file, bucket = "tender-bot")
  relevant_contracts <- master_descriptions %>% filter(interesting == TRUE, sent == FALSE)
  print(nrow(relevant_contracts))
  master_descriptions <- master_descriptions %>%
    filter(interesting == TRUE) %>%
    mutate(sent = ifelse(title %in% relevant_contracts$title, TRUE, sent))
  aws.s3::s3save(master_descriptions, object = file, bucket = "tender-bot")
}



table <- rbind(table, scotland_contracts)


scotland <- aws.s3::s3read_using(read.csv, object = "s3://tender-bot/scotlandcontracts.csv")
relevant_contracts <- scotland %>% filter(interesting == "True", sent == "False")
print(relevant_contracts)
scotland <- scotland %>% mutate(sent = ifelse(title %in% relevant_contracts$title & interesting == "True", "True", sent))
aws.s3::s3write_using(scotland,
  object = "s3://tender-bot/scotlandcontracts.csv",
  FUN = write.csv,
  bucket = "tender-bot",
  row.names = FALSE
)


new_rows <- nrow(table)
if (new_rows == 0) {
  body <- paste0("<h4>No new contracts found this week</h4>")
} else {
  table <- table[order(table$Rating, decreasing = TRUE), ]
  table <- tableHTML(data.frame(title = make_hyperlink(table$link, table$title), Rating = table$Rating, Description = table$description, Closing = table$Closing, Portal = table$Portal), escape = FALSE)
  # table = table%>% htmlTable::addHtmlTableStyle(align = "l",
  #                                               css.cell = '
  #                                                  background-color: #f7f7f7; font-family: "Roboto";
  #                                                  color: #105474;
  #                                                  border-top: 1px solid #105474;
  #                                                  border-bottom: 1px solid #105474;
  #                                                  border: 1px solid #105474;
  #                                                  font-family: "Roboto";
  #                                                  text-align: left;',
  #                                               css.tspanner	= 'text-align: left;',
  #                                               css.tspanner.sep	= 'text-align: left;',
  #                                               css.table = 'text-align: left;',
  #                                               css.header = 'background-color: #1bc691;
  #                                                  color: #105474;
  #                                                  font-family: "Roboto";')  %>%
  # htmlTable::htmlTable(rnames = F, caption = paste('Contracts'))

  start <- paste0("Found ", new_rows, " relevant new contracts")
  body <- paste(start, table)
}

email <- emayili::envelope(
  to = "samaravazquezperez@ada-mode.com", "nickbarton@ada-mode.com", "jacklewis@ada-mode.com", "daneveritt@ada-mode.com",
  from = "notifications@ada-atlas.com",
  subject = paste("Ada-bot: contract scraper found", new_rows, "new contracts"),
  html = body
)



smtp(email, verbose = F)

rm(smtp, email)
