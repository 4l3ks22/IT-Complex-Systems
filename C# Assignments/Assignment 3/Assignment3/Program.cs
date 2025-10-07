using System;
using System.Text.Json;
using System.Text.Json.Serialization;
namespace Assignment3
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Hello Web Service :-)");
            var request = new Request();
            if (request == null)
            {
                Console.WriteLine("Request is null");
            }
            Console.WriteLine(request);
            string json = JsonSerializer.Serialize(request, new JsonSerializerOptions
            {
                WriteIndented = true
            });

            Console.WriteLine(json);
        }
    }
}
