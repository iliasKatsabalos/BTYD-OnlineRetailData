install.packages('BTYD')
library(dplyr)
library(hypergeo)
library(BTYD)
# We import the fixed functions from Pareto/NBD model. The standard BTYD produces errors
# when transactions per customer are above 100
source("pnbd.R")


#Read the csv file with the retail Data
retail <- read.csv("UKretail.csv", header=TRUE)

#Find if any columns contain NA Data
nacols <- function(df) {
  colnames(df)[unlist(lapply(df, function(x) any(is.na(x))))]
}
retail.na<-nacols(retail)

# We are not interested in the NA in Description column
# But the NAs in CustomerID are not helpful. We have to ommit them in order to make predictions in customer level
retail.full<-retail[complete.cases(retail['CustomerID']),]

# Get the line total 
retail.full['Line_Total'] <- with(retail.full,  retail.full['Quantity'] * retail.full['UnitPrice'])

# Format the date as we need only the date part
retail.full['InvoiceDate'] <- format(as.Date(retail.full[['InvoiceDate']],format="%Y-%m-%d"))

# Remove all returns. We are interested in customer action and not amount of sales
retail.full <- filter(retail.full,substr(retail.full$InvoiceNo,0,1)!="C")

# Group the dataset by customerID and InvoiceDate in order to format it for PARETO/NBD
retail.grouped<-aggregate(retail.full['Line_Total'], by=list(retail.full$CustomerID,retail.full$InvoiceDate), FUN=sum)
colnames(retail.grouped) <- c("cust","date","sales")
                                 
# Split our Dataset into Calibration(Train) and Holdout period(Test)
uniqueDates <- lapply(retail.grouped, unique)
n<-length(uniqueDates$date)

elog<-retail.grouped
end.of.cal.period<-uniqueDates$date[0.8*n]
elog.cal<-filter(elog,elog$date<=end.of.cal.period)

# We are interested at the moment in those customers who made at least 2 transactions
split.data<-dc.SplitUpElogForRepeatTrans(elog.cal)
clean.elog <- split.data$repeat.trans.elog

# We create a Customer by Time matrix
freq.cbt<-dc.CreateFreqCBT(clean.elog)


# Because we have lost customers with 0 repeat transactions, we create another CBT matrix
# with the full Dataset, and merge the two matrices on customerID
tot.cbt<-dc.CreateFreqCBT(elog)
cal.cbt<-dc.MergeCustomers(tot.cbt, freq.cbt)


# We need to create a Customer by Statistic dataset with the following columns
#Number of trans in calibration period/Date of Last Trans/Total time we study the customer
birth.periods<-split.data$cust.data$birth.per
last.dates<-split.data$cust.data$last.date
cal.cbs.dates<-data.frame(birth.periods, last.dates, end.of.cal.period)
cal.cbs <- dc.BuildCBSFromCBTAndDates(cal.cbt,cal.cbs.dates, per='day')

# We estimate the parameters of the NBD (r,a) and the Pareto (s,beta) model
params<-pnbd.EstimateParameters(cal.cbs)
# We estimate the log likelihood of the parameters
ll<-pnbd.cbs.LL(params,cal.cbs)

#optimization - See if the model converges
p.matrix<-c(params,ll)

for (i in 1:9){
  params<-pnbd.EstimateParameters(cal.cbs, params)
  ll<-pnbd.cbs.LL(params, cal.cbs)
  p.matrix.row<-c(params,ll)
  p.matrix<-rbind(p.matrix,p.matrix.row)
}
colnames(p.matrix)<-c("r","alpha","s","beta","LL")
rownames(p.matrix)<-1:10
p.matrix
params <- p.matrix[10,1:4]


# Plotting Goodness of fit on train-calibration period
pnbd.PlotFrequencyInCalibration(params, cal.cbs, 7)

# Plotting Goodness of fit in test - holdout period. We need to create a similar
# customer by statistic matrix for the holdout period
elog <- dc.SplitUpElogForRepeatTrans(elog)$repeat.trans.elog
x.star<-rep(0, nrow(cal.cbs))
cal.cbs<-cbind(cal.cbs,x.star)
elog.custs <- elog$cust
for (i in 1:nrow(cal.cbs)){
  current.cust <- rownames(cal.cbs)[i]
  tot.cust.trans <- length(which(elog.custs==current.cust))
  cal.trans <- cal.cbs[i, "x"]
  cal.cbs[i, "x.star"] <- tot.cust.trans - cal.trans
}

T.star <- 91
censor <- 7
x.star <- cal.cbs[,"x.star"]
comp <- pnbd.PlotFreqVsConditionalExpectedFrequency(params, T.star, cal.cbs, x.star, censor)
rownames(comp)<-c('act','pred','bin')
comp


# Mean squared error of model
predictions <- pnbd.ConditionalExpectedTransactions(params,
                                                    T.star = 91,
                                                    x = cal.cbs[,"x"],
                                                    t.x = cal.cbs[,"t.x"],
                                                    T.cal = cal.cbs[,"T.cal"])
actual <- cal.cbs[,"x.star"]
mse <- mean((predictions-actual)^2)
mse

# Is this anny better than a dummmy classifier?
averages <- (cal.cbs[,"x"]/cal.cbs[,"T.cal"])*91
error <- mean((averages-actual)^2, na.rm = TRUE)
error

# We train the model in the whole Dataset to make new predictions

final<-retail.grouped
split.data<-dc.SplitUpElogForRepeatTrans(final)
clean.elog <- split.data$repeat.trans.elog
freq.cbt<-dc.CreateFreqCBT(clean.elog)
tot.cbt<-dc.CreateFreqCBT(final)
final.cbt<-dc.MergeCustomers(tot.cbt, freq.cbt)
birth.periods<-split.data$cust.data$birth.per
last.dates<-split.data$cust.data$last.date
end.of.time <- as.Date('2011-12-09')
final.cbs.dates<-data.frame(birth.periods, last.dates, end.of.time)
final.cbs <- dc.BuildCBSFromCBTAndDates(final.cbt,final.cbs.dates, per='day')


params<-pnbd.EstimateParameters(final.cbs)
ll<-pnbd.cbs.LL(params,final.cbs)
p.matrix<-c(params,ll)
for (i in 1:9){
  params<-pnbd.EstimateParameters(final.cbs, params)
  ll<-pnbd.cbs.LL(params, final.cbs)
  p.matrix.row<-c(params,ll)
  p.matrix<-rbind(p.matrix,p.matrix.row)
}
colnames(p.matrix)<-c("r","alpha","s","beta","LL")
rownames(p.matrix)<-1:10
p.matrix
params <- p.matrix[10,1:4]

# make predictions for each customer
days.until.next.order <- rep(0, nrow(final.cbs))
final.cbs <- cbind(final.cbs,days.until.next.order)

for (i in 1:nrow(final.cbs)){
  cust <- rownames(final.cbs)[i]
  x <- final.cbs[cust,"x"]
  t.x <- final.cbs[cust,"t.x"]
  T.cal <- final.cbs[cust,"T.cal"]
  day <- 1
  order<-0
  while (order<1 & day<100){
    order <- pnbd.ConditionalExpectedTransactions(params, T.star=day, x,t.x,T.cal)
    day <- day + 1
  }
  final.cbs[i, "days.until.next.order"] <- day
}

date.of.next.order <- end.of.time + final.cbs[,"days.until.next.order"]
results <- data.frame(final.cbs[,"days.until.next.order"], date.of.next.order)
