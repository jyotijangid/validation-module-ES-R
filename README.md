# Validation Module-ES-R

EV Industry (Electrical Vehicle) deals with a lot of meter data. This meter data can be from home charging as well as public charging stations. This meter data has a lot of information regarding a charging session i.e. charging duration, energy consumed, voltage during session, power factor, no of times a particular EV charges in a day. All of this information is very important for CPOs (Charge Point Operators) (who maintains the public charging stations and Electrical Utilities (in case of home charging). The errors in metered data tell the shortcomings/faults with the meters and hence very useful to identify faulty meters. <br />
<br />
This Module helps us track the faulty devices by applying some tests/checks/validations defined by CPOs/Electrical Utilities/MSPs (Metering service provider). <br />
<br />
This module helps in creating an End-to-End Meter Data Management (MDM) System.<br />
The procedure provides market participants and their metering service providers (MSPs) with the process for data collection and validation of revenue metering data for the purpose of settlements.<br /> 
<br />
The procedure includes:<br />
1. recording and collecting revenue metering data;<br />
2. validating, estimating, and editing revenue metering data (VEE Process);<br />
3. processing meter trouble reports (MTRs) to investigate potential problems with revenue meters.<br />
<br />

This module creates a data bridge in R environment from Elastic Search.<br />
The data is pulled (metered data) from an Index is then unnested, formatted, and validated against some tests (tests list given in excel) in R.<br />
Two data tables are formed-<br />
1. Validated data<br />
2. Flagged/Erroneous data<br />
<br />
Both datasets are pushed in Validated & Erroneous Index respectively. The validated data can be used for analysis while erroneous data can help identify the issues with the present data collection system.<br />
<br />
Below are two protocols in the EV Industry which helps establish communication among different parties:<br />
1. OCPP (Open Charge Point Protocol) is the global open communication protocol between the charging station and the central system of the charging station operator. <br />      2. OCPI (Open Charge Point Interface) is an open protocol between operators and service providers.<br />
<br/>
![Data Flow](https://user-images.githubusercontent.com/71806907/123522068-9cfc6a00-d6d8-11eb-92fc-924a18939b47.png)


