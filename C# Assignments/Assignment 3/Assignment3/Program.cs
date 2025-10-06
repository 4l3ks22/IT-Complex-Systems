using System;

namespace Assignment3
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Hello Web Service :-)");
            var categoryService = new CategoryService();
            var test_cat = categoryService.GetCategory(2);
            Console.WriteLine($"Category: {test_cat.Cid}, {test_cat.Name}");
        }
    }
}
