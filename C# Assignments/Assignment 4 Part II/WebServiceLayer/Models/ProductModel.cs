using DataServiceLayer;

namespace WebServiceLayer.Models;

public class ProductModel
{
    public string? Url { get; set; }
    public string Name { get; set; }

    public int UnitPrice { get; set; }

     public string? CategoryName { get; set; }
    public string? CategoryUrl { get; set; }
}
