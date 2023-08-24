using System;
using System.Collections;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using System.Xml;
using Microsoft.SqlServer.Server;

public partial class StoredProcedures
{
    [Microsoft.SqlServer.Server.SqlProcedure]
    public static int spSendPowerBiStream(SqlDouble InValue)
    {
        ServicePointManager.Expect100Continue = true;
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
        // SecurityProtocolType.Tls
        // SecurityProtocolType.Tls11
        // SecurityProtocolType.Tls12
        // SecurityProtocolType.Tls13
        // SecurityProtocolType.Ssl3

        HttpWebRequest request = (HttpWebRequest)WebRequest.Create("https://api.powerbi.com/beta/2a2f93a6-7909-4927-a199-65308b2c2f7e/datasets/6e2e060f-d19b-4e55-aa84-b0653c337fe5/rows?experience=power-bi&key=6D0dLei5cIW4XfRIehMDWTf2UJvXH4zkRv3fbEorW7XEH%2FvlKE20yOTEBWN%2FrL7GZDYtYC%2FTtmPkiBoQaFppOA%3D%3D");

        request.Method = "POST";
        request.Credentials = CredentialCache.DefaultCredentials;
        request.ContentType = "application/json";

        string parameterValue;

        if (InValue.IsNull) 
        {
            parameterValue = "0";
        }
        else
        {
            parameterValue = InValue.ToString();
        }

        var postData = @"
                [
                    {
                        ""ProductionOrderNumber"" :""AAAAA555555"",
                        ""CurrentQuantity"" :" + parameterValue + @",
                        ""TargetQuantity"" :100,
                        ""ScrapQuantity"" :50,
                        ""timestamp"" :""2023-08-22T21:29:47.085Z""
                    }
                ]
            ";
        var payload = Encoding.ASCII.GetBytes(postData);
        request.ContentLength = payload.Length;

        using (var stream = request.GetRequestStream())
        {
            stream.Write(payload, 0, payload.Length);
        }

        var response = (HttpWebResponse)request.GetResponse();

        var responseString = new StreamReader(response.GetResponseStream()).ReadToEnd();

        return 0;
    }
}
