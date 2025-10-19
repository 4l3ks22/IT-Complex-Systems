using DataServiceLayer;
using Mapster;
using MapsterMapper;
using Microsoft.AspNetCore.Mvc;
using WebServiceLayer.Models;

namespace WebServiceLayer.Controllers;

[Route("api/categories")]
[ApiController]
public class CategoriesController : BaseController
{

    public CategoriesController(
        IDataService dataService,
        LinkGenerator generator,
        IMapper mapper) : base(dataService, generator, mapper)
    {
       
    }

    [HttpGet(Name = nameof(GetCategories))]
    public IActionResult GetCategories([FromQuery] QueryParams queryParams)
    {
        queryParams.PageSize = Math.Min(queryParams.PageSize, 3);

        var categories = _dataService.GetCategories(queryParams.Page, queryParams.PageSize)
            .Select(x => CreateCategoryModel(x));

        var numOfItems = _dataService.GetCategoriesCount();

        var result = CreatePaging(nameof(GetCategories), categories, numOfItems, queryParams);

        return Ok(result);
    }

    [HttpGet("{id}", Name = nameof(GetCategory))]
    public IActionResult GetCategory(int id)
    {
        var category = _dataService.GetCategory(id);

        if (category == null)
        {
            return NotFound();
        }

        var model = CreateCategoryModel(category);

        return Ok(model);
    }

    

    [HttpPost]
    public IActionResult CreateCategory(CreateCategoryModel creationModel)
    {
        var category = creationModel.Adapt<Category>();

        _dataService.CreateCategory(category);

        return Created();
    }

    [HttpDelete("{id}")]
    public IActionResult DeleteCategory(int id)
    {
        if (_dataService.DeleteCategory(id))
        {
            return NoContent();
        }

        return NotFound();
    }

    private CategoryModel CreateCategoryModel(Category category)
    {
        var model = _mapper.Map<CategoryModel>(category);
        model.Url = GetUrl(nameof(GetCategory), new { id = category.Id });
        return model;
    }
}
