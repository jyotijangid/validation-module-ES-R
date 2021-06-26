# Validation Module-ES-R

EV Industry (Electrical Vehicle) deals with a lot of meter data. This meter data can be from home charging as well as public charging stations.
This meter data has a lot of information regarding a charging session i.e. charging duration, energy consumed, voltage during session, power factor, 
no of times a particular EV charges in a day. All of this information is very important for CPOs (Charge Point Operators) (who maintains the public charging stations)
and Electrical Utilities (in case of home charging). The errors in metered data tell the shortcomings/faults with the meters and hence very useful to 
identify faulty meters. 

This Module helps us track the faulty devices by applying some tests/checks/validations defined by CPOs/Electrical Utilities/MSPs (Metering service provider).

It is an End-to-End Meter Data Management (MDM) System.
The procedure provides market participants and their metering service providers (MSPs) with the process for data collection and validation of
revenue metering data for the purpose of settlements. 
The procedure includes:
? recording and collecting revenue metering data;
? validating, estimating, and editing revenue metering data;
? processing meter trouble reports (MTRs) to investigate potential problems with revenue meters

This module creates a data bridge in R environment from Elastic Search.
The data pulled (metered data) from an Index is unnested, formatted, tested against some tests (tests list given in excel) in R.
Two data tables are formed-
1. Validated data
2. Flagged/Erroneous data

Both datasets are pushed in Validated & Erroneous Index respectively. The validated data can be used for analysis while erroneous data can help identify the issues with the present data collection system.

Below are two protocols in the EV Industry which helps establish communication among different parties:

OCPP (Open Charge Point Protocol) is the global open communication protocol between the charging station and the central system of the charging station operator.         
OCPI (Open Charge Point Interface) is an open protocol between operators and service providers.
