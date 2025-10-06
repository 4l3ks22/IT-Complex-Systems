using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices.Marshalling;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Assignment3;

public class RequestValidator
{
    private string[] _arrayOfCorrectMethods = { "create", "read", "update", "delete", "echo" };

    private Dictionary<int, string> _status = new Dictionary<int, string>()
    {
        { 1, "Ok" },
        { 2, "Created" },
        { 3, "Updated" },
        { 4, "Bad Request" },
        { 5, "Not Found" },
        { 6, "Error" }
    };
    
    private List<string> _issues = new List<string>();

    public Response ValidateRequest(Request request)
    {   
        // Request validation
        if (request == null)
        {
            return new Response("4 Missing method, missing path, missing date");
        }
       
        // Method validation
        if (request.Method.ToLower() == "")
        {
            _issues.Add("4 Missing method");
        }
        
        else if (!_arrayOfCorrectMethods.Contains(request.Method))
        {
            _issues.Add("4 Illegal method");
        }
        
        // Path validation
        if (request.Path == "")
        {
            _issues.Add("4 Missing path");
        }
        else if (request.Path.StartsWith("/"))
        {
            _issues.Add("4 Invalid path");
        }
        
        // Date validation
        long.TryParse(request.Date, out long dateNum); // Converting date to long
        
        if (request.Date == "")
        {
            _issues.Add("4 Missing date");
        } 
        
        else if (dateNum > 0)
        {
            try
            {
                var date = DateTimeOffset.FromUnixTimeSeconds(dateNum);
            }
            catch (Exception e)
            {
                _issues.Add("4 Illegal date");
            }
        }

        bool IsBodyValidJson(string input)
        {
            try
            {
                JsonDocument.Parse(input);
                return true;
            }
            catch
            {
                return false;
            }
        }

        // Body validation
        if (request.Method.ToLower() == "create" || request.Method.ToLower() =="update")
        {
            if (string.IsNullOrEmpty(request.Body))
            {
                _issues.Add("4 Missing body");
            }
            else if (!IsBodyValidJson(request.Body))
            {
                _issues.Add("4 Illegal body");
            }
        }

        else if (request.Method.ToLower() == "echo")
        {
            if (string.IsNullOrEmpty(request.Body))
            {
                _issues.Add("4 Missing body");
            }
        } 
        
        if (_issues.Count == 0 )
            return new Response("1 Ok");
        else
        {
            return new Response($"4 {string.Join(", ", _issues)}");
        }
    }
}