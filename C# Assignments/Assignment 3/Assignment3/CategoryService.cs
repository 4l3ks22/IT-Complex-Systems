using System.Collections.Generic;
using System.ComponentModel.Design;

namespace Assignment3;

public class CategoryService
{
    private List<Category> _categories = new List<Category>()
    {
        new Category { Id = 1, Name = "Beverage" },
        new Category { Id = 2, Name = "Condiments" },
        new Category { Id = 3, Name = "Confections" }
    };

    public List<Category> GetCategories()
    {
        return _categories;
    }

    public Category GetCategory(int id)
    {
        return _categories.Find(c => c.Id == id);
    }

    public bool UpdateCategory(int id, string newName)
    {
        var receivedCategory = GetCategory(id);
        if (receivedCategory == null) return false;
        receivedCategory.Name = newName;
        return true;
    }

    public bool DeleteCategory(int id)
    {
        var receivedCategory = GetCategory(id);
        if (receivedCategory == null) return false;
        _categories.Remove(receivedCategory);
        return true;
    }

    public bool CreateCategory(int id, string newName)
    {
        if (GetCategory(id) != null) return false;
        _categories.Add(new Category { Id = id, Name = newName });
        return true;
    }
    
}