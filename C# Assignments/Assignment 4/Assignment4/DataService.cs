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
}




    
   

