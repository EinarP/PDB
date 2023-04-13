# ------------------------------------------------------------------------------
# Populate p.db with Fitbit data
# 
# TODO: Get rid of warnings (SQL statements must be issued with dbExecute() 
#     or dbSendStatement() instead of dbGetQuery() or dbSendQuery()
# ------------------------------------------------------------------------------
source('../../private/pdbauth.R')
fbt <- getTokenFit()
 
# Insert observations into obs table
insc_base <- 'INSERT OR REPLACE INTO obs (id, object, property, value, checkpoint, source) VALUES ('

# Fetch recent days' data
steps <- NULL
fb_base <- 'https://api.fitbit.com/1/user/-/'

dateseq <- seq(from = Sys.Date() - 5, to = Sys.Date() - 1, by = 'day')
#dateseq <- seq(from = as.Date("2020-01-29"), to=as.Date("2020-01-29"), by='day')
for (i in seq_along(dateseq)) {

  cur_date <- dateseq[i]
  print(paste("Processing", cur_date))
    
  # Fetch steps
  fbsurl <- paste0(fb_base, 'activities/steps/date/', cur_date, '/1d/1min.json')
  jsteps <- GET(fbsurl, fbt)
        
  totsteps <- as.numeric(content(jsteps)$'activities-steps'[1][[1]]$value)
  if (totsteps > 1000) {

    id <- paste0("'infbstep", cur_date, "'")
    ckpt <- paste0("'", cur_date, "'")
    source <- paste0("'", fbsurl, "'")
    vals <- paste(id, "'steps', 'count'", totsteps, ckpt, source, sep = ', ')
    dbGetQuery(conn = pdbc, paste0(insc_base, vals, ')'))
      
    nmins <- length(content(jsteps)$'activities-steps-intraday'$dataset)
    for (j in 1:nmins) {            
      curdt <- paste(cur_date, content(jsteps)$'activities-steps-intraday'$dataset[j][[1]]$time)
      curst <- content(jsteps)$'activities-steps-intraday'$dataset[j][[1]]$value
      steps <- cbind(steps, c(curdt, curst))
    }
  } 

  # Fetch weight
  fbwurl <- paste0(fb_base, 'body/log/weight/date/', cur_date, '.json')
  jweight <- GET(fbwurl, fbt)
    
  curm <- content(jweight)$weight
  if (length(curm) > 0) {
    id <- paste0("'infbwght", cur_date, "'")
    ckpt <- paste0("'", paste(curm[[1]]$date, curm[[1]]$time), "'")
    source <- paste0("'", fbwurl, "'")
    vals <- paste(id, "'body', 'weight'", curm[[1]]$weight, ckpt, source, sep = ', ')
    dbGetQuery(conn = pdbc, paste0(insc_base, vals, ')'))
  }

  # Fetch fat%
  fbfurl <- paste0(fb_base, 'body/log/fat/date/', cur_date, '.json')
  jfat <- GET(fbfurl, fbt)

  curm <- content(jfat)$fat
  if (length(curm) > 0) {
    id <- paste0("'infbfat", cur_date, "'")
    ckpt <- paste0("'", paste(curm[[1]]$date, curm[[1]]$time), "'")
    source <- paste0("'", fbfurl, "'")
    vals <- paste(id, "'body', 'fat'", curm[[1]]$fat, ckpt, source, sep = ', ')
    dbGetQuery(conn = pdbc, paste0(insc_base, vals, ')'))
  }
    
  # Fetch exercise
  url <- paste0(fb_base, 'activities/list.json?afterDate=', cur_date, '&offset=0&limit=1&sort=asc')
  resp <- content(GET(url, fbt))
  if (length(resp$activities) > 0) {
    a <- resp$activities[[1]]
    if (as.Date(a$startTime) == cur_date) {
      if (a$activityName %in% c('Walk', 'Run')) {
        if (a$distance != "") {
       
          object <- tolower(a$activityName)
          ckpt <- a$startTime

          id <- paste(object, "start_time", a$startTime, sep = '_')
          vals <- paste(id, object, "start_time", a$startTime, ckpt, url, sep = "', '") 
          dbGetQuery(conn = pdbc, paste0(insc_base, "'", vals, "')"))
  
          id <- paste(object, "distance", a$startTime, sep = '_')
          vals <- paste(id, object, "distance", a$distance, ckpt, url, sep = "', '")
          dbGetQuery(conn = pdbc, paste0(insc_base, "'", vals, "')"))
  
          id <- paste(object, "speed", a$startTime, sep = '_')
          vals <- paste(id, object, "speed", a$speed, ckpt, url, sep = "', '")
          dbGetQuery(conn = pdbc, paste0(insc_base, "'", vals, "')"))
        }
      }
    }
  }
}

# Update detailed steps data
steps <- t(steps)
colnames(steps) <- c('dtstamp', 'nsteps')
steps <- as.data.frame(steps)

dbWriteTable(pdbc, 'temptable', steps, overwrite=TRUE, row.names=FALSE)
dbGetQuery(conn=pdbc, "INSERT OR REPLACE INTO det_steps SELECT * FROM temptable")
print("in_fitbitsteps updated.")

dbDisconnect(pdbc)