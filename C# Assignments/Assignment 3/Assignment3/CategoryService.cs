using System.Collections.Generic;
using System.ComponentModel.Design;

namespace Assignment3;

public class CategoryService
{
    private List<Category> _categories = new List<Category>()
    {
        new Category { Cid = 1, Name = "Beverage" },
        new Category { Cid = 2, Name = "Condiments" },
        new Category { Cid = 3, Name = "Confections" }
    };

    public Category GetCategory(int id)
    {
        return _categories.Find(c => c.Cid == id);
    }

    public bool UpdateCategory(int id, string newName)
    {
        var receiveCategory = GetCategory(id);
        if (receiveCategory == null) return false;
        receiveCategory.Name = newName;
        return true;
    }

    public bool DeleteCategory(int id)
    {
        var receiveCategory = GetCategory(id);
        if (receiveCategory == null) return false;
        _categories.Remove(receiveCategory);
        return true;
    }

    public bool CreateCategory(int id, string newName)
    {
        if (GetCategory(id) != null) return false;
        _categories.Add(new Category { Cid = id, Name = newName });
        return true;
    }
    
}