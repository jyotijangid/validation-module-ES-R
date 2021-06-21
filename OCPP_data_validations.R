# ------------------------------ Preparing the R script ---------------------------------------------------------------------------------------------------------- 

# Cleaning up the files
rm(list=ls())

# Reading Libraries
library(elasticsearchr)
library(tidyr)
library(data.table)
library(dplyr)
library(jsonlite)
library(xml2)
library(elastic)
library(reshape2)
library(lubridate)
library(datasets)

#.......... Define a Date Range ..................

gte <- as.POSIXct(ymd_hms("2021-04-26 10:10:00", tz = "GMT")) 
lte <- as.POSIXct(ymd_hms("2021-05-20 10:10:00", tz = "GMT"))

# 1. --------------------------- Establish a connection between R and ES ----------------------------------------------------------------

# Production
es_host <- "elastic-search-host"

#Staging
es_host <- "elastic-search-host"

es_port <- 443
es_transport_schema <- "https"
es_user <- "xxxx"
es_pwd <- "***********"

# URL 
es_url <- paste(es_transport_schema,"://",es_user,":",es_pwd,"@",es_host,":", es_port, sep="")

# query to get data in a range
for_scaling <- query('{
"bool": {
      "must": [
        {
          "range": {
            "meterValue.timestamp": {
              "gte": "2021-04-01T00:00:00Z",
              "lte": "2021-05-19T09:12:00Z"
            }
          }
        }
      ]
    }
}')

# connection
data <- elastic(es_url, "ocpp_external_metervalues_1") %search% (for_scaling)

class(data)
View(data)

#............Getting data in proper format 

ocpp_data <- unnest(unnest(data,meterValue), sampledValue) # unlisting/flattening the dataframe
ocpp_data <- data.table(ocpp_data)[, time_UTC := as.POSIXct(gsub("\\.[0-9]+Z", "", timestamp), format="%Y-%m-%dT%H:%M:%S", tz="GMT")]
View(ocpp_data)

#............Master Data ocpp_data_1

ocpp_data_1 <- ocpp_data[, c("producer","transactionId","time_UTC","value","measurand")]
# format data
ocpp_data_1 <-  distinct(ocpp_data_1, time_UTC, transactionId, producer, measurand, .keep_all = TRUE) # remove all duplicate data points
ocpp_data_1 <- dcast(ocpp_data_1, transactionId + time_UTC + producer ~ measurand, value.var = "value") # Decasting


#convert the datatype of columns
ocpp_data_1 <- data.table(ocpp_data_1)[, `:=` (time_UTC = time_UTC,
                                               Current.Import = as.numeric(Current.Import),
                                               Energy.Active.Import.Register = as.numeric(Energy.Active.Import.Register),
                                               Power.Active.Import = as.numeric(Power.Active.Import),
                                               SoC = as.numeric(SoC))]


ocpp_data_1 <- ocpp_data_1 %>%
  group_by(transactionId) %>%
  arrange(time_UTC) %>%
  mutate(diff_time = time_UTC - lag(time_UTC, default = first(time_UTC)),
         diff_Energy = Energy.Active.Import.Register - lag(Energy.Active.Import.Register, default = first(Energy.Active.Import.Register)),
         diff_SoC = SoC - lag(SoC, default = first(SoC)))

View(ocpp_data_1)

#............ specify a date range 

ocpp_data_2 <- data.table(ocpp_data_1)[ time_UTC > gte | time_UTC < lte, ]
View(ocpp_data_2)
#write.csv(ocpp_data_2, 'C:/Users/Lenovo/Desktop/Elocity onedrive/OneDrive - Elocity Technologies India Private Limited/ocpp_data.csv')

# 2. --------------------------- Data Exploratory Part -------------------------------------------------------------------------------------------------

# a) Transaction wise aggregation 

transId_ocpp_data <- ocpp_data_2 %>% 
  group_by( producer, transactionId) %>%
  dplyr::summarise(
    start_timesatmp = dplyr::first(time_UTC),
    end_timestamp = dplyr::last(time_UTC),
    Current.Import = max(na.omit(Current.Import)),
    Energy.Active.Import.Register = last(Energy.Active.Import.Register) - first(Energy.Active.Import.Register),
    Power.Active.Import = max(na.omit(Power.Active.Import)),
    SoC = last(SoC) - first(SoC),
    duration_min = round((last(time_UTC) - first(time_UTC))/60, 2)
  )

