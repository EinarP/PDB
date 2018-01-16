#
# Populate p.db with Fitbit data
#
# TODO: real verification of being authenticated
#
source('../private/pdbauth.R')

fitbit <- oauth_endpoint(
  authorize='https://www.fitbit.com/oauth2/authorize',
  access='https://api.fitbit.com/oauth2/token')

ep_fit <- oauth_app(appname=fit_app, key=fit_client, secret=fit_secret)

fit_token <- oauth2.0_token(
  endpoint =  fitbit,
  app = ep_fit,
  scope=c('activity', 'nutrition', 'sleep', 'weight'),
  use_basic_auth=TRUE
)

sig <- config(token=fit_token)

# Fetch recent days' data
steps <- NULL

dateseq <- seq(from=Sys.Date()-5, to=Sys.Date()-1, by='day')
# dateseq <- seq(from=as.Date("2017-04-17"), to=as.Date("2017-08-16"), by='day')
for (i in seq_along(dateseq)) {

    curdate <- dateseq[i]
    print(paste("Processing", curdate))
    
    # Fetch steps
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

    # Fetch weight
    fbwurl <- paste0('https://api.fitbit.com/1/user/-/body/log/weight/date/', curdate, '.json')
    jweight <- GET(fbwurl, sig)
    
    curm <- content(jweight)$weight
    if (length(curm) > 0) {
        dbGetQuery(conn=pdbc, paste0("INSERT OR REPLACE INTO obs VALUES ('infbwght", curdate, "', 'kehaline', '", 
            paste(curm[[1]]$date, curm[[1]]$time), "', NULL, 'weight', ", curm[[1]]$weight, ", NULL)"))
    }

    # Fetch fat%
    fbfurl <- paste0('https://api.fitbit.com/1/user/-/body/log/fat/date/', curdate, '.json')
    jfat <- GET(fbfurl, sig)

    curm <- content(jfat)$fat
    if (length(curm) > 0) {
        dbGetQuery(conn=pdbc, paste0("INSERT OR REPLACE INTO obs VALUES ('infbfat", curdate, "', 'kehaline', '", 
            paste(curm[[1]]$date, curm[[1]]$time), "', NULL, 'fat', ", curm[[1]]$fat, ", NULL)"))
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