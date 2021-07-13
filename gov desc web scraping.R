
library(dplyr)
library(stringr)
library(htmltools)
library(rvest)
library(purrr)
library(aws.s3)

aws.s3::s3load('contractsfinderservice.RData',bucket = 'tender-bot')


portal = 'contractsfinderservice.RData'

key_words = c('engineering', 'data analytics', 'prediction', 'anomaly detection', 'supervised', 'unsupervised', 'machine learning', 'AI', 
              'equipment reliability','machine health','digital innovation','industry 4.0','artificial intelligence','smart factory','data science','data visualisation',
              'maintenance prediction' ,'optimisation' ,'forecast', 'model', 'modelling', 'fault detection', 'automatic', 'automation', 'digital twin')
key_words = paste0("\\b", key_words, "\\b")



content_titles = data.frame(
  title = c(  
    "Notice type",       "Notice Status",       "Closing",           "Contract location",  "Publication date", 
    "Contract value"
    
  )
)


#load(file = "/home/nick/Tender-bot/contractsfinderservice.RData")

old_rows = nrow(master_descriptions)

#Specifying the url for desired website to be scraped
base = 'https://www.contractsfinder.service.gov.uk/Search/Results?&page=%d~dashboard_notices'

# iterate through first x pages and save data to descriptions df
descriptions = map_dfr(1:10, function(i){
  
  cat(".")
  pg <- read_html(sprintf(base, i))
  
  # extract project title
  title_data <- html_nodes(pg, 'div.search-result-header') %>% html_attr('title') %>% unlist()

  # extract project further info url
  link_data <- html_nodes(pg, 'div.search-result-header') %>% html_nodes('a') %>% html_attr('href')  %>% unlist()
  
  # extract project id
  id_data <- html_nodes(pg, 'div.search-result-header') %>% html_nodes('h2') %>% html_attr('id')  %>% unlist()
  
  # extract project abstract/description
  desc_data <- html_nodes(pg, 'div.wrap-text') %>%  html_text() %>% unlist()

  
  
  
  
  
  # count number of key words in each abstract for latest links
  # create of interest column, lookup if sent before
  
  # bind latest projects to master data removing 
  
  
  # extract project title
  
  
  
  result_entries <- html_nodes(pg, 'div.search-result') 
  content_data = map_dfr(result_entries, function(contract){
    titles = contract  %>% html_nodes('div.search-result-entry') %>% html_nodes('strong') %>% html_text
    content = contract %>%html_nodes('div.search-result-entry')%>% html_text()
    
    content = str_remove(content, titles) %>% str_trim()
    results_content_data = data.frame(title = titles, content = content)
    results_content_data = left_join(content_titles, results_content_data, by = 'title') %>%
      tidyr::spread(title, content)
    return(results_content_data)
  })
  
  
  return(data.frame('title' = title_data, 'link' = link_data,'description' = desc_data, 'id' = id_data,content_data))
  
})



descriptions = descriptions %>%
  mutate('Rating' = map(description, function(desc){
    match_counts = str_count(str_to_lower(desc), key_words)
    score = sum(match_counts)
    score
  }))
descriptions= as.data.frame(lapply(descriptions, unlist))
descriptions <- descriptions %>% mutate('interesting' = ifelse(descriptions$Rating < 2, F, T))
descriptions = descriptions %>% left_join(., master_descriptions %>% select(id, sent)) %>%
  mutate(sent = ifelse(is.na(sent), F, sent))  %>% distinct(id, .keep_all = TRUE)



master_descriptions = union(master_descriptions, descriptions, by = 'id') 
new_rows = nrow(master_descriptions)-old_rows


##update master_desriptions 
aws.s3::s3save(master_descriptions,object=portal, bucket='tender-bot')
