#
# Populate p.db from PDB.xlsx
#
source('../private/pdbauth.R')

library(readxl)
pdbxl <- paste(pdbdir, "pdb.xlsx", sep="/")
inxl <- read_excel(pdbxl)
inxl$dtstart <- as.character(inxl$dtstart)
inxl$dtend <- as.character(inxl$dtend)

#idpfx <- paste0("inxlimp", format(Sys.Date(), "%Y%m%d"), "-")
#inxl[is.na(inxl$id), "id"] <- paste0(idpfx, sprintf("%04d", seq(1:sum(is.na(inxl["id"])))))

#newrecs <- inxl[substr(inxl$id, 1, nchar(idpfx))==idpfx, ]
dbWriteTable(pdbc, 'temptable', as.data.frame(inxl), overwrite=T, row.names=F)
dbGetQuery(conn=pdbc, "INSERT OR REPLACE INTO obs SELECT * FROM temptable")
dbDisconnect(pdbc)

#write.xlsx(inxl, pdbxl, sheetName="out", row.names=F, showNA=F, append=T)

print("obs updated from PDB.xlsx.")
