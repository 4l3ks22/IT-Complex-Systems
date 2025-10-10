using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Assignment4;
using Microsoft.EntityFrameworkCore;


public class DataService
{
    DatabaseContext db = new();
    public List<Category> GetCategories()
    {
        return db.Categories.ToList();
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

    public void DeleteCategory(int categoryId)
    {
        db.Categories.Remove(GetCategory(categoryId));
        db.SaveChanges();
        GetCategory(categoryId);
    }

    public void UpdateCategory(int categoryId)
    {
        db.Categories.Update(GetCategory(categoryId));
        db.SaveChanges();
        
    }
}




    
   

