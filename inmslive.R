# ------------------------------------------------------------------------------
# Populate p.db with Outlook data
# ------------------------------------------------------------------------------

source('../private/pdbauth.R')
mst <- getTokenMs()

olk_base <- 'https://graph.microsoft.com/v1.0/me/'

cal <- paste0(olk_base,
  'calendarView?startDateTime=2018-01-13T00:00:00&endDateTime=2018-01-15T00:00:00')
resp <- GET(cal, mst) 

# Worked in graph explorer
"https://graph.microsoft.com/v1.0/me/calendarView?startDateTime=2018-01-19&endDateTime=2018-01-20"