transId_ocpp_data <- data.table(transId_ocpp_data)[, duration_min :=  as.numeric(duration_min)]
View(transId_ocpp_data)


# ....................................................... Reporting ....................................................................................................................


# a. EVSE trans wise

EVSE_Trans_wise <- transId_ocpp_data[, c("producer", "transactionId", "Energy.Active.Import.Register", "duration_min")]
EVSE_Trans_wise <- data.table(EVSE_Trans_wise)[, ROC := round(Energy.Active.Import.Register*60/duration_min, 2) ]
View(EVSE_Trans_wise)

# b. Trans Wise

Trans_Wise <- EVSE_Trans_wise[, c("transactionId", "Energy.Active.Import.Register", "duration_min","ROC")]
View(Trans_Wise)


# c. EVSE Wise
EVSE_wise <- setDT(EVSE_Trans_wise)[, `:=`(Total_Energy = sum(Energy.Active.Import.Register),
                                   Total_Time_min = sum(duration_min),
                                   No_of_Trans = .N ), by=producer]
EVSE_wise <- unique( EVSE_wise[ , c(1,6,7,8) ])
View(EVSE_wise)

ggplot()+
  geom_bar(aes(y=Total_Energy, 
               x= producer),
           data = EVSE_wise,
           stat = "identity", col = "black")



# d. Daywise - EVSE - Transaction

EVSE_Day_wise <- ocpp_data_2 %>% 
  group_by(producer, transactionId, time_UTC = cut(time_UTC, breaks= "1 day")) %>%
  summarise(
    Energy = sum(Energy.Active.Import.Register),
    Time_min = as.numeric(sum(diff_time/60))
  )

EVSE_Day_wise <- EVSE_Day_wise %>% 
  group_by(producer, time_UTC) %>%
  summarise(
    Total_Energy = sum(Energy),
    Total_Time_min = round(sum(Time_min), 2),
    No_of_Trans = n()
  )
  
View(EVSE_Day_wise)

# e. Daywise

Day_wise <- ocpp_data_2 %>% 
  group_by(time_UTC = cut(time_UTC, breaks= "1 day")) %>%
             summarise(Total_Energy = sum(diff_Energy),
                       Total_Time_min = round(sum(diff_time)/60, 2))

View(Day_wise)

ggplot()+
  geom_bar(aes(y=Total_Energy, 
                 x= time_UTC),
             data = Day_wise,
             stat = "identity", col = "black") + theme(axis.text.x = element_text(angle = 45, hjust = 1))

# 3. --------------------------- get the VALIDATIONS and apply ----------------------------------------------------------------------------------------

# read the validations file
validations <- fread('C:/Users/Lenovo/Desktop/Elocity onedrive/OneDrive - Elocity Technologies India Private Limited/validations.csv')

final_validations <- validations[apply == 1, ]
View(final_validations)

tests <- final_validations$`Validation ID`
tests

######### Validations and Flagging

ocpp_data_2 <- data.table(ocpp_data_2)

    # 1. Current Spike/ Current drop #final_validations[ `Validation ID`==1, max_threshold ] 
      Test_1 <- data.table(ocpp_data_2)[, Error_Flag := ifelse( Current.Import > 10 | Current.Import < final_validations[ `Validation ID`==1, mini_threshold ], 1, "" )]
      View(Test_1)
      
      # 2. Power Spike/ Power drop #final_validations[ `Validation ID`==2, max_threshold ]
      Test_2 <- data.table(ocpp_data_2)[, Error_Flag := ifelse( Power.Active.Import > 2000 | Power.Active.Import < final_validations[ `Validation ID`== 2, mini_threshold ] , 2, "")]
      View(Test_2)
      
      # 3. Current Energy less than previous Energy
      Test_3 <- data.table(ocpp_data_2)[, Error_Flag := ifelse(diff_Energy < 0, 3, "")]
      View(Test_3)
      
      
      # 4. Current SoC is less than previous SoC
      Test_4 <- data.table(ocpp_data_2)[, Error_Flag := ifelse(diff_SoC < 0, 4, "")]
      View(Test_4)
      
      # 5. Energy NA/Negative 
      Test_5 <- data.table(ocpp_data_2)[, Error_Flag := ifelse( Energy.Active.Import.Register < 0 | is.na(Energy.Active.Import.Register), 5, "")]
      View(Test_5)
      
      # 6. Power NA/Negative 
      Test_6 <- data.table(ocpp_data_2)[, Error_Flag := ifelse( Power.Active.Import < 0 | is.na(Power.Active.Import), 6, "")]
      View(Test_6)
      
      # 7. Energy NA/Negative 
      Test_7 <- data.table(ocpp_data_2)[, Error_Flag := ifelse( Current.Import < 0 | is.na(Current.Import), 7, "")]
      View(Test_7)
      
      # 8. Energy NA/Negative 
      Test_8 <- data.table(ocpp_data_2)[, Error_Flag := ifelse( SoC < 0 | is.na(SoC), 8, "")]
      View(Test_8)      

