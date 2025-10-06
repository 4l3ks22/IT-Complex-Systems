using System;

namespace Assignment3
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Hello Web Service :-)");
            try
            {
                Console.WriteLine(DateTimeOffset.FromUnixTimeSeconds(-521531225151351511));
            }
            catch (Exception e)
            {
                Console.WriteLine(e);
                throw;
            }

        }
    }
}
