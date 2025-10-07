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
        if (string.IsNullOrWhiteSpace(request.Method))
        {
            _issues.Add("Missing method");
        }
        
        else if (!_arrayOfCorrectMethods.Contains(request.Method))
        {
            _issues.Add("Illegal method");
        }
        
        // Path validation
        if (string.IsNullOrWhiteSpace(request.Path))
        {
            _issues.Add("Missing path");
        }
        else if (!request.Path.StartsWith("/"))
        {
            _issues.Add("Invalid path");
        }
        
        // Date validation
        long.TryParse(request.Date, out long dateNum); // Converting date to long
        
        if (string.IsNullOrWhiteSpace(request.Date))
        {
            _issues.Add("Missing date");
        } 
        else if (!long.TryParse(request.Date.Trim(), out _))
        {
            // If it cannot parse as a long integer (Unix seconds), it's illegal
           _issues.Add("Illegal date");
        }

        bool IsBodyValidJson(string input)
        {
            try
            {
                using var doc =JsonDocument.Parse(input);
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
                _issues.Add("Missing body");
            }
            else if (!IsBodyValidJson(request.Body))
            {
                _issues.Add("Illegal body");
            }
        }

        else if (request.Method.ToLower() == "echo")
        {
            if (string.IsNullOrEmpty(request.Body))
            {
                _issues.Add("Missing body");
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