using DataServiceLayer;
using Microsoft.EntityFrameworkCore;

public class DataService : IDataService
{

    private readonly string? _connectString;
    public DataService()
    {
    }
    public DataService(string? connectString)
    {
        _connectString = connectString;
    }
    
    DatabaseContext db = new();

    public List<Category> GetCategories()
    {
        return db.Categories.ToList();
    }

    public List<Category> GetCategories(int page, int pageSize)
    {
        return db.Categories
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToList();
    }

    public int GetCategoriesCount()
    {
        return db.Categories.Count();
    }

    public Category GetCategory(int categoryId)
    {
        var category = db.Categories.FirstOrDefault(x => x.Id == categoryId);
        return category;
    }

    public Category CreateCategory(string name, string description)
    {
        var id = db.Categories.Max(x => x.Id) + 1; // id is not auto incremented, have to manually do it by checking max value and adding 1
        var category = new Category{Id = id, Name = name, Description = description };
        db.Categories.Add(category);
        db.SaveChanges();
        return category;
    }
    
    public Category CreateCategory(Category category)
    {
        db.Categories.Add(category);
        db.SaveChanges();
        return category;
    }


    public bool DeleteCategory(int categoryId)
    {
        var category = GetCategory(categoryId);
        if (category == null) return false;
        
        db.Categories.Remove(category);
        db.SaveChanges();
        return true;
    }

    public bool UpdateCategory(int categoryId, string name, string description)
    {
        var category = GetCategory(categoryId);
        if (category == null) return false;
        
        category.Name = name;
        category.Description = description;
        db.SaveChanges();
        return true;
    }

    public int GetProductCount()
    {
        return db.Products.Count();
    }
    
    public Product GetProduct(int productId)
    {
        return db.Products
            .Include(p => p.Category)
            .FirstOrDefault(p => p.Id == productId);
    }
    
    public List<Product> GetProducts(int page, int pageSize)
    {
        return db.Products
            .Include(p => p.Category)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToList();
    }


    public List<Product> GetProductByCategory(int categoryId)
    {
        var products = db.Products
            .Include(p => p.Category)
            .Where(p => p.CategoryId == categoryId)
            .ToList();
        
        // Populate CategoryName property
        foreach (var product in products)
        {
            if (product.Category != null)
            {
                product.CategoryName = product.Category.Name;
            }
        }
        
        return products;
    }

    public List<Product> GetProductByName(string nameSubString)
    {
        return db.Products
            .Where(p => p.Name.Contains(nameSubString))
            .ToList();
    }

    public Order GetOrder(int orderId)
    {
        return db.Orders
            .Include(o => o.OrderDetails)
                .ThenInclude(od => od.Product)
                    .ThenInclude(p => p.Category)
            .FirstOrDefault(o => o.Id == orderId);
    }

    public List<Order> GetOrders()
    {
        return db.Orders.ToList();
    }
    
    public List<OrderDetails> GetOrderDetailsByOrderId(int orderId)
    {
        return db.OrderDetails
            .Include(od => od.Order)
            .Include(od => od.Product)
            .Where(od => od.OrderId == orderId)
            .ToList();
    }

    public List<OrderDetails> GetOrderDetailsByProductId(int productId)
    {
        return db.OrderDetails
            .Include(od => od.Order)
            .Include(od => od.Product)
            .Where(od => od.ProductId == productId)
            .ToList();
    }
}