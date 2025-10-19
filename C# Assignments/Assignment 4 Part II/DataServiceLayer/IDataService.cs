namespace DataServiceLayer;
public interface IDataService
{

    /////////////////////////////////////////////////
    // Categories
    /////////////////////////////////////////////////

    int GetCategoriesCount();
    IList<Category> GetCategories(int page, int pageSize);
    Category? GetCategory(int id);
    void CreateCategory(Category category);
    bool UpdateCategory(Category category);
    bool DeleteCategory(int id);


    /////////////////////////////////////////////////
    // Products
    /////////////////////////////////////////////////

    int GetProductCount();
    Product? GetProduct(int id);
    IList<Product> GetProducts(int page, int pageSize);
    IList<ProductSearchModel> GetProductByName(string search);
    IList<Category> GetCategoriesByName(string name);
}
