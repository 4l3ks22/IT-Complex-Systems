using DataServiceLayer;
using MapsterMapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Reflection.Emit;
using WebServiceLayer.Models;

namespace WebServiceLayer.Controllers;

[Route("api/products")]
[ApiController]
public class ProductsController : BaseController
{
    public ProductsController(
        IDataService dataService,
        LinkGenerator generator, 
        IMapper mapper) : base(dataService, generator, mapper)
    {
       
    }

    [HttpGet(Name = nameof(GetProducts))]
    public IActionResult GetProducts([FromQuery] QueryParams queryParams)
    {
        var products = _dataService
            .GetProducts(queryParams.Page, queryParams.PageSize)
            .Select(x => CreateProductListModel(x));

        var numOfItems = _dataService.GetProductCount();

        var result = CreatePaging(nameof(GetProducts), products, numOfItems, queryParams);

        return Ok(result);
    }

    

    [HttpGet("{id}", Name = nameof(GetProduct))]
    public IActionResult GetProduct(int id)
    {
        var product = _dataService.GetProduct(id);
        if (product == null)
        {
            return NotFound();
        }
        return Ok(CreateProductModel(product));
    }


    private ProductModel CreateProductModel(Product product)
    {
        var model = _mapper.Map<ProductModel>(product);
        model.Url = GetUrl(nameof(GetProduct), new { id = product.Id });
        model.CategoryUrl = GetUrl(nameof(CategoriesController.GetCategory), new { product.Category.Id});
        return model;
    }

    private ProductListModel CreateProductListModel(Product product)
    {
        var model = _mapper.Map<ProductListModel>(product);
        model.Url = GetUrl(nameof(GetProduct), new { id = product.Id });
        model.CategoryUrl = GetUrl(nameof(CategoriesController.GetCategory), new { product.Category.Id });
        return model;
    }
}
