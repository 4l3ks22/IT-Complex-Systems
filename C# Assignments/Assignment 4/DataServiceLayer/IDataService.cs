namespace DataServiceLayer
{
    public interface IDataService
    {
        // Category related methods
        List<Category> GetCategories(int page, int pagesize);
        Category GetCategory(int categoryId);
        
        Category CreateCategory(string name, string description);
        Category CreateCategory(Category category);

        bool DeleteCategory(int categoryId);
        bool UpdateCategory(int categoryId, string name, string description);
        int GetCategoriesCount();

        // Product related methods
        Product GetProduct(int productId);
        int GetProductCount(); 
        List<Product> GetProducts(int page, int pageSize);
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