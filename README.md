# sql-server-streaming-to-power-bi
**Short description:** Realtime streaming data to Power BI on insert of new data in SQL table using trigger and asynchronous message queue

**Work in progress!**

Solution files are for **Visual Studio 2022** and SQL Server 2022 on prem or Azure SQL Managed Instance.

## Requirements
As soon as new data is inserted in a table on a SQL Server, e.g. production output of a machine, updated data shall be shown in Power BI, e.g. the production progress vs. total ordered quantity vs. scrap quantity per active production order.
* The impact on the INSERT performance should be minimal, i.e. no long blocking of further INSERTs
* The delay between INSERT and visualization in Power BI should be minimal
* The overhead load on the SQL Server, e.g. through constant polling of SQL tables for new data, should be minimal

## Solution
Each new INSERT also puts a short message on an asynchroneous message queue to signal an update for Power BI. Then the INSERT transaction is done and further processing is done asynchronously.

The solution consists of these building blocks:
* A SQL Server Service Broker message queue
* An AFTER INSERT trigger to add a message with just the ID of the last inserted row to the message queue
* A consumer stored procedure to process the messages in the message queue, prepare the data for Power BI and send the data to Power BI
* Message queue ACTIVATION to constantly watch and automatically process new messages in the message queue
* A C# CLR stored procedure to handle the web API communication with Power BI and send the JSON payload containing the new values to Power BI
