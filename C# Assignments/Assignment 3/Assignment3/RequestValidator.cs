using System.Collections.Generic;
using System.Linq;
using System.Text.Json;

namespace Assignment3;

public class RequestValidator
{
    private string[] _arrayOfCorrectMethods = { "create", "read", "update", "delete", "echo" };
    
    private List<string> _issues = new List<string>();

    public Response ValidateRequest(Request? request)
    {   
        // Request validation
        if (request == null)
        {
            return new Response("4 Missing method, missing path, missing date");
        }
       
        // Method validation
        if (string.IsNullOrEmpty(request.Method))
        {
            _issues.Add("missing method");
            return new Response("missing method");
        }
        
        else if (!_arrayOfCorrectMethods.Contains(request.Method))
        {
            _issues.Add("illegal method");
        }
        
        // Path validation
        if (string.IsNullOrWhiteSpace(request.Path))
        {
            _issues.Add("missing path");
        }
        else if (!request.Path.StartsWith("/"))
        {
            _issues.Add("invalid path");
        }
        
        // Date validation
        long.TryParse(request.Date, out long dateResult); // Converting date to long
        
        if (string.IsNullOrWhiteSpace(request.Date))
        {
            _issues.Add("missing date");
        } 
        else if (!long.TryParse(request.Date.Trim(), out _))
        {
            // If it cannot parse as a long integer (Unix seconds), it's illegal
           _issues.Add("illegal date");
        }

        bool IsValidJson(string input)
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
                _issues.Add("missing body");
            }
            else if (!IsValidJson(request.Body))
            {
                _issues.Add("illegal body");
            }
        }

        else if (request.Method.ToLower() == "echo")
        {
            if (string.IsNullOrEmpty(request.Body))
            {
                _issues.Add("missing body");
            }
        }
        
        return _issues.Any() ? new Response($"4 {string.Join(", ", _issues)}") : new Response("1 Ok");
    }
}
