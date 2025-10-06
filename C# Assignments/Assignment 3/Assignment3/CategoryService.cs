using System.Collections.Generic;

namespace Assignment3;

public class CategoryService
{
    private List<Category> _categories = new List<Category>()
    {
        new Category{Cid = 1, Name = "Beverage"},
        new Category{Cid = 2, Name = "Condiments"},
        new Category{Cid = 3, Name = "Confections"}
    };
    
    public Category GetCategory(int id)
    {
        return _categories.Find(c => c.Cid == id);
    }
}