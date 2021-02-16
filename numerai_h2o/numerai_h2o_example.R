library(h2o)
library(Metrics)
library(tidyverse)

setwd("/media/larrydag/Storage_2TB/Documents/Rscripts/Numerai/")

dataDir <- "./numerai_datasets/"

#### initiate h2o 
h2o.init("localhost", nthreads = -1, max_mem_size = "8g")



### import data to h2o
pathToTrain <- paste0(getwd(),"/numerai_datasets/numerai_training_data.csv")
pathToTest <- paste0(getwd(),"/numerai_datasets/numerai_tournament_data.csv")
train.hex <- h2o.importFile(path = pathToTrain)
# tournament.hex <- h2o.importFile(path = pathToTest)


##### model variable names
modelvars <- names(train.hex)[grep("feature", names(train.hex))]

##### target variable name
targetvar <- "target"

### model training parameters
SEEDVAL <- 12345


#### split into devel and valid sets
train.split <- h2o.splitFrame(data = train.hex, ratios=0.75,seed = SEEDVAL)
train.dev <- train.split[[1]]
train.val <- train.split[[2]]

nrow(train.dev)
nrow(train.val)

#### fit Gradient Boosted Machine model
fitGBM <- h2o.gbm(x=modelvars, y=targetvar, training_frame = train.dev
                  , ntrees = 30
                  , min_rows = 100
                  , learn_rate = 0.05
                  , distribution = "AUTO")


### model predictions
pred.gbm.dev <- h2o.predict(fitGBM, newdata=train.dev)
pred.gbm.val <- h2o.predict(fitGBM, newdata=train.val)


### convert to data.frame format 
modelpred.dev <- as.data.frame(pred.gbm.dev)
modelpred.val <- as.data.frame(pred.gbm.val)

### add target variable
modelpred.dev$target <- as.numeric(as.vector(train.dev[[targetvar]]))
modelpred.val$target <- as.numeric(as.vector(train.val[[targetvar]]))


### model evaluation
perf.gbm.dev <- h2o.performance(model = fitGBM, newdata=train.dev)
perf.gbm.val <- h2o.performance(model = fitGBM, newdata=train.val)

h2o.rmse(perf.gbm.dev)
h2o.rmse(perf.gbm.val)



#### evaluate models for Numerai #####

### convert to vector
eraindex <- as.vector(train.dev[["era"]])
eras <- unique(eraindex)

### correlation across eras
eracorr <- lapply(eras, function(i) cor(modelpred.dev[eraindex==i,c("target","predict")], method="spearman")[2,1] )
names(eracorr) <- eras

eramean.dev <- mean(unlist(eracorr))
erasd.dev <- sd(unlist(eracorr))
erasharpe.dev <- eramean.dev/erasd.dev

### validation split
eraindex <- as.vector(train.val[["era"]])
eras <- unique(eraindex)

eracorr <- lapply(eras, function(i) cor(modelpred.val[eraindex==i,c("target","predict")], method="spearman")[2,1] )
names(eracorr) <- eras

eramean.val <- mean(unlist(eracorr))
erasd.val <- sd(unlist(eracorr))
erasharpe.val <- eramean.dev/erasd.dev


# show performance
data.frame(type=c("DEVEL","VALID")
           ,eramean=c(eramean.dev, eramean.val)
           ,erasharpe=c(erasharpe.dev,erasharpe.val)
)

# plot performance
barplot(unlist(eracorr), main="correlation to target")
abline(h=0.002, col="blue", lty=2)
grid()



###### Validation data correlation by era #####

## import data to h2o server
tournament.hex <- h2o.importFile(path = pathToTest)

validation <- tournament.hex[as.vector(h2o.which(tournament.hex[["data_type"]]=="validation")),]

### predict with GBM model
valpredict <- h2o.predict(fitGBM, newdata=validation)
valpredict <- as.data.frame(valpredict)
valpredict$target <- as.numeric(as.vector(validation[[targetvar]]))

### performance across eras
eraindex <- as.vector(validation[["era"]])
eras <- unique(eraindex)

eracorr <- lapply(eras, function(i) cor(valpredict[eraindex==i,c("target","predict")], method="spearman")[2,1] )
names(eracorr) <- eras

eramean <- mean(unlist(eracorr))
erasd <- sd(unlist(eracorr))
erasharpe <- eramean/erasd
eramean
erasharpe

### plot by era
barplot(unlist(eracorr), main="correlation to target")
abline(h=0.002, col="blue", lty=2)
grid()


###### score tournament file ######

pred.gbm.tourn <- h2o.predict(fitGBM, newdata=tournament.hex)

pred <- data.frame(id=as.vector(tournament.hex[["id"]]), prediction=as.vector(pred.gbm.tourn[["predict"]]) )

# Save the predictions out to a CSV file
write.csv(pred, file="submission.csv", quote=F, row.names=F)
