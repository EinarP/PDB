# ------------------------------------------------------------------------------
# Populate p.db with Fitbit data
# ------------------------------------------------------------------------------
source('../private/pdbauth.R')
fbt <- getTokenFit()

# Fetch recent days' data
steps <- NULL
fb_base <- 'https://api.fitbit.com/1/user/-/'

dateseq <- seq(from = Sys.Date() - 5, to = Sys.Date() - 1, by = 'day')
# dateseq <- seq(from = as.Date("2018-04-05"), to=as.Date("2018-04-06"), by='day')
for (i in seq_along(dateseq)) {

    cur_date <- dateseq[i]
    print(paste("Processing", cur_date))
    
    # Fetch steps
    fbsurl <- paste0(fb_base, 'activities/steps/date/', cur_date, '/1d/1min.json')
    jsteps <- GET(fbsurl, fbt)
        
    totsteps <- as.numeric(content(jsteps)$'activities-steps'[1][[1]]$value)
    if (totsteps > 1000) {
        dbGetQuery(conn=pdbc, paste0("INSERT OR REPLACE INTO obs VALUES ('infbstep",
            cur_date, "', 'kehaline', '", cur_date, "', NULL, 'steps', ", totsteps, ", NULL)"))
        
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
        dbGetQuery(conn=pdbc, paste0("INSERT OR REPLACE INTO obs VALUES ('infbwght", cur_date, "', 'kehaline', '", 
            paste(curm[[1]]$date, curm[[1]]$time), "', NULL, 'weight', ", curm[[1]]$weight, ", NULL)"))
    }

    # Fetch fat%
    fbfurl <- paste0(fb_base, 'body/log/fat/date/', cur_date, '.json')
    jfat <- GET(fbfurl, fbt)

    curm <- content(jfat)$fat
    if (length(curm) > 0) {
        dbGetQuery(conn=pdbc, paste0("INSERT OR REPLACE INTO obs VALUES ('infbfat", cur_date, "', 'kehaline', '", 
            paste(curm[[1]]$date, curm[[1]]$time), "', NULL, 'fat', ", curm[[1]]$fat, ", NULL)"))
    }
    
    # Fetch exercise
    url <- paste0(fb_base, 'activities/list.json?afterDate=', cur_date, '&offset=0&limit=1&sort=asc')
    resp <- content(GET(url, fbt))
    
    a <- resp$activities[[1]]
    if (as.Date(a$startTime) == cur_date) {
      if (a$activityName %in% c('Walk', 'Run')) {
        
        ins <- 'INSERT OR REPLACE INTO obs2 (id, object, property, value) VALUES ('
        
        id <- paste0("'", paste(a$activityName, a$startTime, sep = '_'), "'")
        object <- paste0("'", tolower(a$activityName), "'")
        
        vals <- paste(id, object, "'start_time'", paste0("'", a$startTime, "'"), sep = ', ')
        dbGetQuery(conn = pdbc, paste0(ins, vals, ')'))
        
        vals <- paste(id, object, "'distance'", paste0("'", a$distance, "'"), sep = ', ')
        dbGetQuery(conn = pdbc, paste0(ins, vals, ')'))
        
        vals <- paste(id, object, "'speed'", paste0("'", a$speed, "'"), sep = ', ')
        dbGetQuery(conn = pdbc, paste0(ins, vals, ')'))
      }
    }
}

# Update infbstep
steps <- t(steps)
colnames(steps) <- c('dtstamp', 'nsteps')
steps <- as.data.frame(steps)

dbWriteTable(pdbc, 'temptable', steps, overwrite=TRUE, row.names=FALSE)
dbGetQuery(conn=pdbc, "INSERT OR REPLACE INTO in_fitbitsteps SELECT * FROM temptable")
print("in_fitbitsteps updated.")

dbDisconnect(pdbc)