using Microsoft.EntityFrameworkCore;

namespace DataServiceLayer;

public class DataService : IDataService
{
    private readonly string? _connectString;

    public DataService(string? connectString)
    {
        _connectString = connectString;
    }

    /////////////////////////////////////////////////
    // Categories
    /////////////////////////////////////////////////

    public int GetCategoriesCount()
    {
        var db = new NorthwindContext(_connectString);
        return db.Categories.Count();
    }

    public IList<Category> GetCategories(int page, int pageSize)
    {
        var db = new NorthwindContext(_connectString);
        return db.Categories
            .OrderBy(x => x.Id)
            .Skip(page * pageSize)
            .Take(pageSize)
            .ToList();
    }

    public Category? GetCategory(int id)
    {
        var db = new NorthwindContext(_connectString);
        return db.Categories.FirstOrDefault(x => x.Id == id);
    }

    public void CreateCategory(Category category)
    {
        var db = new NorthwindContext(_connectString);
        var maxId = db.Categories.Max(x => x.Id);
        category.Id = maxId + 1;
        db.Categories.Add(category);
        db.SaveChanges();
    }

    public bool UpdateCategory(Category category)
    {
        var db = new NorthwindContext(_connectString);
        db.Update(category);
        return db.SaveChanges() > 0;
    }

    public bool DeleteCategory(int id)
    {
        var db = new NorthwindContext(_connectString);
        var category = db.Categories.Find(id);
        if ((category == null))
        {
            return false;
        }
        db.Categories.Remove(category);
        return db.SaveChanges() > 0;
    }
    public IList<Category> GetCategoriesByName(string name)
    {
        var db = new NorthwindContext(_connectString);
        return db.Categories.Where(x => x.Name.ToLower().Contains(name.ToLower())).ToList();
    }

    /////////////////////////////////////////////////
    // Products
    /////////////////////////////////////////////////

    public int GetProductCount()
    {
        var db = new NorthwindContext(_connectString);
        return db.Products.Count();
    }

    public IList<Product> GetProducts(int page, int pageSize)
    {
        var db = new NorthwindContext(_connectString);
        return db.Products
            .Include(x => x.Category)
            .OrderBy(x => x.Id)
            .Skip(page* pageSize)
            .Take(pageSize)
            .ToList();
    }

    public Product? GetProduct(int id)
    {
        var db = new NorthwindContext(_connectString);
        return db.Products.Include(x => x.Category).FirstOrDefault(x => x.Id == id);
    }

    public IList<ProductSearchModel> GetProductByName(string search)
    {
        var db = new NorthwindContext(_connectString);

        return db.Products
            .Where(x => x.Name.ToLower().Contains(search.ToLower()))
            .ToList()
            .Select(x => new ProductSearchModel { ProductName = x.Name, CategoryName = x.Category.Name })
            .ToList();
    }

}