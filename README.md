# Validation Module-ES-R

End-to-End Meter Data Management (MDM) 
This module creates a data bridge in R environment from Elastic Search.
The data pulled (metered data) from an Index is unnested, formatted, tested against some tests (tests list given in excel) in R.
Two data tables are formed-
1. Validated data
2. Flagged/Erroneous data

Both datasets are pushed in Validated & Erroneous Index respectively. The validated data can be used for analysis while erroneous data can help identify the issues with the present data collection system.