# Create an empty file
Final_Error_File <- data.table(producer = character(),
                               transactionId = integer(),
                               time_UTC = POSIXct(),
                               Current.Import = numeric() ,
                               Energy.Active.Import.Register = numeric(),
                               SoC = numeric(),
                               Power.Active.Import = numeric(),
                               Error_Flag =character())

View(Final_Error_File)
list_All_Error = lapply(ls(pattern = "Test_[1-8]$"), get)
length(list_All_Error)

### Combine all the tests to get one Error File
for (i in tests) {
  if (nrow(list_All_Error[[i]])>0) {
    Error_file <- list_All_Error[[i]][, c(1:7,11)]
    Final_Error_File <- merge(Final_Error_File, Error_file, by = c("producer", "transactionId", "time_UTC","Current.Import", "Energy.Active.Import.Register", "SoC", "Power.Active.Import"), all = TRUE)
    Final_Error_File <- Final_Error_File[, Error_Flag := (ifelse(is.na(Error_Flag.x), as.character(Error_Flag.y) ,
                                                                 ifelse(is.na(Error_Flag.y), as.character(Error_Flag.x), 
                                                                        paste(as.character(Error_Flag.x),as.character(Error_Flag.y),sep = ""))))]
    Final_Error_File <- Final_Error_File[, c("producer", "transactionId", "time_UTC","Current.Import","Energy.Active.Import.Register","Power.Active.Import","SoC","Error_Flag")]
  } else {
    print(paste("No Error File Found for:", names(list_All_Error[i])))
  }
}

Final_Error_File <- Final_Error_File[, Error_Flag := vapply(strsplit(Error_Flag, ""), function(x) paste(x, collapse=", "), character(1L))]
View(Final_Error_File)


###................ Data with No Error_Flag

validated_ocpp_data <- Final_Error_File[Error_Flag == "",]
validated_ocpp_data <- validated_ocpp_data[, c(1:7)]
View(validated_ocpp_data)

### ................ Data with Error_Flag

erroneous_ocpp_data <- Final_Error_File[Error_Flag != "",]
View(erroneous_ocpp_data)


# 4. --------------------------- DUMPING data in Passed & Failed Indexes of ES ------------------------------------------------------------------

conn <- connect(host = es_host, port = es_port, transport_schema = es_transport_schema,
             user = es_user, pwd = es_pwd)

# Validated data in validated index
docs_bulk(
  conn,
  validated_ocpp_data,
  index = "validated_ocpp_data",
  type = NULL,
  chunk_size = 1000,
  doc_ids = NULL,
  es_ids = TRUE,
  raw = FALSE,
  quiet = FALSE,
  query = list(),
  digits = NA
)

# Erroreneous data in erroreneous index
docs_bulk(
  x,
  erroneous_ocpp_data,
  index = "erroneous_ocpp_data",
  type = NULL,
  chunk_size = 1000,
  doc_ids = NULL,
  es_ids = TRUE,
  raw = FALSE,
  quiet = FALSE,
  query = list(),
  digits = NA
)

help("elastic")


cat_(x)
cat_indices(x)
cat_fielddata(x)
cat_nodes(x)
cluster_health(x)
