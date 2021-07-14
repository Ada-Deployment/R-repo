

key_words <- c(
  "engineering", "data analytics", "prediction", "anomaly detection", "supervised", "unsupervised", "machine learning", "AI",
  "equipment reliability", "machine health", "digital innovation", "industry 4.0", "artificial intelligence", "smart factory", "data science", "data visualisation",
  "maintenance prediction", "optimisation", "forecast", "model", "modelling", "fault detection", "automatic", "automation", "digital", "digital twin"
)
key_words <- paste0("\\b", key_words, "\\b")

main <- "https://www.digitalmarketplace.service.gov.uk"

portal <- c("digitalmarketplace.RData")
class(portal)
base <- "https://www.digitalmarketplace.service.gov.uk/digital-outcomes-and-specialists/opportunities?page="
pages <- paste0(base, 1:10)
master_descriptions <- map_df(pages, function(j) {
  cat(".")
  page <- read_html(j)

  result_entries <- html_nodes(page, "li.app-search-result")

  descriptions <- map_dfr(result_entries, function(i) {
    # get basic info: title, description, link
    titles_data <- i %>%
      html_nodes("h2") %>%
      html_text()
    link <- i %>%
      html_nodes("h2") %>%
      html_nodes("a") %>%
      html_attr("href") %>%
      unlist()
    link <- paste0(main, link)
    content_data <- i %>%
      html_nodes("p") %>%
      html_text()
    # rest of information nodes
    content_entries <- i %>% html_nodes("ul")

    # get org and location
    content <- content_entries[1] %>% html_nodes("li")
    org <- content[1] %>% html_text()
    loc <- content[2] %>% html_text()
    first_ <- data.frame(org, loc)

    # get area
    content <- content_entries[2] %>% html_node("li")
    area <- content[1] %>% html_text()
    type <- data.frame(area)

    # get deadlines
    content <- content_entries[3] %>% html_nodes("li")
    len <- length(content)

    if (len != 1) {
      published <- content[1] %>% html_text()
      questions <- content[2] %>% html_text()
      Closing <- content[3] %>% html_text()
    } else {
      published <- "NA"
      questions <- "NA"
      Closing <- content[1] %>% html_text()
    }
    deadlines <- data.frame(published, questions, Closing)


    # combine together
    result <- data.frame("title" = titles_data, "description" = content_data, "link" = link, first_, type, deadlines)

    return(result)
  })
})

master_descriptions <- master_descriptions %>%
  mutate("Rating" = map(description, function(desc) {
    match_counts <- str_count(str_to_lower(desc), key_words)
    score <- sum(match_counts)
    score
  }))
master_descriptions <- as.data.frame(lapply(master_descriptions, unlist))
master_descriptions <- master_descriptions %>%
  mutate("interesting" = ifelse(master_descriptions$Rating < 1, F, T)) %>%
  mutate("sent" = FALSE) %>%
  distinct(title, .keep_all = TRUE)

file <- save(master_descriptions, file = portal) ## will create an object called master_descriptions, not the name of the file
aws.s3::s3save(master_descriptions, object = portal, bucket = "tender-bot")
