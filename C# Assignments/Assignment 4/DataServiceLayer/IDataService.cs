namespace Assignment4;

public interface IDataService
{
    public interface IDataService
    {
        // Category related methods
        List<Category> GetCategories();
        Category GetCategory(int categoryId);
        Category CreateCategory(string name, string description);
        bool DeleteCategory(int categoryId);
        bool UpdateCategory(int categoryId, string name, string description);

        // Product related methods
        Product GetProduct(int productId);
        List<Product> GetProductByCategory(int categoryId);
        List<Product> GetProductByName(string nameSubString);

        // Order related methods
        Order GetOrder(int orderId);
        List<Order> GetOrders();
    
        // OrderDetails related methods
        List<OrderDetails> GetOrderDetailsByOrderId(int orderId);
        List<OrderDetails> GetOrderDetailsByProductId(int productId);
    }
}