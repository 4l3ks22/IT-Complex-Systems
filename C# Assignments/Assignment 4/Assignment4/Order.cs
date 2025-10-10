using System.Collections.ObjectModel;

namespace Assignment4;

public class Order
{
    public int Id { get; set; }
    public  DateTime Date { get; set; }  //date type
    public DateTime Require { get; set; } //date type for requireddate
    public DateTime Shipped { get; set; } //date type
    public int Freight { get; set; }
    public string ShipName { get; set; }
    public string ShipCity { get; set; }


}