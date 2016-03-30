#
# Populate p.db with Fitbit data
#
# TODO: real verification of authentication
#
source('pdbauth.R')

library(httr)
library(RSQLite)

# Fitbit authentication
token_url <- 'https://api.fitbit.com/oauth/request_token'
access_url <- 'https://api.fitbit.com/oauth/access_token'
auth_url <- 'https://www.fitbit.com/oauth/authorize'
fitbit <- oauth_endpoint(token_url, auth_url, access_url)

fbtoken <- oauth1.0_token(fitbit, epapp)
sig <- config(token=fbtoken)

pdbf <- '../../OneDrive/References/Data/p.db'
pdbc <- dbConnect(SQLite(), dbname=pdbf)

# Fetch recent days' data
steps <- NULL
ndays <- 10
dateseq <- seq(from=Sys.Date()-ndays, to=Sys.Date()-1, by='day')
#dateseq <- seq(from=as.Date("2015-08-12"), to=as.Date("2015-08-17"), by='day')
for (i in 1:ndays) {

    curdate <- dateseq[i]
    print(paste("Processing", curdate))

    fbsurl <- paste0('https://api.fitbit.com/1/user/-/activities/steps/date/', curdate, '/1d/1min.json')
    jsteps <- GET(fbsurl, sig)
        
    totsteps <- as.numeric(content(jsteps)$'activities-steps'[1][[1]]$value)
    if (totsteps > 1000) {

        dbGetQuery(conn=pdbc, paste0("INSERT OR REPLACE INTO obs VALUES ('infbstep",
            curdate, "', 'kehaline', '", curdate, "', NULL, 'steps', ", totsteps, ", NULL)"))
        
        nmins <- length(content(jsteps)$'activities-steps-intraday'$dataset)
        for (j in 1:nmins) {            
        
            curdt <- paste(curdate, content(jsteps)$'activities-steps-intraday'$dataset[j][[1]]$time)
            curst <- content(jsteps)$'activities-steps-intraday'$dataset[j][[1]]$value
            steps <- cbind(steps, c(curdt, curst))
        }
    }
    
    fbwurl <- paste0('https://api.fitbit.com/1/user/-/body/log/weight/date/', curdate, '.json')
    jweight <- GET(fbwurl, sig)
    
    curm <- content(jweight)$weight
    if (length(curm) > 0) {
        dbGetQuery(conn=pdbc, paste0("INSERT OR REPLACE INTO obs VALUES ('infbwght", curdate, "', 'kehaline', '", 
            paste(curm[[1]]$date, curm[[1]]$time), "', NULL, 'weight', ", curm[[1]]$weight, ", NULL)"))
    }

    fbfurl <- paste0('https://api.fitbit.com/1/user/-/body/log/fat/date/', curdate, '.json')
    jfat <- GET(fbfurl, sig)

    curm <- content(jfat)$fat
    if (length(curm) > 0) {
        dbGetQuery(conn=pdbc, paste0("INSERT OR REPLACE INTO obs VALUES ('infbfat", curdate, "', 'kehaline', '", 
            paste(curm[[1]]$date, curm[[1]]$time), "', NULL, 'fat', ", curm[[1]]$fat, ", NULL)"))
    }
}

#Update infbstep
steps <- t(steps)
colnames(steps) <- c('dtstamp', 'nsteps')
steps <- as.data.frame(steps)

dbWriteTable(pdbc, 'temptable', steps, overwrite=TRUE, row.names=FALSE)
dbGetQuery(conn=pdbc, "INSERT OR REPLACE INTO in_fitbitsteps SELECT * FROM temptable")
print("in_fitbitsteps updated.")

dbDisconnect(pdbc)