library(GetoptLong)

output = "pkg_aliases_db.json"
GetoptLong("output=s", "output")

all_pkg = installed.packages()[, 1]
path = find.package(all_pkg)

db = lapply(path, function(x) {
	d = readRDS(paste0(x, "/help/aliases.rds"))
	d[names(d) != d]
})
names(db) = all_pkg

library(rjson)
writeLines(toJSON(db), output)
